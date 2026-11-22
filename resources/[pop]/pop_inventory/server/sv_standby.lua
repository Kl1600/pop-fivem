-- Conteneur distant ouvert (suite de sv_remote_containers.lua) : actualisation en direct, déplacement / reprise des conteneurs posés, standby.

-- =====================================================
--  Actualisation EN DIRECT du conteneur distant ouvert.
--  Fouille : reconstruit les sections depuis l'inventaire ACTUEL de la cible.
--  Coffre distant (remote_standby_) : ré-importe depuis RemoteContainers (modifs
--  des autres joueurs). Le client défère le rendu s'il est en plein drag.
-- =====================================================
function Inv.refreshOpenStandby(src)
  local identifier = getIdentifier(src)
  if not identifier then return end
  local store = ensureStore(identifier)
  if not store then return end

  local sinfo = SearchStandby[src]
  if sinfo then
    -- Cible déconnectée -> on arrête (la fermeture nettoiera).
    if not (sinfo.tsrc and GetPlayerName(sinfo.tsrc)) then return end
    local tStore = ensureStore(sinfo.ident)
    if not tStore then return end
    local active = StandbyContainers[src]
    local cids, sections = Inv.buildSearchSections(src, store, tStore, sinfo.ident, sinfo.tsrc)
    if #cids == 0 then return end
    local newActive = cids[1]
    for _, c in ipairs(cids) do if c == active then newActive = active break end end
    StandbyContainers[src] = newActive
    SearchStandby[src] = { ident = sinfo.ident, tsrc = sinfo.tsrc, cids = cids, sections = sections }
    local state = buildState(src, store, nil)
    state.standbyContainerId = newActive
    state.standbyContainer = buildContainerView(store, newActive)
    state.standbyPath = sections
    state.isSearch = true
    StateSeq[src] = (StateSeq[src] or 0) + 1
    state._seq = StateSeq[src]
    TriggerClientEvent('pop_inventory:client:state', src, state)
    return
  end

  local cid = StandbyContainers[src]
  if not cid or not store.containers[cid] then return end
  local c = store.containers[cid]

  -- Source partagée à ré-importer (RemoteContainers ou coffre au sol GroundStore).
  local srcItems = nil
  local remoteId = cid:match('^remote_standby_(.+)$')
  if remoteId and RemoteContainers[remoteId] then
    srcItems = RemoteContainers[remoteId].itemData
  else
    local groundId = cid:match('^ground_standby_(.+)$')
    if groundId and GroundStore.containers[groundId] then
      srcItems = {}
      for slot, gItemId in pairs(GroundStore.containers[groundId].items or {}) do
        local gi = GroundStore.items[gItemId]
        if gi then srcItems[slot] = serializeItemTree(GroundStore, gItemId) end
      end
    end
  end

  if srcItems then
    for _, itemId in pairs(c.items or {}) do
      if store.items[itemId] and store.items[itemId]._isTemporary then
        removeStoreItemTree(store, itemId)
      end
    end
    c.items = {}
    for slot, itemData in pairs(srcItems) do
      if itemData and itemData.defId then
        local tempId = rebuildItemTree(store, itemData, true)
        if tempId then
          local ns = tonumber(slot) or slot
          c.items[ns] = tempId
          setItemLocation(store, tempId, { type = 'container', containerId = cid, slot = ns })
        end
      end
    end
  end
  local state = buildState(src, store, nil)
  state.standbyContainerId = cid
  state.standbyContainer = buildContainerView(store, cid)
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
end

CreateThread(function()
  while true do
    Wait(1500)
    for src in pairs(StandbyContainers) do
      pcall(Inv.refreshOpenStandby, src)
    end
  end
end)

RegisterNetEvent('pop_inventory:server:moveRemoteContainer', function()
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end

  local ped = GetPlayerPed(src)
  local coords = GetEntityCoords(ped)

  local container = getNearbyRemoteContainer(src, { x = coords.x, y = coords.y, z = coords.z })
  if not container then
    notify(src, L('no_box_nearby_server'))
    return
  end

  TriggerClientEvent('pop_inventory:client:startMoveContainer', src, container.id, container.data.coords)
end)

