exports('GetPlayerItems', function(source, itemDefId)
  local identifier = getIdentifier(source)
  if not identifier then return {} end

  local store = ensureStore(identifier)
  if not store or not store.items then return {} end

  local function isOwnedByPlayer(itemId)
    local item = store.items[itemId]
    if not item or item._isTemporary then return false end
    local currentId = itemId
    while currentId do
      local loc = store.itemLocations[currentId]
      if not loc then return false end
      if loc.type == 'equipment' then return true end
      if loc.type == 'container' then
        local c = store.containers[loc.containerId]
        if not c or c.defId == '__remote_container__' or c.defId == '__vehicle_container__' then return false end
        currentId = store.containerOwners[loc.containerId]
      else
        return false
      end
    end
    return false
  end

  local results = {}
  for itemId, item in pairs(store.items) do
    if (not itemDefId or item.defId == itemDefId) and isOwnedByPlayer(itemId) then
      table.insert(results, item)
    end
  end
  return results
end)

RegisterNetEvent('pop_inventory:server:openVehicle', function(plate, class, model)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  if not plate then return end
  plate = tostring(plate)
  if not isPlayerNearPlate(src, plate, 8.0) then return end

  -- Un seul joueur à la fois dans ce coffre (sinon les synchros s'écrasent)
  if not acquireSharedLock(src, vehicleLockKey(plate), { plate = plate }, { 'veh:' }) then
    notify(src, L('chest_in_use'))
    return
  end

  local store = ensureStore(identifier)

  -- Cleanup: Retirer tout ancien conteneur véhicule mal fermé
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' then
       -- Remove temporary items linked to this container
       for _, itemId in pairs(container.items or {}) do
          if store.items[itemId] and store.items[itemId]._isTemporary then
            removeStoreItemTree(store, itemId)
          end
       end
       store.containers[cId] = nil
    end
  end

  local vId = 'plate:' .. plate
  -- Load from database (not just in-memory) so items persist across restarts
  if not Stores[vId] then
    Stores[vId] = loadStore(vId)
  end
  local vStore = Stores[vId]

  -- Determine main container ID for this vehicle
  local containerId = nil
  for cId, c in pairs(vStore.containers) do -- luacheck: ignore 213 512
     containerId = cId
     break
  end

  if not containerId then
    containerId = generateId('veh_' .. plate:gsub('[^%w]', ''))

    local trunkConfig = Config.VehicleTrunks and Config.VehicleTrunks.default or { slots = 60, maxWeight = 200.0 }
    if model then
        for modelName, cfg in pairs(Config.VehicleTrunks or {}) do
            if modelName ~= "default" and (model == GetHashKey(modelName) or tostring(model) == modelName) then
                trunkConfig = cfg
                break
            end
        end
    end

    vStore.containers[containerId] = {
      id = containerId,
      defId = 'vehicle_trunk',
      slots = trunkConfig.slots,
      maxWeight = trunkConfig.maxWeight,
      items = {}
    }
  else -- luacheck: ignore 542
  end

  local vContainer = vStore.containers[containerId]
  if model then
      for modelName, cfg in pairs(Config.VehicleTrunks or {}) do
          if modelName ~= "default" and (model == GetHashKey(modelName) or tostring(model) == modelName) then
              if vContainer.slots ~= cfg.slots or vContainer.maxWeight ~= cfg.maxWeight then
                  vContainer.slots = cfg.slots
                  vContainer.maxWeight = cfg.maxWeight
                  markDirty(vId)
              end
              break
          end
      end
  end

  -- Inject into player store as temporary container
  store.containers[containerId] = {
    id = containerId,
    defId = '__vehicle_container__',
    plate = plate, -- helper for sync
    label = L('trunk_label', plate),
    slots = vContainer.slots,
    maxWeight = vContainer.maxWeight,
    items = {},
  }

  -- Inject items
  for slot, itemId in pairs(vContainer.items) do
    local vItem = vStore.items[itemId]
    if vItem then
      -- Copy the item tree recursively
      copyItemTree(vStore, store, itemId, function(item)
        item._isTemporary = true
        item._vehiclePlate = plate
      end)

      store.containers[containerId].items[slot] = itemId

      -- Also set location
      setItemLocation(store, itemId, { type = 'container', containerId = containerId, slot = slot })
    end
  end

  StandbyContainers[src] = containerId
  store.activeContainerId = containerId
  store.activeContainerIsGround = false
  markDirty(identifier)

  local state = buildState(src, store)
  state.standbyContainerId = containerId
  state.standbyContainer = buildContainerView(store, containerId)

  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]

  TriggerClientEvent('pop_inventory:client:state', src, state)
end)

