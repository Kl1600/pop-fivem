-- Cartons et coffres : port à la main (prop + anim), déplacement au gizmo.

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

function Inv.stopCarryingBox()
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

function Inv.stopCarryingSafe()
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

-- Port du carton / coffre : chaque frame seulement pendant le port, sinon veille 500 ms.
CreateThread(function()
  while true do
    if not CarryingBox.active and not CarryingSafe.active then
      Wait(500)
    else
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
      end
    end
  end
end)

RegisterNetEvent('pop_inventory:client:equipCardboardBox', function()
  startCarryingBox()
end)

RegisterNetEvent('pop_inventory:client:unequipCardboardBox', function()
  Inv.stopCarryingBox()
end)

RegisterNetEvent('pop_inventory:client:equipSafe', function()
  startCarryingSafe()
end)

RegisterNetEvent('pop_inventory:client:unequipSafe', function()
  Inv.stopCarryingSafe()
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
  Inv.startMovingBox(entity)
end)

Inv.MovingBox = {
  active = false,
  prop = nil,
  originalCoords = nil,
  originalHeading = nil,
}

Inv.startMovingBox = function(prop)
  if Inv.MovingBox.active then
    return
  end

  if not DoesEntityExist(prop) then
    return
  end

  Inv.MovingBox.active = true
  Inv.MovingBox.prop = prop
  Inv.MovingBox.originalCoords = GetEntityCoords(prop)
  Inv.MovingBox.originalHeading = GetEntityHeading(prop)
  FreezeEntityPosition(prop, true)

  CreateThread(function()
    local model = GetEntityModel(prop)

    -- Création d'un objet fantôme pour le gizmo
    local ghost = CreateObject(model, Inv.MovingBox.originalCoords.x, Inv.MovingBox.originalCoords.y, Inv.MovingBox.originalCoords.z, false, false, false)
    SetEntityHeading(ghost, Inv.MovingBox.originalHeading)
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
        x = Inv.MovingBox.originalCoords.x,
        y = Inv.MovingBox.originalCoords.y,
        z = Inv.MovingBox.originalCoords.z
      })
    else
      -- Si annulé, s'assurer que la boîte reste à sa place d'origine
      SetEntityCoords(prop, Inv.MovingBox.originalCoords.x, Inv.MovingBox.originalCoords.y, Inv.MovingBox.originalCoords.z, false, false, false, false)
      SetEntityHeading(prop, Inv.MovingBox.originalHeading)
    end

    -- Restauration : un conteneur posé est STATIQUE -> il reste gelé et sans gravité,
    -- sinon le ped qui le touche l'éjecte (le coffre "s'envole").
    SetEntityVisible(prop, true, false)
    SetEntityCollision(prop, true, true)
    SetEntityHasGravity(prop, false)
    FreezeEntityPosition(prop, true)

    if DoesEntityExist(ghost) then DeleteEntity(ghost) end

    Inv.MovingBox.active = false
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
          Inv.startMovingBox(obj)
          return
        end
      end
    end
  end

  TriggerEvent('chat:addMessage', { args = { L('box_tag'), L('no_box_nearby') } })
end, false)
