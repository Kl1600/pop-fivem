function hasLongWeaponEquipped(store)
  local itemId = store.equipment['weapon_long']
  return itemId ~= nil
end

function canStoreLongWeapon(store, itemId) -- luacheck: ignore 131
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
    return false, L('item_invalid')
  end
  local def = getItemDef(item.defId)
  if not def or not def.equipSlot then
    return false, L('not_equipable')
  end
  local slot = def.equipSlot

  if item.defId == 'cardboard_box' and hasBriefcaseEquipped(store) then
    return false, L('carry_box_briefcase')
  end

  if item.defId == 'safe' and hasBriefcaseEquipped(store) then
    return false, L('carry_safe_briefcase')
  end

  if item.defId == 'briefcase' and hasCardboardBoxEquipped(store) then
    return false, L('carry_briefcase_box')
  end

  if item.defId == 'briefcase' and hasSafeEquipped(store) then
    return false, L('carry_briefcase_safe')
  end

  if item.defId == 'cardboard_box' and hasSafeEquipped(store) then
    return false, L('carry_box_safe')
  end

  if item.defId == 'safe' and hasCardboardBoxEquipped(store) then
    return false, L('carry_safe_box')
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
    return false, L('slot_empty')
  end
  store.equipment[slot] = nil
  removeItemLocation(store, itemId)
  local ok = insertIntoActiveContainer(store, itemId)
  if not ok then
    store.equipment[slot] = itemId
    setItemLocation(store, itemId, { type = 'equipment', slot = slot })
    return false, L('no_space')
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
    itemLabel = L('locker_label', tostring(item.meta.lockerNumber))
    if item.meta.isOwnLocker then
      itemLabel = itemLabel .. L('locker_own_suffix')
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
          itemLabel = L('paint_pot_label', colorName)
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
        containerLabel = L('paint_pot_label', colorName)
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
  local key = getGridKey(coords) -- luacheck: ignore 211
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
    label = L('nearby_label'),
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
