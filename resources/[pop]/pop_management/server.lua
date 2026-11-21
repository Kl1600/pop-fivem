print('^2[LAPTOP] Chargement du script serveur...^0')

Config = Config or {}
GlobalState.style80s = (Config.Style == '80s')
Config.DeliveryTime = Config.DeliveryTime or (60 * 60 * 1000)
Config.EnableDeliverySystem = Config.EnableDeliverySystem ~= false -- Default true unless explicitly false

ESX = nil

-- Méthode 1 : exports (ESX Legacy)
local success, result = pcall(function()
    return exports["es_extended"]:getSharedObject()
end)

if success and result then
    ESX = result
    print('^2[LAPTOP] ESX chargé via exports^0')
else
    -- Méthode 2 : TriggerEvent (ESX ancien)
    print('^3[LAPTOP] Tentative de chargement ESX via TriggerEvent...^0')
    TriggerEvent('esx:getSharedObject', function(obj) 
        ESX = obj 
        print('^2[LAPTOP] ESX chargé via TriggerEvent^0')
    end)
end

-- =============================================
-- CATALOGUES SERVEUR (prix de référence)
-- Les prix sont lus depuis les fichiers NUI (html/config.js, html/app.js) pour
-- ne jamais faire confiance au prix envoyé par le client.
-- =============================================
local RES = GetCurrentResourceName()
local CarCatalog, YouToolCatalog = {}, {}