RegisterNetEvent('pop_inventory:server:takeRemoteContainer', function(propCoords)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end

  local store = ensureStore(identifier)

  if hasBriefcaseEquipped(store) then
    notify(src, L('take_box_briefcase'))
    return
  end

  if hasCardboardBoxEquipped(store) or hasSafeEquipped(store) then
    notify(src, L('already_carrying'))
    return
  end

  -- propCoords arrive du client sous forme de vector3 (GetEntityCoords), pas
  -- de table : `type(vector3(...)) == 'vector3'`, jamais 'table'. L'ancien
  -- test tombait donc toujours dans le fallback et ignorait les coords
  -- réelles du carton au profit de la position du joueur.
  local searchCoords = toVector3(propCoords)
  if not searchCoords then
    searchCoords = GetEntityCoords(GetPlayerPed(src))
  end

  local container = getNearbyRemoteContainer(src, searchCoords)
  if not container then
    notify(src, L('no_box_nearby_server'))
    return
  end

  local itemToCreate = 'cardboard_box'
  if container.data and container.data.propModel == 'prop_ld_int_safe_01' then
    itemToCreate = 'safe'
  end

  local itemId = createItem(store, itemToCreate, 1)
  if not itemId then
    notify(src, L('item_create_error_short'))
    return
  end

  local item = store.items[itemId]
  if item and item.containerId then
    -- Créer de nouveaux items basés sur les données du conteneur distant
    for slot, itemData in pairs(container.data.itemData or {}) do
      if itemData and itemData.defId then
        -- rebuildItemTree recrée aussi les conteneurs imbriqués (pot, sac…).
        local newItemId = rebuildItemTree(store, itemData, false)
        if newItemId then
          store.containers[item.containerId].items[slot] = newItemId
          setItemLocation(store, newItemId, { type = 'container', containerId = item.containerId, slot = slot })
        end
      end
    end
  end

  RemoteContainers[container.id] = nil

  local ok = equipItem(store, itemId)
  if ok then
    markDirty(identifier)
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    sendState(src, { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z })
    TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
    TriggerClientEvent('pop_inventory:client:updateRemoteContainers', -1, RemoteContainers)
  else
    notify(src, L('cannot_equip_box'))
  end
end)

-- duplicate dropRemoteContainer removed (defined earlier)

RegisterNetEvent('pop_inventory:server:updateRemoteContainerPos', function(containerId, coords, originalCoords)
  -- Anti-triche : déplacement uniquement autour du joueur (origine et destination)
  local src = source
  if not safeCoordsOverride(src, coords, 10.0) then return end
  if originalCoords and not safeCoordsOverride(src, originalCoords, 10.0) then return end
  if containerId and RemoteContainers[containerId] and RemoteContainers[containerId].coords
      and not safeCoordsOverride(src, RemoteContainers[containerId].coords, 10.0) then return end
  -- Si containerId est nil, chercher le conteneur distant ou la pile au sol le plus proche des coordonnées d'origine
  if not containerId and originalCoords then
    local targetCoords = vector3(originalCoords.x, originalCoords.y, originalCoords.z)
    local closestDist = 2.0
    local found = false

    -- 1. Chercher dans RemoteContainers
    local closestRemoteId = nil
    for id, container in pairs(RemoteContainers) do
      if container and container.coords then
        local dist = #(vector3(container.coords.x, container.coords.y, container.coords.z) - targetCoords)
        if dist <= closestDist then
          closestDist = dist
          closestRemoteId = id
        end
      end
    end

    if closestRemoteId then
      RemoteContainers[closestRemoteId].coords = coords
      TriggerClientEvent('pop_inventory:client:updateRemoteContainers', -1, RemoteContainers)
      found = true
    end

    -- 2. Chercher dans GroundPiles si non trouvé
    if not found then
      closestDist = 2.0
      local closestPileId = nil
      for id, pile in pairs(GroundPiles or {}) do
        if pile and pile.coords then
          local dist = #(vector3(pile.coords.x, pile.coords.y, pile.coords.z) - targetCoords)
          if dist <= closestDist then
            closestDist = dist
            closestPileId = id
          end
        end
      end

      if closestPileId then
        GroundPiles[closestPileId].coords = coords
        markGroundDirty()
        syncGroundDropEntities()
        saveGround()
      end
    end

    return
  end

  if containerId and RemoteContainers[containerId] then
    RemoteContainers[containerId].coords = coords
    TriggerClientEvent('pop_inventory:client:updateRemoteContainers', -1, RemoteContainers)
  end
end)

RegisterNetEvent('pop_inventory:server:requestRemoteContainers', function()
  TriggerClientEvent('pop_inventory:client:updateRemoteContainers', source, RemoteContainers)
end)


function getOrCreateStandbyContainer(store, identifier)
  local containerId = 'standby_' .. identifier:gsub('[^%w]', '_')
  if store.containers[containerId] then
    return containerId
  end
  store.containers[containerId] = {
    id = containerId,
    defId = '__standby_container__',
    label = L('storage_label'),
    slots = 30,
    maxWeight = 100.0,
    items = {},
  }
  return containerId
end

RegisterNetEvent('pop_inventory:server:openStandbyContainer', function(coords)
  local src = source -- luacheck: ignore 211
  -- Désactivé : ce « stockage perso » de 30 cases n'est ouvert par aucun point du
  -- jeu (repli du client seulement) et servait de coffre portable ouvrable partout.
  if true then return end
  local identifier = getIdentifier(src) -- luacheck: ignore 511
  if not identifier then
    return
  end
  local store = ensureStore(identifier)
  local containerId = getOrCreateStandbyContainer(store, identifier)
  StandbyContainers[src] = containerId
  markDirty(identifier)
  local state = buildState(src, store, coords)
  state.standbyContainerId = containerId
  state.standbyContainer = buildContainerView(store, containerId)
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
end)
