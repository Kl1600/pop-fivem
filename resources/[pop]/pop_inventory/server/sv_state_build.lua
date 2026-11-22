-- État envoyé au client (suite de sv_inventory_state.lua) : chemin standby, buildState, sendState, notifications.

function getStandbyPath(store, currentId)
  local path = {}
  local current = currentId
  while current do
    local container = store.containers[current]
    if not container then
      break
    end
    table.insert(path, 1, {
      containerId = current,
      defId = container.defId,
      label = container.label,
    })

    -- If this is a root standby container (e.g. vehicle, static chest, or remote), stop walking up
    if container.defId == '__vehicle_container__' or container.defId == '__static_chest__' or container.defId == '__remote_standby__' then
      break
    end

    local ownerItemId = store.containerOwners[current]
    if not ownerItemId then
      break
    end
    local loc = store.itemLocations[ownerItemId]
    if not loc or loc.type ~= 'container' then
      break
    end
    current = loc.containerId
  end
  return path
end

function buildState(source, store, coordsOverride)
  ensureGroundLoaded()
  ensureActiveContainer(store)

  local state = {
    equipment = {},
    containers = {},
    containerOrder = {},
    activeContainerId = store.activeContainerId,
    activeContainerIsGround = store.activeContainerIsGround,
    ground = nil,
    remoteContainer = nil,
    standbyPath = getStandbyPath(store, StandbyContainers[source]),
  }

  for slot, itemId in pairs(store.equipment) do
    local view = buildItemView(store, itemId)
    if view then
      state.equipment[slot] = view
    end
  end

  state.containerOrder = {}
  for _, slot in ipairs(Config.InventorySettings.ContainerOrder or {}) do
    local itemId = store.equipment[slot]
    local item = itemId and store.items[itemId]
    if item and item.containerId and store.containers[item.containerId] then
      table.insert(state.containerOrder, { defId = slot, containerId = item.containerId })
      state.containers[item.containerId] = buildContainerView(store, item.containerId)
    end
  end

  -- [FIX] Always include the active container if it's not equipped (e.g. phone opened from inventory)
  local activeId = store.activeContainerId
  if activeId and not store.activeContainerIsGround and not string.find(tostring(activeId), '^__local_') then
    local alreadyInOrder = false
    for _, entry in ipairs(state.containerOrder) do
      if entry.containerId == activeId then
        alreadyInOrder = true
        break
      end
    end

    if not alreadyInOrder then
      local container = store.containers[activeId]
      if container then
        table.insert(state.containerOrder, { defId = container.defId, containerId = activeId })
        state.containers[activeId] = buildContainerView(store, activeId)
      end
    end
  end

  local targetId = SearchingPlayers[source]
  if targetId then
    local targetIdentifier = getIdentifier(targetId)
    local targetStore = targetIdentifier and ensureStore(targetIdentifier)
    if targetStore then
      for _, slot in ipairs(Config.InventorySettings.ContainerOrder or {}) do
        local itemId = targetStore.equipment[slot]
        local item = itemId and targetStore.items[itemId]
        if item and item.containerId and targetStore.containers[item.containerId] then
          local cid = "target_" .. item.containerId
          table.insert(state.containerOrder, { defId = slot, containerId = cid, isTarget = true })

          -- Build Target Container View manually to prefix item IDs and avoid search collisions
          local tContainer = targetStore.containers[item.containerId]
          local tDef = getItemDef(tContainer.defId)
          local tItems = {}
          for tSlot = 1, (tContainer.slots or 0) do
            local tItemId = tContainer.items[tSlot]
            if tItemId then
              local tItemView = buildItemView(targetStore, tItemId)
              if tItemView then
                tItemView.id = "ti_" .. tItemView.id
                if tItemView.isContainer then tItemView.containerId = "target_" .. tItemView.containerId end
                tItems[tSlot] = tItemView
              end
            end
          end
          state.containers[cid] = {
            id = cid,
            defId = tContainer.defId,
            label = tDef and tDef.label or tContainer.defId,
            slots = tContainer.slots or 0,
            maxWeight = tContainer.maxWeight or 0,
            weight = getContainerWeight(targetStore, item.containerId),
            items = tItems,
            isTarget = true
          }
        end
      end
    end
  end

  if store.activeContainerId and RemoteContainers[store.activeContainerId] then
    local remoteData = RemoteContainers[store.activeContainerId]
    state.remoteContainer = {
      id = store.activeContainerId,
      label = L('cardboard_box_label'),
      slots = 20,
      maxWeight = 30.0,
      weight = 0,
      items = {},
    }

    for slot, itemId in pairs(remoteData.items or {}) do
      if itemId and store.items[itemId] then
        state.remoteContainer.items[slot] = buildItemView(store, itemId)
        local itemWeight = getItemWeight(store, itemId)
        state.remoteContainer.weight = state.remoteContainer.weight + itemWeight
      end
    end

    -- Ajouter le conteneur distant à state.containers pour l'affichage
    state.containers[store.activeContainerId] = state.remoteContainer
  else
    -- "À proximité" : agrège TOUTES les piles proches dans une seule vue, pour que
    -- plusieurs objets posés côte à côte (donc dans des piles distinctes) soient
    -- tous visibles, et pas seulement la pile la plus proche.
    local groundView, groundAnchor = buildGroundAggregate(source, coordsOverride)
    if groundView then
      state.ground = groundView
      if groundAnchor then
        state.groundCoords = { x = groundAnchor.x, y = groundAnchor.y, z = groundAnchor.z }
      end
      debugPrint('buildState: vue sol agrégée, items=', json.encode(groundView.items or {}))
    else
      debugPrint('buildState: aucune pile au sol à proximité')
    end

    -- Sous-conteneur du sol ouvert (ex: boîte posée au sol) : on le cherche dans
    -- n'importe quelle pile proche, pas seulement la plus proche.
    if store.activeContainerIsGround and store.activeContainerId then
      if GroundStore.containers[store.activeContainerId]
        and findNearbyPileForContainer(source, coordsOverride, store.activeContainerId) then
        state.containers[store.activeContainerId] = buildContainerView(GroundStore, store.activeContainerId)
      else
        store.activeContainerIsGround = false
        store.activeContainerId = nil
      end
    end
  end

  if store.activeContainerId and store.containers[store.activeContainerId] then
    state.containers[store.activeContainerId] = buildContainerView(store, store.activeContainerId)
  elseif store.activeContainerId and state.ground and store.activeContainerId == state.ground.id then
    state.containers[store.activeContainerId] = state.ground
  elseif not state.remoteContainer then
    store.activeContainerIsGround = false
    ensureActiveContainer(store)
    if store.activeContainerId and store.containers[store.activeContainerId] then
      state.containers[store.activeContainerId] = buildContainerView(store, store.activeContainerId)
    end
  end

  state.activeContainerId = store.activeContainerId

  -- Stock de peinture : compté DANS les pots (pot_peinture), comme le pistolet.
  local paintStock = { peinture_rouge = 0, peinture_jaune = 0, peinture_bleue = 0 }
  for _, container in pairs(store.containers or {}) do
    if container.defId == 'pot_peinture' then
      for _, itemId in pairs(container.items or {}) do
        local it = store.items[itemId]
        if it and paintStock[it.defId] ~= nil then
          paintStock[it.defId] = paintStock[it.defId] + (it.qty or 1)
        end
      end
    end
  end
  state.paintStock = paintStock

  return state
