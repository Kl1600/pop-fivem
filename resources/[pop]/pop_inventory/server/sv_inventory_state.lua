function hasLongWeaponEquipped(store)
  local itemId = store.equipment['weapon_long']
  return itemId ~= nil
end

function canStoreLongWeapon(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false
  end
  local def = getItemDef(item.defId)
  if not def or not listContains(def.tags or {}, 'weapon_long') then
    return true
  end
  return not hasLongWeaponEquipped(store)
end

function hasCardboardBoxEquipped(store)
  for _, iid in pairs(store.equipment) do
    local it = store.items[iid]
    if it and it.defId == 'cardboard_box' then return true end
  end
  return false
end

function hasSafeEquipped(store)
  for _, iid in pairs(store.equipment) do
    local it = store.items[iid]
    if it and it.defId == 'safe' then return true end
  end
  return false
end

function hasBriefcaseEquipped(store)
  for _, iid in pairs(store.equipment) do
    local it = store.items[iid]
    if it and it.defId == 'briefcase' then return true end
  end
  return false
end

equipItem = function(store, itemId)
  local item = store.items[itemId]
  if not item then
    return false, 'Item invalide'
  end
  local def = getItemDef(item.defId)
  if not def or not def.equipSlot then
    return false, 'Non equipable'
  end
  local slot = def.equipSlot

  if item.defId == 'cardboard_box' and hasBriefcaseEquipped(store) then
    return false, 'Impossible de porter une boite avec une malette'
  end

  if item.defId == 'safe' and hasBriefcaseEquipped(store) then
    return false, 'Impossible de porter un coffre avec une malette'
  end

  if item.defId == 'briefcase' and hasCardboardBoxEquipped(store) then
    return false, 'Impossible de porter une malette avec une boite'
  end

  if item.defId == 'briefcase' and hasSafeEquipped(store) then
    return false, 'Impossible de porter une malette avec un coffre'
  end

  if item.defId == 'cardboard_box' and hasSafeEquipped(store) then
    return false, 'Impossible de porter une boite avec un coffre'
  end

  if item.defId == 'safe' and hasCardboardBoxEquipped(store) then
    return false, 'Impossible de porter un coffre avec une boite'
  end
  
  if store.equipment[slot] then
    local oldItemId = store.equipment[slot]
    store.equipment[slot] = nil
    removeItemLocation(store, oldItemId)
    -- On essaie de ranger l'ancien item dans l'inventaire
    local ok, err = autoInsertExistingItem(store, oldItemId)
    if not ok then
      -- Si on ne peut pas ranger l'ancien item (plus de place), on annule l'opération
      store.equipment[slot] = oldItemId
      setItemLocation(store, oldItemId, { type = 'equipment', slot = slot })
      return false, err or "Pas de place pour ranger l'item occupant le slot"
    end
  end

  local location = store.itemLocations[itemId]
  if location and location.type == 'container' then
    removeItemFromContainer(store, location.containerId, location.slot)
  end

  store.equipment[slot] = itemId
  setItemLocation(store, itemId, { type = 'equipment', slot = slot })
  ensureActiveContainer(store)
  return true
end

function unequipItem(store, slot)
  local itemId = store.equipment[slot]
  if not itemId then
    return false, 'Slot vide'
  end
  store.equipment[slot] = nil
  removeItemLocation(store, itemId)
  local ok = insertIntoActiveContainer(store, itemId)
  if not ok then
    store.equipment[slot] = itemId
    setItemLocation(store, itemId, { type = 'equipment', slot = slot })
    return false, 'Pas de place'
  end
  ensureActiveContainer(store)
  return true
end

-- Allume/éteint la radio selon l'occupation du slot 'radio'. Événement DÉTERMINISTE
-- (pas un toggle) -> idempotent, on peut l'appeler après chaque action d'équipement.
local lastRadioPower = {}
function clearRadioPower(src) lastRadioPower[src] = nil end -- appelé à la déconnexion

function updateRadioPower(src, store)
  local hasRadio = false
  if store and store.items then
    for _, item in pairs(store.items) do
      if item.defId == 'radio' and not item._isTemporary then
        hasRadio = true
        break
      end
    end
  end
  -- N'envoie l'événement qu'au changement d'état (appelé à chaque sendState)
  if lastRadioPower[src] == hasRadio then return end
  lastRadioPower[src] = hasRadio
  TriggerClientEvent('pop_inventory:client:setRadioPower', src, hasRadio)
end

function buildItemView(store, itemId)
  local item = store.items[itemId]
  if not item then
    return nil
  end
  local def = getItemDef(item.defId)
  if not def then
    return nil
  end
  
  local itemLabel = def.label or item.defId
  local gradientColor = def.gradientColor
  
  if item.meta and item.meta.customLabel then
    itemLabel = item.meta.customLabel
  elseif item.defId == 'carkeys' and type(item.meta) == 'table' then
    if item.meta.model and item.meta.plate then
      itemLabel = item.meta.model .. " - " .. item.meta.plate
    elseif item.meta.model then
      itemLabel = item.meta.model
    elseif item.meta.plate then
      itemLabel = item.meta.plate
    end
  elseif item.defId == 'casier' and type(item.meta) == 'table' and item.meta.lockerNumber then
    itemLabel = 'Casier #' .. tostring(item.meta.lockerNumber)
    if item.meta.isOwnLocker then
      itemLabel = itemLabel .. ' (vous)'
    end
  elseif item.defId == 'pot_peinture' and item.containerId then
    local potContainer = store.containers[item.containerId]
    if potContainer and potContainer.items then
      local paintItemId = potContainer.items[1] or potContainer.items['1']
      local paintItem = paintItemId and store.items[paintItemId]
      if paintItem then
        local paintDef = getItemDef(paintItem.defId)
        if paintDef then
          local colorName = paintDef.label or paintItem.defId
          if string.find(colorName, "Peinture ") then
            colorName = string.gsub(colorName, "Peinture ", "")
          end
          itemLabel = "Pot de Peinture (" .. colorName .. ")"
          gradientColor = paintDef.gradientColor
        end
      end
    end
  end
  
  local view = {
    id = item.id,
    defId = item.defId,
    label = itemLabel,
    qty = item.qty,
    maxStack = def.maxStack or 1,
    icon = def.icon,
    equipSlot = def.equipSlot,
    usable = def.usable == true,
    isContainer = item.containerId ~= nil,
    containerId = item.containerId,
    meta = item.meta or {},
    gradientColor = gradientColor,
    weaponHash = def.weaponHash,
    tags = def.tags or {},
    description = def.description,
  }

  -- Puits de chargeur : pour une arme à conteneur (pistol/smg/carabine), on expose
  -- l'état du chargeur inséré afin que la case "Chargeur" de la vue accessoires
  -- reflète le contenu réel du puits (source des munitions, cf. tab_chargeurs).
  if item.containerId then
    local well = store.containers[item.containerId]
    if well and well.items then
      for _, magId in pairs(well.items) do
        local mag = magId and store.items[magId]
        if mag then
          local magDef = getItemDef(mag.defId)
          view.magazine = {
            defId = mag.defId,
            icon = magDef and magDef.icon,
            label = (mag.meta and mag.meta.customLabel) or (magDef and magDef.label) or mag.defId,
          }
          break
        end
      end
    end
  end

  return view
end

function buildContainerView(store, containerId)
  local container = store.containers[containerId]
  if not container then
    return nil
  end
  local def = getItemDef(container.defId)
  local items = {}
  for slot = 1, (container.slots or 0) do
    local itemId = container.items[slot]
    if itemId then
      items[slot] = buildItemView(store, itemId)
    end
  end
  
  local containerLabel = def and def.label or container.defId
  if container.defId == 'pot_peinture' then
    local paintItemId = container.items[1] or container.items['1']
    local paintItem = paintItemId and store.items[paintItemId]
    if paintItem then
      local paintDef = getItemDef(paintItem.defId)
      if paintDef then
        local colorName = paintDef.label or paintItem.defId
        if string.find(colorName, "Peinture ") then
          colorName = string.gsub(colorName, "Peinture ", "")
        end
        containerLabel = "Pot de Peinture (" .. colorName .. ")"
      end
    end
  end

  return {
    id = container.id,
    defId = container.defId,
    label = containerLabel,
    slots = container.slots or 0,
    maxWeight = container.maxWeight or 0,
    weight = getContainerWeight(store, containerId),
    items = items,
    engineBay = container.engineBay, -- baie moteur : cases libres assombries côté NUI
  }
end

function getNearbyGroundPile(source, coordsOverride, radiusOverride)
  ensureGroundLoaded()
  local coords = safeCoordsOverride(source, coordsOverride) or getPlayerCoords(source)
  if not coords then
    return nil
  end
  
  local closest = nil
  local closestDist = radiusOverride or (Config.Ground.Radius or 3.0)
  
  -- Optimisation: Utiliser la grille spatiale
  local key = getGridKey(coords)
  local cx, cy = math.floor(coords.x / 50), math.floor(coords.y / 50)
  
  -- On vérifie le bucket actuel et les 8 adjacents (au cas où le joueur est en bord de bucket)
  for x = cx - 1, cx + 1 do
    for y = cy - 1, cy + 1 do
      local k = x .. "," .. y
      if GroundGrid[k] then
        for _, pile in pairs(GroundGrid[k]) do
          if pileHasItems(pile) then
            local pCoords = vector3(pile.coords.x, pile.coords.y, pile.coords.z)
            local dist = #(coords - pCoords)
            if dist <= closestDist then
              closestDist = dist
              closest = pile
            end
          end
        end
      end
    end
  end
  return closest
end

-- Renvoie TOUTES les piles au sol (avec items) dans le rayon, triées de façon
-- déterministe (par id) pour que l'agrégation "À proximité" soit stable entre
-- l'affichage (buildState) et le ramassage (resolveGroundDisplaySlot).
function getNearbyGroundPiles(source, coordsOverride, radiusOverride)
  ensureGroundLoaded()
  local coords = safeCoordsOverride(source, coordsOverride) or getPlayerCoords(source)
  if not coords then
    return {}
  end
  local radius = radiusOverride or (Config.Ground and (Config.Ground.ViewRadius or Config.Ground.Radius)) or 3.0
  local list = {}
  local cx, cy = math.floor(coords.x / 50), math.floor(coords.y / 50)
  for x = cx - 1, cx + 1 do
    for y = cy - 1, cy + 1 do
      local bucket = GroundGrid[x .. "," .. y]
      if bucket then
        for _, pile in pairs(bucket) do
          if pileHasItems(pile) then
            local dist = #(coords - vector3(pile.coords.x, pile.coords.y, pile.coords.z))
            if dist <= radius then
              list[#list + 1] = pile
            end
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
  return list
end

-- Construit la vue agrégée "À proximité" : concatène les items de TOUTES les piles
-- proches dans une seule liste de slots packés (1..N). Renvoie aussi la position
-- d'ancrage (1ère pile) pour le marqueur. La correspondance slot affiché -> slot
-- réel est recalculée à l'identique par resolveGroundDisplaySlot.
function buildGroundAggregate(source, coordsOverride)
  local piles = getNearbyGroundPiles(source, coordsOverride)
  if #piles == 0 then
    return nil, nil
  end
  local items = {}
  local display = 0
  local totalWeight = 0
  local maxWeight = 0
  local anchor = nil
  for _, pile in ipairs(piles) do
    local container = GroundStore.containers[pile.containerId]
    if container then
      maxWeight = maxWeight + (container.maxWeight or 0)
      for realSlot = 1, (container.slots or 0) do
        local itemId = container.items[realSlot]
        if itemId and GroundStore.items[itemId] then
          display = display + 1
          items[display] = buildItemView(GroundStore, itemId)
          totalWeight = totalWeight + getItemWeight(GroundStore, itemId)
          if not anchor then anchor = pile.coords end
        end
      end
    end
  end
  if display == 0 then
    return nil, nil
  end
  local view = {
    id = '__ground__',
    defId = 'ground',
    label = 'À proximité',
    slots = math.max((Config.Ground and Config.Ground.Slots) or 12, display),
    maxWeight = maxWeight,
    weight = totalWeight,
    items = items,
  }
  return view, anchor
end

-- Résout un slot AFFICHÉ de la vue agrégée vers la pile + slot réel sous-jacents.
-- DOIT itérer dans le même ordre que buildGroundAggregate.
function resolveGroundDisplaySlot(source, displaySlot, coordsOverride)
  local idx = tonumber(displaySlot)
  if not idx then
    return nil
  end
  local piles = getNearbyGroundPiles(source, coordsOverride)
  local count = 0
  for _, pile in ipairs(piles) do
    local container = GroundStore.containers[pile.containerId]
    if container then
      for realSlot = 1, (container.slots or 0) do
        local itemId = container.items[realSlot]
        if itemId and GroundStore.items[itemId] then
          count = count + 1
          if count == idx then
            return pile, realSlot, itemId, container
          end
        end
      end
    end
  end
  return nil
end

-- Cherche, parmi les piles proches, celle qui contient (directement ou en
-- sous-conteneur) le containerId donné. Utilisé pour ouvrir une boîte posée au sol.
function findNearbyPileForContainer(source, coordsOverride, containerId)
  if not containerId then return nil end
  local piles = getNearbyGroundPiles(source, coordsOverride)
  for _, pile in ipairs(piles) do
    if pile.containerId == containerId then
      return pile
    end
    if GroundStore.containers[containerId] and isContainerInStore(GroundStore, pile.containerId, containerId) then
      return pile
    end
  end
  return nil
end

-- Cherche un emplacement libre proche de `coords` pour qu'un nouveau drop ne se
-- superpose pas à une pile existante (deux objets posés côte à côte restent
-- distincts visuellement au lieu de se coller).
function findFreeGroundSpot(coords)
  local minGap = 0.5
  local function occupied(c)
    local cx, cy = math.floor(c.x / 50), math.floor(c.y / 50)
    for x = cx - 1, cx + 1 do
      for y = cy - 1, cy + 1 do
        local bucket = GroundGrid[x .. "," .. y]
        if bucket then
          for _, pile in pairs(bucket) do
            if pileHasItems(pile) and #(c - vector3(pile.coords.x, pile.coords.y, pile.coords.z)) < minGap then
              return true
            end
          end
        end
      end
    end
    return false
  end
  if not occupied(coords) then
    return coords
  end
  for ring = 1, 4 do
    local r = minGap * ring
    for step = 0, 7 do
      local ang = (step / 8) * math.pi * 2 + ring * 0.6
      local c = vector3(coords.x + math.cos(ang) * r, coords.y + math.sin(ang) * r, coords.z)
      if not occupied(c) then
        return c
      end
    end
  end
  return coords
end

-- Pose un drop : crée TOUJOURS sa propre pile (pas de fusion) devant le joueur,
-- décalée si nécessaire pour ne pas chevaucher une pile existante.
function createDropPile(source, coordsOverride)
  ensureGroundLoaded()
  local coords = safeCoordsOverride(source, coordsOverride) or getPlayerCoords(source)
  if not coords then
    return nil
  end
  local ped = GetPlayerPed(source)
  if DoesEntityExist(ped) then
    local rad = math.rad(GetEntityHeading(ped))
    coords = vector3(coords.x - math.sin(rad), coords.y + math.cos(rad), coords.z)
  end
  coords = findFreeGroundSpot(coords)
  return createGroundPile(coords)
end

function createGroundPile(coords, maxWeightOverride)
  local containerId = generateId('g')
  GroundStore.containers[containerId] = {
    id = containerId,
    defId = 'ground',
    slots = Config.Ground.Slots,
    maxWeight = maxWeightOverride or Config.Ground.MaxWeight,
    items = {},
  }

  local pileId = generateId('pile')
  local pile = {
    id = pileId,
    coords = { x = coords.x, y = coords.y, z = coords.z },
    containerId = containerId,
  }
  GroundPiles[pileId] = pile
  
  -- Mettre à jour la grille spatiale
  updatePileInGrid(pile)
  
  markGroundDirty()
  return pile
end

function getOrCreateGroundPile(source, coordsOverride)
  ensureGroundLoaded()
  local coords = safeCoordsOverride(source, coordsOverride) or getPlayerCoords(source)
  if not coords then
    return nil
  end
  
  local ped = GetPlayerPed(source)
  if DoesEntityExist(ped) then
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local forwardX = -math.sin(rad)
    local forwardY = math.cos(rad)
    coords = vector3(coords.x + forwardX, coords.y + forwardY, coords.z)
  end

  local closest = nil
  local closestDist = Config.Ground.MergeDistance or 2.0
  for _, pile in pairs(GroundPiles) do
    local dist = #(coords - vector3(pile.coords.x, pile.coords.y, pile.coords.z))
    if dist <= closestDist then
      closestDist = dist
      closest = pile
    end
  end

  if closest then
    return closest
  end

  return createGroundPile(coords)
end

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
  for _, slot in ipairs(Config.Inventory.ContainerOrder or {}) do
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
      for _, slot in ipairs(Config.Inventory.ContainerOrder or {}) do
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
      label = 'Boite en Carton',
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

function notify(source, message)
  TriggerClientEvent('pop_inventory:client:notify', source, message)
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

function clampDropQty(item, qty)
  local itemQty = tonumber(item.qty) or 1
  local amount = tonumber(qty) or itemQty
  amount = math.floor(amount) -- pas de quantité fractionnaire envoyée par le client
  if amount <= 0 or amount > itemQty then
    amount = itemQty
  end
  return amount
end

function canSplitDrop(item, def, qty)
  if not item or not def then
    return false
  end
  if item.containerId then
    return false
  end
  local maxStack = def.maxStack or 1
  return maxStack > 1 and item.qty > 1 and qty < item.qty
end

function resolveOriginItem(store, origin)
  if not origin or not origin.type then
    return nil
  end
  if origin.type == 'equipment' then
    return store.equipment[origin.slot]
  end
  if origin.type == 'container' then
    local slotIndex = tonumber(origin.slot)
    if not slotIndex then
      return nil
    end
    origin.slot = slotIndex
    local container = store.containers[origin.containerId]
    if container then
      return container.items[slotIndex]
    end
  end
  return nil
end

function dropToGround(src, store, origin, qty, coords)
  local itemId = resolveOriginItem(store, origin)
  if not itemId then
    return false, 'Slot vide'
  end
  local item = store.items[itemId]
  if not item then
    return false, 'Item invalide'
  end
  local def = getItemDef(item.defId)
  if not def then
    return false, 'Item inconnu'
  end

  local dropQty = clampDropQty(item, qty)
  local splitDrop = canSplitDrop(item, def, dropQty)
  local dropWeight = splitDrop and itemBaseWeight(def, dropQty) or getItemWeight(store, itemId)

  local function tryGetSlot(pile)
    if not pile then
      return nil, nil, 'Sol indisponible'
    end
    local groundContainer = GroundStore.containers[pile.containerId]
    if not groundContainer then
      return nil, nil, 'Sol indisponible'
    end
    local targetSlot = findEmptySlot(groundContainer)
    if not targetSlot then
      return nil, nil, 'Sol plein'
    end
    if not canAddWeight(GroundStore, pile.containerId, dropWeight) then
      return nil, nil, 'Poids max sol'
    end
    return groundContainer, targetSlot, nil
  end

  local pile = createDropPile(src, coords)
  local groundContainer, targetSlot, err = tryGetSlot(pile)
  if not targetSlot then
    local coordsVec = pile and pile.coords and vector3(pile.coords.x, pile.coords.y, pile.coords.z) or toVector3(coords) or getPlayerCoords(src)
    if coordsVec then
      local weightOverride = nil
      if err == 'Poids max sol' then
        weightOverride = math.max(Config.Ground.MaxWeight or 0, dropWeight)
      end
      local newPile = createGroundPile(coordsVec, weightOverride)
      groundContainer, targetSlot, err = tryGetSlot(newPile)
      if targetSlot then
        pile = newPile
      end
    end
  end
  if not targetSlot then
    return false, err or 'Sol indisponible'
  end

  if splitDrop then
    item.qty = item.qty - dropQty
    local newItemId = createItem(GroundStore, item.defId, dropQty, item.meta)
    if not newItemId then
      return false, 'Erreur creation'
    end
    placeItemInContainer(GroundStore, pile.containerId, targetSlot, newItemId)
  else
    if origin.type == 'equipment' then
      store.equipment[origin.slot] = nil
      removeItemLocation(store, itemId)
    elseif origin.type == 'container' then
      removeItemFromContainer(store, origin.containerId, origin.slot)
    end
    moveItemTree(store, GroundStore, itemId)
    placeItemInContainer(GroundStore, pile.containerId, targetSlot, itemId)
  end

  PlayerGroundFocus[src] = pile.id
  markGroundDirty()
  syncGroundDropEntities()
  debugPrint('dropToGround: item posé, pileId=', pile.id, 'containerId=', pile.containerId, 'itemId=', itemId or newItemId)
  return true
end

function pickupFromGroundToSlot(src, store, groundSlot, toContainerId, toSlot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, groundSlot, coords)
  if not pile then
    return false, 'Rien a proximite'
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, 'Item invalide'
  end

  local targetContainer = store.containers[toContainerId]
  if not targetContainer then
    return false, 'Container invalide'
  end

  local def = getItemDef(item.defId)
  if not def then
    return false, 'Item inconnu'
  end

  if not isAllowedInContainer(targetContainer.defId, item.defId, def) then
    return false, 'Restriction container'
  end

  local targetSlot = tonumber(toSlot)
  if not targetSlot then
    return false, 'Slot cible invalide'
  end

  -- Objet-conteneur (sac…) vers une case occupée : refus AVANT de le retirer du
  -- sol (avant, l'objet était retiré puis la fonction sortait : objet perdu).
  if item.containerId and (targetContainer.items[targetSlot] or targetContainer.items[tostring(targetSlot)]) then
    return false, 'Slot occupe'
  end

  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  if groundContainer then
    groundContainer.items[slotIndex] = nil
    groundContainer.items[tostring(slotIndex)] = nil
  end

  if item.containerId then
    moveItemTree(GroundStore, store, itemId)
    local weight = getItemWeight(store, itemId)
    if not canAddWeight(store, toContainerId, weight) then
      moveItemTree(store, GroundStore, itemId)
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, 'Poids max'
    end
    
    placeItemInContainer(store, toContainerId, targetSlot, itemId)
  else
    local weight = itemBaseWeight(def, item.qty)
    if not canAddWeight(store, toContainerId, weight) then
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, 'Poids max'
    end
    
    local targetItemId = targetContainer.items[targetSlot]
    if targetItemId then
      local targetItem = store.items[targetItemId]
      if canStackItems(item, targetItem) then
        local maxStack = def.maxStack or 1
        local space = maxStack - targetItem.qty
        if space > 0 then
          local add = math.min(space, item.qty)
          targetItem.qty = targetItem.qty + add
          item.qty = item.qty - add
          if item.qty > 0 then
            placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
          else
            purgeItemFromGround(itemId)
          end
        else
          placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
          return false, 'Pile pleine'
        end
      else
        placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
        return false, 'Slot occupe'
      end
    else
      local newItemId = createItem(store, item.defId, item.qty, item.meta)
      placeItemInContainer(store, toContainerId, targetSlot, newItemId)
      purgeItemFromGround(itemId)
    end
  end

  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  return true
end

function unequipToSlot(store, equipSlot, toContainerId, toSlot)
  local itemId = store.equipment[equipSlot]
  if not itemId then
    return false, 'Slot vide'
  end
  
  local targetContainer = store.containers[toContainerId]
  if not targetContainer then
    return false, 'Container invalide'
  end

  local item = store.items[itemId]
  if not item then
    return false, 'Item invalide'
  end

  local def = getItemDef(item.defId)
  if not def then
    return false, 'Item inconnu'
  end

  if not isAllowedInContainer(targetContainer.defId, item.defId, def) then
    return false, 'Restriction container'
  end

  local targetSlot = tonumber(toSlot)
  if not targetSlot then
    return false, 'Slot cible invalide'
  end

  local targetItemId = targetContainer.items[targetSlot]
  if targetItemId then
    return false, 'Slot occupe'
  end

  local weight = getItemWeight(store, itemId)
  if not canAddWeight(store, toContainerId, weight) then
    return false, 'Poids max'
  end

  store.equipment[equipSlot] = nil
  removeItemLocation(store, itemId)
  placeItemInContainer(store, toContainerId, targetSlot, itemId)
  ensureActiveContainer(store)
  return true
end

function pickupFromGround(src, store, slot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, slot, coords)
  if not pile then
    return false, 'Rien a proximite'
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, 'Item invalide'
  end

  if item.containerId then
    removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
    if groundContainer then
      groundContainer.items[slotIndex] = nil
      groundContainer.items[tostring(slotIndex)] = nil
    end
    moveItemTree(GroundStore, store, itemId)
    local ok, err = autoInsertExistingItem(store, itemId)
    if not ok then
      local def = getItemDef(item.defId)
      if def and def.equipSlot and not store.equipment[def.equipSlot] then
        local equipOk = equipItem(store, itemId)
        if equipOk then
          purgeItemFromGround(itemId)
          pruneEmptyGroundPiles()
          markGroundDirty()
          -- broadcastGroundDrops() -- SUPPRIMÉ: Optimisation "Manière Forte"
          return true
        end
      end
      moveItemTree(store, GroundStore, itemId)
      placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
      return false, err or 'Pas de place'
    end
    purgeItemFromGround(itemId)
    pruneEmptyGroundPiles()
    markGroundDirty()
    syncGroundDropEntities()
    PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
    return true
  end

  local ok, err = autoInsertItem(store, item.defId, item.qty, item.meta)
  if not ok then
    return false, err or 'Pas de place'
  end
  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  if groundContainer then
    groundContainer.items[slotIndex] = nil
    groundContainer.items[tostring(slotIndex)] = nil
  end
  purgeItemFromGround(itemId)
  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  return true
end

function pickupEquipFromGround(src, store, slot, equipSlot, coords)
  local pile, slotIndex, itemId, groundContainer = resolveGroundDisplaySlot(src, slot, coords)
  if not pile then
    return false, 'Rien a proximite'
  end
  local item = GroundStore.items[itemId]
  if not item then
    return false, 'Item invalide'
  end
  local def = getItemDef(item.defId)
  if not def or not def.equipSlot or def.equipSlot ~= equipSlot then
    return false, 'Slot occupe'
  end
  if store.equipment[equipSlot] then
    return false, 'Slot occupe'
  end

  removeItemFromContainer(GroundStore, pile.containerId, slotIndex)
  moveItemTree(GroundStore, store, itemId)
  local ok, err = equipItem(store, itemId)
  if not ok then
    moveItemTree(store, GroundStore, itemId)
    placeItemInContainer(GroundStore, pile.containerId, slotIndex, itemId)
    return false, err or 'Action impossible'
  end
  PlayerGroundFocus[src] = pileHasItems(pile) and pile.id or nil
  pruneEmptyGroundPiles()
  markGroundDirty()
  -- broadcastGroundDrops() -- SUPPRIMÉ
  return true
end

function syncRemoteContainerChanges(store)
  -- Synchroniser les modifications des conteneurs distants vers RemoteContainers
  local changed = false
  for containerId, container in pairs(store.containers or {}) do
    if container.defId == '__remote_container__' and RemoteContainers[containerId] then
      changed = true
      RemoteContainers[containerId].itemData = {}
      for slot, itemId in pairs(container.items or {}) do
        local item = store.items[itemId]
        if item then
          -- Sérialise l'arbre complet (item + conteneur imbriqué éventuel : pot, sac…).
          RemoteContainers[containerId].itemData[slot] = serializeItemTree(store, itemId)
        end
      end
    end
  end
  if changed then
    saveRemoteContainers()
  end
end

