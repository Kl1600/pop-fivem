-- pop_doorlock : chargement SQL, cache, accès, changement d'état, synchronisation et exports.
-- La table Doorlock est partagée avec keys.lua, lockpick.lua et editor.lua (chargés après ce fichier).

Doorlock = {
    groups = {}, -- [id] = { id, label, locked, distance, security, alert, jobs = {}, keyId = string|nil, doorIds = { id, ... } }
    doors = {},  -- [id] = { id, groupId, center = vector3, leaves = { { model, x, y, z } }, locked = bool }
    ready = false,
}

local RES = GetCurrentResourceName()

local TOLERANCE      = 1.0   -- marge (m) ajoutée à group.distance pour les contrôles serveur
local STATE_SPAM_MS  = 500   -- anti-spam de setState, par joueur
local READY_TIMEOUT  = 10000 -- attente max (ms) de la fin du chargement SQL dans un callback
local DISTANCE_MIN   = 1.0   -- bornes de la distance d'interaction d'un groupe
local DISTANCE_MAX   = 5.0
Doorlock.TOLERANCE = TOLERANCE

------------------------------------------------------------------------
-- Outils communs
------------------------------------------------------------------------

--- Message console (anglais, non traduit : lu par les admins seulement).
function Doorlock.Log(msg, ...)
    print(('[%s] ' .. msg):format(RES, ...))
end

function Doorlock.Debug(msg, ...)
    if Config.Debug then Doorlock.Log(msg, ...) end
end

