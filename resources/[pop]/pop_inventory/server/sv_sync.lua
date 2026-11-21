RegisterNetEvent('pop_inventory:server:playerReady', function(coords)
  local src = source
  updatePlayerCoords(src, coords)
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end
  
  local store = loadStore(identifier)
  if not store then
    -- Erreur critique de chargement, on kick pour éviter de corrompre les données ?
    -- Ou au moins on n'active pas le store
    DropPlayer(src, "[TAB_INVENTORY] Erreur critique lors du chargement de l'inventaire. Reconnectez-vous.")
    return
  end

  Stores[identifier] = store
  sendState(src, coords)
  TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(Stores[identifier]))
end)

RegisterNetEvent('pop_inventory:server:requestState', function(coords)
  updatePlayerCoords(source, coords)
  sendState(source, coords)
end)

function syncVehicleContainerChanges(store)
  -- 1. Identify vehicle containers in player store and sync back to vehicle DB
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' and container.plate then
      local vId = 'plate:' .. container.plate
      -- Load from DB if not already loaded
      if not Stores[vId] then
        Stores[vId] = loadStore(vId)
      end
      local vStore = Stores[vId]
      
      -- Rebuild vehicle store: clean slate for this container
      vStore.containers[cId] = {
        id = cId,
        defId = 'vehicle_trunk',
        slots = container.slots,
        maxWeight = container.maxWeight,
        items = {}, 
      }
      vStore.items = {}
      
      -- Copy current items from player store into vehicle store
      for slot, itemId in pairs(container.items or {}) do
        local pItem = store.items[itemId]
        if pItem then
          -- Clone item tree for vehicle DB (recursive clean copy)
          copyItemTree(store, vStore, itemId, function(item)
            item._isTemporary = nil
            item._vehiclePlate = nil
          end)
          
          vStore.containers[cId].items[slot] = itemId
          
          -- Keep player-side item tree marked as temporary
          local function markTreeTemporary(iId)
            local item = store.items[iId]
            if item then
              item._isTemporary = true
              item._vehiclePlate = container.plate
              if item.containerId then
                local subContainer = store.containers[item.containerId]
                if subContainer then
                  for _, subItemId in pairs(subContainer.items or {}) do
                    markTreeTemporary(subItemId)
                  end
                end
              end
            end
          end
          markTreeTemporary(itemId)
        end
      end
      
      -- Save the vehicle store to DB
      saveStore(vId, vStore)
    end
  end
  
  -- 2. Clean up items that were moved OUT of vehicle container
  -- Use itemLocations to check if the item is still inside a vehicle container
  for itemId, item in pairs(store.items) do
    if item._vehiclePlate then
      local inVehicle = false
      local loc = store.itemLocations[itemId]
      if loc and loc.type == 'container' and loc.containerId then
        local current = loc.containerId
        while current do
          local parentContainer = store.containers[current]
          if parentContainer and parentContainer.defId == '__vehicle_container__' and parentContainer.plate == item._vehiclePlate then
            inVehicle = true
            break
          end
          local ownerItemId = store.containerOwners[current]
          if not ownerItemId then
            break
          end
          local ownerLoc = store.itemLocations[ownerItemId]
          if not ownerLoc or ownerLoc.type ~= 'container' then
            break
          end
          current = ownerLoc.containerId
        end
      end
      
      if not inVehicle then
        item._isTemporary = nil
        item._vehiclePlate = nil
      end
    end
  end
end

