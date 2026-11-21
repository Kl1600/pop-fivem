local ESX = exports['es_extended']:getSharedObject()

local staticVehicles = {}

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(500)
    end

    for _, location in ipairs(Config.Locations) do
        local locSpawn = location.spawnCoords
        for _, data in ipairs(location.displayVehicles) do
            local hash = GetHashKey(data.model)
            RequestModel(hash)
            while not HasModelLoaded(hash) do
                Wait(10)
            end

            local veh = CreateVehicle(hash, data.coords.x, data.coords.y, data.coords.z - 0.2, data.coords.w, false, false)
            SetEntityAsMissionEntity(veh, true, true)
            SetEntityInvincible(veh, true)
            FreezeEntityPosition(veh, true)
            SetVehicleDoorsLocked(veh, 2)
            SetModelAsNoLongerNeeded(hash)

            -- N'autoriser que l'option "Louer ..." sur ces véhicules d'exposition
            Entity(veh).state:set('onlyRentTarget', true, false)

            table.insert(staticVehicles, veh)

            exports.ox_target:addLocalEntity(veh, {
                {
                    name = 'rent_' .. data.model,
                    icon = 'fas fa-key',
                    label = data.label,
                    onSelect = function()
                        local isClear = ESX.Game.IsSpawnPointClear(vector3(locSpawn.x, locSpawn.y, locSpawn.z), 3.0)
                        if not isClear then
                            exports['pop_notify']:ShowNotify({
                                title = 'Zone bloquée',
                                message = 'Il y a déjà un véhicule sur la zone !',
                                icon = 'fas fa-triangle-exclamation',
                                duration = 5000
                            })
                            return
                        end
                        TriggerServerEvent('pop_bikerental:server:buyVehicle', data.model, locSpawn.x, locSpawn.y, locSpawn.z, locSpawn.w)
                    end
                }
            })
        end
    end
end)

RegisterNetEvent('pop_bikerental:client:spawnVehicle', function(model, sx, sy, sz, sw)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    ESX.Game.SpawnVehicle(model, vector3(sx, sy, sz), sw, function(vehicle)
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        local plate = GetVehicleNumberPlateText(vehicle)
        SetModelAsNoLongerNeeded(hash)

        if model == 'ventoso' then
            TriggerServerEvent('vehicle_keys:server:giveKey', plate, 'Ventoso Location')
            exports['pop_notify']:ShowNotify({
                title = 'Clés',
                message = 'Vous avez reçu les clés du Ventoso.',
                icon = 'fas fa-key',
                duration = 5000
            })
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, veh in ipairs(staticVehicles) do
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
            end
        end
    end
end)
