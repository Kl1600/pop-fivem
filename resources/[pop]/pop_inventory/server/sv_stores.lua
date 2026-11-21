function ensureStore(identifier)
  if not identifier then
    return nil
  end

  if not Stores[identifier] then
    local store = loadStore(identifier)
    if not store then
      return nil
    end
    Stores[identifier] = store
  end
  return Stores[identifier]
end

function loadStore(identifier)
  local store = createStore()
  if not (Config.Persistence and Config.Persistence.UseDatabase) then
    store._loaded = true
    return store
  end

  if not MySQL then
    return nil
  end

  local tableName = safeTableName(Config.Persistence.InventoriesTable)
  if not tableName or tableName == '' then
    return nil
  end

  local row = mysqlSingle(string.format('SELECT data FROM `%s` WHERE identifier = ?', tableName), { identifier })
  
  if row == 'ERROR' then
    return nil -- Indique une erreur critique de DB
  end

  if row and row.data then
    local decoded = json.decode(row.data)
    if type(decoded) == 'table' then
      store.items = decoded.items or {}
      store.containers = decoded.containers or {}
      store.activeContainerId = decoded.activeContainerId
      -- Migrate: move equipment items to their correct slot key based on def.equipSlot
      local rawEquip = decoded.equipment or {}
      local migratedEquip = {}
      for slot, itemId in pairs(rawEquip) do
        local item = store.items[itemId]
        if item and not item._isTemporary then
          local def = getItemDef(item.defId)
          local correctSlot = def and def.equipSlot
          if correctSlot and correctSlot ~= slot and not migratedEquip[correctSlot] then
            migratedEquip[correctSlot] = itemId
          else
            migratedEquip[slot] = itemId
          end
        end
      end
      store.equipment = migratedEquip
      rebuildLocations(store)
    end
  end

  store._loaded = true
  return store
end

function saveStore(identifier, store)
  if not store or not store._loaded or not store._dirty then
    return
  end

  if not (Config.Persistence and Config.Persistence.UseDatabase) or not MySQL then
    store._dirty = false
    return
  end
  
  local cleanContainers = {}
  for k, v in pairs(store.containers) do
    if v.defId ~= '__remote_container__' and v.defId ~= '__vehicle_container__' and v.defId ~= '__remote_standby__' and v.defId ~= '__static_chest__' then
      cleanContainers[k] = v
    end
  end
  
  local cleanItems = {}
  for itemId, item in pairs(store.items or {}) do
    if not item._isTemporary then
      cleanItems[itemId] = item
    end
  end
  
  --[ Manière Forte: Yield before blocking encoding ]--
  Wait(0)
  local payload = json.encode({
    items = cleanItems,
    containers = cleanContainers,
    equipment = store.equipment,
    activeContainerId = store.activeContainerId,
  })

  local tableName = safeTableName(Config.Persistence.InventoriesTable)
  if not tableName or tableName == '' then
    store._dirty = false
    return
  end

  -- Use non-blocking update
  mysqlUpdate(string.format('INSERT INTO `%s` (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', tableName), {
    identifier,
    payload,
  }, function()
    store._dirty = false
  end)
end

-- Background save thread: Process dirty stores every 60 seconds with staggering to prevent DB spikes
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        local dirtyCount = 0
        for identifier, store in pairs(Stores) do
            if store._dirty then
                saveStore(identifier, store)
                dirtyCount = dirtyCount + 1
                Wait(500) -- Stagger: 0.5s between EACH player save to avoid I/O spikes
            end
        end
        if dirtyCount > 0 then
            debugPrint('Background Save:', dirtyCount, 'inventories persisted.')
        end
    end
end)

function markDirty(identifier)
  local store = Stores[identifier]
  if store then
    store._dirty = true
  end
end

function itemBaseWeight(def, qty)
  local unit = tonumber(def and def.weight) or 0
  return unit * (tonumber(qty) or 1)
end

function getContainerWeight(store, containerId, _visited)
  if _visited and _visited[containerId] then
    return 0
  end
  local container = store.containers[containerId]
  if not container then
    return 0
  end
  local visited = _visited or {}
  visited[containerId] = true
  local total = 0
  for _, itemId in pairs(container.items) do
    total = total + (store.items[itemId] and itemBaseWeight(getItemDef(store.items[itemId].defId), store.items[itemId].qty) or 0)
    if store.items[itemId] and store.items[itemId].containerId then
      total = total + getContainerWeight(store, store.items[itemId].containerId, visited)
    end
  end
  return total
