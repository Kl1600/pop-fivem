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

function saveStore(identifier, store, noYield)
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

  -- Petite pause avant l'encodage (sauf à l'arrêt de la ressource, où Wait est impossible)
  if not noYield then Wait(0) end
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

function getContainerWeight(store, containerId, _visited) -- luacheck: ignore 214
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

function cloneItem(store, sourceItem) -- luacheck: ignore 131
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
    return nil, L('item_unknown')
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
  for _, slot in ipairs(Config.InventorySettings.ContainerOrder or {}) do
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
