-- =====================================================================
--  CAPOT / MOTEUR  -  Serveur
--  Ouvre le "conteneur distant" du capot d'un véhicule (comme le coffre),
--  contenant les pièces fixes : moteur (3x3, lui-même ouvrable) + batterie.
--  Le moteur contient : bloc_moteur (2x2) centré + 4 motorparts.
--
--  Réutilise toute la machinerie __vehicle_container__ : on préfixe la plaque
--  par 'ENG-' pour persister dans un store dédié 'plate:ENG-<plaque>'. Le sync
--  (syncVehicleContainerChanges) et la fermeture (closeStandbyContainer) le
--  gèrent donc automatiquement, exactement comme le coffre.
--
--  Réparation moteur (analyse mécano) : un piston_casse est inséré dans le moteur
--  quand le moteur est endommagé ; il faut le retirer pour valider la tâche.
-- =====================================================================

local ENGINE_SLOTS = 18       -- 6 colonnes x 3 rangées (assez pour moteur 3x3 + batterie)
local ENGINE_MAXWEIGHT = 800.0

-- Plaque du capot/moteur actuellement ouvert par chaque joueur. Nécessaire pour la
-- détection de réparation à la FERMETURE : le handler principal de close retire le
-- conteneur du store joueur AVANT que nos handlers tournent, donc getOpenEnginePlate
-- renverrait nil. On garde la plaque ici pour lire le store persistant (déjà synchro).
local OpenEnginePlate = {}

-- Moteurs en cours de réparation : [src] = plaque. La réparation se valide dès que le
-- piston cassé est remplacé par un motorpart neuf (détection autonome, sans barre).