end

function getItemWeight(store, itemId)
  local item = store.items[itemId]
  if not item then
    return 0
  end
  local def = getItemDef(item.defId)
  local weight = itemBaseWeight(def, item.qty)
  if item.containerId then
    weight = weight + getContainerWeight(store, item.containerId)
  end
  return weight
end

function isAllowedInContainer(containerDefId, itemDefId, itemDef)
  -- Paint items (tag 'peinture') can ONLY be stored inside 'pot_peinture' containers
  if itemDef and itemDef.tags then
    for _, tag in ipairs(itemDef.tags) do
      if tag == 'peinture' then
        if containerDefId ~= 'pot_peinture' then
          return false
        end
        break
      end
    end
  end

  local rules = Config.ContainerRestrictions and Config.ContainerRestrictions[containerDefId]
  if not rules then
    return true
  end

  if rules.allowItems and not listContains(rules.allowItems, itemDefId or '') then
    return false
  end

  if rules.allowTags then
    local tags = itemDef.tags or {}
    local ok = false
    for _, tag in ipairs(tags) do
      if listContains(rules.allowTags, tag) then
        ok = true
        break
      end
    end
    if not ok then
      return false
    end
  end

  if rules.denyItems and listContains(rules.denyItems, itemDefId or '') then
    return false
  end

  if rules.denyTags then
    for _, tag in ipairs(itemDef.tags or {}) do
      if listContains(rules.denyTags, tag) then
        return false
      end
    end
  end

  return true
end

function canAddWeight(store, containerId, additionalWeight)
  local container = store.containers[containerId]
  if not container then
    return false
  end
  local maxWeight = container.maxWeight or 0
  local currentWeight = getContainerWeight(store, containerId)
  return (currentWeight + additionalWeight) <= maxWeight + 0.0001
end

function canStackItems(itemA, itemB)
  if not itemA or not itemB then
    return false
  end
  if itemA.defId ~= itemB.defId then
    return false
  end
  local def = getItemDef(itemA.defId)
  if not def or (def.maxStack or 1) <= 1 then
    return false
  end
  return metaKey(itemA.meta) == metaKey(itemB.meta)
end

function cloneItem(store, sourceItem)
  if not sourceItem then
    return nil
  end
  local itemId = generateId('i')
  local item = {
    id = itemId,
    defId = sourceItem.defId,
    qty = sourceItem.qty or 1,
    meta = sourceItem.meta or {},
    containerId = nil,
  }
  
  if sourceItem.containerId then
    -- Si l'item source avait un conteneur, créer un nouveau conteneur
    local def = getItemDef(item.defId)
    if def and def.container then
      local containerId = generateId('c')
      store.containers[containerId] = {
        id = containerId,
        defId = item.defId,
        slots = def.container.slots or 0,
        maxWeight = def.container.maxWeight or 0,
        items = {},
      }
      store.containerOwners[containerId] = itemId
      item.containerId = containerId
    end
  end
  
  store.items[itemId] = item
  return itemId
end

function createItem(store, defId, qty, meta)
  local def = getItemDef(defId)
  if not def then
    return nil, 'Item inconnu'
  end
  local itemId = generateId('i')
  local item = {
    id = itemId,
    defId = defId,
    qty = qty or 1,
    meta = meta or {},
    containerId = nil,
  }

  if def.container then
    local containerId = generateId('c')
    store.containers[containerId] = {
      id = containerId,
      defId = defId,
      slots = def.container.slots or 0,
      maxWeight = def.container.maxWeight or 0,
      items = {},
    }
    store.containerOwners[containerId] = itemId
    item.containerId = containerId
  end

  store.items[itemId] = item
  return itemId
end

function removeItemFromContainer(store, containerId, slot)
  local container = store.containers[containerId]
  if not container then
    return nil
  end
  local itemId = container.items[slot]
  if itemId then
    container.items[slot] = nil
    removeItemLocation(store, itemId)
  end
  return itemId
end

function placeItemInContainer(store, containerId, slot, itemId)
  local container = store.containers[containerId]
  if not container then
    return false
  end
  container.items[slot] = itemId
  setItemLocation(store, itemId, { type = 'container', containerId = containerId, slot = slot })
  return true
end

local moveContainerTree

