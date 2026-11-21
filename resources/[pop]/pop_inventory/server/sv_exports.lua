exports('GiveItem', function(target, defId, qty, meta)
  local identifier = getIdentifier(target)
  if not identifier then
    return false, 'identifiant introuvable'
  end
  defId = normalizeSection(defId)
  local store = ensureStore(identifier)
  local def = getItemDef(defId)
  if not def then
    return false, 'item inconnu'
  end

  local function cleanupOrphan(store, itemId)
    local item = store.items[itemId]
    if item and item.containerId then
      store.containers[item.containerId] = nil
      store.containerOwners[item.containerId] = nil
    end
    store.items[itemId] = nil
  end

  -- Résultat calculé ici, puis synchro UNIQUE en bas (markDirty + sendState).
  -- (Avant : chaque branche faisait return -> sendState jamais appelé pour les items
  --  normaux, l'item n'apparaissait pas côté client. Corrigé.)
  local ok, err
  if def.equipSlot and def.container then
    if not store.equipment[def.equipSlot] then
      local itemId = createItem(store, defId, 1, meta)
      if itemId then
        local equipped = equipItem(store, itemId)
        if equipped then
          ok = true
        else
          cleanupOrphan(store, itemId)
          ok, err = autoInsertItem(store, defId, 1, meta)
        end
      else
        ok, err = autoInsertItem(store, defId, 1, meta)
      end
    else
      ok, err = autoInsertItem(store, defId, 1, meta)
    end
  elseif def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, defId, 1, meta)
    if not itemId then return false, 'erreur creation' end
    local equipped = equipItem(store, itemId)
    if not equipped then
      cleanupOrphan(store, itemId)
      return false, err or 'impossible d\'equiper'
    end
    ok = true
  else
    ok, err = autoInsertItem(store, defId, qty or 1, meta)
  end

  if not ok then
    return false, err
  end

  markDirty(identifier)
  sendState(target)
  TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
  return true
end)

exports('GiveAndEquip', function(target, defId, qty, meta)
  local identifier = getIdentifier(target)
  if not identifier then return false, 'identifiant introuvable' end
  
  defId = normalizeSection(defId)
  local store = ensureStore(identifier)
  local def = getItemDef(defId)
  if not def then return false, 'item inconnu' end

  local itemId = createItem(store, defId, 1, meta)
  if not itemId then return false, 'erreur création' end

  if def.equipSlot then
      -- If slot occupied, try to unequip first (moves old item to inventory)
      if store.equipment[def.equipSlot] then
          unequipItem(store, def.equipSlot)
      end
      
      -- Try to equip new item
      local equipped = equipItem(store, itemId)
      
      -- If equip failed (e.g. unequip failed due to full inventory, slot still occupied),
      -- put new item in inventory as fallback
      if not equipped then
          local inserted, err = autoInsertExistingItem(store, itemId)
          if not inserted then
             -- Last resort: drop to ground or force inventory via specialized logic?
             -- For now, return false but item exists (maybe floating).
             -- Actually autoInsertExistingItem handles most cases. 
             -- If it fails, we might lose the item reference unless we handle it.
             -- But createItem added it to store.items.
             return false, err or 'Inventaire plein'
          end
      end
  else
      -- Not equipable, just insert
      local inserted, err = autoInsertExistingItem(store, itemId)
      if not inserted then return false, err or 'Inventaire plein' end
  end

  markDirty(identifier)
  sendState(target)
  TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
  return true, store.items[itemId] and store.items[itemId].containerId
end)

exports('ClearPlayerStore', function(target)
    local identifier = getIdentifier(target)
    if not identifier then return false end
    
    local store = ensureStore(identifier)
    store.items = {}
    store.equipment = {}
    store.containers = {}
    store.itemLocations = {}
    store.containerOwners = {}
    store.activeContainerId = nil
    
    markDirty(identifier)
    sendState(target)
    TriggerClientEvent('pop_inventory:client:applyEquipment', target, {})
    return true
end)

exports('addItemToContainer', function(source, containerId, defId, qty, meta)
  local identifier = getIdentifier(source)
  if not identifier then return false, 'Joueur introuvable' end
  
  local store = ensureStore(identifier)
  local container = store.containers[containerId]
  if not container then return false, 'Container introuvable' end
  
  local slot = findEmptySlot(container)
  if not slot then return false, 'Container plein' end
  
  local itemId = createItem(store, defId, qty, meta)
  if not itemId then return false, 'Erreur creation item' end
  
  if placeItemInContainer(store, containerId, slot, itemId) then
    markDirty(identifier)
    local state = buildState(source, store)
    StateSeq[source] = (StateSeq[source] or 0) + 1
    state._seq = StateSeq[source]
    TriggerClientEvent('pop_inventory:client:state', source, state)
    return true
  end
  return false, 'Erreur lors du placement de l\'item'
end)

AddEventHandler('playerDropped', function()
  local identifier = getIdentifier(source)
  PlayerCoords[source] = nil
  StateSeq[source] = nil
  PlayerGroundFocus[source] = nil
  if identifier and Stores[identifier] then
    saveStore(identifier, Stores[identifier])
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  -- Sauvegarde immédiate de tous les inventaires (la boucle de sauvegarde
  -- s'arrête avec la ressource, un simple markDirty serait perdu).
  for identifier, store in pairs(Stores) do
    if store._loaded then store._dirty = true end
    pcall(saveStore, identifier, store, true)
  end
  saveGround(true)
end)

CreateThread(function()
  local interval = Config.Inventory.AutoSaveIntervalMs or 120000
  while true do
    Wait(interval)
    -- Les inventaires joueurs sont sauvegardés par le thread de sv_stores.lua,
    -- seulement s'ils ont changé (avant : tous marqués « modifiés » ici = écritures inutiles).
    saveRemoteContainers()
  end
end)

CreateThread(function()
  local interval = (Config.Persistence and Config.Persistence.GroundSaveIntervalMs)
    or (Config.Inventory.AutoSaveIntervalMs or 120000)
  while true do
    Wait(interval)
    saveGround()
  end
end)

-- (thread de broadcast remplacé par syncGroundDropEntities via UtilityNet)

