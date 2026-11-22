lib.versionCheck('overextended/ox_target')

if not lib.checkDependency('ox_lib', '3.21.0', true) then return end

---@type table<number, EntityInterface>
local entityStates = {}

---@param netId number
RegisterNetEvent('ox_target:setEntityHasOptions', function(netId)
    local entity = Entity(NetworkGetEntityFromNetworkId(netId))
    entity.state.hasTargetOptions = true
    entityStates[netId] = entity
end)

---@param netId number
---@param door number
RegisterNetEvent('ox_target:toggleEntityDoor', function(netId, door)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local owner = NetworkGetEntityOwner(entity)
    TriggerClientEvent('ox_target:toggleEntityDoor', owner, netId, door)
end)

CreateThread(function()
    local arr = {}
    local num = 0

    while true do
        Wait(10000)

        for netId, entity in pairs(entityStates) do
            if not DoesEntityExist(entity.__data) or not entity.state.hasTargetOptions then
                entityStates[netId] = nil
                num += 1

                arr[num] = netId
            end
        end

        if num > 0 then
            TriggerClientEvent('ox_target:removeEntity', -1, arr)
            table.wipe(arr)

            num = 0
        end
    end
end)

-- POP : identité du joueur pour l'en-tête du menu (NOM Prénom + ID).
lib.callback.register('ox_target:popIdentity', function(source)
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, ESX = pcall(function() return exports.es_extended:getSharedObject() end)
    local xPlayer = ok and ESX and ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local first = xPlayer.get and xPlayer.get('firstName')
    local last = xPlayer.get and xPlayer.get('lastName')

    if (not first or first == '') and xPlayer.getName then
        local full = xPlayer.getName() or ''
        first, last = full:match('^(%S+)%s+(.+)$')
        first = first or full
    end

    return { first = first, last = last }
end)