function syncRemoteStandbyChanges(store)
  local PREFIX_REMOTE = 'remote_standby_'
  local PREFIX_GROUND = 'ground_standby_'

  local inStandby = {}
  local remoteChanged = false
  local groundChanged = false

  for cId, container in pairs(store.containers) do
    if container.defId ~= '__remote_standby__' then
      -- not a standby container, skip
    elseif cId:sub(1, #PREFIX_REMOTE) == PREFIX_REMOTE then
      -- Sync back to RemoteContainers
      local remoteId = cId:sub(#PREFIX_REMOTE + 1)
      if RemoteContainers[remoteId] then
        remoteChanged = true
        RemoteContainers[remoteId].itemData = {}
        for slot, itemId in pairs(container.items or {}) do
          local item = store.items[itemId]
          if item then
            local function markTreeInStandby(iId)
              inStandby[iId] = true
              local it = store.items[iId]
              if it and it.containerId then
                local subC = store.containers[it.containerId]
                if subC then
                  for _, subItemId in pairs(subC.items or {}) do
                    markTreeInStandby(subItemId)
                  end
                end
              end
            end
            markTreeInStandby(itemId)
            -- Sérialise l'arbre complet (item + conteneur imbriqué éventuel : pot, sac…).
            RemoteContainers[remoteId].itemData[slot] = serializeItemTree(store, itemId)
          end
        end
      end
    elseif cId:sub(1, #PREFIX_GROUND) == PREFIX_GROUND then
      -- Sync back to GroundStore sub-container
      local groundContainerId = cId:sub(#PREFIX_GROUND + 1)
      local groundContainer = GroundStore.containers[groundContainerId]
      if groundContainer then
        groundChanged = true
        -- Remove old GroundStore items (arbres complets : nettoie aussi les
        -- conteneurs imbriqués orphelins issus d'une synchro précédente).
        for _, oldItemId in pairs(groundContainer.items or {}) do
          removeStoreItemTree(GroundStore, oldItemId)
        end
        -- Rebuild from current standby container
        groundContainer.items = {}
        for slot, itemId in pairs(container.items or {}) do
          local item = store.items[itemId]
          if item then
            local function markTreeInStandby(iId)
              inStandby[iId] = true
              local it = store.items[iId]
              if it and it.containerId then
                local subC = store.containers[it.containerId]
                if subC then
                  for _, subItemId in pairs(subC.items or {}) do
                    markTreeInStandby(subItemId)
                  end
                end
              end
            end
            markTreeInStandby(itemId)
            -- Reconstruit l'arbre complet (item + conteneur imbriqué) dans GroundStore.
            local node = serializeItemTree(store, itemId)
            local newId = rebuildItemTree(GroundStore, node, false)
            if newId then
              groundContainer.items[slot] = newId
              setItemLocation(GroundStore, newId, { type = 'container', containerId = groundContainerId, slot = tonumber(slot) })
            end
          end
        end
      end
    end
  end

  if remoteChanged then saveRemoteContainers() end
  if groundChanged then markGroundDirty(); saveGround() end

  -- Clear _isTemporary on items moved OUT of standby into player containers
  for itemId, item in pairs(store.items) do
    if item._isTemporary and not inStandby[itemId] then
      local loc = store.itemLocations and store.itemLocations[itemId]
      if loc and loc.type == 'container' and loc.containerId then
        local inStandbyOrVehicle = false
        local current = loc.containerId
        while current do
          local parentContainer = store.containers[current]
          if parentContainer and (
             parentContainer.defId == '__remote_standby__' or
             parentContainer.defId == '__vehicle_container__' or
             parentContainer.defId == '__remote_container__' or
             parentContainer.defId == '__static_chest__'
          ) then
            inStandbyOrVehicle = true
            break
          end
          local ownerItemId = store.containerOwners[current]
          if not ownerItemId then
            break
          end
          local ownerLoc = store.itemLocations[ownerItemId]
          if not ownerLoc or ownerLoc.type ~= 'container' then
            break
          end
          current = ownerLoc.containerId
        end
        
        if not inStandbyOrVehicle then
          item._isTemporary = nil
        end
      end
    end
  end
end

function syncStaticChestChanges(store)
  for cId, container in pairs(store.containers) do
    if container.defId == '__static_chest__' and container._staticChestId then
      local sId = 'static_' .. container._staticChestId
      if not Stores[sId] then
        Stores[sId] = loadStore(sId)
      end
      local sStore = Stores[sId]
      local sContainer = sStore.containers[cId]
      if sContainer then
        sContainer.items = {}
        sStore.items = {}
        for slot, itemId in pairs(container.items or {}) do
          local pItem = store.items[itemId]
          if pItem then
            copyItemTree(store, sStore, itemId, function(item)
              item._isTemporary = nil
              item._staticChestId = nil
            end)
            sContainer.items[slot] = itemId
            
            -- Keep player-side items in the tree marked as temporary
            local function markTreeTemporary(iId)
              local item = store.items[iId]
              if item then
                item._isTemporary = true
                item._staticChestId = container._staticChestId
                if item.containerId then
                  local subContainer = store.containers[item.containerId]
                  if subContainer then
                    for _, subItemId in pairs(subContainer.items or {}) do
                      markTreeTemporary(subItemId)
                    end
                  end
                end
              end
            end
            markTreeTemporary(itemId)
          end
        end
        sStore._dirty = true
        saveStore(sId, sStore)
      end
    end
  end

  -- Re-check/Cleanup items moved OUT of static chests
  for itemId, item in pairs(store.items) do
    if item._staticChestId then
      local inStatic = false
      local loc = store.itemLocations[itemId]
      if loc and loc.type == 'container' and loc.containerId then
        local current = loc.containerId
        while current do
          local container = store.containers[current]
          if container and container.defId == '__static_chest__' and container._staticChestId == item._staticChestId then
            inStatic = true
            break
          end
          local ownerItemId = store.containerOwners[current]
          if not ownerItemId then
            break
          end
          local ownerLoc = store.itemLocations[ownerItemId]
          if not ownerLoc or ownerLoc.type ~= 'container' then
            break
          end
          current = ownerLoc.containerId
        end
      end
      
      if not inStatic then
        item._isTemporary = nil
        item._staticChestId = nil
      end
    end
  end
end

