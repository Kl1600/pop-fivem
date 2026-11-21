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
local function standbyPlacementError(store, containerId, toSlot, movingDefId, excludeSlot)
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
            return 'Emplacement occupé'
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
      return ('Pièce %dx%d : déborde de la grille'):format(mw, mh)
    end
    for dr = 0, mh - 1 do
      for dc = 0, mw - 1 do
        local bSlot = toSlot + dr * cols + dc
        if bSlot > maxSlots then
          return ('Pièce %dx%d : pas assez de place'):format(mw, mh)
        end
        if defAt(bSlot) then
          return ('Pièce %dx%d : cases occupées'):format(mw, mh)
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
    notify(src, 'Aucune boite a proximite')
    return
  end

  store.activeContainerId = container.id
  store.activeContainerIsGround = false
  
  -- Créer un conteneur virtuel pour le conteneur distant s'il n'existe pas
  if not store.containers[container.id] then
    store.containers[container.id] = {
      id = container.id,
      defId = '__remote_container__',
      label = 'Boite en Carton',
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
                notify(src, err or 'Action impossible')
              end
              return
            end
          end
        end
      end
    end
    notify(src, 'Aucune boite a proximite')
    return
  end

  store.activeContainerId = container.id
  store.activeContainerIsGround = false

  -- Créer un conteneur virtuel pour le conteneur distant s'il n'existe pas
  if not store.containers[container.id] then
    store.containers[container.id] = {
      id = container.id,
      defId = '__remote_container__',
      label = 'Boite en Carton',
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
  local boxLabel    = 'Boite en Carton'

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
    notify(src, 'Aucune boite a proximite')
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
local function buildSearchSections(src, store, tStore, targetIdentifier, targetId)
  clearSearchContainers(store, src)

  local cids, sections = {}, {}
  for _, eqSlot in ipairs(Config.Inventory.ContainerOrder or {}) do
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
  local wC = { id = wcid, defId = '__remote_standby__', label = 'Armes', slots = 6, maxWeight = 1000.0, weight = 0, items = {} }
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
    sections[#sections + 1] = { containerId = wcid, defId = 'weapons', label = 'Armes' }
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
    notify(src, 'Trop loin.')
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

  local cids, sections = buildSearchSections(src, store, tStore, targetIdentifier, targetId)

  if #cids == 0 then
    notify(src, 'Rien à fouiller (aucune poche).')
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

-- =====================================================
--  Actualisation EN DIRECT du conteneur distant ouvert.
--  Fouille : reconstruit les sections depuis l'inventaire ACTUEL de la cible.
--  Coffre distant (remote_standby_) : ré-importe depuis RemoteContainers (modifs
--  des autres joueurs). Le client défère le rendu s'il est en plein drag.
-- =====================================================
local function refreshOpenStandby(src)
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
    local cids, sections = buildSearchSections(src, store, tStore, sinfo.ident, sinfo.tsrc)
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
      pcall(refreshOpenStandby, src)
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
    notify(src, 'Aucune boite a proximite')
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
    notify(src, 'Impossible de prendre une boite avec une malette')
    return
  end

  if hasCardboardBoxEquipped(store) or hasSafeEquipped(store) then
    notify(src, 'Vous portez deja un conteneur')
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
    notify(src, 'Aucune boite a proximite')
    return
  end

  local itemToCreate = 'cardboard_box'
  if container.data and container.data.propModel == 'prop_ld_int_safe_01' then
    itemToCreate = 'safe'
  end

  local itemId = createItem(store, itemToCreate, 1)
  if not itemId then
    notify(src, 'Erreur creation item')
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
    notify(src, 'Impossible d\'equiper la boite')
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
    label = 'Stockage',
    slots = 30,
    maxWeight = 100.0,
    items = {},
  }
  return containerId
end

RegisterNetEvent('pop_inventory:server:openStandbyContainer', function(coords)
  local src = source
  -- Désactivé : ce « stockage perso » de 30 cases n'est ouvert par aucun point du
  -- jeu (repli du client seulement) et servait de coffre portable ouvrable partout.
  if true then return end
  local identifier = getIdentifier(src)
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

    local playerJob = nil
    if Config.Framework == 'esx' and ESX then
      local xPlayer = ESX.GetPlayerFromId(src)
      if xPlayer and xPlayer.job then
        playerJob = xPlayer.job.name
      end
    elseif Config.Framework == 'qbcore' and QBCore then
      local xPlayer = QBCore.Functions.GetPlayer(src)
      if xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.job then
        playerJob = xPlayer.PlayerData.job.name
      end
    end

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
      if Config.Framework == 'esx' and ESX then
        TriggerClientEvent('esx:showNotification', src, "~r~Vous n'avez pas le travail requis pour ouvrir ce coffre.")
      elseif Config.Framework == 'qbcore' and QBCore then
        TriggerClientEvent('QBCore:Notify', src, "Vous n'avez pas le travail requis pour ouvrir ce coffre.", "error")
      else
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Système', "Vous n'avez pas le travail requis pour ouvrir ce coffre." } })
      end
      return
    end
  end

  -- Un seul joueur à la fois dans ce coffre (sinon les synchros s'écrasent)
  if not acquireSharedLock(src, staticLockKey(chestId), lockInfo, { 'veh:', 'static:' }) then
    notify(src, 'Ce coffre est déjà utilisé par quelqu\'un.')
    return
  end

  local store = ensureStore(identifier)

  -- Cleanup: Retirer tout ancien conteneur statique/véhicule mal fermé
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' or container.defId == '__static_chest__' then
       -- Remove temporary items linked to this container
       for slot, itemId in pairs(container.items or {}) do
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
    for cId, c in pairs(sStore.containers) do
       containerId = cId
       break
    end
  end
  
  if not containerId then
    -- Look up config for this chest
    local chestConfig = nil
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
        for slot, itemId in pairs(container.items or {}) do
          if store.items[itemId] and store.items[itemId]._isTemporary then
            removeStoreItemTree(store, itemId)
          end
        end
        store.containers[cId] = nil
      elseif container.defId == '__remote_standby__' or container.defId == '__static_chest__' then
        -- Remove ALL items (synced to source above, nothing should stay in player store)
        for slot, itemId in pairs(container.items or {}) do
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
      local placeErr = standbyPlacementError(store, action.toContainerId, toSlot, movingDefId, excludeSlot)
      if placeErr then
        notify(src, placeErr)
      else
        local ok, err = moveItemBetweenContainers(store, action.fromContainerId, fromSlot, action.toContainerId, toSlot)
        if not ok then
          notify(src, err or 'Action impossible')
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
          notify(src, err or 'Action impossible')
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
      local placeErr = standbyPlacementError(store, action.toContainerId, toSlot, movingDefId, nil)
      if placeErr then
        notify(src, placeErr)
      else
        local ok, err = unequipToSlot(store, action.equipSlot, action.toContainerId, toSlot)
        if not ok then
          notify(src, err or 'Action impossible')
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
        pcall(refreshOpenStandby, osrc)
      end
    end
  end
end)

