-- pop_enterprisegarage — serveur
-- Flotte d'entreprise persistante. Collabore avec pop_vehiclepersistence :
--   • Sortie  -> véhicule spawné + clés données -> pop_vehiclepersistence le sauve.
--   • Rangement -> retiré du monde ET de la table persistent_vehicles.

ESX = exports['es_extended']:getSharedObject()

local function findGarage(name)
    for _, g in ipairs(Config.Garages) do
        if g.label == name then return g end
    end
    return nil
end

local function normalPlate(plate)
    return string.upper(string.gsub(plate or '', '%s+', ''))
end

local function genPlate()
    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local p = ''
    for _ = 1, 8 do
        local r = math.random(1, #charset)
        p = p .. string.sub(charset, r, r)
    end
    return p
end

local function scalarAwait(query, params)
    local p = promise.new()
    exports.oxmysql:scalar(query, params, function(r) p:resolve(r) end)
    return Citizen.Await(p)
end

-- Plaque unique : absente de la flotte, des véhicules joueurs et de la persistance
local function uniquePlate()
    for _ = 1, 20 do
        local plate = genPlate()
        local used = (tonumber(scalarAwait('SELECT COUNT(*) FROM enterprise_garage_vehicles WHERE plate = ?', { plate })) or 0) > 0
        if not used then
            local ok, n = pcall(scalarAwait, 'SELECT COUNT(*) FROM owned_vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
            used = ok and (tonumber(n) or 0) > 0
        end
        if not used then
            local ok, n = pcall(scalarAwait, 'SELECT COUNT(*) FROM persistent_vehicles WHERE plate = ?', { plate })
            used = ok and (tonumber(n) or 0) > 0
        end
        if not used then return plate end
    end
    return genPlate()
end

local function persistenceStarted()
    return GetResourceState('pop_vehiclepersistence') == 'started'
end

-- Retire la plaque de la persistance (mémoire + base) pour qu'elle ne réapparaisse pas
local function forgetPersistent(plate)
    if persistenceStarted() then
        local ok = pcall(function() exports.pop_vehiclepersistence:Forget(plate) end)
        if ok then return end
    end
    exports.oxmysql:execute('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
end

-- Entité réseau d'une plaque (usage ponctuel)
local function findVehicleByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and normalPlate(GetVehicleNumberPlateText(veh)) == plate then
            return veh
        end
    end
    return nil
end

local function isWrecked(veh)
    return GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= -3900.0 or GetVehicleBodyHealth(veh) <= 0.0
end

-- Reprend les clés de cette plaque au joueur (pop_inventory)
local function takeKeys(src, plate)
    if GetResourceState('pop_inventory') ~= 'started' then return end
    pcall(function()
        local items = exports.pop_inventory:GetPlayerItems(src, 'carkeys') or {}
        for _, item in ipairs(items) do
            if item.meta and item.meta.plate and normalPlate(item.meta.plate) == plate and item.id then
                exports.pop_inventory:removeItemById(src, item.id)
            end
        end
    end)
end

-- ── Table + seed de la flotte ────────────────────────────────────────────────
CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS enterprise_garage_vehicles (
            id     INT AUTO_INCREMENT PRIMARY KEY,
            garage VARCHAR(64)  NOT NULL,
            job    VARCHAR(64)  NOT NULL,
            model  VARCHAR(64)  NOT NULL,
            label  VARCHAR(64),
            plate  VARCHAR(12)  NOT NULL UNIQUE,
            state  VARCHAR(12)  NOT NULL DEFAULT 'in',
            props  LONGTEXT,
            INDEX idx_garage (garage),
            INDEX idx_job (job)
        )
    ]], {}, function()
        -- Seed : insère la flotte configurée uniquement si le garage est vide.
        for _, g in ipairs(Config.Garages) do
            exports.oxmysql:scalar('SELECT COUNT(*) FROM enterprise_garage_vehicles WHERE garage = ?', { g.label }, function(count)
                if (count or 0) > 0 then return end
                CreateThread(function()
                    for _, v in ipairs(g.vehicles or {}) do
                        exports.oxmysql:execute(
                            'INSERT INTO enterprise_garage_vehicles (garage, job, model, label, plate, state) VALUES (?, ?, ?, ?, ?, ?)',
                            { g.label, g.job, v.model, v.label or v.model, uniquePlate(), 'in' }
                        )
                    end
                    print(('[EntrepriseGarage] Flotte initialisée pour "%s" (%d véhicules).'):format(g.label, #(g.vehicles or {})))
                end)
            end)
        end
    end)
end)

-- ── Validation accès ─────────────────────────────────────────────────────────
local function canUse(src, garage)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if not garage then return false end
    if xPlayer.getJob().name ~= garage.job then return false end
    -- Anti-abus : le joueur doit être au garage (point d'interaction ou zone de sortie).
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local s = garage.spawn
    return #(pos - garage.coords) < 40.0 or #(pos - vector3(s.x, s.y, s.z)) < 40.0
end

-- Clés autorisées : uniquement pour un véhicule que ce joueur vient de sortir.
local pendingKeys = {}
AddEventHandler('playerDropped', function() pendingKeys[source] = nil end)

-- ── Liste de la flotte ───────────────────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:requestList', function(garageName)
    local src = source
    local garage = findGarage(garageName)
    if not canUse(src, garage) then return end

    exports.oxmysql:execute(
        'SELECT model, label, plate, state FROM enterprise_garage_vehicles WHERE garage = ? ORDER BY label',
        { garageName },
        function(rows)
            TriggerClientEvent('pop_enterprisegarage:openMenu', src, {
                garage   = garageName,
                vehicles = rows or {},
            })
        end
    )
end)

-- ── Sortir un véhicule ───────────────────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:takeOut', function(garageName, plate)
    local src = source
    local garage = findGarage(garageName)
    if not canUse(src, garage) then return end
    plate = normalPlate(plate)

    exports.oxmysql:execute(
        'SELECT model, props, state FROM enterprise_garage_vehicles WHERE garage = ? AND plate = ?',
        { garageName, plate },
        function(rows)
            local row = rows and rows[1]
            if not row then return end
            local fromState = 'in'
            if row.state ~= 'in' then
                -- Véhicule sorti : récupérable seulement s'il n'existe plus dans le monde
                -- (détruit, supprimé, ou rangé loin de tout joueur). Sinon : déjà sorti.
                local veh = findVehicleByPlate(plate)
                if veh and not isWrecked(veh) then
                    TriggerClientEvent('esx:showNotification', src, 'Ce véhicule est déjà sorti.')
                    return
                end
                if veh then DeleteEntity(veh) end
                forgetPersistent(plate)
                fromState = row.state
            end
            -- Passage atomique -> 'out' : empêche une double sortie simultanée.
            exports.oxmysql:update(
                'UPDATE enterprise_garage_vehicles SET state = ? WHERE garage = ? AND plate = ? AND state = ?',
                { 'out', garageName, plate, fromState },
                function(affected)
                    if not affected or affected == 0 then return end
                    local props = nil
                    if row.props and row.props ~= '' then
                        local ok, decoded = pcall(json.decode, row.props)
                        if ok then props = decoded end
                    end
                    pendingKeys[src] = pendingKeys[src] or {}
                    pendingKeys[src][plate] = true
                    TriggerClientEvent('pop_enterprisegarage:spawn', src, {
                        model = row.model,
                        plate = plate,
                        props = props,
                        spawn = garage.spawn,
                    })
                end
            )
        end
    )
end)

