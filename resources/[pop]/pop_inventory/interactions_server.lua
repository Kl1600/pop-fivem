-- Events serveur importés de tab_interactions (hors menottes/escorte/fouille déjà gérés).
local ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent('pop_inventory:server:consumeItem', function(itemName)
    exports.pop_inventory:RemoveItem(source, itemName, 1)
end)

RegisterNetEvent('pop_inventory:server:putInVehicle', function(targetId, vehNetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= 'police' then return end
    TriggerClientEvent('pop_inventory:client:putInVehicle', targetId, vehNetId)
end)

RegisterNetEvent('pop_inventory:server:outVehicle', function(targetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= 'police' then return end
    TriggerClientEvent('pop_inventory:client:outVehicle', targetId)
end)

RegisterNetEvent('pop_inventory:server:healPlayer', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= 'ambulance' then return end
    if exports.pop_inventory:RemoveItem(src, 'kitsoins', 1) then
        TriggerClientEvent('pop_inventory:client:heal', targetId)
        TriggerClientEvent('notification:client:send', src, { title = 'EMS', message = 'Individu soigné.', type = 'success' })
    end
end)

