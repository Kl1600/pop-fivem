local ESX = exports['es_extended']:getSharedObject()

local staticVehicles = {}

-- Chargement de modèle avec délai max (évite une boucle infinie si le modèle n'existe pas)
local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

-- Point de spawn libre ? (les véhicules d'exposition ne comptent pas)
local function isSpawnClear(coords, radius)
    local ignore = {}
    for _, v in ipairs(staticVehicles) do ignore[v] = true end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if not ignore[veh] and #(GetEntityCoords(veh) - coords) <= radius then
            return false
        end
    end
    return true
end

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(500)
    end

    for _, location in ipairs(Config.Locations) do
        local locSpawn = location.spawnCoords
        for _, data in ipairs(location.displayVehicles) do
            local hash = GetHashKey(data.model)
            if not loadModel(hash) then
                print(('^3[pop_bikerental] Modèle introuvable : %s (véhicule d\'exposition ignoré)^7'):format(data.model))
                goto continue
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
                        local isClear = isSpawnClear(vector3(locSpawn.x, locSpawn.y, locSpawn.z), 3.0)
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
            ::continue::
        end
    end
end)

RegisterNetEvent('pop_bikerental:client:spawnVehicle', function(model, sx, sy, sz, sw)
    local hash = GetHashKey(model)
    if not loadModel(hash) then return end

    ESX.Game.SpawnVehicle(model, vector3(sx, sy, sz), sw, function(vehicle)
        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        local plate = GetVehicleNumberPlateText(vehicle)
        SetModelAsNoLongerNeeded(hash)

        -- vehicle_keys est optionnel : seulement s'il tourne sur le serveur
        if model == 'ventoso' and GetResourceState('vehicle_keys') == 'started' then
            pcall(TriggerServerEvent, 'vehicle_keys:server:giveKey', plate, 'Ventoso Location')
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
