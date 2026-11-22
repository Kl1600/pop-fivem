function getNearbyRemoteContainer(source, coords)
  local playerCoords = safeCoordsOverride(source, coords) or getPlayerCoords(source)
  if not playerCoords then
    return nil
  end

  local closestDist = 3.0
  local closestContainer = nil

  for containerId, data in pairs(RemoteContainers) do
    if data.coords then
      local dist = #(playerCoords - vector3(data.coords.x, data.coords.y, data.coords.z))
      if dist <= closestDist then
        closestDist = dist
        closestContainer = { id = containerId, data = data }
      end
    end
  end

  return closestContainer
end

-- =====================================================
-- Armes longues = double case dans le coffre distant (gauche)
-- =====================================================
-- La grille gauche du coffre fait 6 colonnes. Une arme longue placée au slot N
-- (1-indexé, ordre row-major) "couvre" le slot N+1 de la même rangée. L'occupation
-- est DÉRIVÉE des données (pas de marqueur stocké) : une arme longue au slot N
-- implique que N+1 est inaccessible.
local STANDBY_COLS = 6

local function isLongWeaponDef(defId)
  if not defId then return false end
  local def = getItemDef(defId)
  if not def or not def.tags then return false end
  for _, tag in ipairs(def.tags) do
    if tag == 'weapon_long' then return true end
  end
  return false
end

-- Encombrement {w,h} d'une def : gridSpan explicite (ex: moteur 3x3), sinon une arme
-- longue occupe 2x1, sinon 1x1. Centralise la logique pour la validation de grille.
local function getDefSpan(defId)
  if not defId then return 1, 1 end
  local def = getItemDef(defId)
  if def and def.gridSpan and def.gridSpan.w and def.gridSpan.h then
    return def.gridSpan.w, def.gridSpan.h
  end
  if isLongWeaponDef(defId) then return 2, 1 end
  return 1, 1
end

-- Retourne un message d'erreur si le placement est interdit, sinon nil.
-- Gère les items multi-cases (gridSpan) : armes longues (2x1) ET moteur (3x3).
-- excludeSlot : slot à considérer comme vide (slot source d'un déplacement interne).
function Inv.standbyPlacementError(store, containerId, toSlot, movingDefId, excludeSlot)
  local c = store.containers[containerId]
  if not c then return nil end
  -- Grilles concernées : coffre distant, conteneurs véhicule (coffre / capot moteur)
  -- ET l'intérieur du moteur (defId 'moteur' -> bloc_moteur 2x2 à valider).
  if c.defId ~= '__remote_standby__' and c.defId ~= '__vehicle_container__' and c.defId ~= 'moteur' then return nil end

  local cols = STANDBY_COLS
  local maxSlots = c.slots or 0

  local function defAt(slot)
    if excludeSlot and slot == excludeSlot then return nil end
    local id = c.items[slot]
    return id and store.items[id] and store.items[id].defId or nil
  end
  -- col 0-indexée du slot (1-indexé)
  local function colOf(slot) return (slot - 1) % cols end

  -- 1) Le slot cible est-il déjà couvert par un item multi-cases dont l'ancre est
  --    en haut/à gauche (dans un rayon de 3 cases) ?
  local tcol = colOf(toSlot)
  for dr = 0, 2 do
    for dc = 0, 2 do
      if not (dr == 0 and dc == 0) and tcol - dc >= 0 then
        local aSlot = toSlot - dr * cols - dc
        if aSlot >= 1 then
          local aw, ah = getDefSpan(defAt(aSlot))
          if aw > dc and ah > dr then
            return L('placement_taken')
          end
        end
      end
    end
  end

  -- 2) L'item déplacé occupe w x h cases : le bloc entier doit tenir dans la grille
  --    et être libre.
  local mw, mh = getDefSpan(movingDefId)
  if mw > 1 or mh > 1 then
    if tcol + (mw - 1) > (cols - 1) then
      return L('placement_overflow', mw, mh)
    end
    for dr = 0, mh - 1 do
      for dc = 0, mw - 1 do
        local bSlot = toSlot + dr * cols + dc
        if bSlot > maxSlots then
          return L('placement_no_room', mw, mh)
        end
        if defAt(bSlot) then
          return L('placement_cells_taken', mw, mh)
        end
      end
    end
  end

  return nil
end