end

function sendState(source, coordsOverride)
  local identifier = getIdentifier(source)
  if not identifier then
    return
  end
  local store = ensureStore(identifier)
  if not store then
    return
  end
  local state = buildState(source, store, coordsOverride)
  local standbyId = StandbyContainers[source]
  if standbyId and store.containers[standbyId] then
    state.standbyContainerId = standbyId
    state.standbyContainer = buildContainerView(store, standbyId)
  end
  StateSeq[source] = (StateSeq[source] or 0) + 1
  state._seq = StateSeq[source]
  TriggerClientEvent('pop_inventory:client:state', source, state)
  updateRadioPower(source, store)
end

function buildEquipmentDefs(store)
  local defs = {}
  for slot, itemId in pairs(store.equipment) do
    local item = store.items[itemId]
    if item then
      defs[slot] = { defId = item.defId, meta = item.meta or {}, containerId = item.containerId }
    end
  end
  return defs
end

--- Notification simple du script (style d'origine : icône info, 4 s).
function notify(source, message)
  Bridge.Notify(source, { message = message, icon = 'fas fa-info', duration = 4000 })
end

-- Quantité colorée pour les notifs (suit la logique HTML du script notification).
-- qty <= 1 -> "un", sinon "xN" ; toujours en vert/gras.
function itemQtyTag(qty)
  qty = tonumber(qty) or 1
  local txt = qty > 1 and ('x' .. qty) or 'un'
  return "<span style='color:#2ecc71; font-weight:bold;'>" .. txt .. "</span>"
end

function clearAllGroundDrops()
  GroundPiles = {}
  GroundStore = {
    items = {},
    containers = {},
    itemLocations = {},
    containerOwners = {},
  }
  PlayerGroundFocus = {}
  rebuildLocations(GroundStore)
  markGroundDirty()
  syncGroundDropEntities()
  saveGround(true)
end
