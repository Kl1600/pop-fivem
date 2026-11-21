local CarryingBox = {
  active = false,
  prop = nil,
  animDict = 'anim@heists@box_carry@',
  animName = 'idle',
}

local CarryingSafe = {
  active = false,
  prop = nil,
  animDict = 'anim@heists@box_carry@',
  animName = 'idle',
}

local function loadAnimDict(dict)
  if not HasAnimDictLoaded(dict) then
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 2000 do
      Wait(10)
      timeout = timeout + 10
    end
  end
  return HasAnimDictLoaded(dict)
end

local function isCarryingBriefcase()
  return GetResourceState('pop_inventory') == 'started' and exports.pop_inventory:IsHoldingItem('briefcase')
end

local function startCarryingBox()
  if CarryingBox.active then
    return
  end

  local ped = PlayerPedId()
  
  if not loadAnimDict(CarryingBox.animDict) then
    return
  end

  local propHash = GetHashKey('prop_cs_cardbox_01')
  RequestModel(propHash)
  local timeout = 0
  while not HasModelLoaded(propHash) and timeout < 2000 do
    Wait(10)
    timeout = timeout + 10
  end

  if not HasModelLoaded(propHash) then
    return
  end

  local coords = GetEntityCoords(ped)
  CarryingBox.prop = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, false)
  SetModelAsNoLongerNeeded(propHash)

  AttachEntityToEntity(
    CarryingBox.prop,
    ped,
    GetPedBoneIndex(ped, 28422),
    0.0, -0.1, -0.05,
    0.0, 0.0, 0.0,
    true, true, false, true, 1, true
  )

  TaskPlayAnim(ped, CarryingBox.animDict, CarryingBox.animName, 8.0, -8.0, -1, 49, 0, false, false, false)

  CarryingBox.active = true
end

local function stopCarryingBox()
  if not CarryingBox.active then
    -- Failsafe: même si CarryingBox.active est false, on nettoie d'éventuels props restants
    local ped = PlayerPedId()
    local propHash = GetHashKey('prop_cs_cardbox_01')
    local objects = GetGamePool('CObject')
    for _, obj in ipairs(objects) do
      if GetEntityModel(obj) == propHash and IsEntityAttachedToEntity(obj, ped) then
        DeleteEntity(obj)
      end
    end
    return
  end

  local ped = PlayerPedId()
  ClearPedTasks(ped)

  if DoesEntityExist(CarryingBox.prop) then
    DetachEntity(CarryingBox.prop, true, false)
    SetEntityAsMissionEntity(CarryingBox.prop, true, true)
    DeleteEntity(CarryingBox.prop)
  end

  -- Nettoyage supplémentaire par modèle au cas où
  local propHash = GetHashKey('prop_cs_cardbox_01')
  local objects = GetGamePool('CObject')
  for _, obj in ipairs(objects) do
    if GetEntityModel(obj) == propHash and IsEntityAttachedToEntity(obj, ped) then
      DeleteEntity(obj)
    end
  end

  CarryingBox.active = false
  CarryingBox.itemId = nil
  CarryingBox.prop = nil
end

local function startCarryingSafe()
  if CarryingSafe.active then
    return
  end

  local ped = PlayerPedId()
  
  if not loadAnimDict(CarryingSafe.animDict) then
    return
  end

  local propHash = GetHashKey('prop_ld_int_safe_01')
  RequestModel(propHash)
  local timeout = 0
  while not HasModelLoaded(propHash) and timeout < 2000 do
    Wait(10)
    timeout = timeout + 10
  end

  if not HasModelLoaded(propHash) then
    return
  end

  local coords = GetEntityCoords(ped)
  CarryingSafe.prop = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, false)
  SetModelAsNoLongerNeeded(propHash)

  -- Using the same attachment offset as cardboard box for the safe
  AttachEntityToEntity(
    CarryingSafe.prop,
    ped,
    GetPedBoneIndex(ped, 28422),
    0.0, -0.1, -0.05,
    0.0, 0.0, 0.0,
    true, true, false, true, 1, true
  )

  TaskPlayAnim(ped, CarryingSafe.animDict, CarryingSafe.animName, 8.0, -8.0, -1, 49, 0, false, false, false)

  CarryingSafe.active = true
