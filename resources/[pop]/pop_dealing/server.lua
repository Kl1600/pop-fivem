-- ─────────────────────────────────────────────
-- pop_dealing - logique serveur
-- Spawn de clients NPC par zone, gestion des deals
-- ─────────────────────────────────────────────

local ESX = exports['es_extended']:getSharedObject()

local customers      = {}   -- [id] = { zoneIdx, drugDefId, qty, unitPrice, totalPrice, model, coords, heading, isCop, claimedBy, expiresAt, sentTo }
local nextId         = 1
local lastSpawnAtZone = {}  -- [zoneIdx] = os.time()

math.randomseed(os.time())

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function pickWeighted(drugs)
    local total = 0
    for _, d in ipairs(drugs) do total = total + (d.demand or 1) end
    local roll = math.random() * total
    local acc  = 0
    for _, d in ipairs(drugs) do
        acc = acc + (d.demand or 1)
        if roll <= acc then return d end
    end
    return drugs[1]
end

local function randomPointInZone(zone)
    local angle = math.random() * math.pi * 2
    local dist  = math.sqrt(math.random()) * zone.radius
    return vec3(zone.center.x + math.cos(angle) * dist,
                zone.center.y + math.sin(angle) * dist,
                zone.center.z)
end

local function countCustomersInZone(zoneIdx)
    local n = 0
    for _, c in pairs(customers) do
        if c.zoneIdx == zoneIdx then n = n + 1 end
    end
    return n
end

-- Génère un maxPrice unitaire (limite haute du client) à partir de basePrice
local function rollMaxPrice(basePrice)
    local minM, maxM = Config.MaxPriceMultiplier[1], Config.MaxPriceMultiplier[2]
    local mult = minM + math.random() * (maxM - minM)
    return math.floor(basePrice * mult + 0.5)
end

-- Données envoyées au client : sans le prix max ni le flag flic (secrets serveur)
local function publicData(c)
    return {
        id        = c.id,
        zoneIdx   = c.zoneIdx,
        static    = c.static,
        drugDefId = c.drugDefId,
        drugLabel = c.drugLabel,
        drugIcon  = c.drugIcon,
        qty       = c.qty,
        model     = c.model,
        x         = c.x,
        y         = c.y,
        z         = c.z,
        heading   = c.heading,
    }
end

-- Crée le PNJ chez un seul joueur (et retient qu'il l'a)
local function sendCustomer(src, c)
    c.sentTo = c.sentTo or {}
    if c.sentTo[src] then return end
    c.sentTo[src] = true
    TriggerClientEvent('pop_dealing:spawnCustomer', src, publicData(c))
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Clients de zone : envoyés uniquement aux joueurs proches, retirés quand ils s'éloignent
local function streamZoneCustomers()
    local range = Config.CustomerStreamRange or 150.0
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local pc  = playerCoords(src)
        if pc then
            for id, c in pairs(customers) do
                if not c.ownerSrc then
                    c.sentTo = c.sentTo or {}
                    local dist = #(pc - vec3(c.x, c.y, c.z))
                    if not c.sentTo[src] and dist <= range then
                        sendCustomer(src, c)
                    elseif c.sentTo[src] and dist > range + 50.0 and c.claimedBy ~= src then
                        c.sentTo[src] = nil
                        TriggerClientEvent('pop_dealing:removeCustomer', src, id)
                    end
                end
            end
        end
    end
end

local function generateCustomer(zoneIdx)
    local zone = Config.Zones[zoneIdx]
    if not zone then return end

    local drug     = pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]
    local coords   = randomPointInZone(zone)

    local id = nextId
    nextId = nextId + 1

    customers[id] = {
        id           = id,
        zoneIdx      = zoneIdx,
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,            -- prix indicatif affiché au joueur
        maxUnit      = maxUnit,             -- limite haute par unité (secret)
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = coords.x,
        y            = coords.y,
        z            = coords.z,
        heading      = math.random(0, 359) + 0.0,
        isCop        = math.random() < (Config.BustChance or 0.0),
        claimedBy    = nil,
        expiresAt    = os.time() + 600,
        sentTo       = {},
    }

    -- Envoyé seulement aux joueurs proches (voir streamZoneCustomers)
    streamZoneCustomers()
    return customers[id]