RegisterNetEvent('pop_inventory:server:openRemoteContainer', function()
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end

  local store = ensureStore(identifier)
  local ped = GetPlayerPed(src)
  local coords = GetEntityCoords(ped)

  local container = getNearbyRemoteContainer(src, { x = coords.x, y = coords.y, z = coords.z })
  if not container then
    notify(src, L('no_box_nearby_server'))
    return
  end

  store.activeContainerId = container.id
  store.activeContainerIsGround = false

  -- Créer un conteneur virtuel pour le conteneur distant s'il n'existe pas
  if not store.containers[container.id] then
    store.containers[container.id] = {
      id = container.id,
      defId = '__remote_container__',
      label = L('cardboard_box_label'),
      slots = 20,
      maxWeight = 30.0,
      weight = 0,
      items = {},
    }
  end

  -- Créer des items temporaires pour chaque item du conteneur distant
  for slot, itemData in pairs(container.data.itemData or {}) do
    if itemData and itemData.defId then
      -- Vérifier si un item existe déjà à ce slot
      if not store.containers[container.id].items[slot] then
        -- rebuildItemTree recrée aussi les conteneurs imbriqués (pot, sac…).
        local tempItemId = rebuildItemTree(store, itemData, true)
        if tempItemId then
          store.containers[container.id].items[slot] = tempItemId
          setItemLocation(store, tempItemId, { type = 'container', containerId = container.id, slot = tonumber(slot) })
        end
      end
    end
  end

  markDirty(identifier)
  sendState(src, { x = coords.x, y = coords.y, z = coords.z })
end)

RegisterNetEvent('pop_inventory:server:openRemoteContainerFromProp', function(coords)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end

  local store = ensureStore(identifier)

  local container = getNearbyRemoteContainer(src, coords)
  if not container then
    -- Fallback: tenter de ramasser un item équipable (boite/malette) depuis une pile au sol
    local pile = getNearbyGroundPile(src, coords)
    if pile then
      local groundContainer = GroundStore.containers[pile.containerId]
      if groundContainer then
        for slot, itemId in pairs(groundContainer.items) do
          local item = GroundStore.items[itemId]
          if item then
            local def = getItemDef(item.defId)
            if def and def.equipSlot then
              local ok, err = pickupEquipFromGround(src, store, slot, def.equipSlot, coords)
              if ok then
                markDirty(identifier)
                sendState(src, coords)
                TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
              else
                notify(src, err or L('action_impossible'))
              end
              return
            end
          end
        end
      end
    end
    notify(src, L('no_box_nearby_server'))
    return
  end

  store.activeContainerId = container.id
  store.activeContainerIsGround = false

  -- Créer un conteneur virtuel pour le conteneur distant s'il n'existe pas
  if not store.containers[container.id] then
    store.containers[container.id] = {
      id = container.id,
      defId = '__remote_container__',
      label = L('cardboard_box_label'),
      slots = 20,
      maxWeight = 30.0,
      weight = 0,
      items = {},
    }
  end

  -- Créer des items temporaires pour chaque item du conteneur distant
  for slot, itemData in pairs(container.data.itemData or {}) do
    if itemData and itemData.defId then
      -- Vérifier si un item existe déjà à ce slot
      if not store.containers[container.id].items[slot] then
        -- rebuildItemTree recrée aussi les conteneurs imbriqués (pot, sac…).
        local tempItemId = rebuildItemTree(store, itemData, true)
        if tempItemId then
          store.containers[container.id].items[slot] = tempItemId
          setItemLocation(store, tempItemId, { type = 'container', containerId = container.id, slot = tonumber(slot) })
        end
      end
    end
  end

  markDirty(identifier)
  sendState(src, coords)
end)