end

local function stopCarryingSafe()
  if not CarryingSafe.active then
    -- Failsafe
    local ped = PlayerPedId()
    local propHash = GetHashKey('prop_ld_int_safe_01')
    local objects = GetGamePool('CObject')
    for _, obj in ipairs(objects) do
      if GetEntityModel(obj) == propHash and IsEntityAttachedToEntity(obj, ped) then
        DeleteEntity(obj)
      end
    end
    return
  end

  local ped = PlayerPedId()
  ClearPedTasks(ped)

  if DoesEntityExist(CarryingSafe.prop) then
    DetachEntity(CarryingSafe.prop, true, false)
    SetEntityAsMissionEntity(CarryingSafe.prop, true, true)
    DeleteEntity(CarryingSafe.prop)
  end

  -- Nettoyage supplémentaire
  local propHash = GetHashKey('prop_ld_int_safe_01')
  local objects = GetGamePool('CObject')
  for _, obj in ipairs(objects) do
    if GetEntityModel(obj) == propHash and IsEntityAttachedToEntity(obj, ped) then
      DeleteEntity(obj)
    end
  end

  CarryingSafe.active = false
  CarryingSafe.itemId = nil
  CarryingSafe.prop = nil
end

CreateThread(function()
  while true do
    Wait(0)
    
    if CarryingBox.active then
      local ped = PlayerPedId()
      if IsPedInAnyVehicle(ped, true) then
        if DoesEntityExist(CarryingBox.prop) then
          DeleteEntity(CarryingBox.prop)
          CarryingBox.prop = nil
        end
        if IsEntityPlayingAnim(ped, CarryingBox.animDict, CarryingBox.animName, 3) then
          ClearPedTasks(ped)
        end
        Wait(200)
      else
        if not DoesEntityExist(CarryingBox.prop) then
          local propHash = GetHashKey('prop_cs_cardbox_01')
          RequestModel(propHash)
          local timeout = 0
          while not HasModelLoaded(propHash) and timeout < 2000 do
            Wait(10)
            timeout = timeout + 10
          end
          if HasModelLoaded(propHash) then
            local coords = GetEntityCoords(ped)
            CarryingBox.prop = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, false)
            AttachEntityToEntity(
              CarryingBox.prop,
              ped,
              GetPedBoneIndex(ped, 28422),
              0.0, -0.1, -0.05,
              0.0, 0.0, 0.0,
              true, true, false, true, 1, true
            )
            SetModelAsNoLongerNeeded(propHash)
          end
        end

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 44, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 263, true)

        if not IsEntityPlayingAnim(ped, CarryingBox.animDict, CarryingBox.animName, 3) then
          TaskPlayAnim(ped, CarryingBox.animDict, CarryingBox.animName, 8.0, -8.0, -1, 49, 0, false, false, false)
        end
      end
    elseif CarryingSafe.active then
      local ped = PlayerPedId()
      if IsPedInAnyVehicle(ped, true) then
        if DoesEntityExist(CarryingSafe.prop) then
          DeleteEntity(CarryingSafe.prop)
          CarryingSafe.prop = nil
        end
        if IsEntityPlayingAnim(ped, CarryingSafe.animDict, CarryingSafe.animName, 3) then
          ClearPedTasks(ped)
        end
        Wait(200)
      else
        if not DoesEntityExist(CarryingSafe.prop) then
          local propHash = GetHashKey('prop_ld_int_safe_01')
          RequestModel(propHash)
          local timeout = 0
          while not HasModelLoaded(propHash) and timeout < 2000 do
            Wait(10)
            timeout = timeout + 10
          end
          if HasModelLoaded(propHash) then
            local coords = GetEntityCoords(ped)
            CarryingSafe.prop = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, false)
            AttachEntityToEntity(
              CarryingSafe.prop,
              ped,
              GetPedBoneIndex(ped, 28422),
              0.0, -0.1, -0.05,
              0.0, 0.0, 0.0,
              true, true, false, true, 1, true
            )
            SetModelAsNoLongerNeeded(propHash)
          end
        end

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 44, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 263, true)

        if not IsEntityPlayingAnim(ped, CarryingSafe.animDict, CarryingSafe.animName, 3) then
          TaskPlayAnim(ped, CarryingSafe.animDict, CarryingSafe.animName, 8.0, -8.0, -1, 49, 0, false, false, false)
        end
      end
    else
      Wait(500)
    end
  end