end

-- Anti-abus : le joueur doit être physiquement proche du client
local function isNearCustomer(src, c)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    -- clients statiques : ne bougent pas ; clients de zone : marchent vers le joueur
    local maxDist = c.static and 15.0 or ((Config.CustomerDetectRange or 40.0) + 15.0)
    return #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) <= maxDist
end

local function removeCustomer(id)
    local c = customers[id]
    if not c then return end
    customers[id] = nil
    -- Uniquement aux joueurs qui ont ce PNJ
    for src in pairs(c.sentTo or {}) do
        TriggerClientEvent('pop_dealing:removeCustomer', src, id)
    end
end

-- Joueurs dont le job ESX fait partie de Config.PoliceJobs
local function getPoliceSources()
    local jobs = {}
    for _, j in ipairs(Config.PoliceJobs or { 'police' }) do jobs[j] = true end
    local list = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        if xPlayer.job and jobs[xPlayer.job.name] then
            list[#list + 1] = xPlayer.source
        end
    end
    return list
end

-- Nom du lieu pour l'alerte : zone de deal, sinon territoire (pop_territories)
local function placeLabel(c)
    local zone = Config.Zones[c.zoneIdx]
    if zone then return zone.name end
    local ok, _, label = pcall(function() return exports.pop_territories:getZoneAt(c.x, c.y) end)
    return (ok and label) or '?'
end

-- ─────────────────────────────────────────────
-- Mode "vente de drogue" par joueur (déclenché via l'item pochonweed)
-- ─────────────────────────────────────────────

local sellingPlayers = {}   -- [src] = { lastSpawn = os.time() }

local function dealNotify(src, message, icon)
    TriggerClientEvent('pop_dealing:notify', src, {
        icon = icon or 'fas fa-cannabis', message = message, duration = 4000,
    })
end

-- Le joueur a-t-il au moins une drogue vendable sur lui ?
local function hasSellableDrug(src)
    if Config.DevIgnoreItemCheck then return true end
    for _, d in ipairs(Config.Drugs) do
        if exports.pop_inventory:getItemCount(src, d.defId) > 0 then return true end
    end
    return false
end

local function countSellerCustomers(src)
    local n = 0
    for _, c in pairs(customers) do
        if c.ownerSrc == src then n = n + 1 end
    end
    return n
end

local function stopSelling(src, message)
    if not sellingPlayers[src] then return end
    sellingPlayers[src] = nil
    for id, c in pairs(customers) do
        if c.ownerSrc == src then removeCustomer(id) end
    end
    if message then dealNotify(src, message, 'fas fa-ban') end
end

-- Génère un client à une distance aléatoire autour du joueur (il marchera vers lui)
local function generateCustomerNear(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pc = GetEntityCoords(ped)

    local angle = math.random() * math.pi * 2
    local dmin  = Config.SellingSpawnMin or 12.0
    local dmax  = Config.SellingSpawnMax or 25.0
    local dist  = dmin + math.random() * (dmax - dmin)

    local drug     = pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]

    local id = nextId
    nextId = nextId + 1

    customers[id] = {
        id           = id,
        zoneIdx      = 0,
        ownerSrc     = src,
        static       = true,   -- reste sur place + blip ; le joueur vient à lui
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,
        maxUnit      = maxUnit,
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = pc.x + math.cos(angle) * dist,
        y            = pc.y + math.sin(angle) * dist,
        z            = pc.z,
        heading      = math.random(0, 359) + 0.0,
        isCop        = math.random() < (Config.BustChance or 0.0),
        claimedBy    = nil,
        expiresAt    = os.time() + 600,
        sentTo       = {},
    }

    -- Client personnel : créé uniquement chez le vendeur
    sendCustomer(src, customers[id])
end

-- Bascule le mode vente (appelé par pochonweed.onUse côté pop_inventory)
exports('toggleSelling', function(src)
    src = tonumber(src)
    if not src then return end

    if sellingPlayers[src] then
        stopSelling(src, 'Vente arrêtée.')
        return
    end

    if not hasSellableDrug(src) then
        return dealNotify(src, 'Tu n\'as aucune drogue à vendre.', 'fas fa-circle-exclamation')
    end

    sellingPlayers[src] = { lastSpawn = 0 }
    dealNotify(src, 'Vente activée — repère les clients sur la carte et va les voir.', 'fas fa-handshake')
end)

-- Tick de spawn pour les vendeurs actifs
CreateThread(function()
    while true do
        Wait(3000)
        local now = os.time()
        for src, sess in pairs(sellingPlayers) do
            if GetPlayerPed(src) == 0 then
                stopSelling(src)
            elseif not hasSellableDrug(src) then
                stopSelling(src, 'Plus de drogue en stock — mode vente coupé.')
            elseif countSellerCustomers(src) < (Config.SellingMaxCustomers or 3)
                   and now - (sess.lastSpawn or 0) >= (Config.SellingSpawnInterval or 18) then
                generateCustomerNear(src)
                sess.lastSpawn = now
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Tick de spawn
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        -- Despawn auto des clients trop vieux
        for id, c in pairs(customers) do
            if now >= c.expiresAt then removeCustomer(id) end
        end

        -- Clients de zone : création / retrait selon la distance des joueurs
        streamZoneCustomers()

        -- En mode dev: pas de spawn automatique, on passe par /dealing_spawn
        if Config.DevIgnoreZone then
            goto continue
        end

        -- Spawn dans chaque zone si sous la limite
        for idx in ipairs(Config.Zones) do
            local last = lastSpawnAtZone[idx] or 0
            if now - last >= (Config.CustomerSpawnCooldown or 30)
               and countCustomersInZone(idx) < (Config.MaxCustomersPerZone or 2) then
                generateCustomer(idx)
                lastSpawnAtZone[idx] = now
            end
        end

        ::continue::
    end
end)

-- ─────────────────────────────────────────────
-- Sync à la connexion
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:requestSync', function()
    local src = source
    local pc  = playerCoords(src)
    local range = Config.CustomerStreamRange or 150.0
    local list = {}
    for _, c in pairs(customers) do
        c.sentTo = c.sentTo or {}
        local mine = c.ownerSrc == src
        local near = not c.ownerSrc and pc and #(pc - vec3(c.x, c.y, c.z)) <= range
        if mine or near then
            c.sentTo[src] = true
            list[#list + 1] = publicData(c)
        end
    end
    TriggerClientEvent('pop_dealing:syncAll', src, list)
end)

-- ─────────────────────────────────────────────
-- Le joueur "approche" le client (verrouille pour éviter race)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:claim', function(customerId)
    local src = source
    local c   = customers[customerId]
    if Config.Debug then print(('[pop_dealing] claim src=%d id=%s c=%s'):format(src, tostring(customerId), tostring(c ~= nil))) end
    if not c then return end
    if not isNearCustomer(src, c) then return end
    if c.claimedBy and c.claimedBy ~= src then
        TriggerClientEvent('pop_dealing:notify', src, {
            icon = 'fas fa-circle-exclamation', message = 'Ce client discute déjà avec quelqu\'un.', duration = 3000,
        })
        return
    end
    c.claimedBy = src
    TriggerClientEvent('pop_dealing:offerDetails', src, {
        id           = c.id,
        drugDefId    = c.drugDefId,
        drugLabel    = c.drugLabel,
        drugIcon     = c.drugIcon,
        qty          = c.qty,
        hintUnit     = c.hintUnit,
        hintTotal    = c.hintUnit * c.qty,
        attemptsLeft = c.attemptsLeft,
        maxAttempts  = Config.MaxAttempts or 3,
    })
end)

RegisterNetEvent('pop_dealing:unclaim', function(customerId)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    if c.claimedBy == src then c.claimedBy = nil end
end)

-- ─────────────────────────────────────────────
-- Proposition (le joueur envoie son prix par unité)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:propose', function(customerId, proposedUnit)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    if c.claimedBy ~= src then return end
    if not isNearCustomer(src, c) then return end

    proposedUnit = math.floor(tonumber(proposedUnit) or 0)
    if proposedUnit <= 0 then return end

    -- Vérif stock
    local have = exports.pop_inventory:getItemCount(src, c.drugDefId)
    if have < c.qty then
        TriggerClientEvent('pop_dealing:notify', src, {
            icon = 'fas fa-circle-exclamation',
            message = ('Pas assez de %s (%d/%d).'):format(c.drugLabel, have, c.qty),
            duration = 3000,
        })
        c.claimedBy = nil
        TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
        return
    end

    -- Si flic infiltré → bust uniquement si le deal est accepté (sinon il joue le jeu)
    if proposedUnit <= c.maxUnit then
        if c.isCop then
            TriggerClientEvent('pop_dealing:bust', src, publicData(c))
            -- Alerte envoyée uniquement à la police
            local alert = {
                coords = vec3(c.x, c.y, c.z),
                radius = Config.BustAlertRadius,
                label  = ('Deal de drogue suspect (%s)'):format(placeLabel(c)),
            }
            for _, copSrc in ipairs(getPoliceSources()) do
                TriggerClientEvent('pop_dealing:dispatchAlert', copSrc, alert)
            end
            removeCustomer(customerId)
            return
        end

        -- Échange
        local totalPrice = proposedUnit * c.qty
        local ok = exports.pop_inventory:removeItem(src, c.drugDefId, c.qty)
        if not ok then
            c.claimedBy = nil
            TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
            return
        end

        -- Guerre de territoires : applique le multiplicateur de la zone + enregistre la vente
        local okT, finalPrice = pcall(function()
            return exports.pop_territories:recordDrugSale(src, totalPrice)
        end)
        if okT and finalPrice then
            totalPrice = finalPrice
        end

        -- Paiement en objet cash (pop_inventory), pas le compte ESX money
        local paid = exports.pop_inventory:addItem(src, Config.MoneyItem or 'cash', totalPrice)
        if not paid then
            -- Inventaire plein : on rend la marchandise
            exports.pop_inventory:addItem(src, c.drugDefId, c.qty)
            c.claimedBy = nil
            TriggerClientEvent('pop_dealing:notify', src, {
                icon = 'fas fa-circle-exclamation', message = 'Inventaire plein, deal annulé.', duration = 3000,
            })
            TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
            return
        end

        TriggerClientEvent('pop_dealing:proposeResult', src, {
            id          = c.id,
            status      = 'accept',
            unitPrice   = proposedUnit,
            totalPrice  = totalPrice,
        })
        TriggerClientEvent('pop_dealing:dealComplete', src, {
            drugLabel  = c.drugLabel,
            qty        = c.qty,
            totalPrice = totalPrice,
        })
        removeCustomer(customerId)

        -- Plus de drogue après cette vente → on coupe le mode vente
        if sellingPlayers[src] and not hasSellableDrug(src) then
            stopSelling(src, 'Dernier pochon vendu — vente terminée.')
        end
        return
    end

    -- Refus : décrémenter les tentatives
    c.attemptsLeft = c.attemptsLeft - 1

    if c.attemptsLeft <= 0 then
        -- Le client en a marre, il s'en va
        TriggerClientEvent('pop_dealing:proposeResult', src, {
            id     = c.id,
            status = 'walkaway',
        })
        removeCustomer(customerId)
        return
    end

    -- Indice : trop cher (haut) ; on pourrait raffiner pour donner un hint
    local hintDir = 'too_high'
    TriggerClientEvent('pop_dealing:proposeResult', src, {
        id           = c.id,
        status       = 'refuse',
        hintDir      = hintDir,
        attemptsLeft = c.attemptsLeft,
    })
end)

