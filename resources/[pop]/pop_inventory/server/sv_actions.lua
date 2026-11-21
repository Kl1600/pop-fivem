local function finalizeInventoryAction(src, store, identifier, action)
  ensureActiveContainer(store)
  syncRemoteContainerChanges(store)
  syncVehicleContainerChanges(store)
  syncStaticChestChanges(store)
  markDirty(identifier)
  sendState(src, action and action.coords)
  TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
end

-- Casiers (Config.LockerRooms) : ouvrir le casier d'un collègue exige le bon code,
-- demandé en direct à pop_management (jamais stocké dans pop_inventory). Ouvrir SON
-- PROPRE casier (meta.isOwnLocker, posé par sv_lockers.lua à l'ouverture de la salle)
-- ne demande rien. Vérification 100% côté serveur : le client ne peut pas mentir sur
-- la propriété du casier.
local function handleOpenCasier(src, store, identifier, action, ownerItem)
  local containerId = action.containerId
  local lockerNumber = ownerItem.meta and ownerItem.meta.lockerNumber
  local job = ownerItem.meta and ownerItem.meta.job

  local function grantOpen()
    local isStandbySub = false
    local standbyCId = StandbyContainers[src]
    if standbyCId and isContainerInStore(store, standbyCId, containerId) then
      isStandbySub = true
    end

    if isStandbySub then
      StandbyContainers[src] = containerId
    elseif store.containers[containerId] then
      store.activeContainerId = containerId
      store.activeContainerIsGround = false
    end
    finalizeInventoryAction(src, store, identifier, action)
  end

  if ownerItem.meta and ownerItem.meta.isOwnLocker then
    grantOpen()
    return
  end

  if GetResourceState('pop_management') ~= 'started' or not job or not lockerNumber then
    notify(src, 'Casier indisponible.')
    finalizeInventoryAction(src, store, identifier, action)
    return
  end

  local code = action.lockerCode
  if not code or code == '' then
    TriggerClientEvent('pop_inventory:client:requestLockerCode', src, containerId)
    return
  end

  exports['pop_management']:checkLockerCode(job, lockerNumber, code, function(ok)
    if ok then
      grantOpen()
    else
      notify(src, 'Code incorrect.')
      TriggerClientEvent('pop_inventory:client:requestLockerCode', src, containerId)
    end
  end)
end

RegisterNetEvent('pop_inventory:server:action', function(action)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end
  local store = ensureStore(identifier)
  if not action or type(action) ~= 'table' then
    return
  end
  updatePlayerCoords(src, action.coords)

  local actionType = action.type
  debugPrint('action', actionType, json.encode(action))

  if actionType == 'move' then
    local ok, err = moveItemCrossStore(src, action.fromContainerId, action.fromSlot, action.toContainerId, action.toSlot)
    if not ok then
      notify(src, err or _U('action_impossible'))
    end
  elseif actionType == 'equip' then
    local container = store.containers[action.containerId]
    if container and container.items[action.slot] then
      local itemId = container.items[action.slot]
      local ok, err = equipItem(store, itemId)
      if not ok then
        notify(src, err or _U('action_impossible'))
      end
    end
  elseif actionType == 'unequip' then
    local ok, err = unequipItem(store, action.slot)
    if not ok then
      notify(src, err or _U('action_impossible'))
    end
  elseif actionType == 'drop' then
    local fromType = action.fromType or 'container'
    local origin = { type = fromType, slot = action.slot, containerId = action.containerId }
    local ok, err = dropToGround(src, store, origin, action.qty, action.coords)
    if not ok then
      notify(src, err or _U('action_impossible'))
    end
  elseif actionType == 'pickup' then
    local ok, err = pickupFromGround(src, store, action.slot, action.coords)
    if not ok then
      notify(src, err or _U('action_impossible'))
    end
  elseif actionType == 'pickupToSlot' then
    local ok, err = pickupFromGroundToSlot(src, store, action.slot, action.toContainerId, action.toSlot, action.coords)
    if not ok then
      notify(src, err or 'Action impossible')
    end
  elseif actionType == 'unequipToSlot' then
    local ok, err = unequipToSlot(store, action.slot, action.toContainerId, action.toSlot)
    if not ok then
      notify(src, err or 'Action impossible')
    end
  elseif actionType == 'open' then
    local containerId = action.containerId
    local actualStore, actualCId = resolveStoreAndContainerId(src, containerId)

    local ownerItemId = actualStore.containerOwners[actualCId]
    local ownerItem = ownerItemId and actualStore.items[ownerItemId]
    if ownerItem and ownerItem.defId == 'casier' then
      handleOpenCasier(src, store, identifier, action, ownerItem)
      return
    end

    -- Check if it belongs to a standby container!
    local isStandbySub = false
    local standbyCId = StandbyContainers[src]
    if standbyCId and isContainerInStore(store, standbyCId, containerId) then
      isStandbySub = true
    end
    
    if isStandbySub then
      StandbyContainers[src] = containerId
    else
      if actualStore.containers[actualCId] then
        store.activeContainerId = containerId
        store.activeContainerIsGround = false
      else
        -- Boîte (ou pile) posée au sol : on la cherche dans n'importe quelle pile
        -- proche, pas seulement la plus proche (vue "À proximité" agrégée).
        local pile = findNearbyPileForContainer(src, action.coords, containerId)
        if pile then
          store.activeContainerId = containerId
          store.activeContainerIsGround = true
        end
      end
    end
  elseif actionType == 'close' then
    local containerId = action.containerId
    if store.activeContainerId == containerId then
      store.activeContainerId = nil
      ensureActiveContainer(store)
    end
    
    -- If it's a standby container, find its parent and switch StandbyContainers[src] back
    local standbyCId = StandbyContainers[src]
    if standbyCId and standbyCId == containerId then
      local parentContainerId = nil
      local ownerItemId = store.containerOwners[containerId]
      if ownerItemId then
        local loc = store.itemLocations[ownerItemId]
        if loc and loc.type == 'container' then
          parentContainerId = loc.containerId
        end
      end
      if parentContainerId then
        StandbyContainers[src] = parentContainerId
      end
    end
  elseif actionType == 'use' then
    local fromType = action.fromType or 'container'
    local itemId = nil
    local containerStore = fromType == 'ground' and GroundStore or store
    -- Pour le sol, action.containerId/slot sont des indices AFFICHÉS (vue agrégée) :
    -- on résout la vraie pile + slot sous-jacents.
    local useContainerId = action.containerId
    local useSlot = action.slot

    if fromType == 'equipment' then
      itemId = store.equipment[action.slot]
    elseif fromType == 'ground' then
      local pile, realSlot, gItemId = resolveGroundDisplaySlot(src, action.slot, action.coords)
      if pile then
        useContainerId = pile.containerId
        useSlot = realSlot
        itemId = gItemId
      end
    else
      local container = containerStore.containers[action.containerId]
      if container then
        itemId = container.items[action.slot]
      end
    end

    if itemId then
      local item = containerStore.items[itemId]
      local def = item and getItemDef(item.defId) or nil
      
      if def and def.usable then
        local consumeItem = true

        -- Trigger Custom Logic
        if type(def.onUse) == 'function' then
          if def.onUse(src, item, def) == false then consumeItem = false end
        end

        if def.export then
          local splitT = {}
          for str in string.gmatch(def.export, "([^:]+)") do table.insert(splitT, str) end
          if #splitT == 2 then
            local res, exp = splitT[1], splitT[2]
            if GetResourceState(res) == 'started' then
              local success, result = pcall(function()
                return exports[res][exp](exports[res], src, item, def)
              end)
              if success and result == false then
                consumeItem = false
              elseif not success then
                print("^1[pop_inventory] Error calling export " .. def.export .. ": " .. tostring(result) .. "^7")
              end
            end
          end
        end

        if def.serverEvent then
          TriggerEvent(def.serverEvent, src, item, def)
        end

        if def.clientEvent then
          TriggerClientEvent(def.clientEvent, src, item, def)
        end

        -- Consume the item if allowed
        if consumeItem then
          if item.qty > 1 then
            item.qty = item.qty - 1
          else
            if fromType == 'equipment' then
              store.equipment[action.slot] = nil
              removeItemLocation(store, itemId)
              store.items[itemId] = nil
              TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
            else
              removeItemFromContainer(containerStore, useContainerId, useSlot)
              containerStore.items[itemId] = nil
              if item.containerId then
                containerStore.containers[item.containerId] = nil
                containerStore.containerOwners[item.containerId] = nil
              end
            end
            if containerStore == GroundStore then
              markGroundDirty()
            end
          end
        end
      end
    end
  elseif actionType == 'pickupEquip' then
    local ok, err = pickupEquipFromGround(src, store, action.slot, action.equipSlot, action.coords)
    if not ok then
      notify(src, err or 'Action impossible')
    end
  elseif actionType == 'split' then
    local ok, err = splitStack(store, action.containerId, action.slot, math.floor(tonumber(action.qty) or 0))
    if not ok then
      notify(src, err or 'Action impossible')
    end
  elseif actionType == 'rename' then
    local itemId = nil
    if action.fromType == 'equipment' then
      itemId = store.equipment[action.slot]
    else
      local container = store.containers[action.containerId]
      if container then
        itemId = container.items[tonumber(action.slot)]
      end
    end

    if itemId and store.items[itemId] then
      local item = store.items[itemId]
      item.meta = item.meta or {}
      item.meta.customLabel = action.label
      notify(src, 'Item renommé en : ' .. action.label)
    else
      notify(src, 'Item introuvable')
    end
  elseif actionType == 'weapon_attach' or actionType == 'weapon_detach' then
    local weaponItem = nil
    local weaponItemId = nil
    if action.weaponLocation == 'equipment' then
      weaponItemId = store.equipment[action.equipSlot]
    else
      local wContainer = store.containers[action.weaponContainerId]
      if wContainer then
        weaponItemId = wContainer.items[tonumber(action.weaponSlot)]
      end
    end
    weaponItem = weaponItemId and store.items[weaponItemId] or nil

    local weaponDef = weaponItem and getItemDef(weaponItem.defId) or nil
    local mapping = weaponDef and weaponDef.weaponHash and Config.WeaponAttachments
                       and Config.WeaponAttachments[weaponDef.weaponHash] or nil
    local slotDef = mapping and mapping[action.attachmentSlot] or nil

    -- Le slot 'magazine' accepte n'importe quel chargeur (tag 'magazine'), pas seulement
    -- le chargeur par defaut de l'arme. Le client envoie alors action.attachDefId.
    local function isMagazineDef(defId)
      local d = defId and getItemDef(defId)
      if not d then return false end
      for _, t in ipairs(d.tags or {}) do if t == 'magazine' then return true end end
      return false
    end

    -- Trouve une instance (itemId) d'un defId rangee dans un conteneur du joueur,
    -- hors du puits cible. Retourne itemId, containerId, slot.
    local function findLooseInstance(defId, excludeContainerId)
      for id, it in pairs(store.items) do
        if it.defId == defId and not it._isTemporary then
          local loc = store.itemLocations[id]
          if loc and loc.type == 'container' and loc.containerId ~= excludeContainerId then
            return id, loc.containerId, loc.slot
          end
        end
      end
      return nil
    end

    -- ===== Slot "Chargeur" d'une arme a puits (pistol/smg/carabine) =====
    -- On insere/retire le chargeur dans le sous-conteneur (puits) de l'arme. C'est
    -- ce puits que lit tab_chargeurs pour alimenter les munitions -> l'arme tire.
    -- Les armes SANS puits gardent le comportement composant (chargeur etendu visuel).
    local isMagWellWeapon = weaponItem and weaponItem.containerId ~= nil

    if action.attachmentSlot == 'magazine' and isMagWellWeapon then
      local wellId = weaponItem.containerId
      local well = store.containers[wellId]
      if not well then
        notify(src, 'Puits de chargeur indisponible')
      elseif actionType == 'weapon_attach' then
        if (weaponItem.qty or 1) > 1 then
          notify(src, 'Separez l\'arme avant d\'y inserer un chargeur')
        elseif findEmptySlot(well) == nil then
          notify(src, 'Un chargeur est deja insere')
        else
          local magDef = action.attachDefId
          local def = magDef and getItemDef(magDef)
          if not magDef or not isMagazineDef(magDef) or not def then
            notify(src, 'Chargeur invalide')
          elseif not isAllowedInContainer(well.defId, magDef, def) then
            notify(src, 'Ce chargeur ne correspond pas a cette arme')
          else
            local magId, fromCId, fromSlot = findLooseInstance(magDef, wellId)
            if not magId then
              notify(src, 'Chargeur absent de l\'inventaire')
            else
              local destSlot = findEmptySlot(well)
              local fromC = store.containers[fromCId]
              if fromC then fromC.items[fromSlot] = nil end
              removeItemLocation(store, magId)
              placeItemInContainer(store, wellId, destSlot, magId)
            end
          end
        end
      else -- weapon_detach
        local magId, magSlot
        for slot, id in pairs(well.items) do magId, magSlot = id, slot; break end
        if not magId then
          notify(src, 'Aucun chargeur a retirer')
        else
          well.items[magSlot] = nil
          removeItemLocation(store, magId)
          local ok, err = autoInsertExistingItem(store, magId)
          if not ok then
            placeItemInContainer(store, wellId, magSlot, magId)
            notify(src, err or 'Pas de place pour le chargeur')
          end
        end
      end
    elseif not slotDef then
      notify(src, 'Accessoire incompatible')
    elseif actionType == 'weapon_attach' then
      if (weaponItem.qty or 1) > 1 then
        notify(src, 'Séparez l\'arme avant d\'y attacher un accessoire')
      else
        weaponItem.meta = weaponItem.meta or {}
        weaponItem.meta.attachments = weaponItem.meta.attachments or {}
        if weaponItem.meta.attachments[action.attachmentSlot] then
          notify(src, 'Un accessoire est déjà attaché à ce slot')
        else
          -- Quel item consommer : pour le slot chargeur, le chargeur choisi par le joueur ;
          -- sinon l'item exact defini par la config de l'arme.
          local consumeDef = slotDef.item
          if action.attachmentSlot == 'magazine' and action.attachDefId and isMagazineDef(action.attachDefId) then
            consumeDef = action.attachDefId
          end
          local ok = exports[GetCurrentResourceName()]:removeItem(src, consumeDef, 1)
          if not ok then
            notify(src, 'Accessoire absent de l\'inventaire')
          else
            weaponItem.meta.attachments[action.attachmentSlot] = consumeDef
          end
        end
      end
    else
      weaponItem.meta = weaponItem.meta or {}
      weaponItem.meta.attachments = weaponItem.meta.attachments or {}
      local currentDefId = weaponItem.meta.attachments[action.attachmentSlot]
      if not currentDefId then
        notify(src, 'Aucun accessoire à retirer')
      else
        local ok, err = autoInsertItem(store, currentDefId, 1, nil)
        if not ok then
          notify(src, err or 'Pas de place pour l\'accessoire')
        else
          weaponItem.meta.attachments[action.attachmentSlot] = nil
        end
      end
    end
  end

  finalizeInventoryAction(src, store, identifier, action)
end)

RegisterCommand('pop_inventory-give', function(source, args)
  local target = tonumber(args[1])
  local defIndex = 2
  if not target then
    target = source
    defIndex = 1
  end
  local defId = normalizeSection(args[defIndex] or '')
  local qty = tonumber(args[defIndex + 1] or 1) or 1
  if not defId or defId == '' then
    print('[TAB_INVENTORY] pop_inventory-give: defId vide')
    return
  end
  local identifier = getIdentifier(target)
  if not identifier then
    print('[TAB_INVENTORY] pop_inventory-give: identifier introuvable pour source', target)
    return
  end
  local store = ensureStore(identifier)
  local def = getItemDef(defId)
  if not def then
    print('[TAB_INVENTORY] pop_inventory-give: Item inconnu:', defId)
    notify(target, 'Item inconnu: ' .. defId)
    return
  end

  print('[TAB_INVENTORY] pop_inventory-give: Tentative de donner', qty, 'x', defId, 'à', target)

  local function cleanupOrphan(store, itemId)
    local item = store.items[itemId]
    if item and item.containerId then
      store.containers[item.containerId] = nil
      store.containerOwners[item.containerId] = nil
    end
    store.items[itemId] = nil
  end

  if def.equipSlot and def.container then
    -- Container-item (panta, hoddie, etc.): try to equip if possible
    local canEquip = not store.equipment[def.equipSlot]
    
    if canEquip then
      local itemId = createItem(store, defId, 1)
      if itemId then
        local ok, err = equipItem(store, itemId)
        if ok then
          notify(target, 'Vous avez reçu et équipé ' .. itemQtyTag(1) .. ' ' .. (def.label or defId))
          if defId == 'cardboard_box' then
            TriggerClientEvent('pop_inventory:client:equipCardboardBox', target)
          elseif defId == 'safe' then
            TriggerClientEvent('pop_inventory:client:equipSafe', target)
          end
          markDirty(identifier)
          sendState(target)
          TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
          return
        else
          cleanupOrphan(store, itemId)
        end
      end
    end

    -- Fallback: try to put in inventory
    local ok, err = autoInsertItem(store, defId, 1)
    if ok then
      notify(target, 'Vous avez reçu ' .. itemQtyTag(1) .. ' ' .. (def.label or defId) .. ' (rangé)')
    else
      notify(target, err or 'Pas de place pour ranger cet item')
    end
  elseif def.equipSlot and not store.equipment[def.equipSlot] then
    local itemId = createItem(store, defId, 1)
    if not itemId then
      notify(target, 'Erreur lors de la création de l\'item')
      return
    end
    local ok, err = equipItem(store, itemId)
    if not ok then
      cleanupOrphan(store, itemId)
      notify(target, err or 'Impossible d\'équiper')
      return
    end
    notify(target, 'Vous avez reçu ' .. itemQtyTag(1) .. ' ' .. (def.label or defId))
  else
    local ok, err = autoInsertItem(store, defId, qty)
    if ok then
      notify(target, 'Vous avez reçu ' .. itemQtyTag(qty) .. ' ' .. (def.label or defId))
    else
      notify(target, err or 'Pas de place dans les containers')
    end
  end

  markDirty(identifier)
  sendState(target)
  TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
end, true)

RegisterCommand('pop_inventory-cleardrops', function(source)
  if source ~= 0 and not IsPlayerAceAllowed(source, 'pop_inventory.cleardrops') then
    notify(source, 'Permissions insuffisantes pour supprimer les drops.')
    return
  end
  clearAllGroundDrops()
  if source == 0 then
    print('[TAB_INVENTORY] Tous les drops ont été supprimés.')
  else
    notify(source, 'Tous les drops ont été supprimés.')
  end
end, true)