-- ADDED BY ANTIGRAVITY FOR BANKUI INTEGRATION
-- SÉCURITÉ : événement serveur LOCAL uniquement (AddEventHandler). En RegisterNetEvent,
-- n'importe quel client pouvait se donner (ou donner à autrui) n'importe quel item.
AddEventHandler('pop_inventory:server:giveItemBankui', function(source, itemDefId, qty)
  qty = math.floor(tonumber(qty) or 1)
  if qty < 1 then return end
  local identifier = getIdentifier(source)
  if not identifier then return end

  local store = ensureStore(identifier)
  ensureActiveContainer(store)

  local def = getItemDef(itemDefId)
  if not def then
    print('[POP_INVENTORY] Impossible de trouver la def de l\'item:', itemDefId)
    return
  end

  local placed = false

  -- Auto-equip if the item has an equipSlot and the slot is empty
  if def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, itemDefId, 1)
    if itemId then
      local ok, err = equipItem(store, itemId) -- luacheck: ignore 211
      if ok then
        placed = true
        qty = qty - 1
      else
        -- Cleanup if failed
        local created = store.items[itemId]
        if created and created.containerId then
          store.containers[created.containerId] = nil
          store.containerOwners[created.containerId] = nil
        end
        store.items[itemId] = nil
      end
    end
  end

  if qty > 0 then
    -- Create the remaining item(s)
    local itemId = createItem(store, itemDefId, qty)
    if itemId then
      -- Find empty slot in active container first
      local containerId = store.activeContainerId
      local container = containerId and store.containers[containerId]
      local placedRemaining = false

      if container and isAllowedInContainer(container.defId, itemDefId, def) then
         local slot = findEmptySlot(container)
         if slot then
            if placeItemInContainer(store, containerId, slot, itemId) then
               placedRemaining = true
               placed = true
            end
         end
      end

      -- Fallback to other containers if not placed
      if not placedRemaining then
          for cId, c in pairs(store.containers) do
             if cId ~= containerId and c.defId ~= '__remote_container__' and isAllowedInContainer(c.defId, itemDefId, def) then
                 local slot = findEmptySlot(c)
                 if slot then
                     if placeItemInContainer(store, cId, slot, itemId) then
                         placedRemaining = true
                         placed = true
                         break
                     end
                 end
             end
          end
      end

      if not placedRemaining then
          -- Cleanup orphan item if no space found
          store.items[itemId] = nil
          if Config.Debug then print('[POP_INVENTORY] Inventaire plein pour:', itemDefId) end
          notify(source, L('inv_full'))
      end
    end
  end

  if placed then
      markDirty(identifier)

      local state = buildState(source, store)
      StateSeq[source] = (StateSeq[source] or 0) + 1
      state._seq = StateSeq[source]
      TriggerClientEvent('pop_inventory:client:state', source, state)
      TriggerClientEvent('pop_inventory:client:applyEquipment', source, buildEquipmentDefs(store))
  end
end)

-- SÉCURITÉ : événement serveur LOCAL uniquement (un client pouvait vider l'inventaire d'autrui).
AddEventHandler('pop_inventory:server:removeItem', function(source, itemDefId, qty)
  qty = math.floor(tonumber(qty) or 1)
  if qty < 1 then return end
  local identifier = getIdentifier(source)
  if not identifier then return end

  local store = ensureStore(identifier)

  -- Find items to remove
  local itemsToRemove = {}
  local foundQty = 0

  for _, item in pairs(store.items) do
      if item.defId == itemDefId and not item._isTemporary then
          table.insert(itemsToRemove, item)
          foundQty = foundQty + (item.qty or 1)
      end
  end

  if foundQty < qty then
      if Config.Debug then print('[POP_INVENTORY] Pas assez d items pour retirer:', itemDefId) end
      return
  end

  local remaining = qty

  -- Process removal
  for _, item in ipairs(itemsToRemove) do
      if remaining <= 0 then break end

      local toRemove = math.min(remaining, item.qty or 1)

      if toRemove >= (item.qty or 1) then
          -- Remove entire item
          -- Find parent container and clear slot
          local loc = store.itemLocations[item.id]
          if loc and loc.type == 'container' then
              local parentContainer = store.containers[loc.containerId]
              if parentContainer then
                  parentContainer.items[loc.slot] = nil
              end
          end

          store.items[item.id] = nil
          store.itemLocations[item.id] = nil

          remaining = remaining - toRemove
      else
          -- Reduce quantity
          item.qty = item.qty - toRemove
          remaining = 0
      end
  end

  markDirty(identifier)

  local state = buildState(source, store)
  StateSeq[source] = (StateSeq[source] or 0) + 1
  state._seq = StateSeq[source]
  TriggerClientEvent('pop_inventory:client:state', source, state)
end)

