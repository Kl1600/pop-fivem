-- pop_enterprisegarage — fonctions communes du serveur (chargé en premier, voir fxmanifest).
-- Flotte d'entreprise persistante. Collabore avec pop_vehiclepersistence :
--   • Sortie  -> véhicule spawné + clés données -> pop_vehiclepersistence le sauve.
--   • Rangement -> retiré du monde ET de la table persistent_vehicles.

Garage = {}

function Garage.FindGarage(name)
    for _, g in ipairs(Config.Garages) do
        if g.label == name then return g end
    end
    return nil
end

function Garage.NormalPlate(plate)
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

-- Plaque unique : absente de la flotte, des véhicules joueurs et de la persistance
function Garage.UniquePlate()
    for _ = 1, 20 do
        local plate = genPlate()
        local used = (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM enterprise_garage_vehicles WHERE plate = ?', { plate })) or 0) > 0
        if not used then
            local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM owned_vehicles WHERE REPLACE(plate, " ", "") = ?', { plate })
            used = ok and (tonumber(n) or 0) > 0
        end
        if not used then
            local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM persistent_vehicles WHERE plate = ?', { plate })
            used = ok and (tonumber(n) or 0) > 0
        end
        if not used then return plate end
    end
    return genPlate()
end

-- Retire la plaque de la persistance (mémoire + base) pour qu'elle ne réapparaisse pas
function Garage.ForgetPersistent(plate)
    if GetResourceState('pop_vehiclepersistence') == 'started' then
        local ok = pcall(function() exports.pop_vehiclepersistence:Forget(plate) end)
        if ok then return end
    end
    MySQL.update('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
end

-- Entité réseau d'une plaque (usage ponctuel)
function Garage.FindVehicleByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and Garage.NormalPlate(GetVehicleNumberPlateText(veh)) == plate then
            return veh
        end
    end
    return nil
end

function Garage.IsWrecked(veh)
    return GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= -3900.0 or GetVehicleBodyHealth(veh) <= 0.0
end

-- pop_inventory direct : clés à métadonnées (plaque), retirées par id.
function Garage.GiveKeys(src, plate)
    if GetResourceState('pop_inventory') ~= 'started' then return end
    pcall(function()
        exports.pop_inventory:GiveItem(src, 'carkeys', 1, {
            plate = plate,
            description = L('key_description', plate),
        })
    end)
end

function Garage.TakeKeys(src, plate)
    if GetResourceState('pop_inventory') ~= 'started' then return end
    pcall(function()
        local items = exports.pop_inventory:GetPlayerItems(src, 'carkeys') or {}
        for _, item in ipairs(items) do
            if item.meta and item.meta.plate and Garage.NormalPlate(item.meta.plate) == plate and item.id then
                exports.pop_inventory:removeItemById(src, item.id)
            end
        end
    end)
end

-- ── Validation accès ─────────────────────────────────────────────────────────
-- Job du garage, et joueur au garage (point d'interaction ou zone de sortie).
function Garage.CanUse(src, garage)
    if not garage then return false end
    if not Bridge.HasJob(src, garage.job) then return false end
    local s = garage.spawn
    return Bridge.IsNear(src, garage.coords, Config.UseDistance)
        or Bridge.IsNear(src, vector3(s.x, s.y, s.z), Config.UseDistance)
end
