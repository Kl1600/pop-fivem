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

  local store = ensureStore(identifier)

  -- Cleanup: Retirer tout ancien conteneur véhicule mal fermé
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' then
       -- Remove temporary items linked to this container
       for slot, itemId in pairs(container.items or {}) do
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
  for cId, c in pairs(vStore.containers) do
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
  else
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
    label = 'Coffre ' .. plate,
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
    print('[TAB_INVENTORY] Impossible de trouver la def de l\'item:', itemDefId)
    return
  end
  
  local placed = false

  -- Auto-equip if the item has an equipSlot and the slot is empty
  if def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, itemDefId, 1)
    if itemId then
      local ok, err = equipItem(store, itemId)
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
          print('[TAB_INVENTORY] Inventaire plein pour:', itemDefId)
          notify(source, 'Inventaire plein !')
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
  
  for itemId, item in pairs(store.items) do
      if item.defId == itemDefId and not item._isTemporary then
          table.insert(itemsToRemove, item)
          foundQty = foundQty + (item.qty or 1)
      end
  end
  
  if foundQty < qty then
      print('[TAB_INVENTORY] Pas assez d items pour retirer:', itemDefId)
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

    local store = ensureStore(identifier)
    
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
        notify(src, 'Erreur: Objet introuvable ou invalide')
        return
    end

    -- Transfer
    local success, err = false, 'Transfert impossible'
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
            
            notify(src, 'Erreur: ' .. (err or 'Cible pleine'))
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
            
            notify(src, 'Erreur: ' .. (err or 'Transfert impossible'))
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

        notify(src, "Vous avez donné " .. itemQtyTag(item.qty) .. " " .. itemLabel)
        notify(targetId, "Vous avez reçu " .. itemQtyTag(item.qty) .. " " .. itemLabel)
    else
        notify(src, 'Erreur: ' .. (err or 'Transfert impossible'))
    end
end)

function GiveItem(source, itemDefId, qty, meta)
  local identifier = getIdentifier(source)
  if not identifier then return false, 'Joueur introuvable' end

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

