-- =====================================================
--  Module CLÉS DE VÉHICULE (ex vehicle_keys) — CLIENT
-- =====================================================
local function trim(value)
    if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'toggle_vehicle_lock',
            icon = 'fa-solid fa-key',
            label = 'Clé',
            distance = VehicleKeysConfig.InteractionDistance,
            onSelect = function(data)
                local entity = data.entity
                local plate = trim(GetVehicleNumberPlateText(entity))
                local netId = NetworkGetNetworkIdFromEntity(entity)
                TriggerServerEvent('vehicle_keys:server:toggleLock', netId, plate)
            end
        }
    })
end)

RegisterNetEvent('vehicle_keys:client:playAnimation', function()
    local dict = VehicleKeysConfig.Animations.lock.dict
    local anim = VehicleKeysConfig.Animations.lock.anim
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, 8.0, -1, 48, 1, false, false, false)
    Wait(VehicleKeysConfig.Animations.lock.duration)
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('vehicle_keys:client:syncLockState', function(netId, isLocked)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        SetVehicleDoorsLocked(entity, isLocked and 2 or 1)
        SetVehicleLights(entity, 2)
        Wait(200)
        SetVehicleLights(entity, 0)
        Wait(200)
        SetVehicleLights(entity, 2)
        Wait(200)
        SetVehicleLights(entity, 0)
    end
end)

RegisterNetEvent('vehicle_keys:client:ShowNotify', function(data)
    exports["pop_notify"]:ShowNotify(data)
end)

RegisterCommand('givekey', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local plate = nil
    local modelName = "Véhicule"

    if vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle)
        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local labelText = GetLabelText(displayName)
        modelName = (labelText == "NULL" and displayName:sub(1,1):upper() .. displayName:sub(2):lower()) or labelText
    else
        local pedCoords = GetEntityCoords(ped)
        local closestVehicle = 0
        local closestDistance = 5.0
        local pool = GetGamePool('CVehicle')
        for i = 1, #pool do
            local v = pool[i]
            local dist = #(pedCoords - GetEntityCoords(v))
            if dist < closestDistance then
                closestDistance = dist
                closestVehicle = v
            end
        end
        if closestVehicle ~= 0 then
            plate = GetVehicleNumberPlateText(closestVehicle)
            local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(closestVehicle))
            local labelText = GetLabelText(displayName)
            modelName = (labelText == "NULL" and displayName:sub(1,1):upper() .. displayName:sub(2):lower()) or labelText
        end
    end

    if not plate then
        TriggerEvent('vehicle_keys:client:ShowNotify', {
            icon = "fas fa-info",
            message = "Aucun véhicule à proximité ou dans lequel vous êtes installé.",
            duration = 5000
        })
        return
    end

    TriggerServerEvent('vehicle_keys:server:giveKey', plate, modelName)
end, false)