end)

RegisterNetEvent('pop_inventory:client:equipCardboardBox', function()
  startCarryingBox()
end)

RegisterNetEvent('pop_inventory:client:unequipCardboardBox', function()
  stopCarryingBox()
end)

RegisterNetEvent('pop_inventory:client:equipSafe', function()
  startCarryingSafe()
end)

RegisterNetEvent('pop_inventory:client:unequipSafe', function()
  stopCarryingSafe()
end)

RegisterNetEvent('pop_inventory:client:openRemoteContainer', function(prop)
  if not DoesEntityExist(prop) then
    return
  end
  
  local coords = GetEntityCoords(prop)
  TriggerServerEvent('pop_inventory:server:openRemoteContainerFromProp', coords)
end)

RegisterNetEvent('pop_inventory:client:moveCardboardBox', function(entity)
  if not DoesEntityExist(entity) then
    return
  end
  startMovingBox(entity)
end)

local MovingBox = {
  active = false,
  prop = nil,
  originalCoords = nil,
  originalHeading = nil,
}

local function showHelpNotification(text)
  BeginTextCommandDisplayHelp("STRING")
  AddTextComponentString(text)
  EndTextCommandDisplayHelp(0, false, true, -1)
end

local function DrawHackControls()
    if not buttonsScaleform then
        buttonsScaleform = RequestScaleformMovie("instructional_buttons")
        while not HasScaleformMovieLoaded(buttonsScaleform) do Wait(0) end

        PushScaleformMovieFunction(buttonsScaleform, "CLEAR_ALL")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(0)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 215, true))
        PushScaleformMovieMethodParameterString("Entrer")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(1)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 21, true))
        PushScaleformMovieMethodParameterString("Shift")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(2)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 22, true))
        PushScaleformMovieMethodParameterString("Monter")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(3)

        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 175, true))
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 174, true))
                PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 173, true))
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 172, true))


        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(4)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 46, true))
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 44, true))
        PushScaleformMovieMethodParameterString("Rotation")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieMethodParameterString("Déplacement")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
        PopScaleformMovieFunctionVoid()
    end
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
end


