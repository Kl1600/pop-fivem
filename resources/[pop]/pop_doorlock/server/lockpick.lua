-- pop_doorlock : crochetage. Le client joue le mini-jeu, le serveur décide du résultat
-- (session, durée, distance, item, chance d'échec et de bris).
-- NOTE: le succès du mini-jeu est déclaré par le client (impossible à prouver côté serveur). Il est borné par la
-- durée de session et revérifié (porte, distance, outil) ; failChance est tiré même quand le client annonce un succès.

local Doorlock = Doorlock

local SESSION_MIN_MS   = 1000 -- durée minimale d'une session valide
local SESSION_EXTRA_MS = 3000 -- marge ajoutée à level.time (latence, rotation vers la porte, chargement de l'anim)
local TOLERANCE        = Doorlock.TOLERANCE or 1.0 -- marge ajoutée à group.distance

local sessions  = {} -- [src] = { doorId, level, started }
local doorBusy  = {} -- [doorId] = src
local cooldowns = {} -- [src] = GetGameTimer() de fin du cooldown

local function endSession(src)
    local s = sessions[src]
    if not s then return nil end
    sessions[src] = nil
    if doorBusy[s.doorId] == src then doorBusy[s.doorId] = nil end
    return s
end

local function startCooldown(src)
    cooldowns[src] = GetGameTimer() + (tonumber(Config.Lockpick.Cooldown) or 0) * 1000
end

-- NOTE: une session jamais terminée (client fermé, mini-jeu bloqué) expire après time + SESSION_EXTRA_MS :
-- elle est alors supprimée et le cooldown démarre, pour ne pas bloquer le joueur ni la porte indéfiniment.
local function purgeExpired(src, doorId, now)
    local s = sessions[src]
    if s and now - s.started > s.level.time + SESSION_EXTRA_MS then
        endSession(src)
        startCooldown(src)
    end
    local other = doorBusy[doorId]
    s = other and sessions[other]
    if other and (not s or now - s.started > s.level.time + SESSION_EXTRA_MS) then
        endSession(other)
        doorBusy[doorId] = nil
    end
end

-- Alerte des jobs configurés + event local pour les scripts de dispatch.
local function sendAlert(src, door, group)
    local c = door.center
    local coords = { x = c.x, y = c.y, z = c.z }
    for _, p in ipairs(Bridge.GetPlayers()) do
        if Bridge.HasJob(p, Config.Lockpick.AlertJobs) then
            TriggerClientEvent('pop_doorlock:client:alert', p, coords)
        end
    end
    TriggerEvent('pop_doorlock:lockpickAlert', src, door.center, group.id)
end

Callback.Register('pop_doorlock:lockpickStart', function(src, doorId)
    if not Doorlock.WaitReady() or not Bridge.GetPlayer(src) then return false, 'error' end
    local door, group = Doorlock.GetDoor(doorId)
    if not door then return false, 'error' end
    -- 1. porte verrouillée
    if not door.locked then return false, 'door_not_locked' end
    -- 2. niveau crochetable
    local level = Config.Lockpick.Levels[group.security]
    if not level then return false, 'lockpick_impossible' end
    -- 3. distance (position serveur)
    if not Bridge.IsNear(src, door.center, group.distance + TOLERANCE) then return false, 'too_far' end
    -- 3b. un joueur qui a l'accès ouvre normalement (pas de session, pas d'alerte)
    if Doorlock.HasAccess(src, group) then return false, 'has_access' end
    -- 4. cooldown
    local now = GetGameTimer()
    purgeExpired(src, door.id, now)
    if cooldowns[src] and now < cooldowns[src] then return false, 'cooldown' end
    -- 5. une seule session par joueur et par porte
    if sessions[src] or doorBusy[door.id] then return false, 'busy' end
    -- 6. outil
    if not Bridge.HasItem(src, Config.Lockpick.Item) then return false, 'missing_item' end
    -- 7. session (+ alerte)
    sessions[src] = { doorId = door.id, level = level, started = now }
    doorBusy[door.id] = src
    if group.alert then sendAlert(src, door, group) end
    Doorlock.Debug('%s (%s) started lockpicking door #%d', tostring(GetPlayerName(src)), src, door.id)
    -- 8. paramètres lus dans la config, jamais fournis par le client
    return true, { hits = level.hits, zone = level.zone, speed = level.speed, time = level.time }
end)

Callback.Register('pop_doorlock:lockpickEnd', function(src, doorId, success, cancelled)
    -- 1. session de ce joueur, supprimée dans tous les cas
    local s = endSession(src)
    if not s then return nil end
    -- 2. le cooldown démarre maintenant
    startCooldown(src)
    if s.doorId ~= Doorlock.ToInt(doorId) then return nil end
    -- 3. annulation : pas de bris
    if cancelled == true then return 'cancelled' end
    -- 4. contrôles : durée, porte toujours verrouillée et toujours crochetable, distance, outil
    local now = GetGameTimer()
    local elapsed = now - s.started
    local level = s.level
    local door, group = Doorlock.GetDoor(s.doorId)
    if elapsed < SESSION_MIN_MS or elapsed > level.time + SESSION_EXTRA_MS
        or not door or not door.locked
        or not Config.Lockpick.Levels[group.security]
        or not Bridge.IsNear(src, door.center, group.distance + TOLERANCE)
        or not Bridge.HasItem(src, Config.Lockpick.Item) then
        return 'failed'
    end
    -- 5. réussite du mini-jeu + tirage serveur
    if success == true and math.random() >= level.failChance then
        Doorlock.SetDoorState(door.id, false)
        Doorlock.Debug('%s (%s) picked door #%d', tostring(GetPlayerName(src)), src, door.id)
        return 'unlocked'
    end
    -- 6. échec : l'outil peut casser
    if math.random() < level.breakChance and Bridge.RemoveItem(src, Config.Lockpick.Item, 1) then
        return 'broken'
    end
    return 'failed'
end)

Bridge.OnPlayerDropped(function(src)
    endSession(src)
    cooldowns[src] = nil
end)
