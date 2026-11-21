-- pop_vehiclepersistence : serveur (OneSync requis).
-- Les véhicules suivis sont gardés en mémoire (Vehicles[plate]) et en base ; l'entité n'existe que si un joueur est proche.
-- Le client n'envoie qu'un netId et des propriétés visuelles : position, cap, plaque, modèle, type, verrouillage,
-- santé et propriétaire sont toujours lus côté serveur.

local RES = GetCurrentResourceName()

local TICK             = 5000    -- ms, boucle de proximité
local SAVE_TICK        = 60000   -- ms, sauvegarde différentielle
local EXPIRE_TICK      = 3600000 -- ms, expiration
local DESPAWN_MARGIN   = 50.0    -- m
local SPAWN_BUDGET     = 5       -- créations max par tick
local EXIT_DISTANCE    = 10.0    -- m, joueur qui vient de sortir
local UPDATE_COOLDOWN  = 2000    -- ms par joueur
local OWNED_CACHE      = 300     -- s
local PROPS_MAX_LENGTH = 8192    -- caractères JSON
local SPAWN_TIMEOUT    = 3000    -- ms

local WRITE_DELAY     = 2000  -- ms, une écriture max par plaque
local OWNER_TIMEOUT   = 5000  -- ms, attente d'un propriétaire réseau après création
local OWNER_STEP      = 100   -- ms
local PENDING_RESEND  = 10000 -- ms, statebag reposé si les props ne sont toujours pas appliquées
local PENDING_SETTLE  = 1500  -- ms après 'applied' avant de relire la santé serveur
local SQL_STUCK       = 10000 -- ms, une requête sans réponse au-delà ne bloque plus la file de la plaque
-- NOTE: GetVehicleMaxNumberOfPassengers n'existe pas côté serveur : on teste les sièges -1..14 (16 places max).
local MAX_SEAT = 14
local STATE_PROPS = 'pop_vehiclepersistence_props'

-- Champs de props toujours lus côté serveur (jamais pris au client).
local SERVER_FIELDS = { 'bodyHealth', 'engineHealth', 'tankHealth', 'dirtLevel' }

