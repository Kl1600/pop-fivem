-- Events serveur importés de tab_interactions (hors menottes/escorte/fouille déjà gérés).

RegisterNetEvent('pop_inventory:server:consumeItem', function(itemName)
    exports.pop_inventory:RemoveItem(source, itemName, 1)
end)

RegisterNetEvent('pop_inventory:server:putInVehicle', function(targetId, vehNetId)
    if not Bridge.HasJob(source, 'police') then return end
    TriggerClientEvent('pop_inventory:client:putInVehicle', targetId, vehNetId)
end)

RegisterNetEvent('pop_inventory:server:outVehicle', function(targetId)
    if not Bridge.HasJob(source, 'police') then return end
    TriggerClientEvent('pop_inventory:client:outVehicle', targetId)
end)

RegisterNetEvent('pop_inventory:server:healPlayer', function(targetId)
    local src = source
    if not Bridge.HasJob(src, 'ambulance') then return end
    if exports.pop_inventory:RemoveItem(src, 'kitsoins', 1) then
        TriggerClientEvent('pop_inventory:client:heal', targetId)
        Inv.NotifyTyped(src, { title = L('ems_title'), message = L('individual_healed'), type = 'success' })
    end
end)