RegisterNetEvent('pop_inventory:server:saveState', function(state)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    local store = ensureStore(identifier) -- luacheck: ignore 211

    -- Update store based on the received state.
    -- Ideally, we should validate and only update changed items/containers.
    -- For now, we trust the client state regarding item moves within the player's inventory scope
    -- But be careful not to blindly overwrite everything.

    -- A safer approach for this specific request (saving status on close):
    -- Just trigger a save of the current server-side store to the database.
    -- The operations (move, etc.) should have already updated the server-side store via other events.
    -- If 'state' contains data not yet synced (unlikely if all actions go through server), we might need to process it.

    -- Assuming actions (move, drop) are sync, just saving the store is enough.
    markDirty(identifier)

    -- Also save ground if any interaction happened
    saveGround()

    debugPrint(src, 'saved state on UI close')
end)

RegisterNetEvent('pop_inventory:server:giveItem', function(targetId, fromContainerId, fromSlot, itemData, fromType)
    local src = source
    local srcId = getIdentifier(src)
    targetId = tonumber(targetId)
    if not targetId or targetId == src or type(itemData) ~= 'table' then return end
    local tgtId = getIdentifier(targetId)

    if not srcId or not tgtId then
        return
    end
    -- Anti-triche : don uniquement à un joueur proche
    local sp, tp = GetPlayerPed(src), GetPlayerPed(targetId)
    if sp ~= 0 and tp ~= 0 and #(GetEntityCoords(sp) - GetEntityCoords(tp)) > 6.0 then return end
    local srcStore = ensureStore(srcId)
    local tgtStore = ensureStore(tgtId)

    local item = nil
    local itemId = nil

    if fromType == 'equipment' then
        itemId = srcStore.equipment[fromSlot]
        if itemId then
            item = srcStore.items[itemId]
        end
    else
        fromSlot = tonumber(fromSlot) or fromSlot
        local container = srcStore.containers[fromContainerId]
        if container then
            itemId = container.items[fromSlot]
            if itemId then
                item = srcStore.items[itemId]
            end
        end
    end

    -- Les items temporaires (copies d'un coffre/conteneur distant) ne se donnent pas : duplication
    if not item or item.defId ~= itemData.defId or item._isTemporary then
        notify(src, L('invalid_object'))
        return
    end

    -- Transfer
    local success, err = false, L('transfer_impossible') -- luacheck: ignore 311
    if item.containerId then
        -- Need to move the whole item tree to preserve container contents
        moveItemTree(srcStore, tgtStore, itemId)
        success, err = autoInsertExistingItem(tgtStore, itemId)
        if success then
            -- Note: moveItemTree already removed from srcStore.items and locations
            if fromType == 'equipment' then
                srcStore.equipment[fromSlot] = nil
            else
                local container = srcStore.containers[fromContainerId]
                if container then container.items[fromSlot] = nil end
            end
        else
            -- Revert back
            moveItemTree(tgtStore, srcStore, itemId)
            local locType = (fromType == 'equipment' and 'equipment' or 'container')
            setItemLocation(srcStore, itemId, { type = locType, containerId = fromContainerId, slot = fromSlot })
            if locType == 'equipment' then
                srcStore.equipment[fromSlot] = itemId
            else
                local container = srcStore.containers[fromContainerId]
                if container then container.items[fromSlot] = itemId end
            end

            -- Sync source on error to revert visual optimistic UI drop
            local srcState = buildState(src, srcStore)
            StateSeq[src] = (StateSeq[src] or 0) + 1
            srcState._seq = StateSeq[src]
            TriggerClientEvent('pop_inventory:client:state', src, srcState)
            TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(srcStore))

            notify(src, L('error_prefix', err or L('target_full')))
            return
        end
    else
        -- Normal transfer
        success, err = autoInsertItem(tgtStore, item.defId, item.qty, item.meta)
        if success then
            -- Remove from source
            if fromType == 'equipment' then
                srcStore.equipment[fromSlot] = nil
            else
                local container = srcStore.containers[fromContainerId]
                if container then container.items[fromSlot] = nil end
            end
            srcStore.items[itemId] = nil
            removeItemLocation(srcStore, itemId)
        else
            -- Sync source on error to revert visual optimistic UI drop
            local srcState = buildState(src, srcStore)
            StateSeq[src] = (StateSeq[src] or 0) + 1
            srcState._seq = StateSeq[src]
            TriggerClientEvent('pop_inventory:client:state', src, srcState)
            TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(srcStore))

            notify(src, L('error_prefix', err or L('transfer_impossible')))
            return
        end
    end

    if success then
        saveStore(srcId, srcStore)
        saveStore(tgtId, tgtStore)

        -- Sync source
        local srcState = buildState(src, srcStore)
        StateSeq[src] = (StateSeq[src] or 0) + 1
        srcState._seq = StateSeq[src]
        TriggerClientEvent('pop_inventory:client:state', src, srcState)
        TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(srcStore))

        -- Sync target
        local tgtState = buildState(targetId, tgtStore)
        StateSeq[targetId] = (StateSeq[targetId] or 0) + 1
        tgtState._seq = StateSeq[targetId]
        TriggerClientEvent('pop_inventory:client:state', targetId, tgtState)
        TriggerClientEvent('pop_inventory:client:applyEquipment', targetId, buildEquipmentDefs(tgtStore))

        if item.defId == 'cardboard_box' then
            TriggerClientEvent('pop_inventory:client:equipCardboardBox', targetId)
        elseif item.defId == 'safe' then
            TriggerClientEvent('pop_inventory:client:equipSafe', targetId)
        end

        local def = getItemDef(item.defId)
        local itemLabel = (item.meta and item.meta.customLabel) or (def and def.label) or item.defId

        notify(src, L('gave_item', itemQtyTag(item.qty), itemLabel))
        notify(targetId, L('received_item', itemQtyTag(item.qty), itemLabel))
    else
        notify(src, L('error_prefix', err or L('transfer_impossible')))
    end
