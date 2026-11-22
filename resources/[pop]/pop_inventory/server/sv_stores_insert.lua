-- Stores (suite de sv_stores.lua) : insertion automatique, découpe de pile, déplacements entre inventaires, sérialisation.

function autoInsertItem(store, defId, qty, meta)
  local def = getItemDef(defId)
  if not def then
    return false, L('item_unknown')
  end
  local remaining = qty

  -- Paint items (tag 'peinture') must go directly into an existing pot_peinture container.
  local isPaint = false
  for _, tag in ipairs(def.tags or {}) do
    if tag == 'peinture' then
      isPaint = true
      break
    end
  end

  if isPaint then
    local paintPots = {}
    for _, container in pairs(store.containers) do
      if container.defId == 'pot_peinture' then
        table.insert(paintPots, container)
      end
    end

    if #paintPots == 0 then
      return false, L('no_paint_pot')
    end

    -- Try to stack in existing paint pots first
    if def.maxStack and def.maxStack > 1 then
      for _, container in ipairs(paintPots) do
        for _, itemId in pairs(container.items) do
          local existing = store.items[itemId]
          if existing and canStackItems(existing, { defId = defId, meta = meta or {} }) then
            local maxStack = def.maxStack
            local space = maxStack - existing.qty
            if space > 0 then
              local add = math.min(space, remaining)
              local addWeight = itemBaseWeight(def, add)
              if canAddWeight(store, container.id, addWeight) then
                existing.qty = existing.qty + add
                remaining = remaining - add
                if remaining <= 0 then
                  return true
                end
              end
            end
          end
        end
      end
    end

    -- Insert into empty slots of paint pots
    for _, container in ipairs(paintPots) do
      while remaining > 0 do
        local slot = findEmptySlot(container)
        if not slot then
          break
        end
        local stackQty = math.min(remaining, def.maxStack or 1)
        local itemId = createItem(store, defId, stackQty, meta)
        if not itemId then
          break
        end
        local addWeight = getItemWeight(store, itemId)
        if not canAddWeight(store, container.id, addWeight) then
          local created = store.items[itemId]
          if created and created.containerId then
            store.containers[created.containerId] = nil
            store.containerOwners[created.containerId] = nil
          end
          store.items[itemId] = nil
          break
        end
        placeItemInContainer(store, container.id, slot, itemId)
        remaining = remaining - stackQty
        if remaining <= 0 then
          return true
        end
      end
    end

    return false, L('paint_pots_full')
  end

  -- Auto-equip if the item has an equipSlot and the slot is empty
  if def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, defId, 1, meta)
    if itemId then
      local ok, err = equipItem(store, itemId) -- luacheck: ignore 211
      if ok then
        remaining = remaining - 1
        if remaining <= 0 then
          return true
        end
      else
        -- Clean up created item if equip failed
        local created = store.items[itemId]
        if created and created.containerId then
          store.containers[created.containerId] = nil
          store.containerOwners[created.containerId] = nil
        end
        store.items[itemId] = nil
      end
    end
  end

  local ordered = getOrderedContainers(store)

  if def.maxStack and def.maxStack > 1 then
    for _, containerId in ipairs(ordered) do
      local container = store.containers[containerId]
      if isAllowedInContainer(container.defId, defId, def) then
        for _, itemId in pairs(container.items) do
          local existing = store.items[itemId]
          if existing and canStackItems(existing, { defId = defId, meta = meta or {} }) then
            local maxStack = def.maxStack
            local space = maxStack - existing.qty
            if space > 0 then
              local add = math.min(space, remaining)
              local addWeight = itemBaseWeight(def, add)
              if canAddWeight(store, containerId, addWeight) then
                existing.qty = existing.qty + add
                remaining = remaining - add
                if remaining <= 0 then
                  return true
                end
              end
            end
          end
        end
      end
    end
  end

  for _, containerId in ipairs(ordered) do
    local container = store.containers[containerId]
    if isAllowedInContainer(container.defId, defId, def) then
      while remaining > 0 do
        local slot = findEmptySlot(container)
        if not slot then
          break
        end
        local stackQty = math.min(remaining, def.maxStack or 1)
        local itemId = createItem(store, defId, stackQty, meta)
        if not itemId then
          break
        end
        local addWeight = getItemWeight(store, itemId)
        if not canAddWeight(store, containerId, addWeight) then
          local created = store.items[itemId]
          if created and created.containerId then
            store.containers[created.containerId] = nil
            store.containerOwners[created.containerId] = nil
          end
          store.items[itemId] = nil
          break
        end
        placeItemInContainer(store, containerId, slot, itemId)
        remaining = remaining - stackQty
        if remaining <= 0 then
          return true
        end
      end
    end
  end

  return false, L('no_space')