-- ── Clés (pop_inventory) après spawn ─────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:giveKeys', function(plate)
    local src = source
    plate = normalPlate(plate)
    if not pendingKeys[src] or not pendingKeys[src][plate] then return end
    pendingKeys[src][plate] = nil
    if GetResourceState('pop_inventory') ~= 'started' then return end
    pcall(function()
        exports.pop_inventory:GiveItem(src, 'carkeys', 1, {
            plate = plate,
            description = 'Plaque: ' .. plate,
        })
    end)
end)

-- ── Ranger un véhicule ───────────────────────────────────────────────────────
-- Contrôles serveur : véhicule de ce garage, sorti ('out'), entité réelle portant
-- cette plaque et ce modèle, à côté du joueur. Empêche la duplication.
local storing = {}

RegisterNetEvent('pop_enterprisegarage:store', function(garageName, plate, props, netId)
    local src = source
    local garage = findGarage(garageName)
    if not canUse(src, garage) then return end
    plate = normalPlate(plate)
    if plate == '' or storing[plate] then return end

    local veh = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2
        or normalPlate(GetVehicleNumberPlateText(veh)) ~= plate then
        TriggerClientEvent('esx:showNotification', src, 'Aucun véhicule à ranger.')
        return
    end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 8.0 then
        TriggerClientEvent('esx:showNotification', src, 'Approchez-vous du véhicule.')
        return
    end

    storing[plate] = true
    exports.oxmysql:execute(
        'SELECT model, state FROM enterprise_garage_vehicles WHERE garage = ? AND plate = ?',
        { garageName, plate },
        function(rows)
            local row = rows and rows[1]
            if not row then
                storing[plate] = nil
                TriggerClientEvent('esx:showNotification', src, 'Ce véhicule n\'appartient pas à ce garage.')
                return
            end
            if row.state ~= 'out' then
                storing[plate] = nil
                TriggerClientEvent('esx:showNotification', src, 'Ce véhicule est déjà au garage.')
                return
            end
            if math.tointeger(GetEntityModel(veh) % 4294967296) ~= math.tointeger(GetHashKey(row.model) % 4294967296) then
                storing[plate] = nil
                TriggerClientEvent('esx:showNotification', src, 'Ce véhicule n\'appartient pas à ce garage.')
                return
            end

            -- Props : table de taille raisonnable, plaque et modèle forcés
            local propsJson = nil
            if type(props) == 'table' then
                props.plate = plate
                props.model = GetHashKey(row.model)
                local ok, encoded = pcall(json.encode, props)
                if ok and encoded and #encoded <= 16000 then propsJson = encoded end
            end

            exports.oxmysql:update(
                'UPDATE enterprise_garage_vehicles SET state = ?, props = ? WHERE garage = ? AND plate = ? AND state = ?',
                { 'in', propsJson, garageName, plate, 'out' },
                function(affected)
                    storing[plate] = nil
                    if not affected or affected == 0 then return end
                    -- Collaboration : retire la plaque de la persistance (mémoire + base).
                    forgetPersistent(plate)
                    takeKeys(src, plate)
                    TriggerClientEvent('pop_enterprisegarage:confirmStore', src, plate)
                    -- Filet de sécurité : supprime l'entité si le client ne l'a pas fait.
                    SetTimeout(2000, function()
                        if DoesEntityExist(veh) then DeleteEntity(veh) end
                    end)
                end
            )
        end
    )
end)
