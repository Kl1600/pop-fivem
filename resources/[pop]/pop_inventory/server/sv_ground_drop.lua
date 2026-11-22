-- Poser au sol / ramasser (suite de sv_inventory_state.lua).

function clampDropQty(item, qty)
  local itemQty = tonumber(item.qty) or 1
  local amount = tonumber(qty) or itemQty
  amount = math.floor(amount) -- pas de quantité fractionnaire envoyée par le client
  if amount <= 0 or amount > itemQty then
    amount = itemQty
  end
  return amount
end

function canSplitDrop(item, def, qty)
  if not item or not def then
    return false
  end
  if item.containerId then
    return false
  end
  local maxStack = def.maxStack or 1
  return maxStack > 1 and item.qty > 1 and qty < item.qty
end

function resolveOriginItem(store, origin)
  if not origin or not origin.type then
    return nil
  end
  if origin.type == 'equipment' then
    return store.equipment[origin.slot]
  end
  if origin.type == 'container' then
    local slotIndex = tonumber(origin.slot)
    if not slotIndex then
      return nil
    end
    origin.slot = slotIndex
    local container = store.containers[origin.containerId]
    if container then
      return container.items[slotIndex]
    end
  end
  return nil
end

function dropToGround(src, store, origin, qty, coords)
  local itemId = resolveOriginItem(store, origin)
  if not itemId then
    return false, L('slot_empty')
  end
  local item = store.items[itemId]
  if not item then
    return false, L('item_invalid')
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, L('item_unknown')
  end

  local dropQty = clampDropQty(item, qty)
  local splitDrop = canSplitDrop(item, def, dropQty)
  local dropWeight = splitDrop and itemBaseWeight(def, dropQty) or getItemWeight(store, itemId)

  local function tryGetSlot(pile)
    if not pile then
      return nil, nil, L('ground_unavailable')
    end
    local groundContainer = GroundStore.containers[pile.containerId]
    if not groundContainer then
      return nil, nil, L('ground_unavailable')
    end
    local targetSlot = findEmptySlot(groundContainer)
    if not targetSlot then
      return nil, nil, L('ground_full')
    end
    if not canAddWeight(GroundStore, pile.containerId, dropWeight) then
      return nil, nil, L('ground_max_weight')
    end
    return groundContainer, targetSlot, nil
  end

  local pile = createDropPile(src, coords)
  local groundContainer, targetSlot, err = tryGetSlot(pile) -- luacheck: ignore 231
  if not targetSlot then
    local coordsVec = pile and pile.coords and vector3(pile.coords.x, pile.coords.y, pile.coords.z) or toVector3(coords) or getPlayerCoords(src)
    if coordsVec then
      local weightOverride = nil
      if err == L('ground_max_weight') then
        weightOverride = math.max(Config.Ground.MaxWeight or 0, dropWeight)
      end
      local newPile = createGroundPile(coordsVec, weightOverride)
      groundContainer, targetSlot, err = tryGetSlot(newPile)
      if targetSlot then
        pile = newPile
      end
    end
  end
  if not targetSlot then
    return false, err or L('ground_unavailable')
  end

  if splitDrop then
    item.qty = item.qty - dropQty
    local newItemId = createItem(GroundStore, item.defId, dropQty, item.meta)
    if not newItemId then
      return false, L('create_error')
    end
    placeItemInContainer(GroundStore, pile.containerId, targetSlot, newItemId)
  else
    if origin.type == 'equipment' then
      store.equipment[origin.slot] = nil
      removeItemLocation(store, itemId)
    elseif origin.type == 'container' then
      removeItemFromContainer(store, origin.containerId, origin.slot)
    end
    moveItemTree(store, GroundStore, itemId)
    placeItemInContainer(GroundStore, pile.containerId, targetSlot, itemId)
  end

  PlayerGroundFocus[src] = pile.id
  markGroundDirty()
  syncGroundDropEntities()
  debugPrint('dropToGround: item posé, pileId=', pile.id, 'containerId=', pile.containerId, 'itemId=', itemId or newItemId)
  return true
end