--- Nombre fini (ni NaN ni infini).
function Doorlock.IsFinite(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

--- Entier (accepte un flottant entier, ex. 3.0 venant d'un JSON), sinon nil.
function Doorlock.ToInt(v)
    if math.type(v) == 'integer' then return v end
    if Doorlock.IsFinite(v) and v == math.floor(v) then return math.tointeger(v) end
    return nil
end

function Doorlock.ClampDistance(d)
    return math.min(DISTANCE_MAX, math.max(DISTANCE_MIN, d)) + 0.0
end

--- Appel oxmysql protégé : renvoie le résultat, ou nil en cas d'erreur SQL (signalée en console).
function Doorlock.Sql(fn, query, params)
    local ok, res = pcall(fn, query, params)
    if not ok then
        Doorlock.Log('SQL error: %s', tostring(res))
        return nil
    end
    return res
end

--- Attend la fin du chargement (au plus 10 s). Renvoie true si le cache est prêt.
function Doorlock.WaitReady()
    local waited = 0
    while not Doorlock.ready and waited < READY_TIMEOUT do
        Wait(100)
        waited = waited + 100
    end
    return Doorlock.ready
end

--- Porte et groupe d'un doorId venant du client (validé), ou nil.
function Doorlock.GetDoor(doorId)
    local door = Doorlock.doors[Doorlock.ToInt(doorId)]
    local group = door and Doorlock.groups[door.groupId]
    if not group then return nil end
    return door, group
end

------------------------------------------------------------------------
-- Formats envoyés aux clients (§4.1). La clé (keyId) n'est jamais envoyée.
------------------------------------------------------------------------

function Doorlock.PublicGroup(id)
    local g = Doorlock.groups[id]
    if not g then return nil end
    local doors = {}
    for _, doorId in ipairs(g.doorIds) do
        local d = Doorlock.doors[doorId]
        if d then
            local leaves = {}
            for i, l in ipairs(d.leaves) do
                leaves[i] = { model = l.model, x = l.x, y = l.y, z = l.z }
            end
            doors[#doors + 1] = {
                id = d.id,
                locked = d.locked,
                center = { x = d.center.x, y = d.center.y, z = d.center.z },
                leaves = leaves,
            }
        end
    end
    return { id = g.id, distance = g.distance, security = g.security, doors = doors }
end

function Doorlock.AdminGroup(id)
    local g = Doorlock.groups[id]
    if not g then return nil end
    local jobs = {}
    for k, v in pairs(g.jobs) do jobs[k] = v end
    local doors = {}
    for _, doorId in ipairs(g.doorIds) do
        local d = Doorlock.doors[doorId]
        if d then doors[#doors + 1] = { id = d.id, double = #d.leaves == 2, locked = d.locked } end
    end
    return {
        id = g.id, label = g.label, locked = g.locked, distance = g.distance,
        security = g.security, alert = g.alert, jobs = jobs, hasKey = g.keyId ~= nil,
        doors = doors,
    }
end

--- Diffuse un groupe ajouté ou modifié à tous les joueurs.
function Doorlock.SyncGroup(id)
    local pub = Doorlock.PublicGroup(id)
    if pub then TriggerClientEvent('pop_doorlock:client:syncGroup', -1, pub) end
end

------------------------------------------------------------------------
-- Accès et état
------------------------------------------------------------------------

--- Job / grade du groupe ou clé du groupe. Aucun passe-droit admin (un admin se donne une clé).
function Doorlock.HasAccess(src, group)
    if type(group) ~= 'table' then group = Doorlock.groups[Doorlock.ToInt(group)] end
    if not group or not src then return false end
    if next(group.jobs) and Bridge.HasJob(src, group.jobs) then return true end
    if group.keyId and Doorlock.HasDoorKey and Doorlock.HasDoorKey(src, group.keyId) then return true end
    return false
end

--- Change l'état d'une porte (sans contrôle d'accès) et le diffuse. Rien n'est diffusé si l'état est déjà le bon.
function Doorlock.SetDoorState(doorId, locked)
    local door = Doorlock.doors[doorId]
    if not door or type(locked) ~= 'boolean' then return false end
    if door.locked == locked then return true end
    door.locked = locked
    TriggerClientEvent('pop_doorlock:client:setState', -1, doorId, locked)
    return true
end

------------------------------------------------------------------------
-- Chargement
------------------------------------------------------------------------

local CREATE_GROUPS = [[
CREATE TABLE IF NOT EXISTS `pop_doorlock_groups` (
  `id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `label`    VARCHAR(32)      NOT NULL,
  `locked`   TINYINT(1)       NOT NULL DEFAULT 1,
  `distance` FLOAT            NOT NULL DEFAULT 2.0,
  `security` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `alert`    TINYINT(1)       NOT NULL DEFAULT 0,
  `jobs`     LONGTEXT         NULL,
  `key_id`   VARCHAR(16)      NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `key_id` (`key_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local CREATE_DOORS = [[
CREATE TABLE IF NOT EXISTS `pop_doorlock_doors` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group_id` INT UNSIGNED NOT NULL,
  `x`        FLOAT        NOT NULL,
  `y`        FLOAT        NOT NULL,
  `z`        FLOAT        NOT NULL,
  `leaves`   LONGTEXT     NOT NULL,
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `pop_doorlock_doors_group` FOREIGN KEY (`group_id`)
    REFERENCES `pop_doorlock_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- oxmysql renvoie TINYINT(1) en booléen, mais on accepte aussi 0 / 1.
local function toBool(v)
    return v == true or v == 1
end

local function decodeJobs(raw)
    if raw == nil or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    if not ok or type(t) ~= 'table' then return nil end
    local jobs = {}
    for k, v in pairs(t) do
        local grade = Doorlock.ToInt(v)
        if type(k) == 'string' and grade then jobs[k] = grade end
    end
    return jobs
end

-- 1 ou 2 battants { model (entier), x, y, z (finis) }, sinon nil.
local function decodeLeaves(raw)
    if type(raw) ~= 'string' then return nil end
    local ok, t = pcall(json.decode, raw)
    if not ok or type(t) ~= 'table' or type(t[1]) ~= 'table' or t[3] ~= nil then return nil end
    local leaves = {}
    for i = 1, 2 do
        local l = t[i]
        if l ~= nil then
            if type(l) ~= 'table' then return nil end
            local model = Doorlock.ToInt(l.model)
            if not model or not Doorlock.IsFinite(l.x) or not Doorlock.IsFinite(l.y) or not Doorlock.IsFinite(l.z) then
                return nil
            end
            leaves[i] = { model = model, x = l.x + 0.0, y = l.y + 0.0, z = l.z + 0.0 }
        end
    end
    return leaves
end

local function load()
    if not Doorlock.Sql(MySQL.query.await, CREATE_GROUPS) then return false end
    if not Doorlock.Sql(MySQL.query.await, CREATE_DOORS) then return false end

    local groupRows = Doorlock.Sql(MySQL.query.await,
        'SELECT `id`, `label`, `locked`, `distance`, `security`, `alert`, `jobs`, `key_id` FROM `pop_doorlock_groups`')
    if not groupRows then return false end
    local doorRows = Doorlock.Sql(MySQL.query.await,
        'SELECT `id`, `group_id`, `x`, `y`, `z`, `leaves` FROM `pop_doorlock_doors` ORDER BY `id`')
    if not doorRows then return false end

    local groups, doors = {}, {}

    for _, r in ipairs(groupRows) do
        local id = Doorlock.ToInt(r.id)
        local jobs = decodeJobs(r.jobs)
        if not id or not jobs then
            Doorlock.Log('invalid group row #%s ignored', tostring(r.id))
        else
            local security = Doorlock.ToInt(r.security)
            if security ~= 0 and security ~= 1 then security = 2 end -- valeur inconnue : la plus sûre
            groups[id] = {
                id = id,
                label = tostring(r.label or ''),
                locked = toBool(r.locked),
                distance = Doorlock.ClampDistance(tonumber(r.distance) or 2.0),
                security = security,
                alert = toBool(r.alert),
                jobs = jobs,
                keyId = (type(r.key_id) == 'string' and r.key_id ~= '') and r.key_id or nil,
                doorIds = {},
            }
        end
    end

    for _, r in ipairs(doorRows) do
        local id, groupId = Doorlock.ToInt(r.id), Doorlock.ToInt(r.group_id)
        local g = groupId and groups[groupId]
        local leaves = decodeLeaves(r.leaves)
        local x, y, z = tonumber(r.x), tonumber(r.y), tonumber(r.z)
        if not id or not g or not leaves or not x or not y or not z then
            Doorlock.Log('invalid door row #%s ignored', tostring(r.id))
        else
            -- L'état courant n'est pas sauvegardé : chaque porte reprend l'état de démarrage de son groupe.
            doors[id] = { id = id, groupId = groupId, center = vector3(x, y, z), leaves = leaves, locked = g.locked }
            g.doorIds[#g.doorIds + 1] = id
        end
    end

    Doorlock.groups, Doorlock.doors = groups, doors
    return true
end

CreateThread(function()
    if not load() then
        -- NOTE: sans base de données, la ressource reste inactive (les callbacks renvoient 'error' ou une liste vide).
        Doorlock.Log('loading failed: check oxmysql and the database connection')
        return
    end
    Doorlock.ready = true
    local nGroups, nDoors = 0, 0
    for _ in pairs(Doorlock.groups) do nGroups = nGroups + 1 end
    for _ in pairs(Doorlock.doors) do nDoors = nDoors + 1 end
    Doorlock.Debug('loaded %d groups, %d doors', nGroups, nDoors)
    if Doorlock.CheckKeySupport then Doorlock.CheckKeySupport() end
end)

------------------------------------------------------------------------
-- Callbacks joueurs
------------------------------------------------------------------------

Callback.Register('pop_doorlock:getDoors', function()
    if not Doorlock.WaitReady() then return {} end
    local ids = {}
    for id in pairs(Doorlock.groups) do ids[#ids + 1] = id end
    table.sort(ids)
    local list = {}
    for i, id in ipairs(ids) do list[i] = Doorlock.PublicGroup(id) end
    return list
end)

Callback.Register('pop_doorlock:getAccess', function(src, groupId)
    if not Doorlock.WaitReady() or not Bridge.GetPlayer(src) then return false end
    local group = Doorlock.groups[Doorlock.ToInt(groupId)]
    if not group then return false end
    return Doorlock.HasAccess(src, group)
end)

local lastStateChange = {} -- [src] = GetGameTimer() du dernier appel

Callback.Register('pop_doorlock:setState', function(src, doorId, locked)
    if not Doorlock.WaitReady() then return false, 'error' end
    -- 1. porte connue, booléen, joueur chargé
    local door, group = Doorlock.GetDoor(doorId)
    if not door or type(locked) ~= 'boolean' or not Bridge.GetPlayer(src) then return false, 'error' end
    -- 2. anti-spam
    local now = GetGameTimer()
    if lastStateChange[src] and now - lastStateChange[src] < STATE_SPAM_MS then return false, 'cooldown' end
    lastStateChange[src] = now
    -- 3. distance (position serveur)
    if not Bridge.IsNear(src, door.center, group.distance + TOLERANCE) then return false, 'too_far' end
    -- 4. accès
    if not Doorlock.HasAccess(src, group) then return false, 'door_no_access' end
    -- 5. état
    if door.locked == locked then return true end
    Doorlock.SetDoorState(door.id, locked)
    Doorlock.Debug('%s (%s) %s door #%d', tostring(GetPlayerName(src)), src, locked and 'locked' or 'unlocked', door.id)
    return true
end)

Bridge.OnPlayerDropped(function(src)
    lastStateChange[src] = nil
end)

------------------------------------------------------------------------
-- Exports serveur (réservés aux scripts : aucun contrôle d'accès sauf HasAccess)
------------------------------------------------------------------------

exports('GetDoorState', function(doorId)
    local door = Doorlock.doors[Doorlock.ToInt(doorId)]
    if not door then return nil end
    return door.locked
end)

exports('SetDoorState', function(doorId, locked)
    doorId = Doorlock.ToInt(doorId)
    if not doorId or type(locked) ~= 'boolean' then return false end
    return Doorlock.SetDoorState(doorId, locked)
end)

exports('SetGroupState', function(groupId, locked)
    local group = Doorlock.groups[Doorlock.ToInt(groupId)]
    if not group or type(locked) ~= 'boolean' then return false end
    for _, doorId in ipairs(group.doorIds) do Doorlock.SetDoorState(doorId, locked) end
    return true
end)

exports('HasAccess', function(src, groupId)
    src = tonumber(src)
    local group = Doorlock.groups[Doorlock.ToInt(groupId)]
    if not src or not group then return false end
    return Doorlock.HasAccess(src, group)
end)

exports('GiveKey', function(src, groupId)
    src = tonumber(src)
    local group = Doorlock.groups[Doorlock.ToInt(groupId)]
    if not src or not group or not Bridge.GetPlayer(src) then return false end
    local ok = Doorlock.GiveKey(src, group)
    return ok == true
end)