-- ─────────────────────────────────────────────
-- Refus du deal
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:refuse', function(customerId)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    -- Claimé par ce joueur, ou client libre (timeout d'approche) à proximité de lui
    if c.claimedBy ~= src and (c.claimedBy ~= nil or not isNearCustomer(src, c)) then return end
    -- Le client s'en va, vexé
    removeCustomer(customerId)
end)

-- ─────────────────────────────────────────────
-- Cleanup à la déco
-- ─────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    stopSelling(src)
    for _, c in pairs(customers) do
        if c.claimedBy == src then c.claimedBy = nil end
        if c.sentTo then c.sentTo[src] = nil end
    end
end)

-- ─────────────────────────────────────────────
-- Commandes dev (réservées aux admins : ace pop.admin)
-- ─────────────────────────────────────────────

local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'pop.admin')
end

-- Spawn un client juste devant le joueur (peu importe la zone)
RegisterCommand('dealing_spawn', function(src)
    if not isAdmin(src) then return end
    if src == 0 then return print('[pop_dealing] à utiliser en jeu') end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pc      = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad     = math.pi / 180.0
    -- 2m devant le joueur (vecteur "avant" du ped)
    local fx      = pc.x - math.sin(heading * rad) * 2.0
    local fy      = pc.y + math.cos(heading * rad) * 2.0

    local drug     = pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]

    local id = nextId
    nextId = nextId + 1

    customers[id] = {
        id           = id,
        zoneIdx      = 0,
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,
        maxUnit      = maxUnit,
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = fx,
        y            = fy,
        z            = pc.z,
        heading      = (heading + 180.0) % 360.0,
        isCop        = false,
        claimedBy    = nil,
        expiresAt    = os.time() + 600,
        sentTo       = {},
    }

    if Config.Debug then
        print(('[pop_dealing] spawn id=%d model=%s drug=%s x%d hint=$%d max=$%d @ %.2f,%.2f,%.2f'):format(
            id, model, drug.defId, qty, hintUnit, maxUnit, fx, fy, pc.z))
    end

    sendCustomer(src, customers[id])
    TriggerClientEvent('pop_dealing:notify', src, {
        icon = 'fas fa-info',
        message = ('Client spawn #%d : %s x%d (hint $%d/u, max $%d/u)'):format(id, drug.label, qty, hintUnit, maxUnit),
        duration = 4000,
    })
end, false)

-- Liste les clients actifs côté serveur
RegisterCommand('dealing_list', function(src)
    if not isAdmin(src) then return end
    local n = 0
    for id, c in pairs(customers) do
        n = n + 1
        local msg = ('[pop_dealing] #%d zone=%d drug=%s x%d max=$%d/u claimed=%s coords=%.1f,%.1f,%.1f'):format(
            id, c.zoneIdx or 0, c.drugDefId, c.qty, c.maxUnit or 0, tostring(c.claimedBy), c.x, c.y, c.z)
        if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { '[dealing]', msg } }) end
    end
    if n == 0 then
        local msg = '[pop_dealing] aucun client actif'
        if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { '[dealing]', msg } }) end
    end
end, false)

-- Wipe tous les clients
RegisterCommand('dealing_clear', function(src)
    if not isAdmin(src) then return end
    for id in pairs(customers) do removeCustomer(id) end
    if src ~= 0 then
        TriggerClientEvent('pop_dealing:notify', src, { icon = 'fas fa-trash', message = 'Tous les clients supprimés.', duration = 3000 })
    end
end, false)