do
    local carsJs = LoadResourceFile(RES, 'html/config.js') or ''
    local starts = {}
    for pos, model in carsJs:gmatch("()model:%s*'([^']+)'") do
        starts[#starts + 1] = { pos = pos, model = model:lower() }
    end
    for i, s in ipairs(starts) do
        local seg = carsJs:sub(s.pos, (starts[i + 1] and starts[i + 1].pos - 1) or #carsJs)
        local price = tonumber(seg:match('price:%s*(%d+)'))
        if price then
            CarCatalog[s.model] = { price = price, job = seg:match("job:%s*'([^']+)'") }
        end
    end

    local appJs = LoadResourceFile(RES, 'html/app.js') or ''
    local block = appJs:match('const youToolConfig%s*=%s*(%b{})') or ''
    for line in block:gmatch('[^\n]+') do
        local model = line:match("model:%s*'([^']+)'")
        local price = tonumber(line:match('price:%s*(%d+)'))
        if model and price then
            local label = line:match("label:%s*'(.-)',%s*price")
            YouToolCatalog[model] = { price = price, label = label and label:gsub("\\'", "'") or model }
        end
    end
end

local function isBossJob(job)
    return Config.DevMode or (job and job.grade_name == 'boss')
end

local function scalarAwait(query, params)
    local p = promise.new()
    exports.oxmysql:scalar(query, params, function(v) p:resolve(v or false) end)
    return Citizen.Await(p) or nil
end

-- Même règle que l'affichage "isBoss" de l'app Gouv
local function isGouvBoss(job)
    if Config.DevMode then return true end
    if not job or job.name ~= 'gouv' then return false end
    local g = job.grade_name
    return g == 'boss' or g == 'adjoint' or g == 'secretaire' or g == 'maire' or g == 'president' or (tonumber(job.grade) or 0) >= 3
end

local function escapeHtml(s)
    return (tostring(s or ''):gsub('[<>]', { ['<'] = '&lt;', ['>'] = '&gt;' }))
end

-- Attendre que ESX soit chargé
Citizen.CreateThread(function()
    local attempts = 0
    while ESX == nil and attempts < 100 do
        Citizen.Wait(100)
        attempts = attempts + 1
    end
    
    if ESX then
        print('^2[LAPTOP] ESX chargé avec succès après '.. (attempts * 100) ..'ms^0')
    else
        print('^1[LAPTOP] ERREUR: ESX n\'a pas pu être chargé!^0')
    end
end)

-- =============================================
-- AUTO-CREATION DE LA TABLE YOUTOOL_ORDERS & THREADS
-- =============================================
CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `youtool_orders` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `society` VARCHAR(50) NOT NULL,
            `item_model` VARCHAR(50) NOT NULL,
            `item_label` VARCHAR(100) NOT NULL,
            `quantity` INT NOT NULL,
            `price` INT NOT NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `delivery_time` TIMESTAMP NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Colonnes ajoutées pour le système job YouTool : le commettant (client)
    -- qui doit récupérer sa commande au Port, et son nom affiché dans l'app job.
    -- On vérifie via information_schema (ADD COLUMN IF NOT EXISTS n'existe pas sur
    -- MySQL 5.7/8.0 et faisait échouer l'INSERT -> commandes non enregistrées).
    local function ensureColumn(tableName, columnName, definition)
        exports.oxmysql:execute(
            "SELECT COUNT(*) AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?",
            { tableName, columnName },
            function(rows)
                if rows and rows[1] and tonumber(rows[1].c) == 0 then
                    exports.oxmysql:execute(("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(tableName, columnName, definition))
                end
            end
        )
    end

    ensureColumn('youtool_orders', 'user_identifier', 'VARCHAR(50) DEFAULT NULL')
    ensureColumn('youtool_orders', 'customer_name', 'VARCHAR(100) DEFAULT NULL')
    ensureColumn('youtool_orders', 'cart_items', 'TEXT DEFAULT NULL') -- JSON des articles d'un panier (1 panier = 1 carton)
    -- Livraison physique par le livreur GoPostal (checklist + blip vers le client/PNJ bot)
    ensureColumn('youtool_orders', 'delivery_coords', 'VARCHAR(64) DEFAULT NULL') -- "x,y,z" capturé à la commande
    ensureColumn('youtool_orders', 'assigned_to', 'VARCHAR(50) DEFAULT NULL') -- identifier du livreur qui a validé/pris le colis
    ensureColumn('youtool_orders', 'is_bot', 'TINYINT(1) NOT NULL DEFAULT 0') -- commande PNJ générée automatiquement
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `dealership_orders` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `user_identifier` VARCHAR(60) DEFAULT NULL,
            `society` VARCHAR(50) DEFAULT NULL,
            `vehicle_model` VARCHAR(60) NOT NULL,
            `vehicle_color` VARCHAR(30) DEFAULT NULL,
            `ordered_at` INT NOT NULL DEFAULT 0,
            `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
            `customer_name` VARCHAR(100) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_status` (`status`),
            KEY `idx_user` (`user_identifier`)
        )
    ]], {}, function()
        ensureColumn('dealership_orders', 'customer_name', 'VARCHAR(100) DEFAULT NULL')
    end)
    -- Casiers (pop_inventory) : matricule = numéro de casier de l'employé pour son job
    -- actuel, code_casier = code à 4 chiffres demandé pour ouvrir le casier d'un collègue.
    ensureColumn('users', 'matricule', 'INT DEFAULT NULL')
    ensureColumn('users', 'code_casier', 'VARCHAR(4) DEFAULT NULL')

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `tab_settings` (
            `setting_key` VARCHAR(50) NOT NULL,
            `setting_value` VARCHAR(255) NOT NULL,
            PRIMARY KEY (`setting_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        exports.oxmysql:scalar('SELECT setting_value FROM tab_settings WHERE setting_key = ?', {'tva'}, function(value)
            if value then
                GlobalState.tva = tonumber(value) or 20
                print('^2[LAPTOP] TVA chargee depuis la DB: '..GlobalState.tva..'%^0')
            else
                GlobalState.tva = 20
                exports.oxmysql:execute('INSERT INTO tab_settings (setting_key, setting_value) VALUES (?, ?)', {'tva', '20'})
                print('^2[LAPTOP] TVA initialisee a 20%^0')
            end
        end)
    end)
end)

-- Un joueur est staff YouTool s'il a le job EN PRINCIPAL ou EN JOB2 (les
-- intérimaires GoPostal passent par xPlayer.setJob2(), voir pop_interim).
local function isYouToolStaff(xPlayer)
    if not xPlayer then return false end
    local jobName = Config.YouToolJob or 'youtool'
    local job = xPlayer.getJob()
    if job and job.name == jobName then return true end
    local ok, job2 = pcall(function() return xPlayer.getJob2() end)
    if ok and job2 and job2.name == jobName then return true end
    return false
end

-- Notifie tous les employés du job YouTool (nouvelle commande, etc.)
local function notifyYouToolStaff(payload)
    local xPlayers = ESX.GetPlayers()
    for i = 1, #xPlayers, 1 do
        local xTarget = ESX.GetPlayerFromId(xPlayers[i])
        if isYouToolStaff(xTarget) then
            TriggerClientEvent('cr-laptop:notifyLogo', xTarget.source, payload)
        end
    end
end

local function countYouToolStaffOnline()
    local count = 0
    local xPlayers = ESX.GetPlayers()
    for i = 1, #xPlayers, 1 do
        if isYouToolStaff(ESX.GetPlayerFromId(xPlayers[i])) then
            count = count + 1
        end
    end
    return count
end

-- Retrouve le spot bot (et son modèle de PNJ) correspondant à des coords
-- "x,y,z" déjà stockées en DB, pour spawn le bon PNJ côté client.
local function findBotSpotByCoords(x, y, z)
    for _, spot in ipairs(Config.YouToolBotSpots or {}) do
        local d = math.sqrt((spot.pos.x - x)^2 + (spot.pos.y - y)^2 + (spot.pos.z - z)^2)
        if d < 1.0 then return spot end
    end
    return nil
end

-- Periodic thread to transition pending orders to ready
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        local success, result = pcall(function()
            -- Timer de SECOURS : si aucun employé YouTool n'a validé la commande, elle
            -- passe quand même en 'ready' après Config.YouToolDeliveryTime pour que le
            -- client puisse la récupérer au Port. (La validation, elle, est instantanée.)
            exports.oxmysql:execute("SELECT * FROM youtool_orders WHERE status = ? AND delivery_time <= NOW() AND is_bot = 0", {'pending'}, function(pendingOrders)
                if pendingOrders and #pendingOrders > 0 then
                    for _, order in ipairs(pendingOrders) do
                        exports.oxmysql:execute('UPDATE youtool_orders SET status = ? WHERE id = ?', {'ready', order.id}, function(rowsChanged)
                            local affected = type(rowsChanged) == 'table' and rowsChanged.affectedRows or rowsChanged
                            if affected and affected > 0 then
                                TriggerClientEvent('pop_management:shelfRefresh', -1) -- carton plus "pending"
                            end
                            if affected and affected > 0 and order.user_identifier then
                                -- Notifie le client (commettant) : commande prête au Port
                                local xCust = ESX.GetPlayerFromIdentifier(order.user_identifier)
                                if xCust then
                                    TriggerClientEvent('cr-laptop:notifyLogo', xCust.source, {
                                        image = "nui://pop_management/html/gopostal.png",
                                        title = "GoPostal",
                                        message = "Votre commande (" .. order.quantity .. "x " .. order.item_label .. ") est <span style='color:#2ecc71; font-weight:bold;'>prête</span> au Port !",
                                        duration = 10000
                                    })
                                    TriggerClientEvent('pop_management:client:refreshMyOrders', xCust.source)
                                end
                            end
                        end)
                    end
                end
            end)
        end)
        if not success then
            print('[LAPTOP] error checking youtool orders:', result)
        end
    end
end)

-- Commandes "bot" (cas de figure 3) : toutes les Config.YouToolBotInterval ms,
-- si au moins un livreur est en ligne, génère une commande PNJ (carton sur
-- l'étagère + livraison vers un PNJ éphémère sur un des spots configurés).
-- ignoreStaffCheck = true : utilisé par la commande dev /ytbot pour tester
-- seul, sans avoir besoin d'un 2e joueur en job/job2 youtool connecté.
local function generateBotOrder(ignoreStaffCheck)
    if not (Config.YouToolBotSpots and #Config.YouToolBotSpots > 0) then
        print('[YouTool][bot] aucun spot configuré (Config.YouToolBotSpots).')
        return
    end
    if not (Config.YouToolBotCatalog and #Config.YouToolBotCatalog > 0) then
        print('[YouTool][bot] aucun article configuré (Config.YouToolBotCatalog).')
        return
    end
    if not ignoreStaffCheck and countYouToolStaffOnline() <= 0 then
        print('[YouTool][bot] aucun livreur (job/job2 youtool) en ligne, commande non générée.')
        return
    end

    local spot = Config.YouToolBotSpots[math.random(#Config.YouToolBotSpots)]
    local item = Config.YouToolBotCatalog[math.random(#Config.YouToolBotCatalog)]
    local deliverySeconds = math.floor((Config.YouToolDeliveryTime or 120000) / 1000)
    local coordsStr = ('%.2f,%.2f,%.2f'):format(spot.pos.x, spot.pos.y, spot.pos.z)

    exports.oxmysql:execute(
        'INSERT INTO youtool_orders (society, item_model, item_label, quantity, price, status, delivery_time, user_identifier, customer_name, delivery_coords, is_bot) VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?, ?, ?, 1)',
        {
            'bot',
            item.model,
            item.label,
            1,
            0,
            'pending',
            deliverySeconds,
            nil,
            spot.label or 'Client GoPostal',
            coordsStr
        },
        function(insertId)
            print(('[YouTool][bot] commande générée id=%s item=%s spot=%s'):format(tostring(insertId), tostring(item.label), tostring(spot.label)))
            TriggerClientEvent('pop_management:shelfRefresh', -1)
            notifyYouToolStaff({
                image   = "nui://pop_management/html/gopostal.png",
                title   = "Livraisons GoPostal",
                message = "Nouvelle commande PNJ : <span style='color:#e67e22; font-weight:bold;'>" .. item.label .. "</span> à livrer.",
                duration = 8000
            })
        end
    )
end

CreateThread(function()
    if not Config.YouToolBotEnabled then return end

    while true do
        Wait(Config.YouToolBotInterval or (5 * 60 * 1000))
        local ok, err = pcall(generateBotOrder, false)
        if not ok then
            print('[LAPTOP] error generating bot youtool order:', err)
        end
    end
end)

-- Commande DEV : force la génération immédiate d'une commande PNJ (sans
-- attendre l'intervalle, sans exiger un 2e joueur livreur en ligne).
RegisterCommand('ytbot', function(source)
    if source ~= 0 and not Config.DevMode then return end
    local ok, err = pcall(generateBotOrder, true)
    if not ok then
        print('[LAPTOP] /ytbot error:', err)
    end
end, false)

-- Ready orders callback for client spawning
ESX.RegisterServerCallback('pop_management:getReadyYouToolOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    local societyName = xPlayer.getJob().name
    exports.oxmysql:execute('SELECT * FROM youtool_orders WHERE society = ? AND status = ?', {societyName, 'ready'}, function(orders)
        cb(orders or {})
    end)
end)

-- Colis EN ATTENTE pour l'étagère du Port (cartons physiques). Public (pas de
-- gate job) : tout le monde voit les cartons posés, mais seul le livreur peut
-- les prendre (vérif côté validateYouToolOrder + ox_target).
ESX.RegisterServerCallback('pop_management:getShelfColis', function(source, cb)
    exports.oxmysql:execute("SELECT id, item_label, quantity FROM youtool_orders WHERE status = 'pending' ORDER BY id ASC LIMIT 50", {}, function(rows)
        local out = {}
        for _, o in ipairs(rows or {}) do
            out[#out + 1] = { id = o.id, label = o.item_label, qty = o.quantity }
        end
        cb(out)
    end)
end)

-- Claim order event
RegisterNetEvent('pop_management:claimYouToolOrder')
AddEventHandler('pop_management:claimYouToolOrder', function(orderId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then
        print(('[YouTool][claim] xPlayer nil pour src=%s'):format(tostring(_source)))
        return
    end

    -- Le retrait se fait par le CLIENT (commettant) qui a passé la commande, au Port.
    local identifier = xPlayer.getIdentifier()

    exports.oxmysql:execute('SELECT * FROM youtool_orders WHERE id = ? AND user_identifier = ? AND status = ?', {orderId, identifier, 'ready'}, function(orders)
        if not (orders and orders[1]) then
            print(('[YouTool][claim] ordre introuvable (id=%s id=%s status=ready)'):format(tostring(orderId), tostring(identifier)))
            TriggerClientEvent('cr-laptop:notify', _source, 'Cette commande n\'est pas disponible.')
            -- Re-sync le client pour qu'il retire le blip si la commande n'existe plus côté serveur
            TriggerClientEvent('pop_management:client:claimYouToolOrderSuccess', _source, orderId)
            return
        end

        local order = orders[1]
        exports.oxmysql:execute('UPDATE youtool_orders SET status = ? WHERE id = ? AND status = ?', {'delivered', orderId, 'ready'}, function(rowsChanged)
            local affected = type(rowsChanged) == 'table' and rowsChanged.affectedRows or rowsChanged
            if not (affected and affected > 0) then
                print(('[YouTool][claim] UPDATE delivered a échoué (id=%s affected=%s)'):format(tostring(orderId), tostring(affected)))
                return
            end

            -- Décoder le panier multi-articles si présent (1 panier = 1 carton)
            local boxItems
            if order.cart_items and order.cart_items ~= '' then
                local ok2, decoded = pcall(json.decode, order.cart_items)
                if ok2 and decoded then
                    boxItems = {}
                    for _, it in ipairs(decoded) do
                        table.insert(boxItems, { defId = tostring(it.model or ''), qty = math.max(1, tonumber(it.quantity) or 1) })
                    end
                end
            end
            if not boxItems then
                boxItems = { { defId = order.item_model, qty = order.quantity } }
            end

            -- L'export peut renvoyer `true` ou `false, err`. Si la fonction
            -- crash en interne on récupère nil — on traite ça comme un échec.
            local ok, success, err = pcall(function()
                return exports['pop_inventory']:GiveCardboardBoxWithItems(_source, boxItems, false)
            end)

            if ok and success then
                TriggerClientEvent('pop_management:shelfRefresh', -1) -- retire le carton de l'étagère
                TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez pris le carton avec les articles commandés.')
                TriggerClientEvent('pop_management:client:claimYouToolOrderSuccess', _source, orderId)
                TriggerClientEvent('pop_management:client:refreshMyOrders', _source)
            else
                local errMsg = (not ok and tostring(success))
                    or (type(err) == 'string' and err)
                    or 'inventaire plein ou export indisponible'
                TriggerClientEvent('cr-laptop:notify', _source, 'Erreur lors de la récupération : ' .. errMsg)
                -- Revert order status back to ready
                exports.oxmysql:execute('UPDATE youtool_orders SET status = ? WHERE id = ?', {'ready', orderId})
                -- IMPORTANT: re-sync le client pour qu'il sache que la commande est de retour à 'ready'
                TriggerClientEvent('pop_management:client:refreshMyOrders', _source)
            end
        end)
    end)
end)

-- =============================================
-- APP "LIVRAISONS YOUTOOL" (réservée au job youtool)
-- =============================================

-- Liste unifiée des commandes (véhicules + colis) en attente de traitement,
-- pour l'app du job YouTool. Inclut pending (à valider) + ready (validée, en
-- attente de retrait par le client).
ESX.RegisterServerCallback('pop_management:getYouToolJobOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isYouToolStaff(xPlayer) then
        print(('[YouTool][jobOrders] accès refusé pour src=%s (job/job2 attendu=%s).'):format(tostring(source), tostring(Config.YouToolJob or 'youtool')))
        return cb({})
    end

    -- Les deux requêtes tournent indépendamment : si l'une échoue (table/colonne
    -- absente), l'autre renvoie quand même ses commandes. cb() est appelé une fois
    -- les deux terminées.
    local result = {}
    local remaining = 2
    local function finish()
        remaining = remaining - 1
        if remaining <= 0 then
            cb(result)
        end
    end

    exports.oxmysql:execute("SELECT id, vehicle_model, vehicle_color, customer_name, user_identifier, status, ordered_at FROM dealership_orders WHERE status IN ('pending','ready') ORDER BY ordered_at DESC LIMIT 50", {}, function(veh)
        for _, o in ipairs(veh or {}) do
            result[#result + 1] = {
                type     = 'vehicle',
                id       = o.id,
                label    = o.vehicle_model,
                qty      = 1,
                customer = o.customer_name or o.user_identifier or '?',
                status   = o.status,
                orderedAt = o.ordered_at or 0
            }
        end
        finish()
    end)

    exports.oxmysql:execute("SELECT id, item_label, quantity, customer_name, user_identifier, status, UNIX_TIMESTAMP(created_at) AS created_at FROM youtool_orders WHERE status IN ('pending','ready') ORDER BY created_at DESC LIMIT 50", {}, function(pkg)
        for _, o in ipairs(pkg or {}) do
            result[#result + 1] = {
                type     = 'package',
                id       = o.id,
                label    = o.item_label,
                qty      = o.quantity,
                customer = o.customer_name or o.user_identifier or '?',
                status   = o.status,
                orderedAt = o.created_at or 0
            }
        end
        finish()
    end)
end)

-- Validation par un employé YouTool.
--  * COLIS : le carton (avec les items dedans) arrive DIRECTEMENT dans les mains de
--    l'employé qui valide (il le livre ensuite). La commande est marquée 'delivered'.
--  * VÉHICULE : passe en 'ready' pour que le client le récupère au Port.
RegisterNetEvent('pop_management:validateYouToolOrder')
AddEventHandler('pop_management:validateYouToolOrder', function(orderType, orderId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if not isYouToolStaff(xPlayer) then
        local job = xPlayer.getJob()
        local ok2, job2 = pcall(function() return xPlayer.getJob2() end)
        print(('[YouTool][validate] refusé src=%s job=%s job2=%s (attendu=%s)'):format(
            tostring(_source),
            tostring(job and job.name),
            tostring(ok2 and job2 and job2.name),
            tostring(Config.YouToolJob or 'youtool')
        ))
        TriggerClientEvent('cr-laptop:notify', _source, "Tu n'es pas employé GoPostal (job/intérim youtool).")
        return
    end

    if orderType == 'vehicle' then
        exports.oxmysql:execute("SELECT * FROM dealership_orders WHERE id = ? AND status = 'pending'", {orderId}, function(rows)
            if not (rows and rows[1]) then
                TriggerClientEvent('cr-laptop:notify', _source, 'Commande introuvable ou déjà validée.')
                return
            end
            local order = rows[1]
            exports.oxmysql:execute("UPDATE dealership_orders SET status = 'ready' WHERE id = ?", {orderId}, function(rc)
                local affected = type(rc) == 'table' and rc.affectedRows or rc
                if not (affected and affected > 0) then return end
                if order.user_identifier then
                    local xCust = ESX.GetPlayerFromIdentifier(order.user_identifier)
                    if xCust then
                        TriggerClientEvent('cr-laptop:notifyLogo', xCust.source, {
                            image = "nui://pop_management/html/46001a-12.webp",
                            title = "GoPostal",
                            message = "Votre <span style='color:#ECA95D;'>" .. order.vehicle_model .. "</span> est <span style='color:#2ecc71; font-weight:bold;'>prêt</span> au Port !",
                            duration = 10000
                        })
                        TriggerClientEvent('pop_management:client:refreshMyOrders', xCust.source)
                    end
                end
                TriggerClientEvent('cr-laptop:notify', _source, 'Véhicule validé — prêt au Port pour le client.')
            end)
        end)
        return
    end

    -- COLIS : carton remis à l'employé YouTool qui valide
    exports.oxmysql:execute("SELECT * FROM youtool_orders WHERE id = ? AND status = 'pending'", {orderId}, function(rows)
        if not (rows and rows[1]) then
            TriggerClientEvent('cr-laptop:notify', _source, 'Commande introuvable ou déjà validée.')
            return
        end
        local order = rows[1]

        -- Décoder le panier multi-articles si présent (1 panier = 1 carton)
        local boxItems
        if order.cart_items and order.cart_items ~= '' then
            local ok2, decoded = pcall(json.decode, order.cart_items)
            if ok2 and decoded then
                boxItems = {}
                for _, it in ipairs(decoded) do
                    table.insert(boxItems, { defId = tostring(it.model or ''), qty = math.max(1, tonumber(it.quantity) or 1) })
                end
            end
        end
        if not boxItems then
            boxItems = { { defId = order.item_model, qty = order.quantity } }
        end

        -- Verrou anti-double validation : on réserve la commande AVANT de donner le carton.
        local courierIdentifier = xPlayer.getIdentifier()
        exports.oxmysql:execute("UPDATE youtool_orders SET status = 'delivered', assigned_to = ? WHERE id = ? AND status = 'pending'", {courierIdentifier, orderId}, function(lock)
        local locked = type(lock) == 'table' and lock.affectedRows or lock
        if not (locked and locked > 0) then
            TriggerClientEvent('cr-laptop:notify', _source, 'Commande introuvable ou déjà validée.')
            return
        end

        local ok, success, err = pcall(function()
            -- doNotEquip = false -> le carton est placé dans le slot malette (briefcase)
            -- et mis directement dans les mains de l'employé par pop_inventory.
            return exports['pop_inventory']:GiveCardboardBoxWithItems(_source, boxItems, false)
        end)
        if ok and success then
            TriggerClientEvent('pop_management:shelfRefresh', -1) -- retire le carton de l'étagère
            TriggerClientEvent('cr-laptop:notify', _source, 'Carton récupéré (malette) — à livrer au client.')

            -- Coords de livraison : celles capturées à la commande (JSON "x,y,z"), sinon
            -- l'un des spots bots configurés pour une commande PNJ.
            local dx, dy, dz
            if order.delivery_coords then
                dx, dy, dz = order.delivery_coords:match('([^,]+),([^,]+),([^,]+)')
            end
            local isBot = tonumber(order.is_bot) == 1

            if dx and dy and dz then
                local pedModel = nil
                if isBot then
                    local spot = findBotSpotByCoords(tonumber(dx), tonumber(dy), tonumber(dz))
                    pedModel = spot and spot.pedModel or nil
                end
                TriggerClientEvent('pop_management:client:startDelivery', _source, {
                    orderId  = orderId,
                    label    = order.item_label,
                    coords   = { x = tonumber(dx), y = tonumber(dy), z = tonumber(dz) },
                    isBot    = isBot,
                    pedModel = pedModel
                })
            end

            if order.user_identifier then
                local xCust = ESX.GetPlayerFromIdentifier(order.user_identifier)
                if xCust then
                    TriggerClientEvent('cr-laptop:notifyLogo', xCust.source, {
                        image = "nui://pop_management/html/a68217-7.png",
                        title = "GoPostal",
                        message = "Votre commande (<span style='color:#e67e22; font-weight:bold;'>" .. order.item_label .. "</span>) est <span style='color:#2ecc71; font-weight:bold;'>en cours de livraison</span>.",
                        duration = 8000
                    })
                    TriggerClientEvent('pop_management:client:refreshMyOrders', xCust.source)
                end
            end
        else
            exports.oxmysql:execute("UPDATE youtool_orders SET status = 'pending', assigned_to = NULL WHERE id = ?", {orderId})
            local errMsg = (not ok and tostring(success)) or (type(err) == 'string' and err) or 'inventaire plein ou export indisponible'
            TriggerClientEvent('cr-laptop:notify', _source, 'Impossible de récupérer le carton : ' .. errMsg)
        end
        end)
    end)
end)

-- Fin de la livraison physique (checklist étape 3) : le livreur a remis le
-- carton au client (ou au PNJ pour une commande bot). Prime livreur + notif.
RegisterServerEvent('pop_management:completeDelivery')
AddEventHandler('pop_management:completeDelivery', function(orderId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer or not isYouToolStaff(xPlayer) then return end

    exports.oxmysql:execute("SELECT * FROM youtool_orders WHERE id = ? AND status = 'delivered' AND assigned_to = ?", {orderId, xPlayer.getIdentifier()}, function(rows)
        local order = rows and rows[1]
        if not order then return end

        -- Le livreur doit être sur le lieu de livraison
        local dx, dy, dz = tostring(order.delivery_coords or ''):match('([^,]+),([^,]+),([^,]+)')
        if dx then
            local ped = GetPlayerPed(_source)
            if ped == 0 or #(GetEntityCoords(ped) - vector3(tonumber(dx), tonumber(dy), tonumber(dz))) > 30.0 then return end
        end

        -- Prime versée une seule fois : la commande passe en 'completed'
        exports.oxmysql:execute("UPDATE youtool_orders SET status = 'completed' WHERE id = ? AND status = 'delivered'", {orderId}, function(rc)
        local affected = type(rc) == 'table' and rc.affectedRows or rc
        if not (affected and affected > 0) then return end

        local bonus = Config.YouToolDeliveryBonus or 75
        xPlayer.addMoney(bonus)
        TriggerClientEvent('cr-laptop:notify', _source, 'Livraison terminée — prime de ' .. bonus .. '$ reçue.')

        if not (tonumber(order.is_bot) == 1) and order.user_identifier then
            local xCust = ESX.GetPlayerFromIdentifier(order.user_identifier)
            if xCust then
                TriggerClientEvent('cr-laptop:notifyLogo', xCust.source, {
                    image = "nui://pop_management/html/gopostal.png",
                    title = "GoPostal",
                    message = "Votre commande (<span style='color:#e67e22; font-weight:bold;'>" .. order.item_label .. "</span>) vous a été <span style='color:#2ecc71; font-weight:bold;'>remise en main propre</span> !",
                    duration = 8000
                })
            end
        end
        end)
    end)
end)

-- Retrait au Port (commettant) : renvoie au client ses véhicules ET colis prêts.
RegisterServerEvent('pop_management:portPickup')
AddEventHandler('pop_management:portPickup', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    local identifier = xPlayer.getIdentifier()

    exports.oxmysql:execute("SELECT id, vehicle_model, vehicle_color, status FROM dealership_orders WHERE user_identifier = ? AND status IN ('ready', 'pending')", {identifier}, function(vehAll)
        exports.oxmysql:execute("SELECT id, item_label, quantity, status FROM youtool_orders WHERE user_identifier = ? AND status IN ('ready', 'pending')", {identifier}, function(pkgAll)
            local vehReady = {}
            local pkgReady = {}
            local hasPending = false

            if vehAll then
                for _, v in ipairs(vehAll) do
                    if v.status == 'ready' then table.insert(vehReady, v) else hasPending = true end
                end
            end
            if pkgAll then
                for _, p in ipairs(pkgAll) do
                    if p.status == 'ready' then table.insert(pkgReady, p) else hasPending = true end
                end
            end

            TriggerClientEvent('pop_management:openPortMenu', _source, vehReady, pkgReady, hasPending)
        end)
    end)
end)

-- Nombre de commandes actives (pending+ready) du joueur, pour le blip "Ma commande".
ESX.RegisterServerCallback('pop_management:getMyActiveOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(0) end
    local identifier = xPlayer.getIdentifier()
    exports.oxmysql:execute([[
        SELECT
            (SELECT COUNT(*) FROM dealership_orders WHERE user_identifier = ? AND status IN ('pending','ready'))
          + (SELECT COUNT(*) FROM youtool_orders   WHERE user_identifier = ? AND status IN ('pending','ready')) AS cnt
    ]], {identifier, identifier}, function(r)
        cb((r and r[1] and r[1].cnt) or 0)
    end)
end)

local societyData = {}

-- Anti-spam cooldown pour la NUI
local playerCooldowns = {}

-- Récupérer les informations d'une société
RegisterServerEvent('cr-laptop:getSocietyData')
AddEventHandler('cr-laptop:getSocietyData', function() -- Plus de paramètre societyName
    local _source = source
    
    -- Prévention spam: on limite à 1 requête toutes les 2.5 secondes par joueur 
    -- (le client attend jusqu'à 2 secondes max dans son while, on ne veut pas qu'il relance trop vite)
    local currentTime = GetGameTimer()
    if playerCooldowns[_source] and (currentTime - playerCooldowns[_source]) < 2500 then
        return
    end
    playerCooldowns[_source] = currentTime

    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    -- Le serveur détermine le job actuel (toujours à jour)
    local job = xPlayer.getJob()
    local societyName = job.name
    
    -- Si chômeur, renvoyer des données vides
    if societyName == 'unemployed' then
        TriggerClientEvent('cr-laptop:receiveSocietyData', _source, {
            money = 0,
            employees = {},
            transactions = {},
            playerGrade = 0,
            playerGradeName = 'none',
            playerGradeLabel = 'Aucun',
            societyLabel = 'Aucune entreprise',
            isBoss = false
        })
        return
    end

    local accountName = 'society_'..societyName

    -- Récupérer l'argent de la société avec un timeout : si esx_addonaccount n'a pas
    -- ce compte en mémoire (cas d'un job fraîchement créé), le callback peut ne jamais
    -- se déclencher → on bloque "Chargement..." pour toujours. Le timeout garantit
    -- qu'on continue le flow même sans réponse, via la requête SQL fallback.
    local accountResponded = false
    local function handleAccount(account)
        if accountResponded then return end
        accountResponded = true
        local money = 0
        if account then money = account.money end

        -- Fonction centralisée pour récupérer les données et les envoyer au client
        local function fetchAndSend(finalMoney)
            -- Optimisé: On ne récupère que les colonnes nécessaires et on limite à 50 employés pour éviter les packets trop gros
            exports.oxmysql:execute('SELECT identifier, firstname, lastname, job, job_grade, matricule, code_casier FROM users WHERE job = ? LIMIT 50', {societyName}, function(employees)
                exports.oxmysql:execute('SELECT * FROM society_transactions WHERE society = ? ORDER BY date DESC LIMIT 10', {'society_'..societyName}, function(transactions)
                    
                    local orderQuery = 'SELECT * FROM dealership_orders WHERE society = ? AND status != ? ORDER BY ordered_at DESC LIMIT 20'
                    local orderParams = {societyName, 'delivered'}
                    
                    if societyName == 'cardealer' then
                        orderQuery = 'SELECT * FROM dealership_orders WHERE status != ? ORDER BY ordered_at DESC LIMIT 50'
                        orderParams = {'delivered'}
                    end

                    exports.oxmysql:execute(orderQuery, orderParams, function(orders)
                        exports.oxmysql:execute('SELECT id, society, item_model, item_label, quantity, price, status, UNIX_TIMESTAMP(created_at) AS created_at, UNIX_TIMESTAMP(delivery_time) AS delivery_time FROM youtool_orders WHERE society = ? ORDER BY created_at DESC LIMIT 20', {societyName}, function(youtoolOrders)
                            -- Véhicules désactivés temporairement : "stored" est un mot réservé MariaDB/MySQL
                            -- récent qui plante la requête sans backticks. À réactiver en backtickant les
                            -- colonnes (`stored`) ou en renommant la colonne en DB.
                            local formattedVehicles = {}

                            local data = {
                                money = finalMoney,
                                employees = employees,
                                transactions = transactions,
                                orders = orders or {},
                                youtoolOrders = youtoolOrders or {},
                                serverTime = os.time(),
                                deliveryTime = Config.DeliveryTime,
                                youtoolDeliveryTime = Config.YouToolDeliveryTime or 120000,
                                vehicles = formattedVehicles,
                                playerGrade = job.grade,
                                playerGradeName = job.grade_name,
                                playerGradeLabel = job.grade_label,
                                societyName = societyName,
                                societyLabel = job.label,
                                isBoss = job.grade_name == 'boss',
                                useTabInventoryKeys = Config.UseTabInventoryKeys
                            }

                            TriggerClientEvent('cr-laptop:receiveSocietyData', _source, data)
                        end)
                    end)
                end)
            end)
        end

        if money == 0 then
            exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountName}, function(sqlMoney)
                if sqlMoney then money = sqlMoney end
                fetchAndSend(money)
            end)
        else
            fetchAndSend(money)
        end
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, handleAccount)

    -- Timeout 800ms : si esx_addonaccount n'a pas rappelé (compte introuvable, resource down,
    -- etc.), on continue quand meme avec money=0 puis lookup SQL direct.
    SetTimeout(800, function()
        if not accountResponded then
            print(('[LAPTOP] esx_addonaccount timeout pour %s, fallback DB direct'):format(accountName))
            handleAccount(nil)
        end
    end)
end)

-- Déposer de l'argent dans la société
RegisterServerEvent('cr-laptop:depositMoney')
AddEventHandler('cr-laptop:depositMoney', function(societyName, amount)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('cr-laptop:notify', _source, 'Montant invalide.')
        return
    end

    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> nécessaire.')
        return
    end

    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount)
        
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..societyName, function(account)
            if account then
                account.addMoney(amount)
                
                -- Enregistrer la transaction
                exports.oxmysql:insert('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
                    'society_'..societyName,
                    xPlayer.getName(),
                    'Dépôt',
                    amount
                })
                
                TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez déposé <span style="color:#2ecc71; font-weight:bold;">'..amount..'$</span> sur le compte.')
                TriggerEvent('cr-laptop:getSocietyData', societyName)
            end
        end)
    else
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez <span style="color:#C52622; font-weight:bold;">pas assez d\'argent</span> sur vous.')
    end
end)

-- Retirer de l'argent de la society
RegisterServerEvent('cr-laptop:withdrawMoney')
AddEventHandler('cr-laptop:withdrawMoney', function(societyName, amount)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('cr-laptop:notify', _source, 'Montant invalide.')
        return
    end

    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> nécessaire.')
        return
    end

    if not isBossJob(job) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut effectuer cette action.')
        return
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..societyName, function(account)
        if account and account.money >= amount then
            account.removeMoney(amount)
            xPlayer.addMoney(amount)
            
            -- Enregistrer la transaction
            exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
                'society_'..societyName,
                xPlayer.getName(),
                'Retrait',
                amount
            })
            
            TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez retiré <span style="color:#e74c3c; font-weight:bold;">'..amount..'$</span> du compte.')
            TriggerEvent('cr-laptop:getSocietyData', societyName)
        else
            TriggerClientEvent('cr-laptop:notify', _source, 'Le compte de l\'entreprise est <span style="color:#C52622; font-weight:bold;">insuffisant</span>.')
        end
    end)
end)

-- Commander un chéquier d'entreprise (SecuroServ) : débite le compte société et dépose
-- l'item checkbook_company (pop_inventory) dans le coffre bancaire de l'entreprise
-- (même coffre que "Compte de l'entreprise" dans pop_bank, id 'bank_company_<job>') —
-- le patron doit aller le récupérer à la banque, pas de livraison instantanée en main.
-- Item pré-marqué meta.company/companyLabel pour que chaque chèque écrit avec soit
-- reconnu comme émis par CETTE entreprise.
RegisterServerEvent('pop_management:orderCompanyCheckbook')
AddEventHandler('pop_management:orderCompanyCheckbook', function(societyName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then return end

    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> nécessaire.')
        return
    end

    local isBoss = Config.DevMode or job.grade_name == 'boss'
    if not isBoss then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut commander un chéquier d\'entreprise.')
        return
    end

    local price = Config.CompanyCheckbookPrice or 1500

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..societyName, function(account)
        if not account or account.money < price then
            TriggerClientEvent('cr-laptop:notify', _source, 'Le compte de l\'entreprise est <span style="color:#C52622; font-weight:bold;">insuffisant</span>.')
            return
        end

        account.removeMoney(price)

        exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
            'society_'..societyName,
            xPlayer.getName(),
            'Chéquier entreprise',
            -price
        })

        local ok = exports.pop_inventory:AddItemToStaticChest('bank_company_' .. job.name, 'checkbook_company', 1, {
            company = job.name,
            companyLabel = job.label,
        })

        if not ok then
            account.addMoney(price) -- coffre entreprise plein/erreur : on rembourse la société
            TriggerClientEvent('cr-laptop:notify', _source, 'Impossible de déposer le chéquier (coffre entreprise plein ?).')
            return
        end

        TriggerClientEvent('cr-laptop:notify', _source, 'Chéquier d\'entreprise commandé pour <span style="color:#e74c3c; font-weight:bold;">'..price..'$</span>. Allez le récupérer au compte de l\'entreprise à la banque.')
        TriggerEvent('cr-laptop:getSocietyData', societyName)
    end)
end)

-- Verser un salaire à un employé
RegisterServerEvent('cr-laptop:paySalary')
AddEventHandler('cr-laptop:paySalary', function(societyName, targetIdentifier, amount)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> nécessaire.')
        return
    end
    if not isBossJob(job) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut effectuer cette action.')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or type(targetIdentifier) ~= 'string' then
        TriggerClientEvent('cr-laptop:notify', _source, 'Montant invalide.')
        return
    end

    -- La cible doit être un employé de la société
    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
    if xTarget then
        if xTarget.getJob().name ~= societyName then return end
    elseif not scalarAwait('SELECT 1 FROM users WHERE identifier = ? AND job = ?', {targetIdentifier, societyName}) then
        return
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..societyName, function(account)
        if account and account.money >= amount then
            account.removeMoney(amount)

            if xTarget then
                xTarget.addAccountMoney('bank', amount)
                TriggerClientEvent('cr-laptop:notify', xTarget.source, 'Vous avez reçu un virement de <span style="color:#2ecc71; font-weight:bold;">'..amount..'$</span>.')
            else
                -- Si le joueur est hors ligne, ajouter directement à la base de données
                exports.oxmysql:execute('UPDATE users SET bank = bank + ? WHERE identifier = ?', {amount, targetIdentifier})
            end
            
            -- Enregistrer la transaction
            exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
                'society_'..societyName,
                'Salaire versé',
                'Salaire',
                -amount
            })
            
            TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez versé un salaire de <span style="color:#2ecc71; font-weight:bold;">'..amount..'$</span>.')
            TriggerEvent('cr-laptop:getSocietyData', societyName)
        else
            TriggerClientEvent('cr-laptop:notify', _source, 'Le compte de l\'entreprise est <span style="color:#C52622; font-weight:bold;">insuffisant</span>.')
        end
    end)
end)

-- Virer un employé (changer son job)
RegisterServerEvent('cr-laptop:fireEmployee')
AddEventHandler('cr-laptop:fireEmployee', function(societyName, targetIdentifier)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> nécessaire.')
        return
    end
    if not isBossJob(job) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut effectuer cette action.')
        return
    end

    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)

    if xTarget then
        if xTarget.getJob().name ~= societyName then return end
        xTarget.setJob('unemployed', 0)
        TriggerClientEvent('cr-laptop:notify', xTarget.source, 'Vous avez été <span style="color:#C52622; font-weight:bold;">licencié</span> de l\'entreprise.')
    else
        exports.oxmysql:execute('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ? AND job = ?', {
            'unemployed',
            0,
            targetIdentifier,
            societyName
        })
    end
    
    
    TriggerClientEvent('cr-laptop:notify', _source, 'L\'employé a été <span style="color:#C52622; font-weight:bold;">renvoyé</span> avec succès.')
    
    -- Forcer la mise à jour des données pour ce joueur
    -- On ré-émet l'événement getSocietyData comme si le client l'avait demandé
    -- Hack: on ne peut pas facilement appeler l'event handler avec une source différente via TriggerEvent
    -- Donc on notifie le client de refaire une demande
    TriggerClientEvent('cr-laptop:forceUpdate', _source)
end)

-- Promouvoir/Rétrograder un employé
RegisterServerEvent('cr-laptop:setGrade')
AddEventHandler('cr-laptop:setGrade', function(societyName, targetIdentifier, newGrade)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Accès au compte <span style="color:#C52622; font-weight:bold;">NON AUTORISÉ</span>')
        return
    end
    if not isBossJob(job) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut effectuer cette action.')
        return
    end

    newGrade = math.floor(tonumber(newGrade) or -1)
    if newGrade < 0 or (ESX.DoesJobExist and not ESX.DoesJobExist(societyName, newGrade)) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Grade invalide.')
        return
    end

    local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)

    if xTarget then
        if xTarget.getJob().name ~= societyName then return end
        xTarget.setJob(societyName, newGrade)
        TriggerClientEvent('cr-laptop:notify', xTarget.source, 'Votre <span style="color:#3498db; font-weight:bold;">grade</span> a été mis à jour.')
    else
        exports.oxmysql:execute('UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?', {
            newGrade,
            targetIdentifier,
            societyName
        })
    end
    
    TriggerClientEvent('cr-laptop:notify', _source, 'Grade modifié')
    TriggerClientEvent('cr-laptop:forceUpdate', _source)
end)

-- Définir le matricule (numéro de casier) et le code casier d'un employé.
-- Consommé par pop_inventory (Config.LockerRooms) via les exports plus bas.
RegisterServerEvent('cr-laptop:setEmployeeLocker')
AddEventHandler('cr-laptop:setEmployeeLocker', function(societyName, targetIdentifier, matricule, code)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then return end

    local job = xPlayer.getJob()
    if job.name ~= societyName then
        TriggerClientEvent('cr-laptop:notify', _source, 'Accès au compte <span style="color:#C52622; font-weight:bold;">NON AUTORISÉ</span>')
        return
    end

    if not isBossJob(job) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Seul le <span style="color:#C52622; font-weight:bold;">patron</span> peut effectuer cette action.')
        return
    end

    matricule = tonumber(matricule)
    code = tostring(code or ''):match('^%s*(.-)%s*$')
    if code == '' then code = nil end
    if code and not code:match('^%d%d%d%d$') then
        TriggerClientEvent('cr-laptop:notify', _source, 'Le code casier doit faire <span style="color:#C52622; font-weight:bold;">4 chiffres</span>.')
        return
    end

    exports.oxmysql:execute('UPDATE users SET matricule = ?, code_casier = ? WHERE identifier = ? AND job = ?', {
        matricule, code, targetIdentifier, societyName
    })

    TriggerClientEvent('cr-laptop:notify', _source, 'Casier de l\'employé mis à jour.')
    TriggerClientEvent('cr-laptop:forceUpdate', _source)
end)

-- =============================
-- EXPORTS CASIERS (pop_inventory)
-- =============================
-- getEmployeeLockerNumber(identifier, job, cb) -> cb(matricule|nil)
exports('getEmployeeLockerNumber', function(identifier, job, cb)
    exports.oxmysql:scalar('SELECT matricule FROM users WHERE identifier = ? AND job = ?', { identifier, job }, function(matricule)
        cb(matricule)
    end)
end)

-- checkLockerCode(job, matricule, code, cb) -> cb(true|false)
exports('checkLockerCode', function(job, matricule, code, cb)
    exports.oxmysql:scalar('SELECT code_casier FROM users WHERE job = ? AND matricule = ?', { job, matricule }, function(storedCode)
        cb(storedCode ~= nil and tostring(storedCode) == tostring(code))
    end)
end)

-- Créer la table des transactions si elle n'existe pas
-- Créer la table des transactions si elle n'existe pas
Citizen.CreateThread(function()
    Citizen.Wait(5000) -- Attendre que MySQL soit prêt
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS society_transactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            society VARCHAR(60) NOT NULL,
            player_name VARCHAR(100),
            action VARCHAR(50),
            amount INT,
            date DATETIME
        )
    ]])
    print('^2[LAPTOP] Table society_transactions créée/vérifiée^0')

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `owned_vehicles` (
            `plate` varchar(12) NOT NULL,
            `owner` varchar(60) DEFAULT NULL,
            `vehicle` longtext,
            `type` varchar(20) DEFAULT 'car',
            `job` varchar(20) DEFAULT NULL,
            `stored` tinyint(1) DEFAULT 0,
            PRIMARY KEY (`plate`)
        )
    ]])
    print('^2[LAPTOP] Table owned_vehicles créée/vérifiée^0')

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `d8_chests` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `property_id` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100),
            `x` FLOAT,
            `y` FLOAT,
            `z` FLOAT,
            `heading` FLOAT
        )
    ]])
    print('^2[LAPTOP] Table d8_chests créée/vérifiée^0')
end)

-- LOGIQUE COMMANDE VEHICULES --

RegisterServerEvent('pop_management:buyVehicle')
AddEventHandler('pop_management:buyVehicle', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    
    -- Prix et job cible lus dans le catalogue serveur (jamais ceux du client)
    if type(data) ~= 'table' or type(data.model) ~= 'string' then return end
    local carDef = CarCatalog[data.model:lower()]
    if not carDef then
        TriggerClientEvent('cr-laptop:notify', _source, 'Véhicule introuvable dans le catalogue.')
        return
    end
    local price = carDef.price
    data.targetJob = carDef.job
    data.color = tostring(data.color or 'black'):sub(1, 32)
    
    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(price * (tvaRate / 100))
    local finalPrice = price + taxAmount

    local accountName = Config.PaymentAccount or ('society_' .. job.name)
    if accountName == '' then accountName = 'society_' .. job.name end

    local targetSociety = job.name
    if data.targetJob then
        targetSociety = data.targetJob
    end

    local function processOrder()
        exports.oxmysql:insert('INSERT INTO dealership_orders (user_identifier, society, vehicle_model, vehicle_color, ordered_at, status, customer_name) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            xPlayer.getIdentifier(),
            targetSociety, -- Utilise le job cible si défini (ex: police), sinon le job de l'acheteur (cardealer)
            data.model,
            data.color,
            os.time(),
            'pending',
            xPlayer.getName()
        }, function(insertId)
            if insertId then
                if Config.YouToolValidationRequired then
                    TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                        image = "nui://pop_management/html/46001a-12.webp",
                        title = "YouTool",
                        message = "Votre commande <span style='color:#ECA95D;'>".. data.model .."</span> est <span style='color:#f39c12;'>en attente de validation</span>. Récupération au Port.",
                        duration = 7000
                    })
                else
                    local waitMinutes = math.floor(Config.DeliveryTime / 60000)
                    TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                        image = "nui://pop_management/html/46001a-12.webp",
                        title = "PDM",
                        message = "Votre <span style='color:#ECA95D;'>".. data.model .."</span> sera livrée au port dans <span style='color:#E74C3C;'>".. waitMinutes .." minutes.</span>",
                        duration = 7000
                    })
                end

                -- Notif au job YouTool : nouvelle commande véhicule à traiter
                notifyYouToolStaff({
                    image = "nui://pop_management/html/3b2d2b-3.png",
                    title = "Livraisons YouTool",
                    message = "Nouvelle commande véhicule : <span style='color:#ECA95D;'>".. data.model .."</span> pour " .. xPlayer.getName() .. ".",
                    duration = 8000
                })
                -- Le client voit son blip "Ma commande" au Port dès maintenant
                TriggerClientEvent('pop_management:client:refreshMyOrders', _source)

                exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
                    accountName,
                    xPlayer.getName(),
                    'Achat Véhicule ' .. data.model .. ' (' .. targetSociety .. ') (Incl. ' .. taxAmount .. '$ TVA)',
                    -finalPrice
                })

                -- Credit TVA to society_gouv
                if taxAmount > 0 then
                    local accountUsName = Config.GouvUSAccount or 'society_gouv'
                    TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
                        if gouvAccount then
                            gouvAccount.addMoney(taxAmount)
                        else
                            exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {taxAmount, accountUsName})
                        end
                    end)
                end

                TriggerEvent('cr-laptop:getSocietyData', job.name)
            end
        end)
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        local currentMoney = 0
        if account then currentMoney = tonumber(account.money) or 0 end

        if account and currentMoney >= finalPrice then
            account.removeMoney(finalPrice)
            processOrder()
        else
            -- Fallback SQL direct si ESX ne trouve pas le compte
            exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountName}, function(sqlMoney)
                if sqlMoney and tonumber(sqlMoney) >= finalPrice then
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {finalPrice, accountName})
                    processOrder()
                else
                    TriggerClientEvent('cr-laptop:notify', _source, 'Fonds insuffisants ou compte introuvable ('..(sqlMoney or 'NIL')..' / '..finalPrice..') sur '..accountName)
                end
            end)
        end
    end)
end)

-- Véhicules retirés au Port en attente d'enregistrement / clés (anti-injection client)
local PendingVehicleRegister = {}
local RegisteredPlates = {}
AddEventHandler('playerDropped', function()
    PendingVehicleRegister[source] = nil
    RegisteredPlates[source] = nil
    playerCooldowns[source] = nil
end)

RegisterServerEvent('pop_management:registerVehicle')
AddEventHandler('pop_management:registerVehicle', function(plate, model, society, vehicleProps)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    -- Uniquement pour un véhicule réellement retiré au Port par ce joueur
    local pending = PendingVehicleRegister[_source]
    if not pending or pending.society ~= society or type(plate) ~= 'string' or #plate > 12 then return end
    PendingVehicleRegister[_source] = nil
    RegisteredPlates[_source] = plate:upper()

    -- On définit le propriétaire : society_police, society_ambulance etc.
    local owner = 'society_' .. society
    
    -- INSERTION 1: Table owned_vehicles (ESX Standard)
    exports.oxmysql:insert('INSERT INTO `owned_vehicles` (`owner`, `plate`, `vehicle`, `type`, `job`, `stored`) VALUES (?, ?, ?, ?, ?, ?)', {
        owner,
        plate,
        json.encode(vehicleProps),
        'car',
        society,
        0 -- Stored 0 car le véhicule est sorti (spawned)
    }, function(id)
        if id then
            print('[TAB_MANAGEMENT] Véhicule enregistré: ' .. plate .. ' pour ' .. owner)
        end
    end)

    -- INSERTION 2: Table persistent_vehicles (Persistence Custom - Fivem-Vehicle-Persistence)
    -- Le user a fourni le schéma : plate, owner_id, vehicle_data
    exports.oxmysql:insert('INSERT INTO persistent_vehicles (plate, owner_id, vehicle_data) VALUES (?, ?, ?)', {
        plate,
        owner, -- owner_id (ex: society_police)
        json.encode(vehicleProps)
    }, function(id)
        -- Pas forcément d'ID retourné sur MyISAM sans AI, mais on log
        print('[TAB_MANAGEMENT] Véhicule enregistré dans persistent_vehicles: ' .. plate)
    end)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check chaque minute
        -- Timer de SECOURS véhicules : si aucun employé YouTool n'a validé, la commande
        -- passe quand même en 'ready' après Config.DeliveryTime (validation = instantané).
        if Config.EnableDeliverySystem then
            local currentTime = os.time()
            local deliverySeconds = Config.DeliveryTime / 1000
            local thresholdTime = currentTime - deliverySeconds
            
            exports.oxmysql:execute('SELECT id, user_identifier, vehicle_model FROM dealership_orders WHERE status = ? AND ordered_at <= ?', {'pending', thresholdTime}, function(orders)
                if orders and #orders > 0 then
                    -- Mark them as ready in ONE query to avoid queueing massive amounts of queries to Node.js
                    exports.oxmysql:update('UPDATE dealership_orders SET status = ? WHERE status = ? AND ordered_at <= ?', {'ready', 'pending', thresholdTime}, function()
                        for _, order in ipairs(orders) do
                            local xPlayer = ESX.GetPlayerFromIdentifier(order.user_identifier)
                            if xPlayer then
                                TriggerClientEvent('cr-laptop:notify', xPlayer.source, 'IMPORT: Votre ' .. order.vehicle_model .. ' est arrivé au port !')
                                -- Force l'interface à se mettre à jour si le joueur est dessus
                                TriggerClientEvent('cr-laptop:forceUpdate', xPlayer.source)
                                TriggerClientEvent('pop_management:client:refreshMyOrders', xPlayer.source)
                            end
                        end
                    end)
                end
            end)
        end
    end
end)

RegisterServerEvent('pop_management:checkOrders')
AddEventHandler('pop_management:checkOrders', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    exports.oxmysql:execute('SELECT * FROM dealership_orders WHERE user_identifier = ? AND status = ?', {xPlayer.getIdentifier(), 'ready'}, function(orders)
        TriggerClientEvent('pop_management:openClaimMenu', _source, orders)
    end)
end)

RegisterServerEvent('pop_management:claimVehicle')
AddEventHandler('pop_management:claimVehicle', function(orderId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    exports.oxmysql:execute('SELECT * FROM dealership_orders WHERE id = ? AND user_identifier = ?', {orderId, xPlayer.getIdentifier()}, function(result)
        if result and result[1] and result[1].status == 'ready' then
            local order = result[1]
            
            -- Update status (atomique : un seul retrait possible)
            exports.oxmysql:execute('UPDATE dealership_orders SET status = ? WHERE id = ? AND status = ?', {'delivered', orderId, 'ready'}, function(rc)
                local affected = type(rc) == 'table' and rc.affectedRows or rc
                if not (affected and affected > 0) then return end
                PendingVehicleRegister[_source] = { model = tostring(order.vehicle_model):lower(), society = order.society }
                TriggerClientEvent('pop_management:spawnClaimedVehicle', _source, order.vehicle_model, order.vehicle_color, order.society)
                TriggerClientEvent('cr-laptop:notify', _source, 'Votre véhicule est sorti.')
            end)
        else
            TriggerClientEvent('cr-laptop:notify', _source, 'Erreur: Commande introuvable ou pas prête.')
        end
    end)
end)

RegisterServerEvent('pop_management:giveVehicleKey')
AddEventHandler('pop_management:giveVehicleKey', function(plate)
    local _source = source
    if type(plate) ~= 'string' or RegisteredPlates[_source] ~= plate:upper() then return end
    RegisteredPlates[_source] = nil

    if not Config.UseTabInventoryKeys then
        TriggerClientEvent('cr-laptop:notify', _source, 'Le véhicule avec la plaque '..plate..' a été enregistré, mais cet inventaire ne supporte pas les clés physiques.')
        return
    end

    local meta = { 
        plate = string.upper(plate),
        description = 'Plaque: ' .. string.upper(plate)
    }
    
    -- Utilisation de l'export pop_inventory pour donner l'item
    local success, err = pcall(function()
        exports.pop_inventory:GiveItem(_source, 'carkeys', 1, meta)
    end)

    if success then
         TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez reçu les clés ('..plate..')')
    else
        print('[ERROR] pop_inventory:GiveItem failed: ', err)
    end
end)

-- Recruter un employé via ox_target
RegisterServerEvent('pop_management:recruitEmployee')
AddEventHandler('pop_management:recruitEmployee', function(targetId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer or not xTarget or targetId == _source then return end

    -- Le joueur recruté doit être à proximité
    local pA, pB = GetPlayerPed(_source), GetPlayerPed(xTarget.source)
    if pA == 0 or pB == 0 or #(GetEntityCoords(pA) - GetEntityCoords(pB)) > 10.0 then return end

    local job = xPlayer.getJob()

    -- Vérifier que le joueur qui recrute est boss
    if job.grade_name == 'boss' then
        xTarget.setJob(job.name, 0)
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous avez <span style="color:#2ecc71; font-weight:bold;">recruté</span> '..xTarget.getName()..'.')
        TriggerClientEvent('cr-laptop:notify', targetId, 'Vous avez été <span style="color:#2ecc71; font-weight:bold;">recruté(e)</span> dans l\'entreprise '..job.label..'.')
    else
        TriggerClientEvent('cr-laptop:notify', _source, 'Vous n\'avez pas l\'<span style="color:#C52622; font-weight:bold;">autorisation</span> de recruter.')
    end
end)

-- Recherche de joueurs pour suggestions (Dynasty 8)
ESX.RegisterServerCallback('pop_management:getPlayersForSuggestion', function(source, cb, search)
    local query = "SELECT identifier, firstname, lastname FROM users WHERE LOWER(CONCAT(firstname, ' ', lastname)) LIKE LOWER(?) LIMIT 10"
    local pattern = '%' .. tostring(search or ''):sub(1, 50) .. '%'
    
    exports.oxmysql:execute(query, {pattern}, function(results)
        local players = {}
        if results then
            for _, v in ipairs(results) do
                table.insert(players, {
                    identifier = v.identifier,
                    name = (v.firstname or '') .. ' ' .. (v.lastname or '')
                })
            end
        end
        cb(players)
    end)
end)

-- Attribuer un locataire (Dynasty 8)
RegisterServerEvent('pop_management:setD8Tenant')
AddEventHandler('pop_management:setD8Tenant', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    -- Vérifier le job
    if xPlayer.getJob().name ~= 'dynasty8' then
        return
    end

    if type(data) ~= 'table' or type(data.identifier) ~= 'string' then return end
    local xTarget = ESX.GetPlayerFromIdentifier(data.identifier)
    local targetName = "Inconnu"
    
    if xTarget then
        targetName = xTarget.getName()
        TriggerClientEvent('cr-laptop:notify', xTarget.source, 'Vous avez un <span style="color:#2ecc71; font-weight:bold;">nouveau bail</span> pour une propriété !')
    end

    TriggerClientEvent('cr-laptop:notify', _source, 'Locataire <span style="color:#2ecc71; font-weight:bold;">'..targetName..'</span> ajouté avec succès.')
    
    -- Ici on pourrait ajouter une insertion SQL si on avait une table pour les baux
    -- Pour l'instant on se contente de la confirmation visuelle et de la notification
end)

local ServerSectorRequests = {
    {
        id = 1,
        sector = 'economie',
        entity = 'Premium Deluxe Motorsport',
        job = 'cardealer',
        object = 'Subvention Transition Énergétique',
        amount = 25000,
        status = 'pending'
    },
    {
        id = 2,
        sector = 'social',
        entity = 'Dynasty 8',
        job = 'dynasty8',
        object = 'Aide Rénovation Urbaine',
        amount = 35000,
        status = 'pending'
    },
    {
        id = 3,
        sector = 'services_publics',
        entity = 'Los Santos Police Department',
        job = 'police',
        object = 'Fonds d\'équipement tactique',
        amount = 15000,
        status = 'pending'
    },
    {
        id = 4,
        sector = 'sante',
        entity = 'Los Santos Medical Center',
        job = 'ambulance',
        object = 'Modernisation des ambulances',
        amount = 20000,
        status = 'pending'
    },
    {
        id = 5,
        sector = 'culture',
        entity = 'Galaxy Club LS',
        job = 'cardealer',
        object = 'Sponsoring Festival d\'Été',
        amount = 10000,
        status = 'pending'
    },
    {
        id = 6,
        sector = 'justice',
        entity = 'Cabinet d\'Avocats LS',
        job = 'cardealer',
        object = 'Aide juridictionnelle d\'urgence',
        amount = 8000,
        status = 'pending'
    }
}

-- =============================
-- GOUV (ADMINISTRATION BC)
-- =============================
RegisterServerEvent('pop_management:requestGouvData')
AddEventHandler('pop_management:requestGouvData', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    if not Config.DevMode and job.name ~= 'gouv' then return end

    local accountName = Config.GouvUSAccount or 'society_gouv'
    if job.name == 'gouv' then accountName = 'society_' .. job.name end

    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        local money = account and account.money or 0

        exports.oxmysql:execute('SELECT identifier, firstname, lastname, job, job_grade FROM users WHERE job = ?', {job.name}, function(employees)
            employees = employees or {}

            local proceedWithVehicles = function(vehicles)
                vehicles = vehicles or {}
                exports.oxmysql:execute('SELECT name, label FROM jobs ORDER BY label ASC', {}, function(jobsList)
                    local availableJobs = {}
                    if jobsList then
                        for _, j in ipairs(jobsList) do
                            if j.name ~= 'unemployed' and j.name ~= 'gouv' then
                                table.insert(availableJobs, {
                                    name = j.name,
                                    label = j.label
                                })
                            end
                        end
                    end

                    local formattedVehicles = {}
                    for _, v in ipairs(vehicles) do
                        local vModel = 'Inconnu'
                        if v.vehicle then
                            local valid, props = pcall(json.decode, v.vehicle)
                            if valid and props then
                                vModel = props.model
                            end
                        end
                        table.insert(formattedVehicles, {
                            model = vModel,
                            plate = v.plate,
                            driver = (v.stored == 1 or v.stored == true) and 'Garage' or 'Sorti'
                        })
                    end

                    -- Check if boss by grade name or if the grade index is high (e.g. grade 3 or 4)
                    local isBoss = Config.DevMode or (job.grade_name == 'boss' or job.grade_name == 'adjoint' or job.grade_name == 'secretaire' or job.grade_name == 'maire' or job.grade_name == 'president' or job.grade >= 3)

                    local gouvData = {
                        money = money,
                        employees = employees,
                        vehicles = formattedVehicles,
                        playerGradeLabel = (Config.DevMode and 'Mode Dev') or job.grade_label,
                        isBoss = isBoss,
                        sectorRequests = ServerSectorRequests,
                        availableJobs = availableJobs,
                        tva = GlobalState.tva or 20
                    }
                    TriggerClientEvent('pop_management:receiveGouvData', _source, gouvData)
                end)
            end

            -- Query vehicles with a fallback in case the 'job' column is missing from the owned_vehicles table
            exports.oxmysql:execute('SELECT plate, vehicle, `stored` FROM owned_vehicles WHERE owner = ? OR job = ?', {accountName, job.name}, function(vehicles)
                if vehicles == nil then
                    print('^1[LAPTOP] owned_vehicles query failed, trying fallback without job column...^0')
                    exports.oxmysql:execute('SELECT plate, vehicle, `stored` FROM owned_vehicles WHERE owner = ?', {accountName}, function(vehiclesFallback)
                        proceedWithVehicles(vehiclesFallback)
                    end)
                else
                    proceedWithVehicles(vehicles)
                end
            end)
        end)
    end)
end)

RegisterServerEvent('pop_management:grantSubsidy')
AddEventHandler('pop_management:grantSubsidy', function(requestId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    if not isGouvBoss(job) then return end
    requestId = tonumber(requestId)

    local request = nil
    for _, r in ipairs(ServerSectorRequests) do
        if r.id == requestId then
            request = r
            break
        end
    end

    if not request then
        TriggerClientEvent('cr-laptop:notify', _source, 'Demande introuvable.')
        return
    end

    if request.status ~= 'pending' then
        TriggerClientEvent('cr-laptop:notify', _source, 'Cette demande a déjà été traitée.')
        return
    end

    local amount = request.amount
    local targetJob = request.job
    local accountGouvName = Config.GouvUSAccount or 'society_gouv'
    local accountTargetName = 'society_' .. targetJob

    local function completeTransfer()
        request.status = 'granted'

        -- Record transactions
        exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
            accountGouvName,
            xPlayer.getName(),
            'Subvention Accordée - ' .. request.entity .. ' (' .. request.object .. ')',
            -amount
        })

        exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
            accountTargetName,
            'Administration BC',
            'Subvention Reçue - ' .. request.object,
            amount
        })

        -- Notify players
        TriggerClientEvent('cr-laptop:notify', _source, 'Subvention de <span style="color:#2ecc71; font-weight:bold;">'..amount..'$</span> accordée à '..request.entity..'.')

        -- Notify target job employees online
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers, 1 do
            local xTarget = ESX.GetPlayerFromId(xPlayers[i])
            if xTarget and xTarget.getJob().name == targetJob then
                TriggerClientEvent('cr-laptop:notifyLogo', xTarget.source, {
                    logo = "gouv.png",
                    title = "Administration BC",
                    message = "Une subvention de <span style='color:#2ecc71; font-weight:bold;'>"..amount.."$</span> a été versée à votre entreprise !",
                    duration = 10000
                })
            end
        end

        TriggerEvent('cr-laptop:getSocietyData', targetJob)
        TriggerClientEvent('cr-laptop:forceUpdate', _source)
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', accountGouvName, function(accountGouv)
        TriggerEvent('esx_addonaccount:getSharedAccount', accountTargetName, function(accountTarget)
            if accountGouv and accountGouv.money >= amount then
                accountGouv.removeMoney(amount)
                if accountTarget then
                    accountTarget.addMoney(amount)
                else
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {amount, accountTargetName})
                end
                completeTransfer()
            else
                exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountGouvName}, function(sqlMoney)
                    if sqlMoney and tonumber(sqlMoney) >= amount then
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {amount, accountGouvName})
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {amount, accountTargetName})
                        completeTransfer()
                    else
                        TriggerClientEvent('cr-laptop:notify', _source, 'Fonds gouvernementaux insuffisants.')
                    end
                end)
            end
        end)
    end)
end)

RegisterServerEvent('pop_management:refuseSubsidy')
AddEventHandler('pop_management:refuseSubsidy', function(requestId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    if not isGouvBoss(job) then return end
    requestId = tonumber(requestId)

    for _, r in ipairs(ServerSectorRequests) do
        if r.id == requestId then
            if r.status == 'pending' then
                r.status = 'refused'
                TriggerClientEvent('cr-laptop:notify', _source, 'Demande refusée.')
                TriggerClientEvent('cr-laptop:forceUpdate', _source)
            else
                TriggerClientEvent('cr-laptop:notify', _source, 'Cette demande a déjà été traitée.')
            end
            return
        end
    end
end)

RegisterServerEvent('pop_management:createAndGrantSubsidy')
AddEventHandler('pop_management:createAndGrantSubsidy', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    if not isGouvBoss(job) then return end

    if type(data) ~= 'table' or not data.sector or not data.entity or not data.job or not data.amount or not data.object then
        TriggerClientEvent('cr-laptop:notify', _source, 'Données de subvention invalides.')
        return
    end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('cr-laptop:notify', _source, 'Montant de subvention invalide.')
        return
    end
    if type(data.job) ~= 'string' or (ESX.DoesJobExist and not ESX.DoesJobExist(data.job, 0)) then
        TriggerClientEvent('cr-laptop:notify', _source, 'Données de subvention invalides.')
        return
    end
    data.entity = escapeHtml(data.entity):sub(1, 100)
    data.object = escapeHtml(data.object):sub(1, 100)
    data.sector = tostring(data.sector):sub(1, 50)

    local targetJob = data.job
    local accountGouvName = Config.GouvUSAccount or 'society_gouv'
    local accountTargetName = 'society_' .. targetJob

    local function completeTransfer()
        local newId = 1
        for _, r in ipairs(ServerSectorRequests) do
            if r.id >= newId then
                newId = r.id + 1
            end
        end

        table.insert(ServerSectorRequests, {
            id = newId,
            sector = data.sector,
            entity = data.entity,
            job = data.job,
            object = data.object,
            amount = amount,
            status = 'granted'
        })

        -- Record transactions
        exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
            accountGouvName,
            xPlayer.getName(),
            'Subvention Accordée - ' .. data.entity .. ' (' .. data.object .. ')',
            -amount
        })

        exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
            accountTargetName,
            'Administration BC',
            'Subvention Reçue - ' .. data.object,
            amount
        })

        -- Notify players
        TriggerClientEvent('cr-laptop:notify', _source, 'Subvention de <span style="color:#2ecc71; font-weight:bold;">'..amount..'$</span> accordée à '..data.entity..'.')

        -- Notify target job employees online
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers, 1 do
            local xTarget = ESX.GetPlayerFromId(xPlayers[i])
            if xTarget and xTarget.getJob().name == targetJob then
                TriggerClientEvent('cr-laptop:notifyLogo', xTarget.source, {
                    logo = "gouv.png",
                    title = "Administration BC",
                    message = "Une subvention de <span style=\'color:#2ecc71; font-weight:bold;\'>"..amount.."$</span> a été versée à votre entreprise !",
                    duration = 10000
                })
            end
        end

        TriggerEvent('cr-laptop:getSocietyData', targetJob)
        TriggerClientEvent('cr-laptop:forceUpdate', _source)
    end

    TriggerEvent('esx_addonaccount:getSharedAccount', accountGouvName, function(accountGouv)
        TriggerEvent('esx_addonaccount:getSharedAccount', accountTargetName, function(accountTarget)
            if accountGouv and accountGouv.money >= amount then
                accountGouv.removeMoney(amount)
                if accountTarget then
                    accountTarget.addMoney(amount)
                else
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {amount, accountTargetName})
                end
                completeTransfer()
            else
                exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountGouvName}, function(sqlMoney)
                    if sqlMoney and tonumber(sqlMoney) >= amount then
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {amount, accountGouvName})
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {amount, accountTargetName})
                        completeTransfer()
                    else
                        TriggerClientEvent('cr-laptop:notify', _source, 'Fonds gouvernementaux insuffisants.')
                    end
                end)
            end
        end)
    end)
end)

RegisterServerEvent('pop_management:changeTva')
AddEventHandler('pop_management:changeTva', function(tva)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if not isGouvBoss(xPlayer.getJob()) then return end

    local newTva = tonumber(tva)
    if not newTva or newTva < 0 or newTva > 100 then
        TriggerClientEvent('cr-laptop:notify', _source, '<span style="color:#e74c3c; font-weight:bold;">TVA Invalide.</span> Saisissez un taux entre 0 et 100.')
        return
    end

    GlobalState.tva = newTva
    exports.oxmysql:execute('INSERT INTO tab_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = ?', {'tva', tostring(newTva), tostring(newTva)})
    
    TriggerClientEvent('cr-laptop:notify', _source, 'La TVA a été mise à jour à <span style="color:#3498db; font-weight:bold;">'..newTva..'%</span>.')
    TriggerClientEvent('esx:showNotification', -1, 'Le gouvernement a modifié le taux de la TVA à ~b~'..newTva..'%~s~.')
end)

RegisterServerEvent('pop_management:createWorkContract')
AddEventHandler('pop_management:createWorkContract', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if not Config.DevMode and xPlayer.getJob().name ~= 'gouv' then return end

    local meta = {
        description = "Citoyen: " .. tostring(data and data.name or '?') .. " | Poste: " .. tostring(data and data.job or '?') .. " | Salaire: " .. tostring(data and data.salary or 0) .. "$",
        type = "Contrat de Travail BC"
    }
    
    local success, err = pcall(function()
        exports.pop_inventory:GiveItem(_source, 'paper', 1, meta)
    end)

    if success then
        TriggerClientEvent('cr-laptop:notify', _source, 'Le <span style="color:#3498db; font-weight:bold;">contrat de travail</span> a été imprimé.')
    else
        TriggerClientEvent('cr-laptop:notify', _source, 'Erreur lors de la création du contrat. Item non trouvé.')
    end
end)

RegisterServerEvent('pop_management:publishGouvNews')
AddEventHandler('pop_management:publishGouvNews', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if not Config.DevMode and xPlayer.getJob().name ~= 'gouv' then return end

    -- Announce to the server
    TriggerClientEvent('cr-laptop:notifyLogo', -1, {
        logo = "https://cdn.discordapp.com/attachments/809480057579241533/1473808036819763332/images_7.jfif?ex=69978e32&is=69963cb2&hm=f8d62350f084b7bd76975e967097a4046ae8c01e525057df05acc409a78d19f6&",
        title = "GOUVERNEMENT BC - " .. escapeHtml(data and data.type),
        message = escapeHtml(data and data.title) .. "<br><br>" .. escapeHtml(data and data.content),
        duration = 15000
    })
    TriggerClientEvent('cr-laptop:notify', _source, 'Votre publication a été envoyée sur EyeFind.')
end)

RegisterServerEvent('pop_management:scheduleCouncil')
AddEventHandler('pop_management:scheduleCouncil', function()
    local _source = source
    TriggerClientEvent('cr-laptop:notify', _source, 'Le conseil a été <span style="color:#3498db; font-weight:bold;">programmé</span>.')
end)

RegisterServerEvent('pop_management:startCouncil')
AddEventHandler('pop_management:startCouncil', function()
    local _source = source
    TriggerClientEvent('cr-laptop:notify', _source, 'Le conseil <span style="color:#2ecc71; font-weight:bold;">commence</span>.')
end)

RegisterServerEvent('pop_management:pauseCouncil')
AddEventHandler('pop_management:pauseCouncil', function()
    local _source = source
    TriggerClientEvent('cr-laptop:notify', _source, 'Le conseil est <span style="color:#e67e22; font-weight:bold;">en pause</span>.')
end)

RegisterServerEvent('pop_management:endCouncil')
AddEventHandler('pop_management:endCouncil', function()
    local _source = source
    TriggerClientEvent('cr-laptop:notify', _source, 'Le conseil est <span style="color:#e74c3c; font-weight:bold;">terminé</span>.')
end)

-- =============================================
-- YOUTOOL B2B ORDER SYSTEM
-- =============================================
RegisterServerEvent('pop_management:buyYouToolItem')
AddEventHandler('pop_management:buyYouToolItem', function(model, label, quantity, price, coords)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local job = xPlayer.getJob()
    quantity = math.floor(tonumber(quantity) or 1)
    -- Prix catalogue serveur (le prix client est ignoré)
    local def = YouToolCatalog[model]
    if not def or quantity > 100 then return end
    label = def.label
    price = def.price * quantity

    local deliveryCoords = nil
    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        deliveryCoords = ('%.2f,%.2f,%.2f'):format(coords.x, coords.y, coords.z)
    end

    if quantity < 1 or price < 0 then return end

    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(price * (tvaRate / 100))
    local finalPrice = price + taxAmount

    local isUnemployed = (job.name == 'unemployed')
    local accountName = 'society_' .. job.name

    -- Helper to finalize the purchase
    local function completeYouToolPurchase()
        local deliverySeconds = math.floor((Config.YouToolDeliveryTime or 120000) / 1000)
        
        exports.oxmysql:execute('INSERT INTO youtool_orders (society, item_model, item_label, quantity, price, status, delivery_time, user_identifier, customer_name, delivery_coords) VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?, ?, ?)', {
            job.name,
            model,
            label,
            quantity,
            finalPrice,
            'pending',
            deliverySeconds,
            xPlayer.getIdentifier(),
            xPlayer.getName(),
            deliveryCoords
        }, function(insertId)
            print(('[YouTool][buy] colis enregistré id=%s society=%s %sx %s'):format(tostring(insertId), tostring(job.name), tostring(quantity), tostring(label)))
            -- Log transaction if not unemployed
            if not isUnemployed then
                exports.oxmysql:execute('INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())', {
                    accountName,
                    xPlayer.getName(),
                    'Achat YouTool - ' .. quantity .. 'x ' .. label .. ' (Incl. ' .. taxAmount .. '$ TVA)',
                    -finalPrice
                })
            end

            -- Credit TVA to society_gouv
            if taxAmount > 0 then
                local accountUsName = Config.GouvUSAccount or 'society_gouv'
                TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
                    if gouvAccount then
                        gouvAccount.addMoney(taxAmount)
                    else
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {taxAmount, accountUsName})
                    end
                end)
            end

            -- Notify the customer (commettant) : commande en attente de validation
            if Config.YouToolValidationRequired then
                TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                    image = "nui://pop_management/html/a68217-7.png",
                    title = "YouTool",
                    message = "Votre commande <span style='color:#e67e22; font-weight:bold;'>".. quantity .."x ".. label .."</span> est <span style='color:#f39c12;'>en attente de validation</span>. Récupération au Port.",
                    duration = 6000
                })
            else
                local deliveryMin = math.floor(deliverySeconds / 60)
                local deliveryText = deliveryMin > 0 and (deliveryMin .. " min") or (deliverySeconds .. " sec")
                TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                    image = "nui://pop_management/html/a68217-7.png",
                    title = "YouTool B2B",
                    message = "Votre commande de <span style='color:#e67e22; font-weight:bold;'>".. quantity .."x ".. label .."</span> est enregistrée ! Livraison sous " .. deliveryText .. ".",
                    duration = 6000
                })
            end

            -- Notif au job YouTool : nouvelle commande colis à traiter
            notifyYouToolStaff({
                image = "nui://pop_management/html/ex2s5794f1uah14nfiwu38w42ht1.png",
                title = "Livraisons YouTool",
                message = "Nouvelle commande colis : <span style='color:#e67e22; font-weight:bold;'>".. quantity .."x ".. label .."</span> pour " .. xPlayer.getName() .. ".",
                duration = 8000
            })

            -- Le client voit son blip "Ma commande" au Port dès maintenant
            TriggerClientEvent('pop_management:client:refreshMyOrders', _source)

            -- Carton physique posé sur l'étagère du Port immédiatement
            TriggerClientEvent('pop_management:shelfRefresh', -1)

            -- Force NUI refresh for society members
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers, 1 do
                local xTarget = ESX.GetPlayerFromId(xPlayers[i])
                if xTarget and xTarget.getJob().name == job.name then
                    TriggerClientEvent('cr-laptop:forceUpdate', xTarget.source)
                    TriggerClientEvent('pop_management:client:updateYouToolOrders', xTarget.source)
                end
            end
        end)
    end

    if isUnemployed then
        -- Personal bank check
        if xPlayer.getAccount('bank').money >= finalPrice then
            xPlayer.removeAccountMoney('bank', finalPrice)
            completeYouToolPurchase()
        else
            TriggerClientEvent('cr-laptop:notify', _source, 'Fonds personnels en banque <span style="color:#C52622; font-weight:bold;">insuffisants</span>.')
        end
    else
        -- Company account check
        TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
            local currentMoney = 0
            if account then currentMoney = tonumber(account.money) or 0 end

            if account and currentMoney >= finalPrice then
                account.removeMoney(finalPrice)
                completeYouToolPurchase()
            else
                -- Fallback SQL direct
                exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountName}, function(sqlMoney)
                    if sqlMoney and tonumber(sqlMoney) >= finalPrice then
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {finalPrice, accountName})
                        completeYouToolPurchase()
                    else
                        TriggerClientEvent('cr-laptop:notify', _source, 'Fonds de l\'entreprise <span style="color:#C52622; font-weight:bold;">insuffisants</span>.')
                    end
                end)
            end
        end)
    end
end)

-- =============================================
-- YOUTOOL B2B — COMMANDE GROUPÉE (PANIER)
-- =============================================
-- Reçoit un tableau d'articles [{model,label,quantity,price}] et traite
-- le tout en une seule vérification de fonds + débit.
RegisterServerEvent('pop_management:buyYouToolCart')
AddEventHandler('pop_management:buyYouToolCart', function(items, coords)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end

    local deliveryCoords = nil
    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        deliveryCoords = ('%.2f,%.2f,%.2f'):format(coords.x, coords.y, coords.z)
    end

    if type(items) ~= 'table' or #items == 0 then return end

    local job          = xPlayer.getJob()
    local isUnemployed = (job.name == 'unemployed')
    local accountName  = 'society_' .. job.name

    -- Calcul du total global (prix déjà multiplié par quantité côté JS)
    -- Prix recalculés depuis le catalogue serveur (prix client ignoré)
    local grandTotal = 0
    local clean = {}
    for _, it in ipairs(items) do
        local def = type(it) == 'table' and YouToolCatalog[it.model]
        local qty = math.floor(tonumber(type(it) == 'table' and it.quantity) or 0)
        if not def or qty < 1 or qty > 100 or #clean >= 50 then
            TriggerClientEvent('cr-laptop:notify', _source, 'Données de panier invalides.')
            return
        end
        local p = def.price * qty
        clean[#clean + 1] = { model = it.model, label = def.label, quantity = qty, price = p }
        grandTotal = grandTotal + p
    end
    items = clean

    if grandTotal <= 0 then return end

    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(grandTotal * (tvaRate / 100))
    local finalPrice = grandTotal + taxAmount

    -- Fonction appelée après vérification et débit réussis
    -- 1 panier = 1 ligne DB = 1 carton (tous les items sérialisés dans cart_items)
    local function processCartOrder()
        local deliverySeconds = math.floor((Config.YouToolDeliveryTime or 120000) / 1000)

        -- Quantité totale (somme de toutes les lignes du panier)
        local totalQty = 0
        for _, it in ipairs(items) do
            totalQty = totalQty + math.max(1, math.floor(tonumber(it.quantity) or 1))
        end

        -- Label résumé affiché dans l'app job et les notifications
        local cartLabel = 'Panier (' .. #items .. ' article' .. (#items > 1 and 's' or '') .. ')'

        -- Sérialiser les articles en JSON pour le carton multi-items
        local cartJson = json.encode(items)

        -- UNE SEULE ligne en DB → UN SEUL carton à la livraison
        exports.oxmysql:execute(
            'INSERT INTO youtool_orders (society, item_model, item_label, quantity, price, status, delivery_time, user_identifier, customer_name, cart_items, delivery_coords) VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), ?, ?, ?, ?)',
            {
                job.name,
                'cart',
                cartLabel,
                totalQty,
                finalPrice,
                'pending',
                deliverySeconds,
                xPlayer.getIdentifier(),
                xPlayer.getName(),
                cartJson,
                deliveryCoords
            },
            function(insertId)
                print(('[YouTool][Cart] panier enregistré id=%s society=%s %d article(s) total=%d$'):format(
                    tostring(insertId), tostring(job.name), #items, finalPrice
                ))

                -- Transaction société unique
                if not isUnemployed then
                    exports.oxmysql:execute(
                        'INSERT INTO society_transactions (society, player_name, action, amount, date) VALUES (?, ?, ?, ?, NOW())',
                        {
                            accountName,
                            xPlayer.getName(),
                            'Panier GoPostal — ' .. #items .. ' article(s) (Incl. ' .. taxAmount .. '$ TVA)',
                            -finalPrice
                        }
                    )
                end

                -- Credit TVA to society_gouv
                if taxAmount > 0 then
                    local accountUsName = Config.GouvUSAccount or 'society_gouv'
                    TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
                        if gouvAccount then
                            gouvAccount.addMoney(taxAmount)
                        else
                            exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {taxAmount, accountUsName})
                        end
                    end)
                end

                -- Notification client résumé
                if Config.YouToolValidationRequired then
                    TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                        image   = "nui://pop_management/html/a68217-7.png",
                        title   = "GoPostal B2B",
                        message = "Votre panier (<span style='color:#e67e22; font-weight:bold;'>" .. #items .. " article(s)</span>) est <span style='color:#f39c12;'>en attente de validation</span>. Récupération au Port.",
                        duration = 7000
                    })
                else
                    local deliveryMin  = math.floor(deliverySeconds / 60)
                    local deliveryText = deliveryMin > 0 and (deliveryMin .. " min") or (deliverySeconds .. " sec")
                    TriggerClientEvent('cr-laptop:notifyLogo', _source, {
                        image   = "nui://pop_management/html/a68217-7.png",
                        title   = "GoPostal B2B",
                        message = "Panier commandé ! <span style='color:#e67e22; font-weight:bold;'>" .. #items .. " article(s)</span> — livraison sous " .. deliveryText .. ".",
                        duration = 7000
                    })
                end

                -- Notif employés YouTool
                notifyYouToolStaff({
                    image   = "nui://pop_management/html/ex2s5794f1uah14nfiwu38w42ht1.png",
                    title = "Livraisons GoPostal",
                    message = "Nouveau panier de <span style='color:#e67e22; font-weight:bold;'>" .. #items .. " article(s)</span> commandé par " .. xPlayer.getName() .. ".",
                    duration = 8000
                })

                TriggerClientEvent('pop_management:client:refreshMyOrders', _source)
                TriggerClientEvent('pop_management:shelfRefresh', -1)

                local xPlayers = ESX.GetPlayers()
                for i = 1, #xPlayers, 1 do
                    local xTarget = ESX.GetPlayerFromId(xPlayers[i])
                    if xTarget and xTarget.getJob().name == job.name then
                        TriggerClientEvent('cr-laptop:forceUpdate', xTarget.source)
                        TriggerClientEvent('pop_management:client:updateYouToolOrders', xTarget.source)
                    end
                end
            end
        )
    end

    -- Vérification et débit du compte
    if isUnemployed then
        if xPlayer.getAccount('bank').money >= finalPrice then
            xPlayer.removeAccountMoney('bank', finalPrice)
            processCartOrder()
        else
            TriggerClientEvent('cr-laptop:notify', _source, 'Fonds personnels en banque <span style="color:#C52622; font-weight:bold;">insuffisants</span> pour ce panier (' .. finalPrice .. '$).')
        end
    else
        TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
            local currentMoney = 0
            if account then currentMoney = tonumber(account.money) or 0 end

            if account and currentMoney >= finalPrice then
                account.removeMoney(finalPrice)
                processCartOrder()
            else
                exports.oxmysql:scalar('SELECT money FROM addon_account_data WHERE account_name = ?', {accountName}, function(sqlMoney)
                    if sqlMoney and tonumber(sqlMoney) >= finalPrice then
                        exports.oxmysql:execute('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {finalPrice, accountName})
                        processCartOrder()
                    else
                        TriggerClientEvent('cr-laptop:notify', _source, 'Fonds de l\'entreprise <span style="color:#C52622; font-weight:bold;">insuffisants</span> pour ce panier (' .. finalPrice .. '$).')
                    end
                end)
            end
        end)
    end
end)



-- =============================
-- DYNASTY 8 — MLO SYSTEM
-- =============================

-- Cache BDD des coffres (chargé au démarrage)
local d8ChestsCache = {}

-- Charger tous les coffres depuis la BDD au démarrage
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    exports.oxmysql:execute('SELECT * FROM `d8_chests`', {}, function(rows)
        if rows then
            for _, row in ipairs(rows) do
                d8ChestsCache[tonumber(row.property_id) or row.property_id] = {
                    id          = row.id,
                    property_id = row.property_id,
                    name        = row.name,
                    x           = row.x,
                    y           = row.y,
                    z           = row.z,
                    heading     = row.heading,
                }
            end
        end
        TriggerClientEvent('pop_management:client:d8LoadChests', -1, d8ChestsCache)
        print('^2[D8] Coffres charges : ' .. #(rows or {}) .. '^0')
    end)
end)

-- (playerSpawned est un événement client : côté serveur on utilise esx:playerLoaded)
AddEventHandler('esx:playerLoaded', function(playerId)
    TriggerClientEvent('pop_management:client:d8LoadChests', playerId, d8ChestsCache)
end)

ESX.RegisterServerCallback('pop_management:d8GetPropertyData', function(source, cb, propertyId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end
    local chest = d8ChestsCache[tonumber(propertyId) or propertyId]
    cb({ chest = chest })
end)

RegisterServerEvent('pop_management:d8GenerateKey')
AddEventHandler('pop_management:d8GenerateKey', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if xPlayer.getJob().name ~= 'dynasty8' or type(data) ~= 'table' then return end
    local propertyId   = tonumber(data.propertyId)
    local propertyName = tostring(data.propertyName or 'Propriete')
    if not propertyId then return end
    local meta = { property_id = propertyId, property_name = propertyName, description = 'Cle : ' .. propertyName }
    local ok, err = pcall(function() exports.pop_inventory:GiveItem(_source, 'key_d8', 1, meta) end)
    if ok then
        TriggerClientEvent('cr-laptop:notify', _source, 'Cle generee. Remettez-la au locataire.')
    else
        print('[D8][ERROR] GiveItem key_d8 failed: ' .. tostring(err))
    end
end)

RegisterServerEvent('pop_management:d8PlaceChest')
AddEventHandler('pop_management:d8PlaceChest', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if xPlayer.getJob().name ~= 'dynasty8' or type(data) ~= 'table' then return end
    local propertyId = tonumber(data.propertyId)
    local name       = tostring(data.name or 'Coffre'):sub(1, 64)
    local x, y, z   = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local heading    = tonumber(data.heading) or 0.0
    if not propertyId or not x or not y or not z then return end
    if d8ChestsCache[propertyId] then
        TriggerClientEvent('cr-laptop:notify', _source, 'Un coffre existe deja pour cette propriete.')
        return
    end
    exports.oxmysql:insert(
        'INSERT INTO `d8_chests` (property_id, name, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
        { propertyId, name, x, y, z, heading },
        function(insertId)
            if not insertId then return end
            local chestData = { id = insertId, property_id = propertyId, name = name, x = x, y = y, z = z, heading = heading }
            d8ChestsCache[propertyId] = chestData
            TriggerClientEvent('pop_management:client:d8SpawnChest', -1, chestData)
            TriggerClientEvent('cr-laptop:notify', _source, 'Coffre place avec succes.')
        end
    )
end)

RegisterServerEvent('pop_management:d8RemoveChest')
AddEventHandler('pop_management:d8RemoveChest', function(data)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    if xPlayer.getJob().name ~= 'dynasty8' or type(data) ~= 'table' then return end
    local propertyId = tonumber(data.propertyId)
    if not propertyId then return end
    exports.oxmysql:execute(
        'DELETE FROM `d8_chests` WHERE property_id = ?',
        { propertyId },
        function(res)
            local affected = type(res) == 'table' and res.affectedRows or res
            if affected and affected > 0 then
                d8ChestsCache[propertyId] = nil
                TriggerClientEvent('pop_management:client:d8DespawnChest', -1, propertyId)
                TriggerClientEvent('cr-laptop:notify', _source, 'Coffre supprime.')
            end
        end
    )
end)

RegisterServerEvent('pop_management:d8OpenChest')
AddEventHandler('pop_management:d8OpenChest', function(propertyId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then return end
    propertyId = tonumber(propertyId)
    if not propertyId then return end
    local isAgent = xPlayer.getJob().name == 'dynasty8'
    local function openIt()
        -- Envoyer au client l'ordre d'ouvrir le coffre (le client trigge pop_inventory:server:openStaticChest)
        TriggerClientEvent('pop_management:client:d8OpenChestUI', _source, 'd8_prop_' .. propertyId, 'Coffre D8 ' .. propertyId)
    end
    if isAgent then openIt() return end
    local hasKey = false
    local inventory = xPlayer.inventory or {}
    for _, item in ipairs(inventory) do
        if item.name == 'key_d8' and item.count > 0 then
            local meta = item.metadata or {}
            if tonumber(meta.property_id) == propertyId then hasKey = true break end
        end
    end
    if hasKey then openIt()
    else TriggerClientEvent('cr-laptop:notify', _source, 'Vous navez pas la cle de cette propriete.') end
end)