RegisterNetEvent('pop_inventory:server:openRemoteContainerStandby', function(coords)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then
    return
  end
  local store = ensureStore(identifier)

  local containerId = nil
  local itemsSource = {}  -- { [slotNumber] = { defId, qty, meta } }
  local boxSlots    = 20
  local boxMaxWeight = 30.0
  local boxLabel    = L('cardboard_box_label')

  -- 1. Remote container (carton posé en tant que container persistant)
  local remoteContainer = getNearbyRemoteContainer(src, coords)
  if remoteContainer then
    containerId = 'remote_standby_' .. remoteContainer.id
    for slot, itemData in pairs(remoteContainer.data.itemData or {}) do
      if itemData and itemData.defId then
        -- itemData est déjà un noeud sérialisé (item + conteneur imbriqué éventuel).
        itemsSource[tonumber(slot)] = itemData
      end
    end
  else
    -- 2. Fallback : ground pile contenant un item cardboard_box avec sous-container
    local pile = getNearbyGroundPile(src, coords)
    if pile then
      local groundContainer = GroundStore.containers[pile.containerId]
      if groundContainer then
        for _, itemId in pairs(groundContainer.items or {}) do
          local item = GroundStore.items[itemId]
          if item and (item.defId == 'cardboard_box' or item.defId == 'safe') and item.containerId then
            local boxContainer = GroundStore.containers[item.containerId]
            if boxContainer then
              local itemDef = getItemDef(item.defId)
              containerId = 'ground_standby_' .. item.containerId
              boxSlots     = boxContainer.slots     or (itemDef and itemDef.container and itemDef.container.slots) or boxSlots
              boxMaxWeight = boxContainer.maxWeight or (itemDef and itemDef.container and itemDef.container.maxWeight) or boxMaxWeight
              boxLabel     = (itemDef and itemDef.label) or boxLabel

              for boxSlot, boxItemId in pairs(boxContainer.items or {}) do
                local boxItem = GroundStore.items[boxItemId]
                if boxItem then
                  -- Sérialise l'arbre complet depuis GroundStore (item + conteneur imbriqué).
                  itemsSource[tonumber(boxSlot)] = serializeItemTree(GroundStore, boxItemId)
                end
              end
            end
            break
          end
        end
      end
    end
  end

  if not containerId then
    notify(src, L('no_box_nearby_server'))
    return
  end

  -- Nettoyer les anciens items temporaires si le container existe déjà
  if store.containers[containerId] then
    for _, itemId in pairs(store.containers[containerId].items or {}) do
      if store.items[itemId] and store.items[itemId]._isTemporary then
        removeStoreItemTree(store, itemId)
      end
    end
  end

  store.containers[containerId] = {
    id = containerId,
    defId = '__remote_standby__',
    label = boxLabel,
    slots = boxSlots,
    maxWeight = boxMaxWeight,
    weight = 0,
    items = {},
  }

  for slot, itemData in pairs(itemsSource) do
    if itemData and itemData.defId then
      -- rebuildItemTree recrée aussi les conteneurs imbriqués (pot, sac…).
      local tempItemId = rebuildItemTree(store, itemData, true)
      if tempItemId then
        store.containers[containerId].items[tonumber(slot)] = tempItemId
        setItemLocation(store, tempItemId, { type = 'container', containerId = containerId, slot = tonumber(slot) })
      end
    end
  end

  StandbyContainers[src] = containerId
  markDirty(identifier)

  local state = buildState(src, store, coords)
  state.standbyContainerId = containerId
  state.standbyContainer = buildContainerView(store, containerId)
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
end)

-- =====================================================
--  FOUILLE en mode standby : chaque conteneur équipé de la cible (pantalon, sac,
--  portefeuille…) devient une SECTION navigable à gauche (barre d'icônes standbyPath).
--  Items copiés en temporaires (_searchSrc) ; syncSearchChanges reporte prises/dépôts.
-- =====================================================
SearchStandby = SearchStandby or {} -- [src] = { ident, tsrc, cids = {..}, sections = {..} }

function syncSearchChanges(store, src)
  local info = SearchStandby[src]
  if not info then return end
  local tStore = ensureStore(info.ident)
  if not tStore then return end

  -- Items encore présents dans une section de fouille (toujours chez la cible).
  local stillIn = {}
  for _, cid in ipairs(info.cids or {}) do
    local sc = store.containers[cid]
    if sc then for _, itemId in pairs(sc.items or {}) do stillIn[itemId] = true end end
  end

  -- 1) PRIS : avaient _searchSrc, ont quitté la fouille -> retirer de la cible.
  local weaponTaken = false
  for itemId, item in pairs(store.items) do
    if item._searchSrc and not stillIn[itemId] then
      local origId = item._searchSrc.id
      local loc = tStore.itemLocations and tStore.itemLocations[origId]
      if loc and loc.type == 'container' and tStore.containers[loc.containerId] then
        tStore.containers[loc.containerId].items[loc.slot] = nil
      elseif loc and loc.type == 'equipment' then
        tStore.equipment[loc.slot] = nil
        weaponTaken = true
      end
      removeStoreItemTree(tStore, origId)
      item._isTemporary = nil
      item._searchSrc = nil
    end
  end

  -- 2) DÉPOSÉS : sans _searchSrc, désormais dans une section -> donner à la cible.
  for _, cid in ipairs(info.cids or {}) do
    local sc = store.containers[cid]
    if sc then
      for slot, itemId in pairs(sc.items or {}) do
        local item = store.items[itemId]
        if item and not item._searchSrc then
          autoInsertItem(tStore, item.defId, item.qty or 1, item.meta)
          sc.items[slot] = nil
          removeStoreItemTree(store, itemId)
        end
      end
    end
  end

  markDirty(info.ident)
  if info.tsrc and GetPlayerName(info.tsrc) then
    pcall(function() sendState(info.tsrc) end)
    -- Si on a retiré une arme équipée, mettre à jour le ped de la cible.
    if weaponTaken then
      pcall(function() TriggerClientEvent('pop_inventory:client:applyEquipment', info.tsrc, buildEquipmentDefs(tStore)) end)
    end
  end
end