function moveItemTree(fromStore, toStore, itemId)
  local item = fromStore.items[itemId]
  if not item then
    return nil
  end
  fromStore.items[itemId] = nil
  removeItemLocation(fromStore, itemId)
  toStore.items[itemId] = item

  if item.containerId then
    moveContainerTree(fromStore, toStore, item.containerId)
  end

  return itemId
end

moveContainerTree = function(fromStore, toStore, containerId)
  if not containerId then
    return
  end
  local container = fromStore.containers[containerId]
  if not container then
    return
  end
  fromStore.containers[containerId] = nil
  toStore.containers[containerId] = container

  local ownerId = fromStore.containerOwners[containerId]
  if ownerId then
    fromStore.containerOwners[containerId] = nil
    toStore.containerOwners[containerId] = ownerId
  end

  for slot, childItemId in pairs(container.items) do
    moveItemTree(fromStore, toStore, childItemId)
    setItemLocation(toStore, childItemId, { type = 'container', containerId = containerId, slot = slot })
  end
end

function findEmptySlot(container)
  for i = 1, (container.slots or 0) do
    if not container.items[i] then
      return i
    end
  end
  return nil
end

function getOrderedContainers(store)
  local ordered = {}
  for _, slot in ipairs(Config.Inventory.ContainerOrder or {}) do
    local itemId = store.equipment[slot]
    local item = itemId and store.items[itemId]
    if item and item.containerId then
      table.insert(ordered, item.containerId)
    end
  end
  return ordered
end

function cleanupRemoteContainers(store)
  -- Nettoyer les conteneurs distants virtuels qui ne sont plus actifs
  for containerId, container in pairs(store.containers or {}) do
    if container.defId == '__remote_container__' and store.activeContainerId ~= containerId then
      store.containers[containerId] = nil
    end
  end
end

function ensureActiveContainer(store)
  cleanupRemoteContainers(store)
  local ordered = getOrderedContainers(store)
  if store.activeContainerIsGround and store.activeContainerId then
    return
  end
  if store.activeContainerId and store.containers[store.activeContainerId] then
    local cId = store.activeContainerId
    local c = store.containers[cId]
    if c.defId == '__remote_container__' or c.defId == '__standby_container__' or c.defId == '__static_chest__' or c.defId == '__vehicle_container__' then
      return
    end

    -- [FIX] Allow item-based containers (like the phone) to stay active even if not in ContainerOrder
    local def = getItemDef(c.defId)
    if def and listContains(def.tags or {}, 'container') then
      return
    end

    local found = false
    for _, id in ipairs(ordered) do
      if id == cId then found = true; break end
    end
    if found then
      return
    end
  end
  store.activeContainerId = ordered[1]
  store.activeContainerIsGround = false
end

function isContainerDescendant(store, movingItemId, targetContainerId)
  local movingItem = store.items[movingItemId]
  if not movingItem or not movingItem.containerId then
    return false
  end
  local current = targetContainerId
  while current do
    if current == movingItem.containerId then
      return true
    end
    local ownerItemId = store.containerOwners[current]
    if not ownerItemId then
      return false
    end
    local location = store.itemLocations[ownerItemId]
    if not location or location.type ~= 'container' then
      return false
    end
    current = location.containerId
  end
  return false
end

function isContainerInStore(store, rootContainerId, targetContainerId)
  local current = targetContainerId
  while current do
    if current == rootContainerId then
      return true
    end
    local ownerItemId = store.containerOwners[current]
    if not ownerItemId then
      return false
    end
    local location = store.itemLocations[ownerItemId]
    if not location or location.type ~= 'container' then
      return false
    end
    current = location.containerId
  end
  return false
end

function autoInsertItem(store, defId, qty, meta)
  local def = getItemDef(defId)
  if not def then
    return false, 'Item inconnu'
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
    for cId, container in pairs(store.containers) do
      if container.defId == 'pot_peinture' then
        table.insert(paintPots, container)
      end
    end

    if #paintPots == 0 then
      return false, 'Aucun pot de peinture'
    end

    -- Try to stack in existing paint pots first
    if def.maxStack and def.maxStack > 1 then
      for _, container in ipairs(paintPots) do
        for slot, itemId in pairs(container.items) do
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

    return false, 'Pots de peinture pleins'
  end

  -- Auto-equip if the item has an equipSlot and the slot is empty
  if def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, defId, 1, meta)
    if itemId then
      local ok, err = equipItem(store, itemId)
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
        for slot, itemId in pairs(container.items) do
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

  return false, 'Pas de place'
