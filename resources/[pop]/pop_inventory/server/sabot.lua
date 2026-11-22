-- =====================================================
--  Module SABOT DE ROUE (ex tab_sabot) — SERVER
--  État des sabots conservé par netId du véhicule.
-- =====================================================

local clamped = {}  -- [vehNetId] = true

local function isAllowed(src)
    if not SabotConfig.PoliceOnly then return true end
    return Bridge.HasJob(src, SabotConfig.PoliceJob)
end

-- Le joueur doit être à côté du véhicule visé (anti-triche : netId arbitraire)
local function isNearVehicle(src, vehNetId)
    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= 8.0
end

local function notify(target, message, ntype)
    Inv.NotifyTyped(target, {
        title    = L('clamp_title'),
        message  = message,
        type     = ntype or 'info',
        duration = 5000
    })
end

-- POSE : nécessite l'item sabot
RegisterNetEvent('pop_sabot:server:place', function(vehNetId)
    local src = source
    vehNetId = tonumber(vehNetId)
    if not vehNetId then return end
    if clamped[vehNetId] then return end
    if not isAllowed(src) then return end
    if not isNearVehicle(src, vehNetId) then return end

    local count = exports.pop_inventory:getItemCount(src, SabotConfig.SabotItem)
    if not count or count <= 0 then return end

    if not exports.pop_inventory:RemoveItem(src, SabotConfig.SabotItem, 1) then return end

    clamped[vehNetId] = true
    TriggerClientEvent('pop_sabot:client:sync', -1, vehNetId, true)

    notify(src, L('clamp_placed'), 'success')
end)

-- RETRAIT : nécessite la clé, rend le sabot
RegisterNetEvent('pop_sabot:server:remove', function(vehNetId)
    local src = source
    vehNetId = tonumber(vehNetId)
    if not vehNetId then return end
    if not clamped[vehNetId] then return end
    if not isAllowed(src) then return end
    if not isNearVehicle(src, vehNetId) then return end

    local keys = exports.pop_inventory:getItemCount(src, SabotConfig.KeyItem)
    if not keys or keys <= 0 then
        notify(src, L('clamp_need_key'), 'error')
        return
    end

    clamped[vehNetId] = nil
    TriggerClientEvent('pop_sabot:client:sync', -1, vehNetId, false)

    exports.pop_inventory:GiveItem(src, SabotConfig.SabotItem, 1)
    notify(src, L('clamp_removed'), 'success')
end)

-- Synchronisation complète demandée par un client (connexion / restart ressource)
RegisterNetEvent('pop_sabot:server:requestSync', function()
    local src = source
    local list = {}
    for netId in pairs(clamped) do
        list[#list + 1] = netId
    end
    TriggerClientEvent('pop_sabot:client:fullSync', src, list)
end)