-- Nettoie les conteneurs de fouille d'un joueur.
local function clearSearchContainers(store, src)
  local info = SearchStandby[src]
  if not info then return end
  for _, cid in ipairs(info.cids or {}) do
    local sc = store.containers[cid]
    if sc then
      for _, itemId in pairs(sc.items or {}) do
        if store.items[itemId] and store.items[itemId]._isTemporary then
          removeStoreItemTree(store, itemId)
        end
      end
      store.containers[cid] = nil
    end
  end
end

-- (Re)construit les sections de fouille depuis l'inventaire ACTUEL de la cible.
-- Retourne cids, sections. Réutilisé par l'ouverture ET l'actualisation en direct.
function Inv.buildSearchSections(src, store, tStore, targetIdentifier, targetId)
  clearSearchContainers(store, src)

  local cids, sections = {}, {}
  for _, eqSlot in ipairs(Config.InventorySettings.ContainerOrder or {}) do
    local eqItemId = tStore.equipment[eqSlot]
    local eqItem = eqItemId and tStore.items[eqItemId]
    if eqItem and eqItem.containerId then
      local c = tStore.containers[eqItem.containerId]
      if c then
        local def = getItemDef(eqItem.defId)
        local cid = ('search_%d_%s'):format(targetId, eqSlot)
        local newC = {
          id = cid, defId = '__remote_standby__',
          label = (def and def.label) or eqSlot,
          slots = c.slots or (def and def.container and def.container.slots) or 20,
          maxWeight = c.maxWeight or (def and def.container and def.container.maxWeight) or 50.0,
          weight = 0, items = {},
        }
        store.containers[cid] = newC
        for s, subId in pairs(c.items or {}) do
          local sub = tStore.items[subId]
          if sub then
            local tempId = generateId('search_tmp')
            store.items[tempId] = {
              id = tempId, defId = sub.defId, qty = sub.qty, meta = sub.meta or {},
              _isTemporary = true, _searchSrc = { ident = targetIdentifier, id = subId },
            }
            local ns = tonumber(s) or s
            newC.items[ns] = tempId
            setItemLocation(store, tempId, { type = 'container', containerId = cid, slot = ns })
          end
        end
        cids[#cids + 1] = cid
        sections[#sections + 1] = { containerId = cid, defId = eqSlot, label = (def and def.label) or eqSlot }
      end
    end
  end

  -- Section ARMES.
  local wcid = ('search_%d_weapons'):format(targetId)
  local wC = { id = wcid, defId = '__remote_standby__', label = L('weapons_label'), slots = 6, maxWeight = 1000.0, weight = 0, items = {} }
  local wslot = 0
  for _, eqSlot in ipairs({ 'weapon_long', 'weapon_pistol', 'weapon_tazer' }) do
    local wItemId = tStore.equipment[eqSlot]
    local wItem = wItemId and tStore.items[wItemId]
    if wItem then
      wslot = wslot + 1
      local tempId = generateId('search_tmp')
      store.items[tempId] = {
        id = tempId, defId = wItem.defId, qty = wItem.qty or 1, meta = wItem.meta or {},
        _isTemporary = true, _searchSrc = { ident = targetIdentifier, id = wItemId },
      }
      wC.items[wslot] = tempId
      setItemLocation(store, tempId, { type = 'container', containerId = wcid, slot = wslot })
    end
  end
  if wslot > 0 then
    store.containers[wcid] = wC
    cids[#cids + 1] = wcid
    sections[#sections + 1] = { containerId = wcid, defId = 'weapons', label = L('weapons_label') }
  end

  return cids, sections
end

RegisterNetEvent('pop_inventory:server:openSearchStandby', function(targetId)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end
  targetId = tonumber(targetId)
  if not targetId then return end

  local targetPed = GetPlayerPed(targetId)
  if not targetPed or targetPed == 0 then return end
  local srcPed = GetPlayerPed(src)
  if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.0 then
    notify(src, L('too_far_dot'))
    return
  end
  -- Anti-triche : même condition que l'ox_target "Fouiller" (mains levées, menotté ou mort)
  local tState = Player(targetId).state
  if not (tState.handsup == true or tState.handcuffed == true or tState.isDead == true
      or GetEntityHealth(targetPed) <= 0) then
    return
  end

  local targetIdentifier = getIdentifier(targetId)
  if not targetIdentifier then return end

  local store = ensureStore(identifier)
  local tStore = ensureStore(targetIdentifier)

  local cids, sections = Inv.buildSearchSections(src, store, tStore, targetIdentifier, targetId)

  if #cids == 0 then
    notify(src, L('nothing_to_search'))
    return
  end

  StandbyContainers[src] = cids[1]
  SearchStandby[src] = { ident = targetIdentifier, tsrc = targetId, cids = cids, sections = sections }
  markDirty(identifier)

  local state = buildState(src, store, nil)
  state.standbyContainerId = cids[1]
  state.standbyContainer = buildContainerView(store, cids[1])
  state.standbyPath = sections
  state.isSearch = true
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
end)
