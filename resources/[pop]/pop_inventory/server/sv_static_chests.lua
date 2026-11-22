-- Coffres fixes, fermeture et actions du standby (suite de sv_remote_containers.lua).

RegisterNetEvent('pop_inventory:server:openStaticChest', function(chestId, label, reqSlots, reqMaxWeight)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  if not chestId then return end
  chestId = tostring(chestId)

  -- Coffres bancaires pop_bank : l'id vient du client -> on revérifie le propriétaire
  -- (sinon n'importe qui pouvait ouvrir le compte d'un autre joueur ou d'une entreprise).
  if ESX and (chestId:sub(1, 14) == 'bank_personal_' or chestId:sub(1, 13) == 'bank_company_') then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if chestId:sub(1, 14) == 'bank_personal_' then
      if chestId:sub(15) ~= xPlayer.identifier then return end
    else
      local job = xPlayer.job
      if not job or chestId:sub(14) ~= job.name or job.grade_name ~= 'boss' then return end
    end
  end

  -- Job permission check
  local chestConfig = nil
  if Config.StaticChests then
    for _, c in ipairs(Config.StaticChests) do
      if c.id == chestId then chestConfig = c; break end
    end
  end

  -- Anti-triche : liste blanche + distance serveur. Avant, n'importe quel id envoyé par
  -- le client ouvrait un coffre, sans contrôle de distance (pillage à distance).
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return end
  local pc = GetEntityCoords(ped)
  local lockInfo = { coords = pc }

  if chestConfig then
    -- Coffre configuré : capacité serveur + joueur à proximité du point (rayon + 2 m)
    reqSlots, reqMaxWeight = nil, nil
    if not chestConfig.coords then return end
    local cc = vector3(chestConfig.coords.x, chestConfig.coords.y, chestConfig.coords.z)
    local maxDist = chestConfig.radius and (chestConfig.radius + 2.0) or 3.0
    if #(pc - cc) > maxDist then return end
    lockInfo.coords = cc
  elseif ESX and (chestId:sub(1, 14) == 'bank_personal_' or chestId:sub(1, 13) == 'bank_company_') then
    -- NOTE: coffres pop_bank hors config, gardés hors liste blanche car leur propriétaire
    -- est revérifié plus haut (pas de pillage possible). Capacité bornée comme avant.
    reqSlots = tonumber(reqSlots)
    reqMaxWeight = tonumber(reqMaxWeight)
    if reqSlots then reqSlots = math.max(1, math.min(math.floor(reqSlots), 200)) end
    if reqMaxWeight then reqMaxWeight = math.max(1.0, math.min(reqMaxWeight, 2000.0)) end
  else
    -- NOTE: coffres de véhicules spéciaux (armytanker / brickadeta, remote_container.lua),
    -- id = '<type>_<plaque>'. Gardés pour ne pas casser ces véhicules : il faut être près
    -- d'un véhicule portant cette plaque, et la capacité est fixée ici (valeurs du client).
    local VEHICLE_CHESTS = {
      tank = { slots = 40, maxWeight = 500.0 },
      brickadeta = { slots = 2, maxWeight = 500.0 },
    }
    local kind, plate = chestId:match('^(%a+)_(.+)$')
    local vcfg = kind and VEHICLE_CHESTS[kind]
    if not vcfg or not isPlayerNearPlate(src, plate, 8.0) then return end
    reqSlots, reqMaxWeight = vcfg.slots, vcfg.maxWeight
    lockInfo = { plate = plate }
  end

  if chestConfig and (chestConfig.jobs or chestConfig.job) then
    local allowedJobs = chestConfig.jobs or chestConfig.job
    if type(allowedJobs) == 'string' then
      allowedJobs = { allowedJobs }
    end

    local job = Bridge.GetJob(src)
    local playerJob = job and job.name

    local isAllowed = false
    if playerJob then
      for _, jobName in ipairs(allowedJobs) do
        if playerJob == jobName then
          isAllowed = true
          break
        end
      end
    end

    if not isAllowed then
      Inv.NotifyTyped(src, { type = 'error', message = L('chest_wrong_job') })
      return
    end
  end

  -- Un seul joueur à la fois dans ce coffre (sinon les synchros s'écrasent)
  if not acquireSharedLock(src, staticLockKey(chestId), lockInfo, { 'veh:', 'static:' }) then
    notify(src, L('chest_in_use'))
    return
  end

  local store = ensureStore(identifier)

  -- Cleanup: Retirer tout ancien conteneur statique/véhicule mal fermé
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' or container.defId == '__static_chest__' then
       -- Remove temporary items linked to this container
       for _, itemId in pairs(container.items or {}) do
          if store.items[itemId] and store.items[itemId]._isTemporary then
            removeStoreItemTree(store, itemId)
          end
       end
       store.containers[cId] = nil
    end
  end

  local sId = 'static_' .. chestId
  -- Load from database (persistent shared storage)
  if not Stores[sId] then
    Stores[sId] = loadStore(sId)
  end
  local sStore = Stores[sId]

  -- Determine main container ID for this chest
  local containerId = nil
  for cId, c in pairs(sStore.containers) do
     if c.defId == 'static_chest' then
        containerId = cId
        break
     end
  end
  if not containerId then
    for cId, c in pairs(sStore.containers) do -- luacheck: ignore 213 512
       containerId = cId
       break
    end
  end

  if not containerId then
    -- Look up config for this chest
    local chestConfig = nil -- luacheck: ignore 421
    if Config.StaticChests then
      for _, c in ipairs(Config.StaticChests) do
        if c.id == chestId then chestConfig = c; break end
      end
    end
    containerId = generateId('static_' .. chestId)
    sStore.containers[containerId] = {
      id = containerId,
      defId = 'static_chest',
      slots = reqSlots or (chestConfig and chestConfig.slots) or 40,
      maxWeight = reqMaxWeight or (chestConfig and chestConfig.maxWeight) or 500.0,
      items = {}
    }
  end

  local sContainer = sStore.containers[containerId]

  if reqSlots then sContainer.slots = reqSlots end
  if reqMaxWeight then sContainer.maxWeight = reqMaxWeight end

  -- Inject into player store as temporary container
  store.containers[containerId] = {
    id = containerId,
    defId = '__static_chest__', -- Special defId to recognize it
    label = label or 'Coffre',
    slots = sContainer.slots,
    maxWeight = sContainer.maxWeight,
    items = {},
    _staticChestId = chestId -- Store chest ID for sync on close
  }

  -- Inject items (create temporary copies pointing to the shared items)
  for slot, itemId in pairs(sContainer.items) do
    local sItem = sStore.items[itemId]
    if sItem then
      copyItemTree(sStore, store, itemId, function(item)
        item._isTemporary = true
        item._staticChestId = chestId
      end)
      store.containers[containerId].items[slot] = itemId
      setItemLocation(store, itemId, { type = 'container', containerId = containerId, slot = slot })
    end
  end

  StandbyContainers[src] = containerId
  saveStore(identifier, store) -- Save player state (temp items not saved to DB but needed for sync)

  local state = buildState(src, store)
  state.standbyContainerId = containerId
  state.standbyContainer = buildContainerView(store, containerId)

  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]

  TriggerClientEvent('pop_inventory:client:state', src, state)
end)

RegisterNetEvent('pop_inventory:server:closeStandbyContainer', function()
  local src = source
  local identifier = getIdentifier(src)
  if identifier then
    local store = ensureStore(identifier)
    -- Sync all shared containers back to their source before closing
    syncVehicleContainerChanges(store)
    syncRemoteStandbyChanges(store)
    syncStaticChestChanges(store)
    syncSearchChanges(store, src)
    SearchStandby[src] = nil
    -- Clean up containers from player store
    for cId, container in pairs(store.containers) do
      if container.defId == '__vehicle_container__' then
        -- Remove only temporary items (vehicle items moved to player inv stay)
        for _, itemId in pairs(container.items or {}) do
          if store.items[itemId] and store.items[itemId]._isTemporary then
            removeStoreItemTree(store, itemId)
          end
        end
        store.containers[cId] = nil
      elseif container.defId == '__remote_standby__' or container.defId == '__static_chest__' then
        -- Remove ALL items (synced to source above, nothing should stay in player store)
        for _, itemId in pairs(container.items or {}) do
          if store.items[itemId] then
            removeStoreItemTree(store, itemId)
          end
        end
        store.containers[cId] = nil
      end
    end
    markDirty(identifier)
  end
  StandbyContainers[src] = nil
  -- Coffres partagés refermés : on libère leurs verrous
  releaseSharedLocks(src)
end)

RegisterNetEvent('pop_inventory:server:standbyAction', function(action)
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

  if actionType == 'move' then
    local fromSlot = tonumber(action.fromSlot)
    local toSlot = tonumber(action.toSlot)
    if fromSlot and toSlot then
      -- Guard double-case arme longue (coffre distant). On exclut le slot source
      -- si on déplace à l'intérieur du même conteneur.
      local fromC = store.containers[action.fromContainerId]
      local movingItemId = fromC and fromC.items[fromSlot]
      local movingDefId = movingItemId and store.items[movingItemId] and store.items[movingItemId].defId
      local excludeSlot = (action.fromContainerId == action.toContainerId) and fromSlot or nil
      local placeErr = Inv.standbyPlacementError(store, action.toContainerId, toSlot, movingDefId, excludeSlot)
      if placeErr then
        notify(src, placeErr)
      else
        local ok, err = moveItemBetweenContainers(store, action.fromContainerId, fromSlot, action.toContainerId, toSlot)
        if not ok then
          notify(src, err or L('action_impossible'))
        end
      end
    end
  elseif actionType == 'equip' then
    local slot = tonumber(action.fromSlot)
    if slot then
      local container = store.containers[action.fromContainerId]
      if container and container.items[slot] then
        local itemId = container.items[slot]
        local ok, err = equipItem(store, itemId)
        if not ok then
          notify(src, err or L('action_impossible'))
        else
          TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
        end
      end
    end
  elseif actionType == 'unequipToSlot' then
    local toSlot = tonumber(action.toSlot)
    if toSlot and action.equipSlot then
      local eqItemId = store.equipment[action.equipSlot]
      local movingDefId = eqItemId and store.items[eqItemId] and store.items[eqItemId].defId
      local placeErr = Inv.standbyPlacementError(store, action.toContainerId, toSlot, movingDefId, nil)
      if placeErr then
        notify(src, placeErr)
      else
        local ok, err = unequipToSlot(store, action.equipSlot, action.toContainerId, toSlot)
        if not ok then
          notify(src, err or L('action_impossible'))
        else
          TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
        end
      end
    end
  elseif actionType == 'selectStandbyContainer' then
    local containerId = action.containerId
    if containerId and store.containers[containerId] then
      StandbyContainers[src] = containerId
    end
  end

  ensureActiveContainer(store)
  syncVehicleContainerChanges(store)
  syncRemoteStandbyChanges(store)
  syncStaticChestChanges(store)
  syncSearchChanges(store, src)
  markDirty(identifier)
  local state = buildState(src, store, action.coords)
  local containerId = StandbyContainers[src]
  if containerId then
    state.standbyContainerId = containerId
    state.standbyContainer = buildContainerView(store, containerId)
  end
  -- Fouille : garder la barre de sections (poches de la cible) à gauche + flag.
  if SearchStandby[src] then
    state.standbyPath = SearchStandby[src].sections
    state.isSearch = true
  end
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
  updateRadioPower(src, store)

  -- Sync EN DIRECT : pousse la mise à jour aux autres personnes qui regardent le
  -- MÊME coffre (même containerId), pour un coffre partagé édité à deux.
  if containerId and not SearchStandby[src] then
    for osrc, ocid in pairs(StandbyContainers) do
      if osrc ~= src and ocid == containerId then
        pcall(Inv.refreshOpenStandby, osrc)
      end
    end
  end
end)