-- Renvoie (vStore, vId, containerId, moteurId) du moteur d'une plaque, en créant
-- le store + la pré-installation (moteur, batterie, intérieur moteur) si besoin.
local function ensureEngineStore(plate)
  -- Plaque normalisée (trim) pour que toutes les sources (capot / analyse) tombent
  -- sur le MÊME store, peu importe le padding de GetVehicleNumberPlateText.
  plate = tostring(plate):gsub('^%s*(.-)%s*$', '%1')
  local engPlate = 'ENG-' .. plate
  local vId = 'plate:' .. engPlate
  if not Stores[vId] then
    Stores[vId] = loadStore(vId)
  end
  local vStore = Stores[vId]

  -- Référence FORCÉE et persistée du coffre moteur externe : une fois connue, on ne
  -- la redérive plus jamais via pairs()/defId (ambigu, le store contient aussi le
  -- sous-conteneur interne de l'item 'moteur'). engineContainerId est la SEULE
  -- source de vérité pour savoir quel conteneur est "le" moteur de cette plaque.
  local containerId = vStore.engineContainerId
  if containerId and not vStore.containers[containerId] then
    containerId = nil
  end

  if not containerId then
    -- Migration ponctuelle : un store déjà existant (créé avant l'ajout de ce champ)
    -- peut contenir le coffre moteur (defId 'vehicle_trunk') sans engineContainerId
    -- renseigné -> on le retrouve une dernière fois par defId, puis on le fige.
    for cId, c in pairs(vStore.containers) do
      if c.defId == 'vehicle_trunk' then
        containerId = cId
        break
      end
    end
  end

  local isNewContainer = false
  if not containerId then
    isNewContainer = true
    containerId = generateId('eng_' .. plate:gsub('[^%w]', ''))
    vStore.containers[containerId] = {
      id = containerId,
      defId = 'vehicle_trunk',
      slots = ENGINE_SLOTS,
      maxWeight = ENGINE_MAXWEIGHT,
      items = {},
    }
  end

  -- Pré-installation / réparation : un conteneur moteur existant (créé par une
  -- version antérieure de ce système, avant l'ajout des pièces, ou suite à un bug)
  -- peut exister sans ses pièces. On vérifie donc l'état réel à CHAQUE appel et on
  -- répare ce qui manque, plutôt que de ne le faire qu'à la création du conteneur.
  local repaired = isNewContainer
  local function addPart(toCid, defId, slot)
    local id = createItem(vStore, defId, 1)
    if not id then return nil end
    vStore.containers[toCid].items[slot] = id
    setItemLocation(vStore, id, { type = 'container', containerId = toCid, slot = slot })
    repaired = true
    return id
  end

  local vContainer = vStore.containers[containerId]
  local moteurId = vContainer.items[1]
  if not moteurId or not vStore.items[moteurId] then
    moteurId = addPart(containerId, 'moteur', 1)
  end
  local batterieId = vContainer.items[4]
  if not batterieId or not vStore.items[batterieId] then
    addPart(containerId, 'batterie', 4)
  end

  -- Intérieur du moteur : bloc_moteur (2x2) centré (slot 3) + 4 motorparts (2/5/8/11).
  local moteurItem = moteurId and vStore.items[moteurId]
  local innerCid = moteurItem and moteurItem.containerId
  if innerCid and vStore.containers[innerCid] then
    local inner = vStore.containers[innerCid]
    local function ensurePart(slot, defId)
      local id = inner.items[slot]
      if not id or not vStore.items[id] then
        addPart(innerCid, defId, slot)
      end
    end
    ensurePart(3, 'bloc_moteur')
    ensurePart(2, 'pieces_moteur')
    ensurePart(5, 'pieces_moteur')
    ensurePart(8, 'pieces_moteur')
    ensurePart(11, 'pieces_moteur')
  end

  if vStore.engineContainerId ~= containerId then
    vStore.engineContainerId = containerId
    repaired = true
  end

  if repaired then
    markDirty(vId)
    saveStore(vId, vStore)
  end

  return vStore, vId, containerId, vStore.containers[containerId].items[1]
end

-- Sous-conteneur (intérieur) du moteur + son id.
local function getMoteurInner(vStore, moteurId)
  local m = moteurId and vStore.items[moteurId]
  local cid = m and m.containerId
  return cid and vStore.containers[cid] or nil, cid
end

-- Le moteur d'une plaque contient-il un piston cassé ? (store persistant)
local function engineHasBrokenPiston(plate) -- luacheck: ignore 211
  local vStore, _, _, moteurId = ensureEngineStore(plate)
  local inner = getMoteurInner(vStore, moteurId)
  if not inner then return false end
  for _, iid in pairs(inner.items or {}) do
    if vStore.items[iid] and vStore.items[iid].defId == 'piston_casse' then
      return true
    end
  end
  return false
end

-- Le moteur est-il réparé ? = piston cassé retiré ET remplacé par un motorpart neuf
-- (>= 4 motorparts dans le moteur, contre 3 + 1 piston cassé à l'état endommagé).
local function engineRepairDone(plate)
  local vStore, _, _, moteurId = ensureEngineStore(plate)
  local inner = getMoteurInner(vStore, moteurId)
  if not inner then return false end
  local broken, parts = 0, 0
  for _, iid in pairs(inner.items or {}) do
    local it = vStore.items[iid]
    if it then
      if it.defId == 'piston_casse' then broken = broken + 1
      elseif it.defId == 'pieces_moteur' then parts = parts + 1 end
    end
  end
  return broken == 0 and parts >= 4
end

-- Casse un piston du moteur : remplace un motorpart (slot 5) par un piston_casse.
local function breakEnginePiston(plate)
  local vStore, vId, _, moteurId = ensureEngineStore(plate)
  local inner, innerCid = getMoteurInner(vStore, moteurId)
  if not inner then return end
  -- Déjà cassé : ne rien faire (idempotent).
  for _, iid in pairs(inner.items or {}) do
    if vStore.items[iid] and vStore.items[iid].defId == 'piston_casse' then return end
  end
  local slot = 5
  local existing = inner.items[slot]
  if existing then
    removeStoreItemTree(vStore, existing)
    inner.items[slot] = nil
  end
  local id = createItem(vStore, 'piston_casse', 1)
  if id then
    inner.items[slot] = id
    setItemLocation(vStore, id, { type = 'container', containerId = innerCid, slot = slot })
  end
  markDirty(vId)
  saveStore(vId, vStore)
end

-- ---------------------------------------------------------------------
--  Ouverture du capot (depuis standby_client / ox_target)
-- ---------------------------------------------------------------------
local isNearPlate = isPlayerNearPlate -- défini dans server/sv_utils.lua

RegisterNetEvent('pop_inventory:server:openVehicleEngine', function(plate)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end
  if not plate then return end
  plate = tostring(plate)
  if not isNearPlate(src, plate, 8.0) then return end
  OpenEnginePlate[src] = plate:gsub('^%s*(.-)%s*$', '%1')

  local store = ensureStore(identifier)

  -- Nettoyage préventif : un seul conteneur véhicule (coffre OU capot) ouvert à la fois.
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' then
      for _, itemId in pairs(container.items or {}) do
        if store.items[itemId] and store.items[itemId]._isTemporary then
          removeStoreItemTree(store, itemId)
        end
      end
      store.containers[cId] = nil
    end
  end

  local vStore, _, containerId = ensureEngineStore(plate)
  local engPlate = 'ENG-' .. plate
  local vContainer = vStore.containers[containerId]

  -- Injecte dans le store joueur comme conteneur véhicule temporaire.
  store.containers[containerId] = {
    id = containerId,
    defId = '__vehicle_container__',
    plate = engPlate,
    label = L('engine_label'),
    slots = vContainer.slots,
    maxWeight = vContainer.maxWeight,
    items = {},
  }

  for slot, itemId in pairs(vContainer.items) do
    local vItem = vStore.items[itemId]
    if vItem then
      copyItemTree(vStore, store, itemId, function(item)
        item._isTemporary = true
        item._vehiclePlate = engPlate
      end)
      store.containers[containerId].items[slot] = itemId
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

-- ---------------------------------------------------------------------
--  Pont avec l'analyse mécano (ox_target)
-- ---------------------------------------------------------------------
-- Insère un piston cassé dans le moteur (appelé quand l'analyse détecte le moteur HS).
RegisterNetEvent('vg_engine:server:breakPiston', function(plate)
  if not plate then return end
  if not isNearPlate(source, plate, 8.0) then return end
  breakEnginePiston(tostring(plate))
end)

-- Détection AUTONOME (aucun bouton de réparation) : le joueur ouvre le capot lui-même
-- (target "Ouvrir le capot") et remplace les pistons cassés. Dès que le moteur ouvert
-- est "réparé" (tous les motorparts présents, aucun piston cassé), on prévient le
-- client -> la case "Réparer le moteur" de la checklist se coche.
-- Ces handlers passent APRÈS le handler principal (sync du store véhicule déjà fait).

-- Plaque réelle du capot/moteur actuellement ouvert par le joueur (ou nil).
local function getOpenEnginePlate(src)
  local identifier = getIdentifier(src)
  if not identifier then return nil end
  local store = Stores[identifier]
  if not store then return nil end
  for _, c in pairs(store.containers or {}) do
    if c.defId == '__vehicle_container__' and type(c.plate) == 'string' and c.plate:sub(1, 4) == 'ENG-' then
      return c.plate:sub(5)
    end
  end
  return nil
end

local function checkEngineRepair(src)
  -- On privilégie la plaque trackée (valable même après retrait du conteneur à la
  -- fermeture). Fallback : conteneur encore ouvert.
  local plate = OpenEnginePlate[src] or getOpenEnginePlate(src)
  if not plate then return end
  if engineRepairDone(plate) then
    TriggerClientEvent('vg_engine:client:engineRepaired', src, plate)
  end
end

AddEventHandler('pop_inventory:server:standbyAction', function()
  checkEngineRepair(source)
end)

AddEventHandler('pop_inventory:server:closeStandbyContainer', function()
  checkEngineRepair(source)
  OpenEnginePlate[source] = nil
end)

AddEventHandler('playerDropped', function()
  if source then OpenEnginePlate[source] = nil end
end)

-- Réparation carrosserie : nécessite une pièce de carrosserie dans l'inventaire.
RegisterNetEvent('vg_engine:server:tryRepairBody', function()
  local src = source
  local count = exports.pop_inventory:getItemCount(src, 'pieces_carrosserie') or 0
  if count > 0 then
    TriggerClientEvent('vg_engine:client:bodyRepairAllowed', src)
  else
    TriggerClientEvent('vg_engine:client:bodyRepairBlocked', src)
  end
end)

-- Consomme la pièce de carrosserie (appelé après la réparation réussie).
RegisterNetEvent('vg_engine:server:consumeBodyPart', function()
  exports.pop_inventory:removeItem(source, 'pieces_carrosserie', 1)
end)

-- Remplacement de pneu : nécessite un item 'pneu' dans l'inventaire (même logique
-- que la carrosserie). wheel = index de la roue (0-3), renvoyé au client.
RegisterNetEvent('vg_engine:server:tryRepairTyre', function(wheel)
  local src = source
  wheel = tonumber(wheel)
  if not wheel or wheel < 0 or wheel > 3 then return end
  local count = exports.pop_inventory:getItemCount(src, 'pneu') or 0
  if count > 0 then
    TriggerClientEvent('vg_engine:client:tyreRepairAllowed', src, wheel)
  else
    TriggerClientEvent('vg_engine:client:tyreRepairBlocked', src, wheel)
  end
end)

-- Consomme le pneu (appelé après le remplacement réussi).
RegisterNetEvent('vg_engine:server:consumeTyre', function()
  exports.pop_inventory:removeItem(source, 'pneu', 1)
end)
