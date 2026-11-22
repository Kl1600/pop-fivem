-- État reçu du serveur, exports client, conteneurs distants posés, marqueurs des coffres fixes.

local failedModels = {}
local lastStateSeq = 0

--[ Optimization: Non-blocking Model Loader ]--
local modelLoadRequests = {}
local function ensureModelLoaded(modelName)
  local modelHash = GetHashKey(modelName)
  if HasModelLoaded(modelHash) then return true end
  if failedModels[modelHash] then return false end

  if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
    failedModels[modelHash] = true
    return false
  end

  if not modelLoadRequests[modelHash] then
    RequestModel(modelHash)
    modelLoadRequests[modelHash] = true
  end

  -- On ne bloque PLUS avec une boucle while.
  -- On retourne false et on laisse le tick suivant retenter.
  return false
end

-- Les props des items au sol sont gérés par utility_lib (UtilityNet).
-- utility_lib crée/supprime les entités côté client via son render loop.


RegisterNetEvent('pop_inventory:client:state', function(state)
  if state and state._seq and state._seq <= lastStateSeq then
    return
  end
  if state and state._seq then
    lastStateSeq = state._seq
  end

  Inv.currentState = state

  SendNUIMessage({ action = 'state', state = state })
  -- updateDropMarkers(state and state.groundDrops) -- Removed: Handled by optimized proximity event
end)

-- Casier (Config.LockerRooms) : ce n'est pas votre casier -> le serveur demande le
-- code (pop_management). Affiché tant que la NUI inventaire est ouverte (la salle de
-- casiers y est déjà visible comme conteneur standby).
RegisterNetEvent('pop_inventory:client:requestLockerCode', function(containerId)
  SendNUIMessage({ action = 'requestLockerCode', containerId = containerId })
end)

RegisterNetEvent('pop_inventory:client:openShop', function(shopId, items)
    Inv.openUi()
    SendNUIMessage({ action = 'shop_mode', shopId = shopId, items = items })
end)

exports('getItemCount', function(itemDefId)
  if not Inv.currentState then return 0 end
  local count = 0

  -- Check equipment
  for _, item in pairs(Inv.currentState.equipment or {}) do
    if item.defId == itemDefId then
      count = count + (item.qty or 1)
    end
  end

  -- Check all containers
  for _, container in pairs(Inv.currentState.containers or {}) do
    for _, item in pairs(container.items or {}) do
      if item.defId == itemDefId then
        count = count + (item.qty or 1)
      end
    end
  end

  return count
end)

exports('GetPlayerItems', function(itemDefId)
  if not Inv.currentState then return {} end
  local results = {}

  -- Check equipment
  for _, item in pairs(Inv.currentState.equipment or {}) do
    if not itemDefId or item.defId == itemDefId then
      table.insert(results, item)
    end
  end

  -- Check all containers
  for _, container in pairs(Inv.currentState.containers or {}) do
    for _, item in pairs(container.items or {}) do
      if not itemDefId or item.defId == itemDefId then
        table.insert(results, item)
      end
    end
  end

  return results
end)

-- Définition (label + icône) d'un item à partir de son defId.
-- Renvoie nil si l'item n'existe pas (l'appelant peut alors afficher un '?').
-- 'icon' est le chemin tel que stocké (ex: 'img/wheel.webp'), relatif à html/.
exports('GetItemDef', function(defId)
  local d = Config.Items and Config.Items[defId]
  if not d then return nil end
  return { label = d.label, icon = d.icon }
end)

-- Notification simple du script (aussi déclenchée par le serveur et d'autres scripts).
RegisterNetEvent('pop_inventory:client:notify', function(message)
  Inv.Notify(message)
end)

local remoteContainerMarkers = {}

RegisterNetEvent('pop_inventory:client:updateRemoteContainers', function(containers)
  local seen = {}
  if containers and type(containers) == 'table' then
    for containerId, container in pairs(containers) do
      if container and container.coords and container.coords.x and container.coords.y and container.coords.z then
        local propModel = container.propModel or 'prop_paper_box_02'
        if not remoteContainerMarkers[containerId] or not DoesEntityExist(remoteContainerMarkers[containerId]) then
          if ensureModelLoaded(propModel) then
            local modelHash = GetHashKey(propModel)
            local entity = CreateObjectNoOffset(modelHash, container.coords.x, container.coords.y, container.coords.z, false, false, false)
            SetEntityAsMissionEntity(entity, true, true)
            -- On place l'objet au sol tant qu'il a encore ses collisions
            if container.coords.h then
              SetEntityHeading(entity, container.coords.h)
            end
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, true, true)
            SetModelAsNoLongerNeeded(modelHash)
            remoteContainerMarkers[containerId] = entity
          end
        else
          local entity = remoteContainerMarkers[containerId]
          if DoesEntityExist(entity) then
            FreezeEntityPosition(entity, false)
            SetEntityCollision(entity, true, true)
            SetEntityCoordsNoOffset(entity, container.coords.x, container.coords.y, container.coords.z, true, true, true)
            if container.coords.h then
              SetEntityHeading(entity, container.coords.h)
            else
              PlaceObjectOnGroundProperly(entity)
            end
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, true, true)
          end
        end
        seen[containerId] = true
      end
    end
  end
  for containerId in pairs(remoteContainerMarkers) do
    if not seen[containerId] then
      local entity = remoteContainerMarkers[containerId]
      if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
      end
      remoteContainerMarkers[containerId] = nil
    end
  end
end)

CreateThread(function()
  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if Config.StaticChests then
      for _, chest in ipairs(Config.StaticChests) do
        local dist = #(coords - chest.coords)
        if dist < (chest.marker and chest.marker.drawDistance or 20.0) then
          if chest.marker and chest.marker.enabled then
            sleep = 0 -- par frame uniquement si un marqueur est réellement dessiné
            local color = chest.marker.color or { r = 255, g = 255, b = 255, a = 180 }
            DrawMarker(
              chest.marker.type or 1,
              chest.coords.x, chest.coords.y, chest.coords.z - 1.0,
              0, 0, 0, 0, 0, 0,
              chest.radius or 2.0, chest.radius or 2.0, 1.0,
              color.r, color.g, color.b, color.a,
              false, true, 2, false, nil, nil, false
            )
          end
        end
      end
    end
    Wait(sleep)
  end
end)


-- Les valeurs peuvent arriver en chaînes (pop_clothes, JSON) : tout est converti
-- en nombre. Renvoie true si le composant 3 (bras) a été posé.
