-- =====================================================
--  Module CLÉS DE VÉHICULE (ex vehicle_keys) — SERVER
-- =====================================================
RegisterNetEvent('vehicle_keys:server:toggleLock', function(netId, plate)
    local _source = source
    netId = tonumber(netId)
    if not netId then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    -- La plaque fait foi côté serveur (jamais celle envoyée par le client) + portée de la télécommande
    plate = GetVehicleNumberPlateText(vehicle) or tostring(plate or '')
    local ped = GetPlayerPed(_source)
    if ped and ped ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 30.0 then return end

    local success, items = pcall(function()
        return exports.pop_inventory:GetPlayerItems(_source, VehicleKeysConfig.KeyItemName)
    end)
    if not success then
        print('[vehicle_keys] Error calling GetPlayerItems:', items)
        return
    end

    local hasKey = false
    for _, item in ipairs(items) do
        local itemPlate = item.meta and item.meta.plate
        if itemPlate then
            local cleanItemPlate = tostring(itemPlate):gsub("%s+", ""):upper()
            local cleanTargetPlate = tostring(plate):gsub("%s+", ""):upper()
            if cleanItemPlate == cleanTargetPlate then
                hasKey = true
                break
            end
        end
    end

    if hasKey then
        local lockStatus = GetVehicleDoorLockStatus(vehicle)
        local newStatus = 2
        if lockStatus == 2 then newStatus = 1 end

        SetVehicleDoorsLocked(vehicle, newStatus)
        TriggerClientEvent('vehicle_keys:client:syncLockState', -1, netId, newStatus == 2)
        TriggerClientEvent('vehicle_keys:client:playAnimation', _source)

        if newStatus == 2 then
            TriggerClientEvent('vehicle_keys:client:ShowNotify', _source, {
                icon = "fas fa-info",
                message = "Véhicule <span style='color:#e74c3c; font-weight:bold;'>verrouillé.</span>",
                duration = 3000
            })
        else
            TriggerClientEvent('vehicle_keys:client:ShowNotify', _source, {
                icon = "fas fa-info",
                message = "Véhicule <span style='color:#2ecc71; font-weight:bold;'>déverrouillé.</span>",
                duration = 3000
            })
        end
    else
        TriggerClientEvent('vehicle_keys:client:ShowNotify', _source, {
            icon = "fas fa-info",
            message = "Vous n'avez pas les clés de ce véhicule <br> <span style='color:#ff2e88; font-weight:bold;'>" .. plate .. "</span>",
            duration = 5000
        })
    end
end)

RegisterNetEvent('vehicle_keys:server:giveKey', function(plate, modelName)
    local source = source
    if source == 0 then return end
    if not plate then return end

    if type(plate) ~= 'string' then return end
    plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")
    if type(modelName) ~= 'string' then modelName = nil end

    -- Sécurité : un joueur ne reçoit une clé que pour un véhicule proche portant cette
    -- plaque ET qu'il a lui-même fait apparaître (location, etc.), sauf s'il est admin.
    if not (isAdminAllowed and isAdminAllowed(source)) then
        local ped = GetPlayerPed(source)
        if not ped or ped == 0 then return end
        local pc = GetEntityCoords(ped)
        local upper = string.upper(plate)
        local allowed = false
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - pc) <= 8.0 then
                local vPlate = string.upper((GetVehicleNumberPlateText(veh) or ''):gsub("^%s*(.-)%s*$", "%1"))
                if vPlate == upper and NetworkGetFirstEntityOwner(veh) == source then
                    allowed = true
                    break
                end
            end
        end
        if not allowed then return end
    end

    local meta = {
        plate = string.upper(plate),
        model = modelName or "Véhicule",
        description = 'Plaque: ' .. string.upper(plate)
    }

    local success, result, err = pcall(function()
        return exports.pop_inventory:GiveItem(source, VehicleKeysConfig.KeyItemName, 1, meta)
    end)
    if not success then
        print('[vehicle_keys] System error calling GiveItem:', result)
        TriggerClientEvent('vehicle_keys:client:ShowNotify', source, {
            icon = "fas fa-info",
            message = "Erreur système lors du give de la clé",
            duration = 5000
        })
        return
    end

    if result == true then
        TriggerClientEvent('vehicle_keys:client:ShowNotify', source, {
            icon = "fas fa-info",
            message = "Clé reçue pour la plaque <br> <span style='color:#2ecc71; font-weight:bold;'>" .. meta.plate .. "</span>",
            duration = 5000
        })
    else
        local reason = err or "Raison inconnue"
        TriggerClientEvent('vehicle_keys:client:ShowNotify', source, {
            icon = "fas fa-info",
            message = "Erreur lors du <span style='color:#e74c3c;'>give de la clé</span><br><span style='font-size:12px'>" .. reason .. "</span>",
            duration = 5000
        })
    end
end)
