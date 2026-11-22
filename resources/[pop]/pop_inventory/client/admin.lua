-- Menu admin de l'inventaire (objets, jobs, météo, véhicules) et actions NUI.

-- =============================================
--  ADMIN : Sélecteur d'items
-- =============================================
RegisterNUICallback('adminRequestItems', function(_, cb)
  TriggerServerEvent('pop_inventory:server:adminRequestItems')
  cb('ok')
end)

RegisterNUICallback('adminGiveItem', function(data, cb)
  if type(data) == 'table' and data.id then
    local qty = tonumber(data.qty) or 1
    if qty < 1 then qty = 1 end
    local meta = nil

    -- Cas spécial : carkeys -> remplir auto plate + model du véhicule actuel (sinon le plus proche)
    if data.id == 'carkeys' then
      local ped = PlayerPedId()
      local vehicle = GetVehiclePedIsIn(ped, false)

      if vehicle == 0 then
        local pedCoords = GetEntityCoords(ped)
        local closestVehicle, closestDistance = 0, 5.0
        local pool = GetGamePool('CVehicle')
        for i = 1, #pool do
          local v = pool[i]
          local dist = #(pedCoords - GetEntityCoords(v))
          if dist < closestDistance then
            closestDistance = dist
            closestVehicle = v
          end
        end
        vehicle = closestVehicle
      end

      if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then plate = plate:gsub('^%s*(.-)%s*$', '%1') end
        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local labelText = GetLabelText(displayName)
        local modelName
        if labelText == 'NULL' then
          modelName = displayName:sub(1, 1):upper() .. displayName:sub(2):lower()
        else
          modelName = labelText
        end
        meta = { plate = plate, model = modelName }
      end
    end

    TriggerServerEvent('pop_inventory:server:adminGiveItem', data.id, qty, meta)
  end
  cb('ok')
end)

RegisterNetEvent('pop_inventory:client:setAdminItems', function(items)
  SendNUIMessage({ action = 'setAdminItems', items = items or {} })
end)

adminAllowed = false  -- global : accessible depuis remote_container.lua (canInteract ox_target)

RegisterNetEvent('pop_inventory:client:setAdminAllowed', function(allowed)
  adminAllowed = allowed == true
  SendNUIMessage({ action = 'setAdminAllowed', allowed = allowed == true })
end)

-- Vérifie le statut admin au démarrage pour que le target ox_target fonctionne
-- même si le joueur n'a pas encore ouvert son inventaire.
CreateThread(function()
  Wait(3000)
  TriggerServerEvent('pop_inventory:server:adminCheck')
end)

RegisterNetEvent('pop_inventory:client:adminDeleteVehicleResult', function(success)
  if success then
    Bridge.Notify({ message = L('vehicle_deleted'), type = 'success' })
  else
    Bridge.Notify({ message = L('vehicle_not_found'), type = 'error' })
  end
end)

RegisterNUICallback('adminOpenClotheShop', function(_, cb)
    TriggerEvent('pop_inventory:client:openClotheShop')
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:openClotheShop', function()
    Inv.closeUi()

    -- pop_clothes n'a pas (encore) de menu admin : appel protégé, sinon message.
    if GetResourceState('pop_clothes') == 'started' then
        local ok = pcall(function() exports['pop_clothes']:openAdmin() end)
        if not ok then
            Inv.Notify(L('no_clothing_system'))
        end
    elseif GetResourceState('fivem-appearance') == 'started' then
        TriggerEvent('fivem-appearance:client:openAppearanceMenu')
    elseif GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openAppearanceMenu')
    else
        Inv.Notify(L('no_clothing_system'))
    end
end)

RegisterNUICallback('adminRequestJobs', function(_, cb)
    TriggerServerEvent('pop_inventory:server:adminRequestJobs')
    cb('ok')
end)

RegisterNUICallback('adminSetJob', function(data, cb)
    if data and data.job then
        TriggerServerEvent('pop_inventory:server:adminSetJob', data.job, data.grade)
    end
    cb('ok')
end)

RegisterNUICallback('adminCreateJob', function(data, cb)
    if data and data.name and data.label then
        TriggerServerEvent('pop_inventory:server:adminCreateJob', data.name, data.label)
    end
    cb('ok')
end)

RegisterNUICallback('adminAddGrade', function(data, cb)
    if data and data.job and data.name and data.label then
        TriggerServerEvent('pop_inventory:server:adminAddGrade', data.job, data.level, data.name, data.label, data.salary)
    end
    cb('ok')
end)

RegisterNUICallback('adminAddSocietyMoney', function(data, cb)
    if data and data.job and data.amount then
        TriggerServerEvent('pop_inventory:server:adminAddSocietyMoney', data.job, data.amount)
    end
    cb('ok')
end)

RegisterNUICallback('adminDeleteJob', function(data, cb)
    if data and data.job then
        TriggerServerEvent('pop_inventory:server:adminDeleteJob', data.job)
    end
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:debugPrint', function(msg)
    -- Réponse du serveur aux commandes admin (popjobschema, erreurs de création de job) : toujours affichée.
    print('[POP_INVENTORY][SRV→CLI] ' .. tostring(msg))
end)

-- Commande F8 pour dump le schema MySQL et identifier les colonnes NOT NULL
-- qui font potentiellement planter l'INSERT.
RegisterCommand('popjobschema', function()
    TriggerServerEvent('pop_inventory:server:adminDumpSchema')
end, false)

RegisterNetEvent('pop_inventory:client:setAdminJobs', function(jobs)
  SendNUIMessage({ action = 'setAdminJobs', jobs = jobs or {} })
end)

RegisterNUICallback('adminSetWeather', function(data, cb)
    if data and data.weather then
        TriggerServerEvent('pop_inventory:server:adminSetWeather', data.weather)
    end
    cb('ok')
end)

-- Admin Vehicles logic
RegisterNUICallback('adminGiveVehicleKeys', function(_, cb)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then plate = plate:gsub('^%s*(.-)%s*$', '%1') end

        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local labelText = GetLabelText(displayName)
        local modelName = (labelText == 'NULL') and displayName or labelText

        local meta = { plate = plate, model = modelName }
        TriggerServerEvent('pop_inventory:server:adminGiveItem', 'carkeys', 1, meta)
        Inv.Notify(L('vehicle_keys_received', plate))
    else
        Inv.Notify(L('no_vehicle_detected'))
    end
    cb('ok')
end)

RegisterNUICallback('adminToggleShowVehicles', function(_, cb)
    ExecuteCommand('showvehicles')
    cb('ok')
end)

RegisterNUICallback('adminToggleShowCasings', function(_, cb)
    ExecuteCommand('showcasings')
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:syncWeather', function(weather)
    SetWeatherTypeOverTime(weather, 15.0)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNUICallback('action', function(data, cb)
  local coords = GetEntityCoords(PlayerPedId())
  data.coords = { x = coords.x, y = coords.y, z = coords.z }
  TriggerServerEvent('pop_inventory:server:action', data)
  cb('ok')
end)
