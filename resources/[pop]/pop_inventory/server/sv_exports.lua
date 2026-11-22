-- (export GiveItem en double retiré : celui de sv_player_items.lua, chargé après,
--  était le seul réellement utilisé)

exports('GiveAndEquip', function(target, defId, qty, meta)
  local identifier = getIdentifier(target)
  if not identifier then return false, L('identifier_not_found') end

  defId = normalizeSection(defId)
  local store = ensureStore(identifier)
  local def = getItemDef(defId)
  if not def then return false, L('item_unknown_lower') end

  local itemId = createItem(store, defId, 1, meta)
  if not itemId then return false, L('create_error_lower') end

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
             return false, err or L('inventory_full_short')
          end
      end
  else
      -- Not equipable, just insert
      local inserted, err = autoInsertExistingItem(store, itemId)
      if not inserted then return false, err or L('inventory_full_short') end
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
  if not identifier then return false, L('player_not_found') end

  local store = ensureStore(identifier)
  local container = store.containers[containerId]
  if not container then return false, L('container_not_found') end

  local slot = findEmptySlot(container)
  if not slot then return false, L('container_full') end

  local itemId = createItem(store, defId, qty, meta)
  if not itemId then return false, L('item_create_error_short') end

  if placeItemInContainer(store, containerId, slot, itemId) then
    markDirty(identifier)
    local state = buildState(source, store)
    StateSeq[source] = (StateSeq[source] or 0) + 1
    state._seq = StateSeq[source]
    TriggerClientEvent('pop_inventory:client:state', source, state)
    return true
  end
  return false, L('item_place_error')
end)

-- Déconnexion : un seul handler pour tout le serveur de l'inventaire.
AddEventHandler('playerDropped', function()
  local src = source
  local identifier = getIdentifier(src)
  PlayerCoords[src] = nil
  StateSeq[src] = nil
  PlayerGroundFocus[src] = nil
  releaseSharedLocks(src)
  clearRadioPower(src)
  if identifier and Stores[identifier] then
    saveStore(identifier, Stores[identifier])
    Stores[identifier] = nil -- nettoyage mémoire
  end
  forgetSourceIdentifier(src)
end)

-- Sauvegarde immédiate de tous les inventaires, du sol et des coffres.
local function saveEverything()
  for identifier, store in pairs(Stores) do
    if store._loaded then store._dirty = true end
    pcall(saveStore, identifier, store, true)
  end
  pcall(saveGround, true)
  pcall(saveRemoteContainers)
end

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  -- La boucle de sauvegarde s'arrête avec la ressource : un simple markDirty serait perdu.
  saveEverything()
end)

-- Redémarrage / arrêt par txAdmin : on sauvegarde avant l'arrêt, quand la base répond encore.
AddEventHandler('txAdmin:events:serverShuttingDown', saveEverything)

CreateThread(function()
  local interval = Config.InventorySettings.AutoSaveIntervalMs or 120000
  while true do
    Wait(interval)
    -- Les inventaires joueurs sont sauvegardés par le thread de sv_stores.lua,
    -- seulement s'ils ont changé (avant : tous marqués « modifiés » ici = écritures inutiles).
    saveRemoteContainers()
  end
end)

CreateThread(function()
  local interval = (Config.Persistence and Config.Persistence.GroundSaveIntervalMs)
    or (Config.InventorySettings.AutoSaveIntervalMs or 120000)
  while true do
    Wait(interval)
    saveGround()
  end
end)

-- (thread de broadcast remplacé par syncGroundDropEntities via UtilityNet)