end)

function GiveItem(source, itemDefId, qty, meta)
  local identifier = getIdentifier(source)
  if not identifier then return false, L('player_not_found') end

  local store = ensureStore(identifier)
  local success, err = autoInsertItem(store, itemDefId, qty or 1, meta)

  if success then
    markDirty(identifier)
    sendState(source)
    TriggerClientEvent('pop_inventory:client:applyEquipment', source, buildEquipmentDefs(store))
    if itemDefId == 'carkeys' and type(meta) == 'table' and meta.plate
        and GetResourceState('pop_vehiclepersistence') == 'started' then
      pcall(function()
        exports['pop_vehiclepersistence']:OnKeyGranted(source, meta.plate)
      end)
    end
    return true
  else
    return false, err
  end
end

exports('addItem', function(source, itemDefId, qty, meta)
  return GiveItem(source, itemDefId, qty, meta)
end)

exports('GiveItem', function(source, itemDefId, qty, meta)
  return GiveItem(source, itemDefId, qty, meta)
end)

exports('removeItem', function(source, itemDefId, qty)
  local identifier = getIdentifier(source)
  if not identifier then return false end

  local store = ensureStore(identifier)
  local itemsToRemove = {}
  local foundQty = 0

  for _, item in pairs(store.items) do
    if item.defId == itemDefId and not item._isTemporary then
      table.insert(itemsToRemove, item)
      foundQty = foundQty + (item.qty or 1)
    end
  end

  if foundQty < (qty or 1) then
    return false
  end

  local remaining = qty or 1

  for _, item in ipairs(itemsToRemove) do
    if remaining <= 0 then break end

    local toRemove = math.min(remaining, item.qty or 1)

    if toRemove >= (item.qty or 1) then
      local loc = store.itemLocations[item.id]
      if loc and loc.type == 'container' then
        local parentContainer = store.containers[loc.containerId]
        if parentContainer then
          parentContainer.items[loc.slot] = nil
        end
      elseif loc and loc.type == 'equipment' then
        store.equipment[loc.slot] = nil
      end

      store.items[item.id] = nil
      store.itemLocations[item.id] = nil

      remaining = remaining - toRemove
    else
      item.qty = item.qty - toRemove
      remaining = 0
    end
  end

  markDirty(identifier)

  local state = buildState(source, store)
  StateSeq[source] = (StateSeq[source] or 0) + 1
  state._seq = StateSeq[source]
  TriggerClientEvent('pop_inventory:client:state', source, state)

  return true
end)
