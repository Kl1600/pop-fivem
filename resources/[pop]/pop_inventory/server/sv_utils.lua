function debugPrint(...)
  if Config.Debug or Config.DebugOptions.PrintActions then
    print('[POP_INVENTORY]', ...)
  end
end

function generateId(prefix)
  idCounter = idCounter + 1
  return string.format('%s_%d_%d', prefix, os.time(), idCounter)
end

function createStore()
  return {
    items = {},
    containers = {},
    equipment = {},
    itemLocations = {},
    containerOwners = {},
    activeContainerId = nil,
    activeContainerIsGround = false,
  }
end

-- Cache source -> identifiant ESX : sert pendant playerDropped, quand ESX a déjà
-- retiré le joueur (sinon l'inventaire ne serait pas sauvegardé à la déconnexion).
local SourceIdentifier = {}

function getIdentifier(source)
  if not source or source == 0 or source == '' then
    return nil
  end
  source = tonumber(source) or source
  if ESX then
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.identifier then
      SourceIdentifier[source] = xPlayer.identifier
      return xPlayer.identifier
    end
    -- Pas de repli sur la license en ESX : un joueur pas encore chargé aurait
    -- sinon un inventaire vide (chargé sous sa license) et apparaîtrait en caleçon.
    return SourceIdentifier[source]
  elseif QBCore then
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer and xPlayer.PlayerData.citizenid then
      return xPlayer.PlayerData.citizenid
    end
  end

  local license = GetPlayerIdentifierByType(source, 'license')
  if license and license ~= '' then
    return license
  end

  local identifiers = GetPlayerIdentifiers(source)
  return identifiers and identifiers[1]
end

-- Le cache est vidé un peu après la déconnexion, une fois les sauvegardes faites
-- (appelé par l'unique playerDropped de sv_exports.lua).
function forgetSourceIdentifier(src)
  src = tonumber(src) or src
  SetTimeout(10000, function() SourceIdentifier[src] = nil end)
end

function toVector3(coords)
  if not coords then
    return nil
  end
  if type(coords) == 'table' and coords.x then
    return vector3(coords.x, coords.y, coords.z)
  end
  return coords
end

-- Coordonnées fournies par le client : acceptées seulement si proches de la position
-- serveur réelle du joueur (sinon nil -> repli sur la position serveur). Empêche de
-- ramasser/ouvrir des piles ou conteneurs à l'autre bout de la carte.
function safeCoordsOverride(source, coords, maxDist)
  local vec = toVector3(coords)
  if type(vec) ~= 'vector3' then return nil end
  if source and source ~= 0 then
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
      local pc = GetEntityCoords(ped)
      if #(pc) > 1.0 and #(pc - vec) > (maxDist or 10.0) then return nil end
    end
  end
  return vec
end

function updatePlayerCoords(source, coords)
  local vec = toVector3(coords)
  if not vec then
    return
  end
  PlayerCoords[source] = vec
end

function getPlayerCoords(source)
  local ped = GetPlayerPed(source)
  if ped and ped ~= 0 then
    return GetEntityCoords(ped)
  end
  return PlayerCoords[source]
end

function normalizeSection(value)
  local section = tostring(value or ''):lower()
  section = section:gsub('%.svg$', '')
  section = section:gsub('%s+', '')
  if section == 'hoodie' then
    section = 'hoddie'
  end
  if section == 'pants' then
    section = 'panta'
  end
  return section
end

function listContains(list, value)
  if not list then
    return false
  end
  for _, entry in ipairs(list) do
    if entry == value then
      return true
    end
  end
  return false
end

function metaKey(meta)
  return json.encode(meta or {})
end

function rebuildLocations(store)
  if not store then return end
  store.itemLocations = {}
  store.containerOwners = {}

  -- Fusion de toutes les itérations en une seule boucle pour les items
  local it = 0
  for itemId, item in pairs(store.items) do
    it = it + 1
    if it % 250 == 0 then Wait(0) end -- Anti-freeze

    if item and item.containerId then
      store.containerOwners[item.containerId] = itemId
    end
  end

  -- Nettoyage et reconstruction des conteneurs
  for containerId, container in pairs(store.containers) do
    it = it + 1
    if it % 200 == 0 then Wait(0) end

    local rebuilt = {}
    for slot, itemId in pairs(container.items or {}) do
      local slotIndex = tonumber(slot)
      if slotIndex then
        rebuilt[slotIndex] = itemId
        if itemId then
          store.itemLocations[itemId] = { type = 'container', containerId = containerId, slot = slotIndex }
        end
      end
    end
    container.items = rebuilt
  end

  -- Reconstruction des slots d'équipement
  for slot, itemId in pairs(store.equipment or {}) do
    if itemId then
      store.itemLocations[itemId] = { type = 'equipment', slot = slot }
    end
  end
end


function getGridKey(coords)
  if not coords then return "0,0" end
  return math.floor(coords.x / 50) .. "," .. math.floor(coords.y / 50)
end

function updatePileInGrid(pile, isRemoving)
  if not pile or not pile.coords then return end
  local key = getGridKey(pile.coords)
  if not GroundGrid[key] then GroundGrid[key] = {} end
  if isRemoving then
    GroundGrid[key][pile.id] = nil
  else
    GroundGrid[key][pile.id] = pile
  end
end

function getGroundSaveId()
  return (Config.Persistence and Config.Persistence.GroundSaveId) or 'ground'
end

isSavePending = false
function pruneEmptyGroundPiles()
  local changed = false
  local count = 0
  for pileId, pile in pairs(GroundPiles) do
    count = count + 1
    if count % 100 == 0 then Wait(0) end -- Timeout anti-freeze

    local containerId = pile and pile.containerId
    local container = containerId and GroundStore.containers[containerId] or nil
    local hasItems = false
    if container and container.items then
      for _, itemId in pairs(container.items) do
        if itemId then
          hasItems = true
          break
        end
      end
    end
    if not container or not hasItems then
      if containerId then
        GroundStore.containers[containerId] = nil
      end
      -- Retirer de la grille avant de supprimer la pile
      updatePileInGrid(pile, true)
      GroundPiles[pileId] = nil
      changed = true
    end
  end
  if changed then
    for source, focusId in pairs(PlayerGroundFocus) do
      if focusId and not GroundPiles[focusId] then
        PlayerGroundFocus[source] = nil
      end
    end
    rebuildLocations(GroundStore)
    syncGroundDropEntities()
  end
  return changed
end

function saveGround(force)
  if not (Config.Persistence and Config.Persistence.GroundToDatabase) or not MySQL then
    return
  end
  local tableName = safeTableName(Config.Persistence.GroundTable)
  if not tableName or tableName == '' then
    return
  end
  if not force and not groundDirty then
    return
  end

  -- Rebuild cache before encoding
  pruneEmptyGroundPiles()

  local payload = json.encode({
    piles = GroundPiles,
    items = GroundStore.items,
    containers = GroundStore.containers,
  })

  mysqlUpdate(
    string.format('INSERT INTO `%s` (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', tableName),
    { getGroundSaveId(), payload },
    function()
      groundDirty = false
      debugPrint('[Persistence] Sol sauvegardé avec succès.')
    end
  )
end

function triggerDelayedGroundSave()
  if isSavePending then return end
  isSavePending = true
  SetTimeout(5000, function()
      saveGround(true)
      isSavePending = false
  end)
end

function markGroundDirty()
  groundDirty = true
  CachedGroundSnapshot = nil -- Invalider le cache
  syncGroundDropEntities()   -- Mettre à jour les props immédiatement
  triggerDelayedGroundSave() -- Planifier une sauvegarde
end

function pileHasItems(pile)
  if not pile or not pile.containerId then
    return false
  end
  local container = GroundStore.containers[pile.containerId]
  if not container or not container.items then
    return false
  end
  for _, itemId in pairs(container.items) do
    if itemId then
      return true
    end
  end
  return false
end

function setItemLocation(store, itemId, location)
  store.itemLocations[itemId] = location
end

function removeItemLocation(store, itemId)
  store.itemLocations[itemId] = nil
end

function purgeItemFromGround(itemId)
  if not itemId then
    return
  end
  for _, container in pairs(GroundStore.containers) do
    for slot, storedId in pairs(container.items or {}) do
      if storedId == itemId then
        container.items[slot] = nil
      end
    end
  end
  GroundStore.items[itemId] = nil
  removeItemLocation(GroundStore, itemId)
end

function bumpIdCounterFromGround()
  local maxCounter = idCounter
  local function checkId(value)
    if type(value) ~= 'string' then
      return
    end
    local counter = value:match('^%w+_%d+_(%d+)$')
    if counter then
      local num = tonumber(counter)
      if num and num > maxCounter then
        maxCounter = num
      end
    end
  end

  for itemId, item in pairs(GroundStore.items or {}) do
    checkId(itemId)
    if item and item.containerId then
      checkId(item.containerId)
    end
  end

  for containerId, _ in pairs(GroundStore.containers or {}) do
    checkId(containerId)
  end

  for pileId, pile in pairs(GroundPiles or {}) do
    checkId(pileId)
    if pile and pile.containerId then
      checkId(pile.containerId)
    end
  end

  idCounter = maxCounter
end

function loadGround()
  if groundLoaded then
    return
  end
  if not (Config.Persistence and Config.Persistence.GroundToDatabase) then
    groundLoaded = true
    return
  end
  if not MySQL then
    return
  end
  local tableName = safeTableName(Config.Persistence.GroundTable)
  if not tableName or tableName == '' then
    groundLoaded = true
    return
  end
  local row = mysqlSingle(string.format('SELECT data FROM `%s` WHERE id = ?', tableName), { getGroundSaveId() })
  if not row or not row.data then
    groundLoaded = true
    return
  end
  local decoded = json.decode(row.data)
  if type(decoded) ~= 'table' then
    groundLoaded = true
    return
  end
  GroundPiles = decoded.piles or decoded.groundPiles or {}
  GroundStore.items = decoded.items or (decoded.store and decoded.store.items) or {}
  GroundStore.containers = decoded.containers or (decoded.store and decoded.store.containers) or {}
  GroundStore.itemLocations = {}
  GroundStore.containerOwners = {}

  -- Initialiser la grille spatiale
  GroundGrid = {}
  for _, pile in pairs(GroundPiles) do
    updatePileInGrid(pile)
  end

  rebuildLocations(GroundStore)
  pruneEmptyGroundPiles()
  bumpIdCounterFromGround()
  groundLoaded = true
end

function ensureGroundLoaded()
  if not groundLoaded then
    loadGround()
  end
end

-- The saveGround function was duplicated, keeping the first definition.

CreateThread(function()
  loadGround()
  Wait(2000) -- attendre que utility_lib soit prêt
  syncGroundDropEntities()
end)


-- Anti-triche : le joueur doit être près d'un véhicule portant cette plaque
-- (sinon n'importe quel moteur serait ouvrable à distance avec une plaque arbitraire).
function isPlayerNearPlate(src, plate, maxDist)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return false end
  local pc = GetEntityCoords(ped)
  if #(pc) < 1.0 then return true end -- position serveur non fiable : on ne bloque pas
  local wanted = tostring(plate):gsub('%s+', ''):upper()
  for _, veh in ipairs(GetAllVehicles()) do
    if #(GetEntityCoords(veh) - pc) <= (maxDist or 8.0) then
      local vp = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', ''):upper()
      if vp == wanted then return true end
    end
  end
  return false
end