local function startMovingBox(prop)
  if MovingBox.active then
    return
  end
  
  if not DoesEntityExist(prop) then
    return
  end
  
  MovingBox.active = true
  MovingBox.prop = prop
  MovingBox.originalCoords = GetEntityCoords(prop)
  MovingBox.originalHeading = GetEntityHeading(prop)
  FreezeEntityPosition(prop, true)
  
  CreateThread(function()
    local model = GetEntityModel(prop)
    
    -- Création d'un objet fantôme pour le gizmo
    local ghost = CreateObject(model, MovingBox.originalCoords.x, MovingBox.originalCoords.y, MovingBox.originalCoords.z, false, false, false)
    SetEntityHeading(ghost, MovingBox.originalHeading)
    SetEntityAlpha(ghost, 200, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    
    -- Masquer la vraie boîte
    SetEntityVisible(prop, false, false)
    SetEntityCollision(prop, false, false)
    
    -- Appel bloquant du Gizmo
    local result = exports.object_gizmo:useGizmo(ghost)
    
    if result then
      local finalCoords = result.position or GetEntityCoords(ghost)
      local finalRot = result.rotation or GetEntityRotation(ghost)
      local finalHeading = finalRot.z
      
      -- Mise à jour locale (visuelle immédiate)
      SetEntityCoords(prop, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false, false)
      SetEntityHeading(prop, finalHeading)
      
      -- Sauvegarde serveur
      TriggerServerEvent('pop_inventory:server:updateRemoteContainerPos', nil, {
        x = finalCoords.x,
        y = finalCoords.y,
        z = finalCoords.z,
        h = finalHeading
      }, {
        x = MovingBox.originalCoords.x,
        y = MovingBox.originalCoords.y,
        z = MovingBox.originalCoords.z
      })
    else
      -- Si annulé, s'assurer que la boîte reste à sa place d'origine
      SetEntityCoords(prop, MovingBox.originalCoords.x, MovingBox.originalCoords.y, MovingBox.originalCoords.z, false, false, false, false)
      SetEntityHeading(prop, MovingBox.originalHeading)
    end
    
    -- Restauration : un conteneur posé est STATIQUE -> il reste gelé et sans gravité,
    -- sinon le ped qui le touche l'éjecte (le coffre "s'envole").
    SetEntityVisible(prop, true, false)
    SetEntityCollision(prop, true, true)
    SetEntityHasGravity(prop, false)
    FreezeEntityPosition(prop, true)

    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    
    MovingBox.active = false
  end)
end

RegisterCommand('carton_deplacer_mode', function()
  -- Chercher un carton à proximité
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local nearbyObjects = GetGamePool('CObject')
  
  for _, obj in ipairs(nearbyObjects) do
    if DoesEntityExist(obj) then
      local objModel = GetEntityModel(obj)
      local targetModel = GetHashKey('prop_cs_cardbox_01')
      if objModel == targetModel then
        local objCoords = GetEntityCoords(obj)
        local dist = #(coords - objCoords)
        if dist < 5.0 then
          startMovingBox(obj)
          return
        end
      end
    end
  end
  
  TriggerEvent('chat:addMessage', { args = { '[Carton]', 'Aucun carton a proximite' } })
end, false)

-- Gestion des targets ox_target pour les cartons et coffres
local CARDBOARD_BOX_MODEL = 'prop_cs_cardbox_01'
local SAFE_BOX_MODEL = 'prop_ld_int_safe_01'

local function setupCardboardBoxTargets()
  if GetResourceState('ox_target') ~= 'started' then
    return
  end
  
  -- Les colis YouTool (pop_management) utilisent le même modèle de carton mais
  -- ne sont PAS des conteneurs pop_inventory : on masque ces options dessus
  -- (flag d'état local 'ytColis' posé par pop_management).
  local function isNotYtColis(entity)
    return not (entity and DoesEntityExist(entity) and Entity(entity).state and Entity(entity).state.ytColis)
  end

  pcall(function()
    exports.ox_target:addModel(CARDBOARD_BOX_MODEL, {
      {
        label = 'Déplacer le carton',
        icon = 'fas fa-arrows-alt',
        distance = 5.5,
        canInteract = isNotYtColis,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            startMovingBox(data.entity)
          end
        end,
      },
      {
        label = 'Ouvrir',
        icon = 'fas fa-box-open',
        distance = 5.5,
        canInteract = isNotYtColis,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerEvent('standby_ui:client:openBox', { x = coords.x, y = coords.y, z = coords.z })
          end
        end,
      },
      {
        label = 'Prendre',
        icon = 'fas fa-hand',
        distance = 5.5,
        onSelect = function(data)
          if not (data and data.entity and DoesEntityExist(data.entity)) then return end
          -- Colis YouTool : route vers la prise de commande (pop_management).
          local st = Entity(data.entity).state
          if st and st.ytColis then
            TriggerServerEvent('pop_management:validateYouToolOrder', 'package', st.ytColis)
            return
          end
          -- Conteneur pop_inventory classique
          local coords = GetEntityCoords(data.entity)
          TriggerServerEvent('pop_inventory:server:takeRemoteContainer', coords)
        end,
      }
    })

    exports.ox_target:addModel(SAFE_BOX_MODEL, {
      {
        label = 'Déplacer le coffre-fort',
        icon = 'fas fa-arrows-alt',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            startMovingBox(data.entity)
          end
        end,
      },
      {
        label = 'Ouvrir',
        icon = 'fas fa-door-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerEvent('standby_ui:client:openBox', { x = coords.x, y = coords.y, z = coords.z })
          end
        end,
      },
      {
        label = 'Prendre',
        icon = 'fas fa-hand',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerServerEvent('pop_inventory:server:takeRemoteContainer', coords)
          end
        end,
      }
    })

    -- Capot moteur : option sur le capot de tous les véhicules -> conteneur distant
    -- (moteur 3x3 + batterie), géré par standby_client.lua / engine_server.lua.
    -- Certains véhicules ont le moteur à l'ARRIÈRE (sportives, etc.) : le capot/coffre
    -- moteur correspond alors à la porte 5 et se trouve à l'arrière (au sens d'ox_target),
    -- pas à l'avant. On détecte le côté du moteur via la position du bone 'engine'.
    local function isRearEngine(vehicle)
        local bone = GetEntityBoneIndexByName(vehicle, 'engine')
        if bone == -1 then return false end
        local world = GetWorldPositionOfEntityBone(vehicle, bone)
        local off = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
        return off.y < 0.0 -- bone moteur derrière le centre = moteur arrière
    end

    -- Porte du capot moteur (4 = capot avant, 5 = capot arrière).
    local function getEngineDoor(vehicle)
        return isRearEngine(vehicle) and 5 or 4
    end

    -- Vrai si le point visé par ox_target est bien du côté du moteur (et pas à l'autre bout).
    local function isHitOnEngineSide(vehicle, coords)
        if not coords then return true end
        local off = GetOffsetFromEntityGivenWorldCoords(vehicle, coords.x, coords.y, coords.z)
        if isRearEngine(vehicle) then
            return off.y < 0.0
        end
        return off.y > 0.0
    end

    -- Liste statique des modèles dont le capot ne s'ouvre JAMAIS (porte non animée
    -- en jeu, peu importe les bones présentes). À compléter au cas par cas quand un
    -- véhicule concerné est identifié. Aucune détection au runtime : fiable à 100%
    -- et zéro impact sur les véhicules classiques (comportement inchangé).
    local NoHoodModels = {
        [GetHashKey('adder')] = true,
    }

    local function hoodIsBroken(vehicle)
        return NoHoodModels[GetEntityModel(vehicle)] == true
    end

    exports.ox_target:addGlobalVehicle({
      {
        name = 'pop_inventory:open_hood_phys',
        label = 'Ouvrir le capot',
        icon = 'fas fa-arrow-up',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) <= 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
            SetVehicleDoorOpen(data.entity, getEngineDoor(data.entity), false, false)
        end
      },
      {
        name = 'pop_inventory:close_hood_phys',
        label = 'Fermer le capot',
        icon = 'fas fa-arrow-down',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) > 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
            SetVehicleDoorShut(data.entity, getEngineDoor(data.entity), false)
        end
      },
      {
        name = 'pop_inventory:capot',
        label = 'Inspecter le moteur',
        icon = 'fas fa-car-battery',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) > 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
          local veh = data and data.entity
          if not veh or not DoesEntityExist(veh) then return end
          local plate = GetVehicleNumberPlateText(veh)
          if not plate then return end
          TriggerEvent('pop_inventory:client:openHood', veh, plate, getEngineDoor(veh))
        end,
      }
    })

    -- Véhicules listés dans NoHoodModels : accès direct au moteur sans restriction
    -- de bone, visible UNIQUEMENT sur ceux-ci (les 3 options ci-dessus sont masquées).
    exports.ox_target:addGlobalVehicle({
      {
        name = 'pop_inventory:repair_engine_no_hood',
        label = 'Inspecter le moteur',
        icon = 'fas fa-car-battery',
        distance = 2.5,
        canInteract = function(entity)
            return hoodIsBroken(entity)
        end,
        onSelect = function(data)
          local veh = data and data.entity
          if not veh or not DoesEntityExist(veh) then return end
          local plate = GetVehicleNumberPlateText(veh)
          if not plate then return end
          TriggerEvent('pop_inventory:client:openHood', veh, plate, getEngineDoor(veh))
        end,
      }
    })

    -- Portes latérales : toggle ouvrir/fermer via la bone ciblée
    local doorBones = {
        { bone = 'door_dside_f', index = 0 },
        { bone = 'door_pside_f', index = 1 },
        { bone = 'door_dside_r', index = 2 },
        { bone = 'door_pside_r', index = 3 },
    }
    local doorOptions = {}
    for _, d in ipairs(doorBones) do
        local idx = d.index
        table.insert(doorOptions, {
            name = 'pop_inventory:door_toggle_' .. idx,
            label = 'Porte',
            icon = 'fas fa-car-side',
            bones = { d.bone },
            distance = 3.0,
            onSelect = function(data)
                if GetVehicleDoorAngleRatio(data.entity, idx) <= 0.0 then
                    SetVehicleDoorOpen(data.entity, idx, false, false)
                else
                    SetVehicleDoorShut(data.entity, idx, false)
                end
            end,
        })
    end
    exports.ox_target:addGlobalVehicle(doorOptions)

    -- ADMIN : suppression d'un véhicule de la carte (persistant ou non)
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pop_inventory:admin_delete_vehicle',
            label = 'Supprimer le véhicule',
            icon = 'fas fa-trash',
            distance = 5.0,
            canInteract = function(entity)
                return adminAllowed == true
            end,
            onSelect = function(data)
                local veh = data and data.entity
                if not veh or not DoesEntityExist(veh) then return end
                local netId = NetworkGetNetworkIdFromEntity(veh)
                TriggerServerEvent('pop_inventory:server:adminDeleteVehicle', netId)
            end,
        }
    })

    -- Gestion des targets ox_target pour l'armytanker
    exports.ox_target:addModel('armytanker', {
      {
        label = 'Ouvrir',
        icon = 'fas fa-box-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local entity = data.entity
            local uniqueId = 'tank_unknown'
            
            if IsEntityAVehicle(entity) then
               local plate = GetVehicleNumberPlateText(entity)
               if plate then
                   plate = string.gsub(plate, "%s+", "")
                   uniqueId = 'tank_' .. plate
               end
            else
               local coords = GetEntityCoords(entity)
               uniqueId = string.format("tank_%d_%d", math.floor(coords.x), math.floor(coords.y))
            end

            local chestData = {
                id = uniqueId,
                label = 'Army Tanker',
                slots = 40,
                maxWeight = 500.0,
            }
            TriggerEvent('standby_ui:client:openArmyTanker', chestData)
          end
        end,
      }
    })

    -- Gestion des targets ox_target pour le brickadeta
    exports.ox_target:addModel('brickadeta', {
      {
        label = 'Ouvrir',
        icon = 'fas fa-box-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local entity = data.entity
            local uniqueId = 'brickadeta_unknown'
            
            if IsEntityAVehicle(entity) then
               local plate = GetVehicleNumberPlateText(entity)
               if plate then
                   plate = string.gsub(plate, "%s+", "")
                   uniqueId = 'brickadeta_' .. plate
               end
            else
               local coords = GetEntityCoords(entity)
               uniqueId = string.format("brickadeta_%d_%d", math.floor(coords.x), math.floor(coords.y))
            end

            local chestData = {
                id = uniqueId,
                label = 'Brickadeta',
                slots = 2,
                maxWeight = 500.0,
            }
            TriggerEvent('standby_ui:client:openArmyTanker', chestData)
          end
        end,
      }
    })
    -- Coffre arrière de l'ambulance
    exports.ox_target:addModel('ambulance', {
      {
        name = 'ambulance_trunk_open',
        label = 'Ouvrir le coffre',
        icon = 'fas fa-truck-medical',
        bones = { 'boot', 'bodywork_rear_extras', 'bumper_r' },
        distance = 2.5,
        canInteract = function(entity)
            return GetVehicleDoorAngleRatio(entity, 5) <= 0.0
        end,
        onSelect = function(data)
            local veh = data and data.entity
            if not veh or not DoesEntityExist(veh) then return end
            local plate = GetVehicleNumberPlateText(veh)
            if not plate then return end
            plate = plate:gsub("^%s*(.-)%s*$", "%1")
            SetVehicleDoorOpen(veh, 5, false, false)
            TriggerEvent('pop_inventory:client:openAmbulanceTrunk', veh, plate)
        end,
      },
      {
        name = 'ambulance_trunk_close',
        label = 'Fermer le coffre',
        icon = 'fas fa-truck-medical',
        bones = { 'boot', 'bodywork_rear_extras', 'bumper_r' },
        distance = 2.5,
        canInteract = function(entity)
            return GetVehicleDoorAngleRatio(entity, 5) > 0.0
        end,
        onSelect = function(data)
            local veh = data and data.entity
            if not veh or not DoesEntityExist(veh) then return end
            SetVehicleDoorShut(veh, 5, false)
        end,
      },
    })

    -- Gestion des targets ox_target pour les Static Chests (Config.StaticChests)
    if Config.StaticChests then
      for _, chest in ipairs(Config.StaticChests) do
        local option = {
            label = chest.label or 'Ouvrir',
            icon = 'fas fa-box-open',
            onSelect = function()
                TriggerServerEvent('pop_inventory:server:openStaticChest', chest.id, chest.label, chest.slots, chest.maxWeight)
            end
        }
        if chest.jobs or chest.job then
            option.groups = chest.jobs or chest.job
        end
        exports.ox_target:addPoint({
            coords = chest.coords,
            radius = chest.radius or 2.0,
            debug = false,
            options = { option }
        })
      end
    end

    -- Les salles de casiers (Config.LockerRooms) ne passent PAS par ox_target :
    -- ce sont des points fixes, gérés par un prompt v3DUI + touche (E/G) dans
    -- standby_client.lua (même mécanique que Config.StaticChests).
  end)