function pickupFromGroundToSlot(src, store, groundSlot, toContainerId, toSlot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, groundSlot, coords)
  if not pile then
    return false, L('nothing_nearby')
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, L('item_invalid')
  end

  local targetContainer = store.containers[toContainerId]
  if not targetContainer then
    return false, L('container_invalid')
  end

  local def = getItemDef(item.defId)
  if not def then
    return false, L('item_unknown')
  end

  if not isAllowedInContainer(targetContainer.defId, item.defId, def) then
    return false, L('container_restriction')
  end

  local targetSlot = tonumber(toSlot)
  if not targetSlot then
    return false, L('target_slot_invalid')
  end

  -- Objet-conteneur (sac…) vers une case occupée : refus AVANT de le retirer du
  -- sol (avant, l'objet était retiré puis la fonction sortait : objet perdu).
  if item.containerId and (targetContainer.items[targetSlot] or targetContainer.items[tostring(targetSlot)]) then
    return false, L('slot_taken')
  end

  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  if groundContainer then
    groundContainer.items[slotIndex] = nil
    groundContainer.items[tostring(slotIndex)] = nil
  end

  if item.containerId then
    moveItemTree(GroundStore, store, itemId)
    local weight = getItemWeight(store, itemId)
    if not canAddWeight(store, toContainerId, weight) then
      moveItemTree(store, GroundStore, itemId)
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, L('max_weight')
    end

    placeItemInContainer(store, toContainerId, targetSlot, itemId)
  else
    local weight = itemBaseWeight(def, item.qty)
    if not canAddWeight(store, toContainerId, weight) then
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, L('max_weight')
    end

    local targetItemId = targetContainer.items[targetSlot]
    if targetItemId then
      local targetItem = store.items[targetItemId]
      if canStackItems(item, targetItem) then
        local maxStack = def.maxStack or 1
        local space = maxStack - targetItem.qty
        if space > 0 then
          local add = math.min(space, item.qty)
          targetItem.qty = targetItem.qty + add
          item.qty = item.qty - add
          if item.qty > 0 then
            placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
          else
            purgeItemFromGround(itemId)
          end
        else
          placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
          return false, L('stack_full')
        end
      else
        placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
        return false, L('slot_taken')
      end
    else
      local newItemId = createItem(store, item.defId, item.qty, item.meta)
      placeItemInContainer(store, toContainerId, targetSlot, newItemId)
      purgeItemFromGround(itemId)
    end
  end

  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  return true
end

function unequipToSlot(store, equipSlot, toContainerId, toSlot)
  local itemId = store.equipment[equipSlot]
  if not itemId then
    return false, L('slot_empty')
  end

  local targetContainer = store.containers[toContainerId]
  if not targetContainer then
    return false, L('container_invalid')
  end

  local item = store.items[itemId]
  if not item then
    return false, L('item_invalid')
  end

  local def = getItemDef(item.defId)
  if not def then
    return false, L('item_unknown')
  end

  if not isAllowedInContainer(targetContainer.defId, item.defId, def) then
    return false, L('container_restriction')
  end

  local targetSlot = tonumber(toSlot)
  if not targetSlot then
    return false, L('target_slot_invalid')
  end

  local targetItemId = targetContainer.items[targetSlot]
  if targetItemId then
    return false, L('slot_taken')
  end

  local weight = getItemWeight(store, itemId)
  if not canAddWeight(store, toContainerId, weight) then
    return false, L('max_weight')
  end

  store.equipment[equipSlot] = nil
  removeItemLocation(store, itemId)
  placeItemInContainer(store, toContainerId, targetSlot, itemId)
  ensureActiveContainer(store)
  return true
end

function pickupFromGround(src, store, slot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, slot, coords)
  if not pile then
    return false, L('nothing_nearby')
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, L('item_invalid')
  end

  if item.containerId then
    removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
    if groundContainer then
      groundContainer.items[slotIndex] = nil
      groundContainer.items[tostring(slotIndex)] = nil
    end
    moveItemTree(GroundStore, store, itemId)
    local ok, err = autoInsertExistingItem(store, itemId)
    if not ok then
      local def = getItemDef(item.defId)
      if def and def.equipSlot and not store.equipment[def.equipSlot] then
        local equipOk = equipItem(store, itemId)
        if equipOk then
          purgeItemFromGround(itemId)
          pruneEmptyGroundPiles()
          markGroundDirty()
          -- broadcastGroundDrops() -- SUPPRIMÉ: Optimisation "Manière Forte"
          return true
        end
      end
      moveItemTree(store, GroundStore, itemId)
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, err or L('no_space')
    end
    purgeItemFromGround(itemId)
    pruneEmptyGroundPiles()
    markGroundDirty()
    syncGroundDropEntities()
    PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
    return true
  end

  local ok, err = autoInsertItem(store, item.defId, item.qty, item.meta)
  if not ok then
    return false, err or L('no_space')
  end
  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  if groundContainer then
    groundContainer.items[slotIndex] = nil
    groundContainer.items[tostring(slotIndex)] = nil
  end
  purgeItemFromGround(itemId)
  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  return true
end

function pickupEquipFromGround(src, store, slot, equipSlot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, slot, coords) -- luacheck: ignore 211
  if not pile then
    return false, L('nothing_nearby')
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, L('item_invalid')
  end
  local def = getItemDef(item.defId)
  if not def or not def.equipSlot or def.equipSlot ~= equipSlot then
    return false, L('slot_taken')
  end
  if store.equipment[equipSlot] then
    return false, L('slot_taken')
  end

  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  moveItemTree(GroundStore, store, itemId)
  local ok, err = equipItem(store, itemId)
  if not ok then
    moveItemTree(store, GroundStore, itemId)
    placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
    return false, err or L('action_impossible')
  end
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  return true
end

function syncRemoteContainerChanges(store)
  -- Synchroniser les modifications des conteneurs distants vers RemoteContainers
  local changed = false
  for containerId, container in pairs(store.containers or {}) do
    if container.defId == '__remote_container__' and RemoteContainers[containerId] then
      changed = true
      RemoteContainers[containerId].itemData = {}
      for slot, itemId in pairs(container.items or {}) do
        local item = store.items[itemId]
        if item then
          -- Sérialise l'arbre complet (item + conteneur imbriqué éventuel : pot, sac…).
          RemoteContainers[containerId].itemData[slot] = serializeItemTree(store, itemId)
        end
      end
    end
  end
  if changed then
    saveRemoteContainers()
  end
end