end

function insertIntoActiveContainer(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false, 'Item inconnu'
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, 'Item inconnu'
  end

  if listContains(def.tags or {}, 'weapon_long') and hasLongWeaponEquipped(store) then
    return false, 'Une arme longue est deja equipee'
  end

  local activeId = store.activeContainerId
  if not activeId or not store.containers[activeId] then
    ensureActiveContainer(store)
    activeId = store.activeContainerId
  end

  if not activeId or not store.containers[activeId] then
    return false, 'Pas de container actif'
  end

  local container = store.containers[activeId]
  if not isAllowedInContainer(container.defId, item.defId, def) then
    return false, 'Restriction container'
  end

  local slot = findEmptySlot(container)
  if not slot then
    return false, 'Pas de place'
  end

  local weight = getItemWeight(store, itemId)
  if not canAddWeight(store, activeId, weight) then
    return false, 'Poids max'
  end

  placeItemInContainer(store, activeId, slot, itemId)
  return true
end

function autoInsertExistingItem(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false, 'Item inconnu'
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, 'Item inconnu'
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
    return false, 'Une arme longue est deja equipee'
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

  return false, 'Pas de place'
end

function splitStack(store, containerId, slot, splitQty)
  local container = store.containers[containerId]
  if not container then
    return false, 'Container introuvable'
  end
  local itemId = container.items[slot]
  local item = itemId and store.items[itemId]
  if not item then
    return false, 'Slot vide'
  end
  local def = getItemDef(item.defId)
  if not def or (def.maxStack or 1) <= 1 then
    return false, 'Non stackable'
  end
  if splitQty <= 0 or splitQty >= item.qty then
    return false, 'Quantite invalide'
  end
  local emptySlot = findEmptySlot(container)
  if not emptySlot then
    return false, 'Pas de slot libre'
  end

  local newItemId = createItem(store, item.defId, splitQty, item.meta)
  if not newItemId then
    return false, 'Erreur creation'
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
    if not itemToMoveId then return false, 'Item non trouvé' end
    
    local item = fromStore.items[itemToMoveId]
    if not item then return false, 'Item invalide' end
    
    local targetContainer = toStore.containers[actualToCId]
    if not targetContainer then return false, 'Container destination invalide' end
    if targetContainer.items[toSlot] then return false, 'Slot occupé' end

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
    return false, 'Container invalide'
  end
  local itemId = fromContainer.items[fromSlot]
  if not itemId then
    return false, 'Slot vide'
  end
  local item = store.items[itemId]
  if not item then
    return false, 'Item invalide'
  end

  if item.containerId and isContainerDescendant(store, itemId, toContainerId) then
    return false, 'Boucle interdite'
  end

  local def = getItemDef(item.defId)
  if not isAllowedInContainer(toContainer.defId, item.defId, def) then
    return false, 'Restriction container'
  end

  local targetItemId = toContainer.items[toSlot]
  if targetItemId then
    local targetItem = store.items[targetItemId]
    if canStackItems(item, targetItem) then
      local maxStack = def.maxStack or 1
      local space = maxStack - targetItem.qty
      if space <= 0 then
        return false, 'Pile pleine'
      end
      local add = math.min(space, item.qty)
      local addWeight = itemBaseWeight(def, add)
      if not canAddWeight(store, toContainerId, addWeight) then
        return false, 'Poids max'
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
      return false, 'Restriction container'
    end

    local weightItem = getItemWeight(store, itemId)
    local weightTarget = getItemWeight(store, targetItemId)
    if not canAddWeight(store, toContainerId, weightItem - weightTarget) then
      return false, 'Poids max'
    end
    if not canAddWeight(store, fromContainerId, weightTarget - weightItem) then
      return false, 'Poids max'
    end

    fromContainer.items[fromSlot] = targetItemId
    toContainer.items[toSlot] = itemId
    setItemLocation(store, itemId, { type = 'container', containerId = toContainerId, slot = toSlot })
    setItemLocation(store, targetItemId, { type = 'container', containerId = fromContainerId, slot = fromSlot })
    return true
  end

  local moveWeight = getItemWeight(store, itemId)
  if not canAddWeight(store, toContainerId, moveWeight) then
    return false, 'Poids max'
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