end

function insertIntoActiveContainer(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false, L('item_unknown')
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, L('item_unknown')
  end

  if listContains(def.tags or {}, 'weapon_long') and hasLongWeaponEquipped(store) then
    return false, L('long_weapon_equipped')
  end

  local activeId = store.activeContainerId
  if not activeId or not store.containers[activeId] then
    ensureActiveContainer(store)
    activeId = store.activeContainerId
  end

  if not activeId or not store.containers[activeId] then
    return false, L('no_active_container')
  end

  local container = store.containers[activeId]
  if not isAllowedInContainer(container.defId, item.defId, def) then
    return false, L('container_restriction')
  end

  local slot = findEmptySlot(container)
  if not slot then
    return false, L('no_space')
  end

  local weight = getItemWeight(store, itemId)
  if not canAddWeight(store, activeId, weight) then
    return false, L('max_weight')
  end

  placeItemInContainer(store, activeId, slot, itemId)
  return true
end

function autoInsertExistingItem(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false, L('item_unknown')
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, L('item_unknown')
  end

  -- Equippable container-items (briefcase, cardboard_box, safe, backpack, etc.)
  -- Default pop_inventory forces them to equip, but we want clothes/backpacks to be storable!
  if def.equipSlot and def.container then
    -- If the slot is empty, we automatically equip it for convenience
    if not store.equipment[def.equipSlot] then
      return equipItem(store, itemId)
    end
    -- If it's already occupied, we gracefully CONTINUE below so it can be stored
    -- inside another container (like a bag or trunk) instead of hard failing.
  end

  if listContains(def.tags or {}, 'weapon_long') and hasLongWeaponEquipped(store) then
    return false, L('long_weapon_equipped')
  end

  local ordered = getOrderedContainers(store)
  for _, containerId in ipairs(ordered) do
    local container = store.containers[containerId]
    if isAllowedInContainer(container.defId, item.defId, def) then
      local slot = findEmptySlot(container)
      if slot then
        local weight = getItemWeight(store, itemId)
        if canAddWeight(store, containerId, weight) then
          placeItemInContainer(store, containerId, slot, itemId)
          return true
        end
      end
    end
  end

  return false, L('no_space')
end

function splitStack(store, containerId, slot, splitQty)
  local container = store.containers[containerId]
  if not container then
    return false, L('container_not_found')
  end
  local itemId = container.items[slot]
  local item = itemId and store.items[itemId]
  if not item then
    return false, L('slot_empty')
  end
  local def = getItemDef(item.defId)
  if not def or (def.maxStack or 1) <= 1 then
    return false, L('not_stackable')
  end
  if splitQty <= 0 or splitQty >= item.qty then
    return false, L('invalid_quantity')
  end
  local emptySlot = findEmptySlot(container)
  if not emptySlot then
    return false, L('no_free_slot')
  end

  local newItemId = createItem(store, item.defId, splitQty, item.meta)
  if not newItemId then
    return false, L('create_error')
  end

  item.qty = item.qty - splitQty
  placeItemInContainer(store, containerId, emptySlot, newItemId)
  return true
end

function resolveStoreAndContainerId(source, cId)
    local targetId = SearchingPlayers[source]
    if cId and type(cId) == 'string' and cId:sub(1, 7) == 'target_' then
        if targetId then
            local targetIdentifier = getIdentifier(targetId)
            local targetStore = targetIdentifier and ensureStore(targetIdentifier)
            if targetStore then
                return targetStore, cId:sub(8)
            end
        end
    end
    return ensureStore(getIdentifier(source)), cId
end

function moveItemCrossStore(source, fromCId, fromSlot, toCId, toSlot)
    local fromStore, actualFromCId = resolveStoreAndContainerId(source, fromCId)
    local toStore, actualToCId = resolveStoreAndContainerId(source, toCId)

    if fromStore == toStore then
        return moveItemBetweenContainers(fromStore, actualFromCId, fromSlot, actualToCId, toSlot)
    end

    -- Transfert d'un store à un autre (Fouille)
    local actualFromContainer = fromStore.containers[actualFromCId]
    local itemToMoveId = actualFromContainer and actualFromContainer.items[fromSlot]
    if not itemToMoveId then return false, L('item_not_found_move') end

    local item = fromStore.items[itemToMoveId]
    if not item then return false, L('item_invalid') end

    local targetContainer = toStore.containers[actualToCId]
    if not targetContainer then return false, L('dest_container_invalid') end
    if targetContainer.items[toSlot] then return false, L('slot_taken_accent') end

    -- Fonction récursive pour copier l'item et ses sous-conteneurs
    local function copyItemRecursively(oldS, oldIId, newS)
        local oldItem = oldS.items[oldIId]
        local newIId = generateId('gi')
        local newItem = {}
        for k, v in pairs(oldItem) do newItem[k] = v end
        newItem.id = newIId

        if oldItem.containerId then
            local oldC = oldS.containers[oldItem.containerId]
            local newCId = generateId('c')
            newItem.containerId = newCId
            newS.containers[newCId] = {
                id = newCId, defId = oldC.defId, label = oldC.label,
                slots = oldC.slots, maxWeight = oldC.maxWeight, items = {}
            }
            newS.containerOwners[newCId] = newIId
            for slot, subId in pairs(oldC.items) do
                local newSubId = copyItemRecursively(oldS, subId, newS)
                newS.containers[newCId].items[slot] = newSubId
                newS.itemLocations[newSubId] = { type = 'container', containerId = newCId, slot = slot }
            end
        end
        newS.items[newIId] = newItem
        return newIId
    end

    -- Fonction récursive pour supprimer l'item et ses sous-conteneurs
    local function deleteItemRecursively(s, iId)
        local i = s.items[iId]
        if i and i.containerId then
            local c = s.containers[i.containerId]
            for _, sid in pairs(c.items) do deleteItemRecursively(s, sid) end
            s.containers[i.containerId] = nil
            s.containerOwners[i.containerId] = nil
        end
        s.items[iId] = nil
        removeItemLocation(s, iId)
    end

    local newItemId = copyItemRecursively(fromStore, itemToMoveId, toStore)
    addItemToContainer(toStore, actualToCId, toSlot, newItemId)
    deleteItemRecursively(fromStore, itemToMoveId)

    local targetId = SearchingPlayers[source]
    if targetId then sendState(targetId) end

    return true
end

moveItemBetweenContainers = function(store, fromContainerId, fromSlot, toContainerId, toSlot)
  local fromContainer = store.containers[fromContainerId]
  local toContainer = store.containers[toContainerId]
  if not fromContainer or not toContainer then
    return false, L('container_invalid')
  end
  local itemId = fromContainer.items[fromSlot]
  if not itemId then
    return false, L('slot_empty')
  end
  local item = store.items[itemId]
  if not item then
    return false, L('item_invalid')
  end

  if item.containerId and isContainerDescendant(store, itemId, toContainerId) then
    return false, L('loop_forbidden')
  end

  local def = getItemDef(item.defId)
  if not isAllowedInContainer(toContainer.defId, item.defId, def) then
    return false, L('container_restriction')
  end

  local targetItemId = toContainer.items[toSlot]
  if targetItemId then
    local targetItem = store.items[targetItemId]
    if canStackItems(item, targetItem) then
      local maxStack = def.maxStack or 1
      local space = maxStack - targetItem.qty
      if space <= 0 then
        return false, L('stack_full')
      end
      local add = math.min(space, item.qty)
      local addWeight = itemBaseWeight(def, add)
      if not canAddWeight(store, toContainerId, addWeight) then
        return false, L('max_weight')
      end
      targetItem.qty = targetItem.qty + add
      item.qty = item.qty - add
      if item.qty <= 0 then
        removeItemFromContainer(store, fromContainerId, fromSlot)
        store.items[itemId] = nil
        if item.containerId then
          store.containers[item.containerId] = nil
          store.containerOwners[item.containerId] = nil
        end
      end
      return true
    end

    local targetDef = getItemDef(targetItem.defId)
    if not isAllowedInContainer(fromContainer.defId, targetItem.defId, targetDef) then
      return false, L('container_restriction')
    end

    local weightItem = getItemWeight(store, itemId)
    local weightTarget = getItemWeight(store, targetItemId)
    if not canAddWeight(store, toContainerId, weightItem - weightTarget) then
      return false, L('max_weight')
    end
    if not canAddWeight(store, fromContainerId, weightTarget - weightItem) then
      return false, L('max_weight')
    end

    fromContainer.items[fromSlot] = targetItemId
    toContainer.items[toSlot] = itemId
    setItemLocation(store, itemId, { type = 'container', containerId = toContainerId, slot = toSlot })
    setItemLocation(store, targetItemId, { type = 'container', containerId = fromContainerId, slot = fromSlot })
    return true
  end

  local moveWeight = getItemWeight(store, itemId)
  if not canAddWeight(store, toContainerId, moveWeight) then
    return false, L('max_weight')
  end

  removeItemFromContainer(store, fromContainerId, fromSlot)
  placeItemInContainer(store, toContainerId, toSlot, itemId)
  return true
end

function copyItemTree(fromStore, toStore, itemId, modifierFn)
  local item = fromStore.items[itemId]
  if not item then return end

  local newItem = {}
  for k, v in pairs(item) do newItem[k] = v end

  if modifierFn then
    modifierFn(newItem)
  end

  toStore.items[itemId] = newItem

  if item.containerId then
    local fromContainer = fromStore.containers[item.containerId]
    if fromContainer then
      toStore.containers[item.containerId] = {
        id = item.containerId,
        defId = fromContainer.defId,
        label = fromContainer.label,
        slots = fromContainer.slots,
        maxWeight = fromContainer.maxWeight,
        items = {}
      }
      toStore.containerOwners[item.containerId] = itemId

      for slot, subItemId in pairs(fromContainer.items) do
        toStore.containers[item.containerId].items[slot] = subItemId
        toStore.itemLocations[subItemId] = { type = 'container', containerId = item.containerId, slot = slot }
        copyItemTree(fromStore, toStore, subItemId, modifierFn)
      end
    end
  end
end

function removeStoreItemTree(store, itemId)
  local item = store.items[itemId]
  if not item then return end

  if item.containerId then
    local container = store.containers[item.containerId]
    if container then
      for _, subItemId in pairs(container.items) do
        removeStoreItemTree(store, subItemId)
      end
      store.containers[item.containerId] = nil
      store.containerOwners[item.containerId] = nil
    end
  end
  store.items[itemId] = nil
  removeItemLocation(store, itemId)
end

-- =====================================================
-- Sérialisation / reconstruction d'arbres d'items
-- (pour persister un item-conteneur — ex: pot, sac — dans un coffre distant/ground)
-- =====================================================

-- Convertit un item + son éventuel conteneur imbriqué (récursif) en table simple
-- persistable. Retourne un "noeud" { id, defId, qty, meta, container? }.
function serializeItemTree(store, itemId)
  local item = store.items[itemId]
  if not item then return nil end
  local node = {
    id = item._originalId or item.id,
    defId = item.defId,
    qty = item.qty,
    meta = item.meta or {},
  }
  if item.containerId then
    local c = store.containers[item.containerId]
    if c then
      local childItems = {}
      for slot, childId in pairs(c.items or {}) do
        local childNode = serializeItemTree(store, childId)
        if childNode then childItems[tostring(slot)] = childNode end
      end
      node.container = {
        defId = c.defId,
        label = c.label,
        slots = c.slots,
        maxWeight = c.maxWeight,
        items = childItems,
      }
    end
  end
  return node
end

-- Reconstruit un item (et son arbre de conteneur) dans `store` depuis un noeud
-- sérialisé. Retourne le nouvel itemId, ou nil. markTemp = pose le flag _isTemporary.
-- Rétro-compat : un noeud legacy {defId, qty, meta, containerId} sans `container`
-- crée un item plat (la référence containerId morte est ignorée).
function rebuildItemTree(store, node, markTemp)
  if not node or not node.defId then return nil end
  local itemId = node.id or generateId('temp_rs')
  store.items[itemId] = {
    id = itemId,
    defId = node.defId,
    qty = node.qty or 1,
    meta = node.meta or {},
    _isTemporary = markTemp or nil,
    _originalId = node.id,
  }
  if node.container then
    local newCid = generateId('c')
    store.items[itemId].containerId = newCid
    store.containers[newCid] = {
      id = newCid,
      defId = node.container.defId,
      label = node.container.label,
      slots = node.container.slots,
      maxWeight = node.container.maxWeight,
      items = {},
    }
    -- Le propriétaire d'un conteneur imbriqué est l'ITEM qui le porte (comme createItem),
    -- pas l'identifiant du store -> sinon getStandbyPath ne peut plus remonter au parent.
    store.containerOwners[newCid] = itemId
    for slot, childNode in pairs(node.container.items or {}) do
      local childId = rebuildItemTree(store, childNode, markTemp)
      if childId then
        local n = tonumber(slot)
        store.containers[newCid].items[n] = childId
        setItemLocation(store, childId, { type = 'container', containerId = newCid, slot = n })
      end
    end
  end
  return itemId
end