end

-- Configurer les targets au démarrage
local function setupPlayerTargets()
  if GetResourceState('ox_target') ~= 'started' then
    return
  end

  exports.ox_target:addGlobalPlayer({
    {
      name = 'pop_inventory:fouiller',
      label = 'Fouiller',
      icon = 'fas fa-search',
      distance = 2.0,
      canInteract = function(entity)
        if IsEntityDead(entity) then return true end
        -- Mains levées (X) via statebag réseau : fouille de n'importe quel joueur.
        if IsPedAPlayer(entity) then
          local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
          if sid > 0 and Player(sid).state.handsup == true then return true end
        end
        -- Fallback animations.
        if IsEntityPlayingAnim(entity, "missminuteman_1ig_2", "handsup_enter", 3) then return true end
        if IsEntityPlayingAnim(entity, "missminuteman_1ig_2", "handsup_base", 3) then return true end
        if IsEntityPlayingAnim(entity, "random@mugging3", "handsup_standing_base", 3) then return true end
        return false
      end,
      onSelect = function(data)
        local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
        TriggerServerEvent('pop_inventory:server:startSearchingPlayer', targetId)
      end,
    },
    {
      name = 'pop_inventory:menotter',
      label = 'Menotter / Démenotter',
      icon = 'fas fa-handcuffs',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local count = exports.pop_inventory:getItemCount('menottes')
        return count and count > 0
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        local alreadyCuffed = Player(targetServerId).state.handcuffed == true
        TriggerServerEvent('pop_inventory:server:menottesPlayer', targetServerId, not alreadyCuffed)
      end,
    },
    {
      name = 'pop_inventory:escorter',
      label = 'Escorter',
      icon = 'fas fa-people-arrows',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local plyId = NetworkGetPlayerIndexFromPed(entity)
        if plyId == -1 then return false end
        local serverId = GetPlayerServerId(plyId)
        -- Menotté ET pas déjà escorté par quelqu'un.
        return Player(serverId).state.handcuffed == true
           and not Player(serverId).state.escortedBy
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        TriggerServerEvent('pop_inventory:server:toggleEscort', targetServerId)
      end,
    },
    {
      name = 'pop_inventory:lacher',
      label = 'Lâcher',
      icon = 'fas fa-hand-peace',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local plyId = NetworkGetPlayerIndexFromPed(entity)
        if plyId == -1 then return false end
        local serverId = GetPlayerServerId(plyId)
        -- Visible seulement si CE joueur est escorté par MOI.
        return Player(serverId).state.escortedBy == GetPlayerServerId(PlayerId())
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        TriggerServerEvent('pop_inventory:server:toggleEscort', targetServerId)
      end,
    }
  })
end

CreateThread(function()
  Wait(1000) -- Attendre que ox_target soit disponible
  setupCardboardBoxTargets()
  setupPlayerTargets()
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  stopCarryingBox()
  stopCarryingSafe()
  MovingBox.active = false
end)