local SQL_CREATE = [[
CREATE TABLE IF NOT EXISTS `pop_vehiclepersistence` (
    `plate`      VARCHAR(8)   NOT NULL,
    `plate_text` VARCHAR(8)   NULL,
    `owner`      VARCHAR(64)  NOT NULL,
    `model`      BIGINT       NOT NULL,
    `vtype`      VARCHAR(16)  NOT NULL DEFAULT 'automobile',
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `heading`    FLOAT        NOT NULL DEFAULT 0,
    `locked`     TINYINT(1)   NOT NULL DEFAULT 1,
    `props`      LONGTEXT     NULL,
    `seen`       INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`),
    KEY `idx_owner` (`owner`)
)]]

-- Migration des tables créées avant l'ajout de `plate_text`.
local SQL_HAS_PLATE_TEXT = [[
SELECT COUNT(*) AS n FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pop_vehiclepersistence' AND COLUMN_NAME = 'plate_text']]
local SQL_ADD_PLATE_TEXT = 'ALTER TABLE `pop_vehiclepersistence` ADD COLUMN `plate_text` VARCHAR(8) NULL AFTER `plate`'

-- NOTE: `props` est le dernier paramètre : s'il vaut nil, oxmysql complète par NULL.
local SQL_UPSERT = [[
INSERT INTO `pop_vehiclepersistence` (`plate`, `owner`, `model`, `vtype`, `x`, `y`, `z`, `heading`, `locked`, `seen`, `plate_text`, `props`)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE `owner` = VALUES(`owner`), `model` = VALUES(`model`), `vtype` = VALUES(`vtype`),
    `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `heading` = VALUES(`heading`),
    `locked` = VALUES(`locked`), `seen` = VALUES(`seen`), `plate_text` = VALUES(`plate_text`), `props` = VALUES(`props`)]]

local SQL_DELETE = 'DELETE FROM `pop_vehiclepersistence` WHERE `plate` = ?'

-- Table du framework : d'abord une recherche exacte (index sur `plate`), puis, seulement si rien n'est trouvé,
-- la comparaison sans espaces (plaques saisies autrement par certains garages).
local FW_SQL = {
    esx = {
        exact = 'SELECT owner, stored FROM owned_vehicles WHERE plate IN (?, ?, ?) LIMIT 1',
        loose = "SELECT owner, stored FROM owned_vehicles WHERE REPLACE(plate, ' ', '') = ? LIMIT 1",
    },
    qb = {
        exact = 'SELECT citizenid, state FROM player_vehicles WHERE plate IN (?, ?, ?) LIMIT 1',
        loose = "SELECT citizenid, state FROM player_vehicles WHERE REPLACE(plate, ' ', '') = ? LIMIT 1",
    },
}

------------------------------------------------------------------------
-- Plaques (même règle que pop_vehiclekeys)
------------------------------------------------------------------------

local Plate = {}

--- Plaque normalisée (sans espaces, majuscules, 1 à 8 caractères alphanumériques) ou nil.
function Plate.Normalize(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('%s', ''):upper()
    if #plate < 1 or #plate > 8 or not plate:match('^%w+$') then return nil end
    return plate
end

--- Texte brut affiché sur la plaque (espaces compris), s'il correspond à la plaque normalisée ; sinon la plaque.
function Plate.Text(raw, plate)
    if type(raw) ~= 'string' or #raw > 8 or not raw:match('^[%w ]+$') or Plate.Normalize(raw) ~= plate then
        return plate
    end
    return raw
end

------------------------------------------------------------------------
-- État
------------------------------------------------------------------------

local Vehicles = {}     -- [plate] = enregistrement (SPEC 3.2, + plateText)
local Mode = 'all'      -- mode effectif
local FwTable = nil     -- 'esx' | 'qb' | nil
local loaded = false
local shuttingDown = false

local lastUpdate = {}   -- [src] = GetGameTimer() du dernier envoi au volant
local lastExit = {}     -- [src] = GetGameTimer() du dernier envoi à la sortie
local lastDriven = {}   -- [src] = dernière entité vue (par le serveur) avec ce joueur au volant
local ownedCache = {}   -- [plate] = { t = os.time(), v = { owner, stored = false } } (positifs uniquement)
local writeQueued = {}  -- [plate] = true si une écriture est programmée
local lastWrite = {}    -- [plate] = GetGameTimer() de la dernière écriture
local sqlBusy = {}      -- [plate] = GetGameTimer() du lancement de la requête en cours
local sqlNext = {}      -- [plate] = { query, params } : dernière requête en attente (la plus récente gagne)

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

local function info(msg, ...)
    print(('[%s] ' .. msg):format(RES, ...))
end

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function clamp(n, lo, hi, default)
    if not finite(n) then return default end
    n = math.max(lo, math.min(hi, n))
    return math.floor(n * 10 + 0.5) / 10
end

local function exists(e)
    return e ~= nil and e ~= 0 and DoesEntityExist(e)
end

-- Hash de modèle normalisé sur 32 bits non signés (signé côté natives, BIGINT en base).
local function modelKey(m)
    m = math.tointeger(tonumber(m))
    return m and (m & 0xFFFFFFFF) or nil
end

local function sameModel(a, b)
    local ka = modelKey(a)
    return ka ~= nil and ka == modelKey(b)
end

-- Aucun siège occupé (joueur ou PNJ).
local function isEmpty(veh)
    for seat = -1, MAX_SEAT do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 then return false end
    end
    return true
end

-- Un client possède l'entité (ses données de synchronisation sont fiables).
local function hasOwner(e)
    local owner = NetworkGetEntityOwner(e)
    return owner ~= nil and owner > 0
end

local function validPlayer(src)
    src = tonumber(src)
    if not src or math.type(src) ~= 'integer' or src <= 0 then return nil end
    if not GetPlayerName(src) or not Bridge.GetPlayer(src) then return nil end
    return src
end

local function vehicleFromNet(netId)
    if math.type(netId) ~= 'integer' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not exists(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function isTemporary(veh)
    return Entity(veh).state.pop_temporary == true
end

-- Une entité est-elle rattachée à un enregistrement ?
local function isTracked(e)
    for _, r in pairs(Vehicles) do
        if r.entity == e then return true end
    end
    return false
end

-- Fin de suivi sans suppression : le jeu reprend la main sur l'entité (si plus aucun enregistrement ne la garde).
local function release(e)
    if exists(e) and not isTracked(e) then SetEntityOrphanMode(e, 0) end
end

-- Rattache veh à rec ; tout autre enregistrement qui pointait sur la même entité est détaché.
local function attach(rec, veh)
    for _, r in pairs(Vehicles) do
        if r ~= rec and r.entity == veh then
            r.entity = nil
            r.pending = nil
            log('detached %s (entity now carries %s)', r.plate, rec.plate)
        end
    end
    if rec.entity ~= veh then rec.pending = nil end
    rec.entity = veh
    SetEntityOrphanMode(veh, 2)
end

------------------------------------------------------------------------
-- Base de données (écritures sérialisées par plaque)
------------------------------------------------------------------------

local sqlRun

local function sqlDone(plate)
    sqlBusy[plate] = nil
    local nxt = sqlNext[plate]
    sqlNext[plate] = nil
    if nxt then sqlRun(plate, nxt[1], nxt[2]) end
end

local function isBusy(plate)
    local t = sqlBusy[plate]
    return t ~= nil and GetGameTimer() - t < SQL_STUCK
end

-- Une requête à la fois par plaque ; en attente, seule la plus récente est gardée (chaque requête décrit l'état complet).
function sqlRun(plate, query, params)
    if isBusy(plate) then
        sqlNext[plate] = { query, params }
        return
    end
    sqlBusy[plate] = GetGameTimer()
    MySQL.query(query, params, function() sqlDone(plate) end)
end

local function snapshot(rec)
    local p = rec.props or {}
    return {
        x = rec.x, y = rec.y, z = rec.z, h = rec.heading, l = rec.locked,
        b = p.bodyHealth, e = p.engineHealth, t = p.tankHealth,
    }
end

local function differs(a, b, threshold)
    if a == nil or b == nil then return a ~= b end
    return math.abs(a - b) > threshold
end

-- Position (> 1 m), cap, verrouillage ou santé changés depuis la dernière écriture.
local function changed(rec)
    local s = rec.snap
    if not s then return true end
    local dx, dy, dz = rec.x - s.x, rec.y - s.y, rec.z - s.z
    if dx * dx + dy * dy + dz * dz > 1.0 then return true end
    local p = rec.props or {}
    return differs(rec.heading, s.h, 1.0) or rec.locked ~= s.l
        or differs(p.bodyHealth, s.b, 0.5) or differs(p.engineHealth, s.e, 0.5) or differs(p.tankHealth, s.t, 0.5)
end

local function rowParams(rec)
    local props
    if rec.props then
        local ok, enc = pcall(json.encode, rec.props)
        if ok then props = enc end
    end
    return {
        rec.plate, rec.owner, rec.model, rec.vtype, rec.x, rec.y, rec.z, rec.heading,
        rec.locked and 1 or 0, rec.seen, rec.plateText or rec.plate, props,
    }
end

local function markWritten(rec)
    lastWrite[rec.plate] = GetGameTimer()
    rec.snap = snapshot(rec)
end

local function write(rec)
    sqlRun(rec.plate, SQL_UPSERT, rowParams(rec))
    markWritten(rec)
end

-- Écriture regroupée : au plus une par plaque toutes les WRITE_DELAY ms.
local function queueSave(rec)
    local plate = rec.plate
    if writeQueued[plate] then return end
    local wait = (lastWrite[plate] or -WRITE_DELAY) + WRITE_DELAY - GetGameTimer()
    if wait <= 0 then return write(rec) end
    writeQueued[plate] = true
    SetTimeout(wait, function()
        writeQueued[plate] = nil
        local cur = Vehicles[plate]
        if cur and not shuttingDown then write(cur) end
    end)
end

--- Arrête le suivi (mémoire + SQL). deleteEntity : true = supprime l'entité, 'empty' = seulement si vide ;
--- une entité gardée est rendue au jeu (SetEntityOrphanMode 0).
local function removeRecord(plate, reason, deleteEntity)
    local rec = Vehicles[plate]
    if not rec then return end
    Vehicles[plate] = nil
    ownedCache[plate] = nil
    lastWrite[plate] = nil
    local e = rec.entity
    rec.entity = nil -- toujours avant DeleteEntity
    rec.pending = nil
    if exists(e) then
        if deleteEntity == true or (deleteEntity == 'empty' and isEmpty(e)) then
            DeleteEntity(e)
        else
            release(e)
        end
    end
    sqlRun(plate, SQL_DELETE, { plate })
    log('removed %s (%s)', plate, reason)
end

------------------------------------------------------------------------
-- Table du framework (mode 'framework')
------------------------------------------------------------------------

local function fwQuery(sql, params)
    local ok, rows = pcall(MySQL.query.await, sql, params)
    if not ok or type(rows) ~= 'table' then return nil end
    return rows
end

-- { owner, stored } si la plaque existe, false si absente, nil si erreur SQL.
-- NOTE: seuls les résultats positifs « sortis » sont mis en cache : absent, rangé ou erreur sont toujours relus.
local function queryOwned(plate, text)
    local q = FwTable and FW_SQL[FwTable]
    if not q then return nil end
    text = type(text) == 'string' and text or plate
    local trimmed = text:match('^%s*(.-)%s*$')
    local rows = fwQuery(q.exact, { text, trimmed, plate })
    if rows and not rows[1] then rows = fwQuery(q.loose, { plate }) end
    if not rows then
        ownedCache[plate] = nil
        return nil
    end
    local row, v = rows[1], false
    if row then
        local owner, stored
        if FwTable == 'esx' then
            owner = row.owner
            stored = row.stored == 1 or row.stored == true
        else
            owner = row.citizenid
            stored = row.state == true or (tonumber(row.state) or 0) ~= 0
        end
        if owner ~= nil and owner ~= '' then v = { owner = tostring(owner), stored = stored } end
    end
    if v and not v.stored then
        ownedCache[plate] = { t = os.time(), v = v }
    else
        ownedCache[plate] = nil
    end
    return v
end

local function getOwned(plate, text, fresh)
    local c = ownedCache[plate]
    if not fresh and c and os.time() - c.t < OWNED_CACHE then return c.v end
    return queryOwned(plate, text)
end

-- Propriétaire si le joueur peut faire suivre ce véhicule, sinon nil.
local function eligibleOwner(src, plate, text, rec)
    if Mode == 'framework' then
        local row = getOwned(plate, text)
        if not row or row.stored then return nil end
        return row.owner
    end
    if Mode == 'keys' then
        local ok, has = pcall(function() return exports.pop_vehiclekeys:HasKey(src, plate) end)
        if not ok or has ~= true then return nil end
    end
    if rec then return rec.owner end
    return Bridge.GetIdentifier(src)
end

------------------------------------------------------------------------
-- Lecture serveur et création
------------------------------------------------------------------------

--- Position, cap, verrouillage, et santé / saleté (si un client possède l'entité et que les props sont appliquées).
local function capture(rec)
    local e = rec.entity
    if not exists(e) then return false end
    local c = GetEntityCoords(e)
    rec.x, rec.y, rec.z = c.x, c.y, c.z
    rec.heading = clamp(GetEntityHeading(e), 0.0, 360.0, rec.heading or 0.0)
    rec.locked = GetVehicleDoorLockStatus(e) >= 2
    -- NOTE: juste après une création, la santé serveur vaut les valeurs par défaut tant que le propriétaire
    -- n'a pas appliqué les props (rec.pending) ; sans propriétaire, pas de données fiables : on garde l'existant.
    if not rec.pending and hasOwner(e) then
        local p = rec.props or {}
        p.bodyHealth   = clamp(GetVehicleBodyHealth(e), -4000.0, 1000.0, p.bodyHealth or 1000.0)
        p.engineHealth = clamp(GetVehicleEngineHealth(e), -4000.0, 1000.0, p.engineHealth or 1000.0)
        p.tankHealth   = clamp(GetVehiclePetrolTankHealth(e), -4000.0, 1000.0, p.tankHealth or 1000.0)
        p.dirtLevel    = clamp(GetVehicleDirtLevel(e), 0.0, 15.0, p.dirtLevel or 0.0)
        rec.props = p
    end
    return true
end

local function adopt(rec, veh, why)
    attach(rec, veh)
    rec.pending = nil
    log('adopted %s (%s)', rec.plate, why)
end

-- Entité du monde portant cette plaque et ce modèle (véhicules temporaires exclus), sinon nil.
local function findInWorld(plate, model)
    for _, veh in ipairs(GetAllVehicles()) do
        if Plate.Normalize(GetVehicleNumberPlateText(veh)) == plate and sameModel(GetEntityModel(veh), model)
            and not isTemporary(veh) then
            return veh
        end
    end
    return nil
end

-- Pose (ou repose) les props à appliquer par le propriétaire réseau. Toujours posé, même vide : le client dégèle.
local function pushProps(rec, veh)
    local state = Entity(veh).state
    state:set(STATE_PROPS, nil, true)
    state:set(STATE_PROPS, Props.Merge(rec.props, {}), true)
    rec.pending.at = GetGameTimer()
end

local function doSpawn(rec)
    local plate = rec.plate
    if Mode == 'framework' then
        -- NOTE: lecture fraîche (sans cache) avant chaque création, pour ne jamais recréer un véhicule rangé.
        local row = getOwned(plate, rec.plateText, true)
        if Vehicles[plate] ~= rec or rec.entity then return end
        if row == nil then return end -- erreur SQL : nouvel essai au tick suivant
        if not row or row.stored then
            return removeRecord(plate, row and 'stored' or 'not owned')
        end
        rec.owner = row.owner
    end

    -- Dernière vérification juste avant la création : la plaque a pu apparaître depuis le tick.
    local found = findInWorld(plate, rec.model)
    if found then return adopt(rec, found, 'found before spawn') end

    local veh = CreateVehicleServerSetter(rec.model, rec.vtype, rec.x, rec.y, rec.z, rec.heading)
    local deadline = GetGameTimer() + SPAWN_TIMEOUT
    while not exists(veh) and GetGameTimer() < deadline do Wait(50) end
    if not exists(veh) then
        info('could not create vehicle %s (model %s), retrying later', plate, tostring(rec.model))
        return
    end
    -- Suivi arrêté, ou autre entité adoptée pendant l'attente : on n'en garde aucune copie.
    if shuttingDown or Vehicles[plate] ~= rec or rec.entity ~= nil then
        DeleteEntity(veh)
        return
    end

    FreezeEntityPosition(veh, true) -- dégelé par le client propriétaire une fois posé au sol
    SetVehicleNumberPlateText(veh, rec.plateText or rec.plate)
    SetVehicleDoorsLocked(veh, rec.locked and 2 or 1)
    attach(rec, veh)
    local pending = { at = GetGameTimer() }
    rec.pending = pending

    -- Le statebag n'est appliqué que par le propriétaire réseau : on attend qu'il y en ait un.
    deadline = GetGameTimer() + OWNER_TIMEOUT
    while exists(veh) and NetworkGetEntityOwner(veh) == -1 and GetGameTimer() < deadline do Wait(OWNER_STEP) end
    if shuttingDown or rec.entity ~= veh or rec.pending ~= pending or not exists(veh) then return end
    -- Sans propriétaire au bout du délai : posé quand même, reposé par le tick (PENDING_RESEND).
    pushProps(rec, veh)

    TriggerEvent('pop_vehiclepersistence:spawned', rec.plate, NetworkGetNetworkIdFromEntity(veh))
    log('spawned %s', plate)
end

local function spawn(rec)
    rec.spawning = true
    CreateThread(function()
        local ok, err = pcall(doSpawn, rec)
        rec.spawning = nil
        if not ok then info('spawn error for %s: %s', rec.plate, tostring(err)) end
    end)
end

------------------------------------------------------------------------
-- Boucles
------------------------------------------------------------------------

-- Plaques suivies présentes dans le monde avec le bon modèle : [plate] = { entité, ... } (temporaires exclus).
local function buildWorld()
    local world = {}
    for _, veh in ipairs(GetAllVehicles()) do
        local plate = Plate.Normalize(GetVehicleNumberPlateText(veh))
        local rec = plate and Vehicles[plate]
        if rec and sameModel(GetEntityModel(veh), rec.model) and not isTemporary(veh) then
            local list = world[plate]
            if list then list[#list + 1] = veh else world[plate] = { veh } end
        end
    end
    return world
end

-- Positions des joueurs ; mémorise aussi le véhicule que chacun conduit (lastDriven, lu côté serveur).
local function playerPositions()
    local list = {}
    for _, src in ipairs(Bridge.GetPlayers()) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            list[#list + 1] = GetEntityCoords(ped)
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then lastDriven[src] = veh end
        end
    end
    return list
end

local function anyNear(players, pos, dist)
    for i = 1, #players do
        if #(players[i] - pos) <= dist then return true end
    end
    return false
end

local function otherEntity(list, own)
    if not list then return nil end
    for _, veh in ipairs(list) do
        if veh ~= own then return veh end
    end
    return nil
end

local function isWreck(e)
    return hasOwner(e) and (GetEntityHealth(e) <= 0 or GetVehicleEngineHealth(e) <= -4000.0)
end

local function tick()
    local players = playerPositions()
    local world = buildWorld()
    local budget = SPAWN_BUDGET
    local spawnDist = tonumber(Config.SpawnDistance) or 150.0
    local despawnDist = spawnDist + DESPAWN_MARGIN
    local now = GetGameTimer()

    for plate, rec in pairs(Vehicles) do
        local e = rec.entity
        if e then
            if not DoesEntityExist(e) then
                -- Disparue sans nous : rangée, fourrière, /dv.
                removeRecord(plate, 'gone')
            elseif Plate.Normalize(GetVehicleNumberPlateText(e)) ~= plate then
                -- Plaque changée (ou entité réutilisée) : on la lâche sans la supprimer.
                rec.entity = nil
                rec.pending = nil
                release(e)
                log('detached %s (plate changed)', plate)
            elseif not rec.pending and isWreck(e) then
                removeRecord(plate, 'wrecked') -- entité rendue au jeu, qui nettoiera l'épave
            else
                local other = otherEntity(world[plate], e)
                if other then
                    -- Copie sortie par un garage : la nôtre, si vide, laisse la place.
                    if isEmpty(e) then
                        rec.entity = nil
                        DeleteEntity(e)
                        adopt(rec, other, 'duplicate')
                    else
                        log('duplicate plate %s: both entities occupied', plate)
                    end
                elseif isEmpty(e) and not anyNear(players, GetEntityCoords(e), despawnDist) then
                    capture(rec)
                    if changed(rec) then write(rec) end
                    rec.entity = nil
                    rec.pending = nil
                    DeleteEntity(e)
                    log('despawned %s', plate)
                elseif rec.pending and not rec.pending.done and not rec.spawning
                    and now - rec.pending.at > PENDING_RESEND then
                    -- Props toujours pas appliquées (propriétaire parti, statebag perdu) : on les repose.
                    pushProps(rec, e)
                    log('props resent %s', plate)
                end
            end
        elseif not rec.spawning then
            local found = world[plate]
            if found then
                -- La plaque existe déjà dans le monde : jamais de seconde copie, quelle que soit la distance.
                adopt(rec, found[1], 'found in world')
            elseif budget > 0 and anyNear(players, vector3(rec.x, rec.y, rec.z), spawnDist) then
                budget = budget - 1
                spawn(rec)
            end
        end
    end
end

-- Sauvegarde différentielle, en une transaction.
local function saveAll()
    local batch, recs = {}, {}
    for plate, rec in pairs(Vehicles) do
        if rec.entity and capture(rec) and changed(rec) then
            if writeQueued[plate] or isBusy(plate) then
                queueSave(rec)
            else
                batch[#batch + 1] = { query = SQL_UPSERT, values = rowParams(rec) }
                recs[#recs + 1] = rec
            end
        end
    end
    if #batch == 0 then return end
    local now = GetGameTimer()
    for _, rec in ipairs(recs) do
        sqlBusy[rec.plate] = now
        markWritten(rec)
    end
    MySQL.transaction(batch, function(ok)
        for _, rec in ipairs(recs) do
            if not ok then rec.snap = nil end -- réessayé au prochain passage
            sqlDone(rec.plate)
        end
        if not ok then info('save transaction failed (%d vehicle(s)), retrying later', #recs) end
    end)
end

local function expire()
    local days = tonumber(Config.ExpireDays) or 0
    if days <= 0 then return end
    local cutoff = os.time() - days * 86400
    for plate, rec in pairs(Vehicles) do
        if rec.seen < cutoff and not rec.spawning and (not exists(rec.entity) or isEmpty(rec.entity)) then
            removeRecord(plate, 'expired', true)
        end
    end
end

local function loop(interval, fn, label)
    CreateThread(function()
        while not shuttingDown do
            Wait(interval)
            if shuttingDown then break end
            local ok, err = pcall(fn)
            if not ok then info('%s error: %s', label, tostring(err)) end
        end
    end)
end

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------

-- Teste les vraies requêtes d'éligibilité (colonnes owner/stored ou citizenid/state comprises).
local function tableWorks(fw)
    local q = FW_SQL[fw]
    return fwQuery(q.exact, { '', '', '' }) ~= nil and fwQuery(q.loose, { '' }) ~= nil
end

local function detectMode()
    if Bridge.Framework == 'esx' then
        FwTable = 'esx'
    elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        FwTable = 'qb'
    end
    local fwOk = FwTable ~= nil and tableWorks(FwTable)
    local keysOk = GetResourceState('pop_vehiclekeys') == 'started'
    local fwName = FwTable == 'esx' and 'owned_vehicles (owner, stored)' or 'player_vehicles (citizenid, state)'

    local m = Config.Mode
    if m == 'framework' or m == 'keys' or m == 'all' then
        -- NOTE: mode forcé gardé même si indisponible (aucun véhicule suivi) plutôt que de tout suivre.
        if m == 'framework' and not fwOk then
            info('WARNING: Config.Mode = "framework" but the framework vehicle table is unavailable: no vehicle will be kept')
        elseif m == 'keys' and not keysOk then
            info('WARNING: Config.Mode = "keys" but pop_vehiclekeys is not started (start it before this resource)')
        end
        return m
    end
    if m ~= 'auto' then info('unknown Config.Mode "%s", using auto', tostring(m)) end
    if fwOk then return 'framework' end
    if FwTable then
        info('WARNING: framework detected but table %s cannot be queried: falling back to %s mode',
            fwName, keysOk and 'keys' or 'all')
    end
    if keysOk then return 'keys' end
    return 'all'
end

-- Enregistrement lu en base, validé ; nil si inutilisable.
local function fromRow(row)
    local plate = Plate.Normalize(row.plate)
    local model = tonumber(row.model)
    local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
    if not plate or not model or not finite(x) or not finite(y) or not finite(z) then return nil end
    if type(row.owner) ~= 'string' or row.owner == '' then return nil end
    local props
    if type(row.props) == 'string' and row.props ~= '' then
        local ok, decoded = pcall(json.decode, row.props)
        if ok then props = Props.Sanitize(decoded) end
    end
    local rec = {
        plate = plate,
        plateText = Plate.Text(row.plate_text, plate),
        owner = row.owner,
        model = math.tointeger(model) or math.floor(model),
        vtype = type(row.vtype) == 'string' and row.vtype ~= '' and row.vtype or 'automobile',
        x = x, y = y, z = z,
        heading = tonumber(row.heading) or 0.0,
        locked = row.locked == 1 or row.locked == true,
        props = props,
        seen = tonumber(row.seen) or os.time(),
        entity = nil,
    }
    rec.snap = snapshot(rec)
    return rec
end

local function migrate()
    local ok, rows = pcall(MySQL.query.await, SQL_HAS_PLATE_TEXT)
    if not ok or type(rows) ~= 'table' or not rows[1] then return end
    if (tonumber(rows[1].n) or 0) == 0 then
        local okAlter, err = pcall(MySQL.query.await, SQL_ADD_PLATE_TEXT)
        if not okAlter then info('WARNING: cannot add column plate_text: %s', tostring(err)) end
    end
end

local function init()
    local ok, err = pcall(MySQL.query.await, SQL_CREATE)
    if not ok then
        info('ERROR: cannot create table: %s', tostring(err))
        return
    end
    migrate()

    Mode = detectMode()

    local okRows, rows = pcall(MySQL.query.await, 'SELECT * FROM `pop_vehiclepersistence`')
    if not okRows or type(rows) ~= 'table' then
        info('ERROR: cannot load vehicles: %s', tostring(rows))
        return
    end

    local days = tonumber(Config.ExpireDays) or 0
    local cutoff = days > 0 and os.time() - days * 86400 or nil
    local count, expired = 0, 0
    for _, row in ipairs(rows) do
        local rec = fromRow(row)
        if not rec then
            MySQL.query(SQL_DELETE, { row.plate })
        elseif cutoff and rec.seen < cutoff then
            MySQL.query(SQL_DELETE, { row.plate })
            expired = expired + 1
        else
            Vehicles[rec.plate] = rec
            count = count + 1
        end
    end

    loaded = true
    info('mode: %s, %d vehicle(s) loaded, %d expired', Mode, count, expired)

    loop(TICK, tick, 'proximity')
    loop(SAVE_TICK, saveAll, 'save')
    loop(EXPIRE_TICK, expire, 'expire')
end

MySQL.ready(function()
    CreateThread(init)
end)

------------------------------------------------------------------------
-- Arrêt
------------------------------------------------------------------------

-- Sauvegarde tout (une transaction, hors file par plaque : la ressource s'arrête), puis supprime les entités vides
-- (les occupées seront adoptées au redémarrage par leur plaque).
local function shutdown()
    if shuttingDown or not loaded then return end
    shuttingDown = true
    local batch = {}
    for plate, rec in pairs(Vehicles) do
        local e = rec.entity
        if exists(e) then
            capture(rec)
            batch[#batch + 1] = { query = SQL_UPSERT, values = rowParams(rec) }
            if isEmpty(e) then
                rec.entity = nil
                DeleteEntity(e)
            end
        elseif writeQueued[plate] or sqlNext[plate] then
            batch[#batch + 1] = { query = SQL_UPSERT, values = rowParams(rec) }
        end
    end
    if #batch > 0 then MySQL.transaction(batch) end
    log('shutdown: vehicles saved')
end

AddEventHandler('onResourceStop', function(res)
    if res == RES then shutdown() end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', shutdown)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

-- Retire les véhicules les plus anciens (entité absente ou vide) jusqu'à repasser sous la limite.
-- La limite ne s'applique que si src est le propriétaire (un ami au volant ne fait rien remorquer).
-- Renvoie false si la limite est atteinte sans véhicule retirable.
local function enforceLimit(src, owner)
    local max = math.floor(tonumber(Config.MaxPerOwner) or 0)
    if max <= 0 then return true end
    if Bridge.GetIdentifier(src) ~= owner then return true end
    while true do
        local count, oldest = 0, nil
        for _, r in pairs(Vehicles) do
            if r.owner == owner then
                count = count + 1
                if not r.spawning and (not exists(r.entity) or isEmpty(r.entity))
                    and (not oldest or r.seen < oldest.seen) then
                    oldest = r
                end
            end
        end
        if count < max then return true end
        if not oldest then return false end
        removeRecord(oldest.plate, 'limit', true)
        -- src est le propriétaire, en ligne.
        Bridge.Notify(src, L('limit_towed', oldest.plateText or oldest.plate, max), 'warning')
    end
end

Callback.Register('pop_vehiclepersistence:update', function(playerId, netId, props)
    if not loaded or shuttingDown then return false end
    local src = validPlayer(playerId)
    if not src then return false end

    local veh = vehicleFromNet(netId)
    if not veh or isTemporary(veh) then return false end
    local vtype = GetVehicleType(veh)
    if type(vtype) ~= 'string' or vtype == '' or vtype == 'train' or #vtype > 16 then return false end
    local model = GetEntityModel(veh)
    if not model or model == 0 then return false end
    local rawPlate = GetVehicleNumberPlateText(veh)
    local plate = Plate.Normalize(rawPlate)
    if not plate then return false end
    local text = Plate.Text(rawPlate, plate)

    local ped = GetPlayerPed(src)
    local driving = ped ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
    if not driving then
        -- NOTE: plus strict que la SPEC : un envoi « à pied » n'est accepté que pour le véhicule que ce joueur
        -- a été vu conduire (lastDriven, lu côté serveur), pour empêcher de faire suivre les véhicules garés autour.
        if lastDriven[src] ~= veh then return false end
        if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > EXIT_DISTANCE then return false end
    end

    -- Cooldowns distincts : un envoi de sortie juste après l'envoi au volant n'est pas perdu.
    local now = GetGameTimer()
    local cd = driving and lastUpdate or lastExit
    if cd[src] and now - cd[src] < UPDATE_COOLDOWN then return false end
    cd[src] = now
    if driving then lastDriven[src] = veh end

    local owner = eligibleOwner(src, plate, text, Vehicles[plate])
    if not owner then return false end
    -- La requête SQL a pu laisser passer du temps : on revérifie l'entité.
    if not exists(veh) or shuttingDown then return false end

    local rec = Vehicles[plate]

    -- Props : validées, taille bornée ; santé et saleté jamais prises au client. Ignorées tant que nos props
    -- ne sont pas appliquées (le client enverrait l'état par défaut du véhicule tout juste créé).
    local clean
    if not (rec and rec.entity == veh and rec.pending) then
        clean = Props.Sanitize(props)
        if clean then
            for _, k in ipairs(SERVER_FIELDS) do clean[k] = nil end
            local ok, enc = pcall(json.encode, clean)
            if not ok or #enc > PROPS_MAX_LENGTH then clean = nil end
        end
    end

    if rec and rec.entity and rec.entity ~= veh and exists(rec.entity) then
        -- Une autre entité porte déjà cette plaque.
        if not isEmpty(rec.entity) then
            log('update %s refused: tracked entity is occupied', plate)
            return false
        end
        local old = rec.entity
        rec.entity = nil
        rec.pending = nil
        DeleteEntity(old)
        log('removed duplicate of %s', plate)
    end

    if not rec then
        if not enforceLimit(src, owner) then return false end
        rec = { plate = plate, owner = owner, seen = os.time(), x = 0.0, y = 0.0, z = 0.0, heading = 0.0, locked = false }
        Vehicles[plate] = rec
        log('tracking %s (owner %s, by %s)', plate, owner, src)
    end

    attach(rec, veh) -- détache tout autre enregistrement pointant sur cette entité
    rec.owner = owner
    rec.plateText = text
    rec.model = model
    rec.vtype = vtype
    if clean then rec.props = Props.Merge(rec.props, clean) end
    capture(rec)
    if driving then rec.seen = os.time() end
    queueSave(rec)
    return true
end)

Callback.Register('pop_vehiclepersistence:applied', function(playerId, netId)
    local src = validPlayer(playerId)
    if not src then return false end
    local veh = vehicleFromNet(netId)
    if not veh then return false end
    -- Seul le propriétaire réseau applique les props.
    if NetworkGetEntityOwner(veh) ~= src then return false end
    local plate = Plate.Normalize(GetVehicleNumberPlateText(veh))
    local rec = plate and Vehicles[plate]
    if not rec or rec.entity ~= veh then return false end
    Entity(veh).state:set(STATE_PROPS, nil, true)
    FreezeEntityPosition(veh, false)
    local pending = rec.pending
    if pending and not pending.done then
        pending.done = true
        -- La santé synchronisée par le client met un instant à remonter au serveur.
        SetTimeout(PENDING_SETTLE, function()
            if rec.pending == pending then rec.pending = nil end
        end)
    end
    return true
end)

local function forget(src)
    lastUpdate[src] = nil
    lastExit[src] = nil
    lastDriven[src] = nil
end

Bridge.OnPlayerDropped(forget)
Bridge.OnPlayerUnloaded(forget)

------------------------------------------------------------------------
-- Intégrations (events locaux serveur)
------------------------------------------------------------------------

-- NOTE: events locaux uniquement ; si une autre ressource les déclarait en net event, on ignore les appels venus d'un client.
local function fromClient()
    local s = source
    return type(s) == 'number' and s > 0 and GetPlayerName(s) ~= nil
end

-- Paramètres : src, plate, props, owned (facultatif, non utilisé : seul compte le suivi par ce script).
AddEventHandler('pop_bennys:saved', function(_, plate, props, _owned)
    if fromClient() then return end
    plate = Plate.Normalize(plate)
    local rec = plate and Vehicles[plate]
    local clean = Props.Sanitize(props)
    if not rec or not clean then return end
    -- Santé, saleté (lues côté serveur) et carburant (consommé depuis) ne viennent jamais du garage.
    for _, k in ipairs(SERVER_FIELDS) do clean[k] = nil end
    clean.fuelLevel = nil
    rec.props = Props.Merge(rec.props, clean)
    queueSave(rec)
    log('bennys update %s', plate)
end)

local PAINT_TARGETS = { primary = { 'color1' }, secondary = { 'color2' }, both = { 'color1', 'color2' } }

AddEventHandler('pop_paintgun:painted', function(_, _, color, target, plate)
    if fromClient() then return end
    plate = Plate.Normalize(plate)
    local rec = plate and Vehicles[plate]
    local fields = PAINT_TARGETS[target]
    if not rec or not fields or math.type(color) ~= 'integer' or color < 0 or color > 255 then return end
    rec.props = rec.props or {}
    for _, k in ipairs(fields) do rec.props[k] = color end
    queueSave(rec)
    log('paint update %s', plate)
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('IsPersisted', function(plate)
    plate = Plate.Normalize(plate)
    return plate ~= nil and Vehicles[plate] ~= nil
end)

exports('RemoveVehicle', function(plate)
    plate = Plate.Normalize(plate)
    local rec = plate and Vehicles[plate]
    if not rec then return false end
    removeRecord(plate, 'export', 'empty') -- occupée : gardée et rendue au jeu
    return true
end)

exports('GetVehicles', function(owner)
    local list = {}
    for _, rec in pairs(Vehicles) do
        if owner == nil or rec.owner == owner then
            list[#list + 1] = {
                plate = rec.plate, owner = rec.owner, model = rec.model,
                x = rec.x, y = rec.y, z = rec.z, spawned = rec.entity ~= nil,
            }
        end
    end
    return list
end)
