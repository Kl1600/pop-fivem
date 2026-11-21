-- pop_bennys — client : aperçu des modifications (callbacks NUI)

RegisterNUICallback('preview_paint', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        if data.target == 'primary' then
            SetVehicleCustomPrimaryColour(Bennys.vehicle, data.r, data.g, data.b)
        else
            SetVehicleCustomSecondaryColour(Bennys.vehicle, data.r, data.g, data.b)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_wheel', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        SetVehicleWheelType(Bennys.vehicle, data.wheelType)
        SetVehicleMod(Bennys.vehicle, 23, data.modIndex, data.customTires or false)
    end
    cb('ok')
end)

RegisterNUICallback('preview_body', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        SetVehicleMod(Bennys.vehicle, data.modType, data.modIndex, false)
    end
    cb('ok')
end)

RegisterNUICallback('preview_performance', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        if data.isToggle then
            ToggleVehicleMod(Bennys.vehicle, data.modType, data.value)
        else
            SetVehicleMod(Bennys.vehicle, data.modType, data.modIndex, false)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_neon', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        if data.type == 'color' then
            SetVehicleNeonLightsColour(Bennys.vehicle, data.r, data.g, data.b)
        else
            SetVehicleNeonLightEnabled(Bennys.vehicle, data.index, data.enabled)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_window', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        SetVehicleWindowTint(Bennys.vehicle, data.tint)
    end
    cb('ok')
end)

RegisterNUICallback('preview_plate', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        -- Seul le style de plaque est modifiable (le texte est lié aux papiers du véhicule)
        if data.style ~= nil then SetVehicleNumberPlateTextIndex(Bennys.vehicle, data.style) end
    end
    cb('ok')
end)

RegisterNUICallback('preview_livery', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        if data.system == 'mod' then
            SetVehicleMod(Bennys.vehicle, 48, data.index, false)
        else
            SetVehicleLivery(Bennys.vehicle, data.index)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_extra', function(data, cb)
    if DoesEntityExist(Bennys.vehicle) then
        -- SetVehicleExtra : 0 = activé, 1 = désactivé (inversé).
        SetVehicleExtra(Bennys.vehicle, data.id, data.enabled and 0 or 1)
    end
    cb('ok')
end)
