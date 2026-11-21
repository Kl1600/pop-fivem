-- =====================================================
--  CASIERS (lockers) — Config.LockerRooms
--
--  Une salle de casiers est un conteneur distant persistant et partagé par job
--  (même mécanique que Config.StaticChests : Stores['static_'..id]), peuplé une
--  fois pour toutes de `count` items 'casier' (1 par matricule possible). Chaque
--  casier a son propre sous-conteneur, comme un coffre-fort/sac.
--
--  Le matricule et le code de chaque employé NE SONT PAS stockés ici : ils sont
--  demandés en direct à pop_management (export) à chaque ouverture. Changer le
--  code ou réassigner un matricule depuis la fiche employé prend donc effet
--  immédiatement, sans toucher au contenu déjà rangé dans les casiers.
--
--  Deux accès (prompt v3DUI + touche, point fixe — cf. standby_client.lua) :
--   - 'openMyLocker'    : touche E (défaut). Ouvre directement SON casier (matricule =
--                         numéro d'employé pour ce job) : le standby pointe sur le
--                         sous-conteneur du casier, donc on arrive d'office dans son
--                         contenu, comme un pot de peinture laissé ouvert. Ni liste ni code.
--   - 'openLockerRoom'  : touche G. Parcourir TOUS les casiers (grille).
--  Le clic droit "Ouvrir" sur un casier dans la grille passe par sv_actions.lua
--  (actionType == 'open'), qui demande le code sauf si le casier est le vôtre.
-- =====================================================

local function getLockerRoomConfig(id)
  for _, lr in ipairs(Config.LockerRooms or {}) do
    if lr.id == id then
      return lr
    end
  end
  return nil
end

local function getPlayerJobName(src)
  if Config.Framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.job and xPlayer.job.name or nil
  elseif Config.Framework == 'qbcore' and QBCore then
    local xPlayer = QBCore.Functions.GetPlayer(src)
    return xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.job and xPlayer.PlayerData.job.name or nil
  end
  return nil
end

-- Charge (ou crée + peuple) le conteneur partagé de la salle de casiers.
-- Retourne sStore, containerId (id du conteneur '__static_chest__'-like contenant
-- les `count` items 'casier').
local function getOrCreateLockerRoomContainer(lockerConfig)
  local sId = 'static_' .. lockerConfig.id
  if not Stores[sId] then
    Stores[sId] = loadStore(sId)
  end
  local sStore = Stores[sId]

  local containerId = nil
  for cId, c in pairs(sStore.containers) do
    if c.defId == 'static_chest' then
      containerId = cId
      break
    end
  end

  if not containerId then
    containerId = generateId('static_' .. lockerConfig.id)
    sStore.containers[containerId] = {
      id = containerId,
      defId = 'static_chest',
      slots = lockerConfig.count or 0,
      maxWeight = 1000000.0, -- le poids se gère par casier (def.container), pas par la salle
      items = {},
    }

    for i = 1, (lockerConfig.count or 0) do
      local itemId = createItem(sStore, 'casier', 1, { lockerNumber = i, job = lockerConfig.job })
      if itemId then
        sStore.containers[containerId].items[i] = itemId
        setItemLocation(sStore, itemId, { type = 'container', containerId = containerId, slot = i })
      end
    end

    sStore._dirty = true
    saveStore(sId, sStore)
  end

  return sStore, containerId
end

-- Injecte la salle de casiers (conteneur + tous les casiers, avec leur sous-conteneur)
-- dans le store du joueur, exactement comme un coffre statique classique
-- (cf. server/sv_remote_containers.lua, openStaticChest). Si `myLockerNumber` est fourni,
-- le casier correspondant est tagué meta.isOwnLocker = true (posé côté serveur, jamais
-- fourni par le client) afin que sv_actions.lua le laisse s'ouvrir sans code.
local function injectLockerRoom(store, lockerConfig, sStore, containerId, myLockerNumber)
  -- Nettoyage des anciens conteneurs statiques/véhicule mal fermés
  for cId, container in pairs(store.containers) do
    if container.defId == '__vehicle_container__' or container.defId == '__static_chest__' then
      for _, itemId in pairs(container.items or {}) do
        if store.items[itemId] and store.items[itemId]._isTemporary then
          removeStoreItemTree(store, itemId)
        end
      end
      store.containers[cId] = nil
    end
  end

  local sContainer = sStore.containers[containerId]
  store.containers[containerId] = {
    id = containerId,
    defId = '__static_chest__',
    label = lockerConfig.label or 'Casiers',
    slots = sContainer.slots,
    maxWeight = sContainer.maxWeight,
    items = {},
    _staticChestId = lockerConfig.id,
  }

  for slot, itemId in pairs(sContainer.items) do
    if sStore.items[itemId] then
      copyItemTree(sStore, store, itemId, function(item)
        item._isTemporary = true
        item._staticChestId = lockerConfig.id
        if item.defId == 'casier' and myLockerNumber and item.meta and item.meta.lockerNumber == myLockerNumber then
          item.meta.isOwnLocker = true
        end
      end)
      store.containers[containerId].items[slot] = itemId
      setItemLocation(store, itemId, { type = 'container', containerId = containerId, slot = slot })
    end
  end
end

local function checkLockerRoomAccess(src, lockerConfig)
  if lockerConfig.job then
    local job = getPlayerJobName(src)
    if job ~= lockerConfig.job then
      notify(src, "Vous n'avez pas le travail requis pour accéder à ces casiers.")
      return false
    end
  end
  -- Anti-triche : le joueur doit être devant la salle des casiers
  if lockerConfig.coords then
    local ped = GetPlayerPed(src)
    local pc = ped ~= 0 and GetEntityCoords(ped)
    if pc and #(pc) > 1.0 and #(pc - vector3(lockerConfig.coords.x, lockerConfig.coords.y, lockerConfig.coords.z)) > (lockerConfig.radius or 1.5) + 5.0 then
      return false
    end
  end
  return true
end

local function doOpenLockerRoom(src, identifier, lockerConfig, myLockerNumber)
  local store = ensureStore(identifier)
  local sStore, containerId = getOrCreateLockerRoomContainer(lockerConfig)
  injectLockerRoom(store, lockerConfig, sStore, containerId, myLockerNumber)

  StandbyContainers[src] = containerId
  saveStore(identifier, store)

  local state = buildState(src, store)
  state.standbyContainerId = containerId
  state.standbyContainer = buildContainerView(store, containerId)
  StateSeq[src] = (StateSeq[src] or 0) + 1
  state._seq = StateSeq[src]
  TriggerClientEvent('pop_inventory:client:state', src, state)
end

RegisterNetEvent('pop_inventory:server:openLockerRoom', function(lockerRoomId)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  local lockerConfig = getLockerRoomConfig(lockerRoomId)
  if not lockerConfig then return end
  if not checkLockerRoomAccess(src, lockerConfig) then return end

  if GetResourceState('pop_management') ~= 'started' then
    doOpenLockerRoom(src, identifier, lockerConfig, nil)
    return
  end

  local job = lockerConfig.job or getPlayerJobName(src)
  exports['pop_management']:getEmployeeLockerNumber(identifier, job, function(myLockerNumber)
    doOpenLockerRoom(src, identifier, lockerConfig, myLockerNumber)
  end)
end)

RegisterNetEvent('pop_inventory:server:openMyLocker', function(lockerRoomId)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  local lockerConfig = getLockerRoomConfig(lockerRoomId)
  if not lockerConfig then return end
  if not checkLockerRoomAccess(src, lockerConfig) then return end

  if GetResourceState('pop_management') ~= 'started' then
    notify(src, 'Système de matricule indisponible (pop_management).')
    return
  end

  local job = lockerConfig.job or getPlayerJobName(src)

  exports['pop_management']:getEmployeeLockerNumber(identifier, job, function(lockerNumber)
    if not lockerNumber then
      notify(src, "Vous n'avez pas de casier attribué pour ce métier.")
      return
    end

    local store = ensureStore(identifier)
    local sStore, containerId = getOrCreateLockerRoomContainer(lockerConfig)
    injectLockerRoom(store, lockerConfig, sStore, containerId, lockerNumber)

    local mainContainer = store.containers[containerId]
    local myContainerId = nil
    for _, itemId in pairs(mainContainer.items) do
      local it = store.items[itemId]
      if it and it.defId == 'casier' and it.meta and it.meta.lockerNumber == lockerNumber then
        myContainerId = it.containerId
        break
      end
    end

    if not myContainerId then
      notify(src, 'Casier introuvable.')
      return
    end

    StandbyContainers[src] = myContainerId
    saveStore(identifier, store)

    local state = buildState(src, store)
    state.standbyContainerId = myContainerId
    state.standbyContainer = buildContainerView(store, myContainerId)
    StateSeq[src] = (StateSeq[src] or 0) + 1
    state._seq = StateSeq[src]
    TriggerClientEvent('pop_inventory:client:state', src, state)
  end)
end)
