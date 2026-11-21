-- =====================================================
--  Module SABOT DE ROUE (ex tab_sabot) — SERVER
--  État des sabots conservé par netId du véhicule.
-- =====================================================

local clamped = {}  -- [vehNetId] = true

local function getESX()
    if GetResourceState('es_extended') ~= 'started' then return nil end
    return exports['es_extended']:getSharedObject()
end

local function isAllowed(src)
    if not SabotConfig.PoliceOnly then return true end
    local esx = getESX()
    if not esx then return true end
    local xPlayer = esx.GetPlayerFromId(src)
    return xPlayer ~= nil and xPlayer.job ~= nil and xPlayer.job.name == SabotConfig.PoliceJob
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
    TriggerClientEvent('notification:client:send', target, {
        title    = 'Sabot',
        message  = message,
        type     = ntype or 'info',
        duration = 5000
    })
end

-- POSE : nécessite l'item sabot
RegisterNetEvent('tab_sabot:server:place', function(vehNetId)
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
    TriggerClientEvent('tab_sabot:client:sync', -1, vehNetId, true)

    notify(src, 'Sabot posé : véhicule immobilisé.', 'success')
end)

-- RETRAIT : nécessite la clé, rend le sabot
RegisterNetEvent('tab_sabot:server:remove', function(vehNetId)
    local src = source
    vehNetId = tonumber(vehNetId)
    if not vehNetId then return end
    if not clamped[vehNetId] then return end
    if not isAllowed(src) then return end
    if not isNearVehicle(src, vehNetId) then return end

    local keys = exports.pop_inventory:getItemCount(src, SabotConfig.KeyItem)
    if not keys or keys <= 0 then
        notify(src, 'Il vous faut une clé de sabot.', 'error')
        return
    end

    clamped[vehNetId] = nil
    TriggerClientEvent('tab_sabot:client:sync', -1, vehNetId, false)

    exports.pop_inventory:GiveItem(src, SabotConfig.SabotItem, 1)
    notify(src, 'Sabot retiré.', 'success')
end)

-- Synchronisation complète demandée par un client (connexion / restart ressource)
RegisterNetEvent('tab_sabot:server:requestSync', function()
    local src = source
    local list = {}
    for netId in pairs(clamped) do
        list[#list + 1] = netId
    end
    TriggerClientEvent('tab_sabot:client:fullSync', src, list)
end)