exports('getItemCount', function(source, itemDefId)
  local identifier = getIdentifier(source)
  if not identifier then return 0 end

  local store = ensureStore(identifier)
  local count = 0
  
  for _, item in pairs(store.items) do
    if item.defId == itemDefId and not item._isTemporary then
      count = count + (item.qty or 1)
    end
  end
  
  return count
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

-- ===== CRAFT SYSTEM =====

function countItemInStore(store, defId)
  local count = 0
  for _, item in pairs(store.items) do
    if item.defId == defId and not item._isTemporary then
      count = count + (tonumber(item.qty) or 1)
    end
  end
  return count
end

function consumeItemInStore(store, defId, qty)
  local remaining = qty
  for _, item in pairs(store.items) do
    if remaining <= 0 then break end
    if item.defId == defId and not item._isTemporary then
      local itemQty = tonumber(item.qty) or 1
      local toRemove = math.min(remaining, itemQty)
      if toRemove >= itemQty then
        local loc = store.itemLocations[item.id]
        if loc and loc.type == 'container' then
          local c = store.containers[loc.containerId]
          if c then c.items[loc.slot] = nil end
        elseif loc and loc.type == 'equipment' then
          store.equipment[loc.slot] = nil
        end
        store.items[item.id] = nil
        store.itemLocations[item.id] = nil
      else
        item.qty = itemQty - toRemove
      end
      remaining = remaining - toRemove
    end
  end
end

RegisterNetEvent('pop_inventory:server:craft', function(recipeId)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  local recipe = nil
  for _, r in ipairs(Config.Recipes or {}) do
    if r.id == recipeId then recipe = r; break end
  end
  if not recipe then
    notify(src, 'Recette inconnue')
    return
  end

  -- Anti-triche : il faut être à un établi proposant cette recette (comme côté client)
  if type(Config.CraftZones) == 'table' and #Config.CraftZones > 0 then
    local ped = GetPlayerPed(src)
    local pc = ped ~= 0 and GetEntityCoords(ped)
    if pc and #(pc) > 1.0 then
      local okZone = false
      for _, zone in ipairs(Config.CraftZones) do
        if #(pc - zone.coords) <= (zone.radius or 2.0) + 3.0 then
          if not zone.recipes or #zone.recipes == 0 then okZone = true; break end
          for _, id in ipairs(zone.recipes) do
            if id == recipeId then okZone = true; break end
          end
          if okZone then break end
        end
      end
      if not okZone then return end
    end
  end

  local store = ensureStore(identifier)

  -- Vérification des ingrédients
  for _, ing in ipairs(recipe.ingredients) do
    if countItemInStore(store, ing.defId) < ing.qty then
      local def = getItemDef(ing.defId)
      notify(src, 'Ingrédients manquants : ' .. (def and def.label or ing.defId))
      return
    end
  end

  -- Consommation des ingrédients
  for _, ing in ipairs(recipe.ingredients) do
    consumeItemInStore(store, ing.defId, ing.qty)
  end

  -- Ajout du résultat
  local ok, err = autoInsertItem(store, recipe.output.defId, recipe.output.qty)
  if not ok then
    -- Remboursement en cas d'échec
    for _, ing in ipairs(recipe.ingredients) do
      autoInsertItem(store, ing.defId, ing.qty)
    end
    notify(src, err or 'Pas de place pour le résultat')
    return
  end

  markDirty(identifier)
  sendState(src)
  TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
  notify(src, 'Fabrication réussie !')
end)

exports('getInventory', function(source)
  local identifier = getIdentifier(source)
  if not identifier then return {} end

  local store = ensureStore(identifier)
  local inventory = {}
  local aggregated = {}
  
  for _, item in pairs(store.items) do
    if not item._isTemporary then
      local def = getItemDef(item.defId)
      if def then
        if not aggregated[item.defId] then
          aggregated[item.defId] = {
            name = item.defId,
            label = def.label or item.defId,
            count = 0,
            limit = -1,
            rare = false,
            canRemove = true
          }
        end
        aggregated[item.defId].count = aggregated[item.defId].count + (item.qty or 1)
      end
    end
  end
  
  for _, data in pairs(aggregated) do
    table.insert(inventory, data)
  end
  
  return inventory
end)

exports('getItemCount', function(source, itemName)
  local identifier = getIdentifier(source)
  if not identifier then return 0 end
  local store = ensureStore(identifier)
  local count = 0
  for _, item in pairs(store.items) do
    if item.defId == itemName and not item._isTemporary then
      count = count + (item.qty or 1)
    end
  end
  return count
end)

exports('UpdateItemMetadata', function(source, itemId, newMeta)
    local identifier = getIdentifier(source)
    if not identifier then return false end
    local store = ensureStore(identifier)
    
    local item = store.items[itemId]
    if item then
        item.meta = newMeta
        markDirty(identifier)
        sendState(source)
        return true
    end
    debugPrint('UpdateItemMetadata failing - item not found:', itemId)
    return false
end)

exports('GetItemMetadata', function(source, itemId)
    local identifier = getIdentifier(source)
    if not identifier then return {} end
    local store = ensureStore(identifier)

    local item = store.items[itemId]
    if item and item.meta then
        return item.meta
    end
    return {}
end)

-- Retire un item précis par son id (et pas "un item au hasard qui matche le defId"comme
-- removeItem/RemoveItem) : nécessaire pour des items non-stackables mais multi-instances
-- avec metadata distincte (ex: chèques de montants différents) où on doit retirer
-- exactement l'instance déposée/utilisée, pas une autre instance du même defId.
exports('removeItemById', function(source, itemId)
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local store = ensureStore(identifier)
    local item = store.items[itemId]
    if not item then return false end

    local loc = store.itemLocations[itemId]
    if loc and loc.type == 'container' then
        local parentContainer = store.containers[loc.containerId]
        if parentContainer then
            parentContainer.items[loc.slot] = nil
        end
    elseif loc and loc.type == 'equipment' then
        store.equipment[loc.slot] = nil
    end

    store.items[itemId] = nil
    store.itemLocations[itemId] = nil

    markDirty(identifier)
    sendState(source)
    return true
end)

exports('RemoveItem', function(source, itemName, qty)
    local identifier = getIdentifier(source)
    if not identifier then return false end
    local store = ensureStore(identifier)
    
    local removed = 0
    -- On parcourt les items pour trouver ceux à supprimer
    for itemId, item in pairs(store.items) do
        if item.defId == itemName and not item._isTemporary then
            local qtyInSlot = item.qty or 1
            local toRemove = math.min(qty - removed, qtyInSlot)
            
            item.qty = qtyInSlot - toRemove
            removed = removed + toRemove
            
            if item.qty <= 0 then
                -- Si l'item a un container (sac à dos, etc), on le supprime aussi
                if item.containerId then
                    store.containers[item.containerId] = nil
                end
                store.items[itemId] = nil
                removeItemLocation(store, itemId)
            end
            
            if removed >= qty then break end
        end
    end
    
    if removed > 0 then
        rebuildLocations(store)
        markDirty(identifier)
        sendState(source)
        return true
    end
    return false
end)

exports('getStore', function(source)
  local identifier = getIdentifier(source)
  if not identifier then return nil end
  return ensureStore(identifier)
end)

exports('GiveCardboardBoxWithItems', function(target, itemsList, doNotEquip)
  local identifier = getIdentifier(target)
  if not identifier then return false, 'Joueur introuvable' end

  local store = ensureStore(identifier)
  local boxItemId, err = createItem(store, 'cardboard_box', 1, {})
  if not boxItemId then
    return false, err or 'Erreur creation boite'
  end

  local containerId = store.items[boxItemId].containerId
  if containerId then
    local container = store.containers[containerId]
    for slot, itemData in ipairs(itemsList) do
      if slot <= container.slots then
        local subItemId, subErr = createItem(store, itemData.defId or itemData.itemDefId, itemData.qty or 1, itemData.meta or {})
        if subItemId then
          container.items[slot] = subItemId
          setItemLocation(store, subItemId, { type = 'container', containerId = containerId, slot = slot })
        end
      end
    end
  end

  local placed = false
  if doNotEquip then
    local def = getItemDef('cardboard_box')
    local ordered = getOrderedContainers(store)
    for _, containerId in ipairs(ordered) do
      local container = store.containers[containerId]
      if isAllowedInContainer(container.defId, 'cardboard_box', def) then
        local slot = findEmptySlot(container)
        if slot then
          local weight = getItemWeight(store, boxItemId)
          if canAddWeight(store, containerId, weight) then
            placeItemInContainer(store, containerId, slot, boxItemId)
            placed = true
            break
          end
        end
      end
    end
  end

  if not placed then
    local success, equipErr = equipItem(store, boxItemId)
    if not success then
      -- Force unequip if there's no space for currently equipped briefcase
      local oldItemId = store.equipment['briefcase']
      if oldItemId then
        store.equipment['briefcase'] = nil
        removeItemLocation(store, oldItemId)
        
        -- Place it on the ground
        local coords = getPlayerCoords(target)
        local pile = getOrCreateGroundPile(target, coords)
        if pile then
          local groundContainer = GroundStore.containers[pile.containerId]
          local gSlot = findEmptySlot(groundContainer)
          if gSlot then
            moveItemTree(store, GroundStore, oldItemId)
            placeItemInContainer(GroundStore, pile.containerId, gSlot, oldItemId)
            markGroundDirty()
          end
        end
      end

      -- Equip the new box forcibly
      store.equipment['briefcase'] = boxItemId
      setItemLocation(store, boxItemId, { type = 'equipment', slot = 'briefcase' })
      ensureActiveContainer(store)
    end
  end

  markDirty(identifier)
  sendState(target)

  if not placed then
    TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
    TriggerClientEvent('pop_inventory:client:equipCardboardBox', target)
  end

  return true
end)

exports('openContainer', function(source, containerId)
  local identifier = getIdentifier(source)
  if not identifier then return end
  local store = ensureStore(identifier)
  if store.containers[containerId] then
    store.activeContainerId = containerId
    store.activeContainerIsGround = false
    sendState(source)
  end
end)

if Config.Debug and Config.Debug.Commands then
    RegisterCommand('testshop', function(source)
        local src = source
        local items = {
            { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.png" },
            { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.png" },
            { id = "soda", price = 40, label = "Soda", icon = "img/soda.png" },
            { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.png" },
        }
        TriggerClientEvent('pop_inventory:client:openShop', src, 'LTD', items)
    end, true)
end


RegisterNetEvent('pop_inventory:server:shopBuy', function(data)
    local src = source
    local xPlayer = nil
    if ESX then xPlayer = ESX.GetPlayerFromId(src) end
    if QBCore then xPlayer = QBCore.Functions.GetPlayer(src) end
    
    if not xPlayer then 
        print("^1[Shop-Error]^7 Joueur non trouvé pour source:", src)
        return 
    end
    
    if type(data) ~= 'table' then return end
    local shopId = data.shopId
    local itemId = data.itemId
    -- SÉCURITÉ : quantité entière et positive (une quantité négative rendait le prix
    -- négatif -> removeAccountMoney d'un montant négatif = argent crédité).
    local qty = math.floor(tonumber(data.qty) or 1)
    if qty < 1 or qty > 1000 then return end
    local method = data.paymentMethod or 'cash'
    

    local shop = Config.Shops[shopId]
    if not shop then 
        print("^1[Shop-Error]^7 Boutique inconnue:", tostring(shopId))
        return 
    end
    
    local itemData = nil
    for _, item in ipairs(shop) do
        if item.id == itemId then
            itemData = item
            break
        end
    end
    
    if not itemData then 
        print("^1[Shop-Error]^7 Item non trouvé dans la boutique:", tostring(itemId))
        return 
    end
    
    local totalPrice = itemData.price * qty
    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(totalPrice * (tvaRate / 100))
    local finalPrice = totalPrice + taxAmount
    local success = false
    local pesosTaxAmt = 0
    
    if method == 'cash' then
        -- Cash is stored as an inventory item on this server (incl. inside the wallet container),
        -- not in the ESX cash account. Check & consume the inventory cash item directly.
        local identifier = getIdentifier(src)
        local store = identifier and Stores[identifier]
        if store and countItemInStore(store, 'cash') >= finalPrice then
            consumeItemInStore(store, 'cash', finalPrice)
            markDirty(identifier)
            success = true
        end
    elseif method == 'bank' then
        local is80s = (GlobalState.style80s == true)
        local cfg = Config.ShopCurrency
        if is80s and cfg and cfg.PesosShops and cfg.PesosShops[shopId] then
            print(string.format("^1[Shop-Error]^7 Paiement en banque bloque en mode 80s pour la boutique: %s", tostring(shopId)))
            TriggerClientEvent('pop_inventory:client:notify', src, "Le paiement en banque est indisponible dans cette boutique en mode 80s.")
            return
        end

        if ESX then
            if xPlayer.getAccount('bank').money >= finalPrice then
                xPlayer.removeAccountMoney('bank', finalPrice)
                success = true
            end
        elseif QBCore then
            if xPlayer.Functions.GetMoney('bank') >= finalPrice then
                xPlayer.Functions.RemoveMoney('bank', finalPrice)
                success = true
            end
        end
    elseif method == 'pesos' then
        -- Mode années 80 : paiement avec l'item 'pesos' (devise séparée du cash/dollar)
        local cfg = Config.ShopCurrency
        if cfg and cfg.PesosShops and cfg.PesosShops[shopId] then
            local rate = cfg.PesosPerDollar or 1
            local pesosTotal = totalPrice * rate
            local pesosTax = math.floor(pesosTotal * (tvaRate / 100))
            pesosTaxAmt = pesosTax
            local finalPesos = pesosTotal + pesosTax
            local identifier = getIdentifier(src)
            local store = identifier and Stores[identifier]
            if store and countItemInStore(store, 'pesos') >= finalPesos then
                consumeItemInStore(store, 'pesos', finalPesos)
                markDirty(identifier)
                success = true
            end
        else
            print("^1[Shop-Error]^7 Paiement Pesos non autorisé pour la boutique:", tostring(shopId))
        end
    end

    if success then
        GiveItem(src, itemId, qty)
        print("^2[Shop-Success]^7 Achat validé pour " .. xPlayer.getName() .. " (Incluant " .. taxAmount .. "$ TVA)")
        TriggerClientEvent('pop_inventory:client:notify', src, "Achat réussi : " .. itemQtyTag(qty) .. " " .. (itemData.label or itemId) .. " (Incl. " .. taxAmount .. "$ TVA)")

        -- Credit TVA to society_gouv for cash and bank methods
        if (method == 'cash' or method == 'bank') and taxAmount > 0 then
            local accountUsName = Config.GouvUSAccount or 'society_gouv'
            TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
                if gouvAccount then
                    gouvAccount.addMoney(taxAmount)
                else
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {taxAmount, accountUsName})
                end
            end)
        elseif method == 'pesos' and pesosTaxAmt > 0 then
            local accountMxName = Config.GouvMXAccount or 'society_gouv2'
            TriggerEvent('esx_addonaccount:getSharedAccount', accountMxName, function(gouvAccount)
                if gouvAccount then
                    gouvAccount.addMoney(pesosTaxAmt)
                else
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {pesosTaxAmt, accountMxName})
                end
            end)
        end
    else
        print("^1[Shop-Wait]^7 Fonds insuffisants pour " .. xPlayer.getName() .. " (" .. finalPrice .. "$ avec TVA)")
        TriggerClientEvent('pop_inventory:client:notify', src, "Vous n'avez pas assez d'argent (" .. finalPrice .. "$ avec TVA).")
    end
end)

-- Thread d'optimisation : Sauvegarde asynchrone échelonnée (Staggered Ultra)
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(Config.Inventory.AutoSaveIntervalMs or 60000)
    
    -- Delay between ground saves and player saves to avoid concurrent heavy disk IO
    saveRemoteContainers()
    Citizen.Wait(10000) -- Délai accru pour étaler la charge
    
    local dirtyIdentifiers = {}
    for identifier, store in pairs(Stores) do
      if store and store._dirty then
        table.insert(dirtyIdentifiers, identifier)
      end
    end
    
    -- On sauvegarde un joueur à la fois avec un délai de sécurité
    for _, identifier in ipairs(dirtyIdentifiers) do
      if Stores[identifier] and Stores[identifier]._dirty then
        saveStore(identifier, Stores[identifier])
        Citizen.Wait(1000) -- 1 seconde complète entre chaque joueur pour la stabilité CPU
      end
    end
    
    saveGround() -- S'assure que le sol est aussi sauvegardé régulièrement
  end
end)

-- Kit de depart : hotdog + bouteille d'eau dans les poches au premier spawn
AddEventHandler('esx:playerLoaded', function(playerId, _, isNew)
    if not isNew then return end
    GiveItem(playerId, 'hotdog', 1)
    GiveItem(playerId, 'bouteille', 1)
end)

-- Sauvegarde forcée lors de la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    local identifier = getIdentifier(src)
    if identifier and Stores[identifier] then
        saveStore(identifier, Stores[identifier])
        -- Nettoyage mémoire
        Stores[identifier] = nil
    end
end)

