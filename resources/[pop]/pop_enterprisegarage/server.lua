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
                for _, v in ipairs(g.vehicles or {}) do
                    exports.oxmysql:execute(
                        'INSERT INTO enterprise_garage_vehicles (garage, job, model, label, plate, state) VALUES (?, ?, ?, ?, ?, ?)',
                        { g.label, g.job, v.model, v.label or v.model, genPlate(), 'in' }
                    )
                end
                print(('[EntrepriseGarage] Flotte initialisée pour "%s" (%d véhicules).'):format(g.label, #(g.vehicles or {})))
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
            if row.state ~= 'in' then
                TriggerClientEvent('esx:showNotification', src, 'Ce véhicule est déjà sorti.')
                return
            end
            -- Passage atomique 'in' -> 'out' : empêche une double sortie simultanée.
            exports.oxmysql:update(
                'UPDATE enterprise_garage_vehicles SET state = ? WHERE garage = ? AND plate = ? AND state = ?',
                { 'out', garageName, plate, 'in' },
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
RegisterNetEvent('pop_enterprisegarage:store', function(garageName, plate, props)
    local src = source
    local garage = findGarage(garageName)
    if not canUse(src, garage) then return end
    plate = normalPlate(plate)

    exports.oxmysql:execute(
        'SELECT state FROM enterprise_garage_vehicles WHERE garage = ? AND plate = ?',
        { garageName, plate },
        function(rows)
            local row = rows and rows[1]
            if not row then
                TriggerClientEvent('esx:showNotification', src, 'Ce véhicule n\'appartient pas à ce garage.')
                return
            end
            -- Range : sauve les props, repasse en garage.
            exports.oxmysql:execute(
                'UPDATE enterprise_garage_vehicles SET state = ?, props = ? WHERE garage = ? AND plate = ?',
                { 'in', type(props) == 'table' and json.encode(props) or nil, garageName, plate }
            )
            -- Collaboration : retire la plaque de la persistance physique.
            exports.oxmysql:execute('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })

            TriggerClientEvent('pop_enterprisegarage:confirmStore', src, plate)
        end
    )
end)
