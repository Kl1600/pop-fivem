-- pop_territories : état, influence, tick, SQL, callback, exports, écoute de pop_crew.
-- Toute l'influence est calculée ici ; le client ne fait que lire (aucun event client -> serveur).

Territories = {}

local RES = GetCurrentResourceName()
local TICK_MS = 60000        -- tick d'influence
local SALE_MAX_DIST = 30.0   -- écart max entre coords de RecordDrugSale et la position serveur
local ALERT_OFFSET = 50      -- décalage aléatoire de l'alerte rivale (m)

------------------------------------------------------------------------
-- Validation de la config (corrigée au démarrage, avec print)
------------------------------------------------------------------------

local function fixNumber(tbl, path, key, default, valid)
    local v = tonumber(tbl[key])
    if v and v == v and v ~= math.huge and v ~= -math.huge and valid(v) then
        tbl[key] = v
        return
    end
    print(('[%s] invalid Config.%s%s, using %s'):format(RES, path, key, default))
    tbl[key] = default
end

do
    if type(Config.Influence) ~= 'table' then Config.Influence = {} end
    if type(Config.Prices) ~= 'table' then Config.Prices = {} end
    local I, P = Config.Influence, Config.Prices
    local positive = function(v) return v >= 0 end
    fixNumber(I, 'Influence.', 'PerSale', 2.0, positive)
    fixNumber(I, 'Influence.', 'PerTick', 0.5, positive)
    fixNumber(I, 'Influence.', 'Decay', 0.1, positive)
    fixNumber(I, 'Influence.', 'SaleCooldown', 10, positive)
    -- Capture > 50 : un seul crew peut l'atteindre (somme d'une zone <= 100).
    fixNumber(I, 'Influence.', 'Capture', 60, function(v) return v >= 51 and v <= 100 end)
    fixNumber(I, 'Influence.', 'Keep', math.min(30, I.Capture - 1), function(v) return v >= 0 and v < I.Capture end)
    fixNumber(P, 'Prices.', 'Owner', 1.25, function(v) return v > 0 end)
    fixNumber(P, 'Prices.', 'Rival', 0.85, function(v) return v > 0 end)
    fixNumber(Config, '', 'RivalAlertCooldown', 120, positive)
end

local INF = Config.Influence

------------------------------------------------------------------------
-- État mémoire
------------------------------------------------------------------------

local influence = {}  -- [zoneId][crewKey] = number (0-100)
local owners = {}     -- [zoneId] = crewKey | nil
local crews = {}      -- [crewKey] = { key, label, color }
local crewOf = {}     -- [src] = crewKey | false (joueurs connectés uniquement)
local lastSale = {}   -- [src] = os.time()
local lastSent = {}   -- [crewKey][zoneId] = entier (dernière influence arrondie envoyée)
local lastAlert = {}  -- [zoneId] = os.time()
local dirty = {}      -- [zoneId][crewKey] = true : ligne à écrire au prochain flush
local crewsDirty = {} -- [crewKey] = true : label/couleur à écrire
local disbandedEarly = {} -- [crewKey] = true : dissous avant la fin du chargement (lignes ignorées)
local loaded = false

for _, zone in ipairs(Zones.List) do influence[zone.id] = {} end

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

local function round(v) return math.floor((v or 0) + 0.5) end

--- Entier (accepte 12.0 ou '12'), sinon nil.
local function toInt(x)
    local n = tonumber(x)
    return n and math.tointeger(n) or nil
end

local function copyCrew(c)
    return c and { key = c.key, label = c.label, color = c.color } or nil
end

local function markDirty(zoneId, key)
    local set = dirty[zoneId]
    if not set then
        set = {}
        dirty[zoneId] = set
    end
    set[key] = true
end

--- Crew propriétaire (copie) ou nil. Crew jamais vu : label L('crew_unknown').
local function ownerCrew(zoneId)
    local key = owners[zoneId]
    if not key then return nil end
    local c = crews[key]
    return { key = key, label = c and c.label or L('crew_unknown'), color = c and c.color or '#ffffff' }
end

--- Sources connectées par clé de crew (depuis le cache crewOf).
local function membersByCrew()
    local map = {}
    for src, key in pairs(crewOf) do
        if key then
            local list = map[key]
            if not list then
                list = {}
                map[key] = list
            end
            list[#list + 1] = src
        end
    end
    return map
end

local function membersOf(key)
    local list = {}
    for src, k in pairs(crewOf) do
        if k == key then list[#list + 1] = src end
    end
    return list
end

------------------------------------------------------------------------
-- SQL
------------------------------------------------------------------------

local SQL_UPSERT = 'INSERT INTO `pop_territories` (`zone`, `crew`, `influence`, `owner`) VALUES (?, ?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `influence` = VALUES(`influence`), `owner` = VALUES(`owner`)'
local SQL_DELETE = 'DELETE FROM `pop_territories` WHERE `zone` = ? AND `crew` = ?'
local SQL_CREW_UPSERT = 'INSERT INTO `pop_territories_crews` (`crew`, `label`, `color`) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `color` = VALUES(`color`)'

-- Toutes les écritures (upserts différés, DELETE de Reset et de dissolution) passent par une file
-- unique dépilée par une seule coroutine : l'ordre mémoire est respecté en base (un upsert ancien
-- ne peut pas arriver après le DELETE d'un Reset).
local sqlQueue = {}     -- { queries = { { query, values }, ... }, done = function(ok) | nil }
local sqlRunning = false

local function runQueue()
    while sqlQueue[1] do
        local job = table.remove(sqlQueue, 1)
        local ok, res = pcall(MySQL.transaction.await, job.queries)
        local success = ok and res and true or false
        if not success then
            print(('[%s] database write failed%s'):format(RES, ok and '' or (': ' .. tostring(res))))
        end
        if job.done then
            local okDone, err = pcall(job.done, success)
            if not okDone then print(('[%s] database callback error: %s'):format(RES, tostring(err))) end
        end
    end
    sqlRunning = false
end

--- Ajoute une transaction à la file (exécutée après toutes celles déjà en attente).
local function enqueue(queries, done)
    if #queries == 0 then return end
    sqlQueue[#sqlQueue + 1] = { queries = queries, done = done }
    if not sqlRunning then
        sqlRunning = true
        CreateThread(runQueue)
    end
end

--- Écrit les lignes « sales » (une transaction, via la file). En cas d'échec, les entrées
--- redeviennent sales (une entrée remarquée entre-temps l'est déjà) et seront réécrites au prochain flush.
local function flush()
    if not loaded or next(dirty) == nil then return end
    local batch, queries = dirty, {}
    dirty = {}
    for zoneId, set in pairs(batch) do
        for key in pairs(set) do
            local v = influence[zoneId] and influence[zoneId][key]
            local isOwner = owners[zoneId] == key
            if v or isOwner then
                queries[#queries + 1] = { query = SQL_UPSERT, values = { zoneId, key, v or 0, isOwner and 1 or 0 } }
            else
                queries[#queries + 1] = { query = SQL_DELETE, values = { zoneId, key } }
            end
        end
    end
    enqueue(queries, function(ok)
        if ok then return end
        for zoneId, set in pairs(batch) do
            if influence[zoneId] then
                for key in pairs(set) do markDirty(zoneId, key) end
            end
        end
    end)
end

--- Écrit les labels/couleurs de crews modifiés (via la file ; remis en attente en cas d'échec).
local function saveCrews()
    if not loaded or next(crewsDirty) == nil then return end
    local batch, queries = crewsDirty, {}
    crewsDirty = {}
    for key in pairs(batch) do
        local c = crews[key]
        if c then queries[#queries + 1] = { query = SQL_CREW_UPSERT, values = { key, c.label, c.color } } end
    end
    enqueue(queries, function(ok)
        if ok then return end
        for key in pairs(batch) do
            if crews[key] then crewsDirty[key] = true end
        end
    end)
end

------------------------------------------------------------------------
-- Crews vus
------------------------------------------------------------------------

--- Enregistre un crew (label/couleur). Si nouveau ou modifié : écriture et re-diffusion des zones qu'il tient
--- (un crew inconnu propriétaire, affiché « Crew inconnu », reçoit ainsi son vrai label).
local function seeCrew(crew)
    if type(crew) ~= 'table' or type(crew.key) ~= 'string' then return end
    local known = crews[crew.key]
    if known and known.label == crew.label and known.color == crew.color then return end
    crews[crew.key] = { key = crew.key, label = crew.label, color = crew.color }
    crewsDirty[crew.key] = true
    saveCrews()
    if loaded then
        for zoneId, key in pairs(owners) do
            if key == crew.key then
                TriggerClientEvent('pop_territories:client:owner', -1, zoneId, ownerCrew(zoneId))
            end
        end
    end
end

------------------------------------------------------------------------
-- État envoyé au client (format SPEC §4)
------------------------------------------------------------------------

local function BuildState(src)
    local key = crewOf[src] or nil
    local zones = {}
    for _, zone in ipairs(Zones.List) do
        zones[zone.id] = {
            owner = loaded and ownerCrew(zone.id) or nil,
            influence = (key and loaded) and round(influence[zone.id][key]) or 0,
        }
    end
    return {
        enabled = Crew.Mode() ~= 'disabled',
        capture = round(INF.Capture),
        crew = key and copyCrew(crews[key]) or nil,
        zones = zones,
    }
end

--- Relit le crew du joueur, met à jour le cache. Renvoie crew, changed (bool).
local function refreshCrew(src)
    local crew = Crew.Get(src)
    if crew then seeCrew(crew) end
    local newKey = crew and crew.key or false
    local changed = crewOf[src] ~= newKey
    crewOf[src] = newKey
    return crew, changed
end

------------------------------------------------------------------------
-- Influence
------------------------------------------------------------------------

--- Fixe la valeur d'un crew, réduit proportionnellement les autres si la somme dépasse 100.
local function applyValue(zoneId, key, v)
    local zinf = influence[zoneId]
    v = math.max(0, math.min(100, v))
    local others = 0
    for k, val in pairs(zinf) do
        if k ~= key then others = others + val end
    end
    local excess = v + others - 100
    if excess > 0 and others > 0 then
        for k, val in pairs(zinf) do
            if k ~= key then
                local nv = val - excess * (val / others)
                zinf[k] = nv >= 0.01 and nv or nil
                markDirty(zoneId, k)
            end
        end
    end
    zinf[key] = v >= 0.01 and v or nil
    markDirty(zoneId, key)
end

--- Ajoute `amount` (peut être négatif) à l'influence de `crew` ; plafond `maxValue` (défaut 100)
--- qui ne fait jamais descendre sous la valeur actuelle.
function Territories.AddInfluence(zoneId, crew, amount, maxValue)
    local zinf = influence[zoneId]
    if not zinf or type(crew) ~= 'table' or type(crew.key) ~= 'string' then return end
    amount = tonumber(amount) or 0
    seeCrew(crew)
    local cur = zinf[crew.key] or 0
    local v
    if amount >= 0 then
        v = math.max(cur, math.min(maxValue or 100, cur + amount))
    else
        v = cur + amount
    end
    if v == cur then return end
    applyValue(zoneId, crew.key, v)
end

--- Valeur fixée par un admin (0-100). Écriture immédiate.
function Territories.SetInfluence(zoneId, crewKey, value)
    if not influence[zoneId] or type(crewKey) ~= 'string' then return end
    if not crews[crewKey] then
        -- NOTE: crew jamais vu : la clé brute sert de label (tronquée à 32 caractères).
        seeCrew(Crew.Make(crewKey, crewKey, '#ffffff'))
    end
    applyValue(zoneId, crewKey, tonumber(value) or 0)
    flush()
end

--- Envoie l'influence arrondie aux membres connectés des crews dont la valeur a changé.
local function sendInfluence(zoneId)
    local zinf = influence[zoneId]
    local keys = {}
    for key in pairs(zinf) do keys[key] = true end
    for key, byZone in pairs(lastSent) do
        if byZone[zoneId] ~= nil then keys[key] = true end
    end
    local members
    for key in pairs(keys) do
        local value = round(zinf[key])
        local sent = lastSent[key]
        if not sent then
            sent = {}
            lastSent[key] = sent
        end
        if (sent[zoneId] or 0) ~= value then
            sent[zoneId] = value ~= 0 and value or nil
            members = members or membersByCrew()
            for _, src in ipairs(members[key] or {}) do
                TriggerClientEvent('pop_territories:client:influence', src, zoneId, value)
            end
        end
    end
end

--- Notifie les membres connectés d'un crew.
local function notifyCrew(key, localeKey, zone, notifyType)
    if not key then return end
    local msg = L(localeKey, L(zone.label))
    for _, src in ipairs(membersOf(key)) do
        Bridge.Notify(src, msg, notifyType)
    end
end

--- Applique l'hystérésis Capture / Keep et diffuse les changements.
function Territories.UpdateOwner(zoneId)
    local zinf = influence[zoneId]
    local zone = Zones.Get(zoneId)
    if not zinf or not zone then return end

    local old = owners[zoneId]
    local new = old
    if old and (zinf[old] or 0) < INF.Keep then new = nil end
    for key, v in pairs(zinf) do
        if key ~= old and v >= INF.Capture then
            new = key
            break
        end
    end

    if new ~= old then
        local oldCrew = ownerCrew(zoneId)
        owners[zoneId] = new
        local newCrew = ownerCrew(zoneId)
        if old then markDirty(zoneId, old) end
        if new then markDirty(zoneId, new) end
        flush() -- écriture immédiate du changement de propriétaire
        TriggerClientEvent('pop_territories:client:owner', -1, zoneId, newCrew)
        notifyCrew(new, 'notify_captured', zone, 'success')
        notifyCrew(old, 'notify_lost', zone, 'error')
        log('owner %s: %s -> %s', zoneId, tostring(old), tostring(new))
        TriggerEvent('pop_territories:ownerChanged', zoneId, copyCrew(newCrew), copyCrew(oldCrew))
    end

    sendInfluence(zoneId)
end

--- Vide l'influence et le propriétaire d'une zone (admin).
function Territories.Reset(zoneId)
    if not influence[zoneId] then return end
    local oldCrew = ownerCrew(zoneId)
    influence[zoneId] = {}
    owners[zoneId] = nil
    dirty[zoneId] = nil
    lastAlert[zoneId] = nil
    enqueue({ { query = 'DELETE FROM `pop_territories` WHERE `zone` = ?', values = { zoneId } } })
    TriggerClientEvent('pop_territories:client:owner', -1, zoneId, nil)
    if oldCrew then TriggerEvent('pop_territories:ownerChanged', zoneId, nil, oldCrew) end
    sendInfluence(zoneId)
end

--- Liste { key, label, value } triée par influence décroissante.
function Territories.GetZoneInfluence(zoneId)
    local list = {}
    for key, v in pairs(influence[zoneId] or {}) do
        list[#list + 1] = { key = key, label = crews[key] and crews[key].label or key, value = v }
    end
    table.sort(list, function(a, b) return a.value > b.value end)
    return list
end

--- Propriétaire (copie) ou nil.
function Territories.GetOwner(zoneId)
    return ownerCrew(zoneId)
end

--- Label connu d'un crew, sinon la clé brute.
function Territories.GetCrewLabel(key)
    return crews[key] and crews[key].label or key
end

function Territories.IsLoaded()
    return loaded
end

------------------------------------------------------------------------
-- Chargement
------------------------------------------------------------------------

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `pop_territories` (
            `zone`       VARCHAR(32) NOT NULL,
            `crew`       VARCHAR(64) NOT NULL,
            `influence`  FLOAT       NOT NULL DEFAULT 0,
            `owner`      TINYINT(1)  NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`zone`, `crew`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `pop_territories_crews` (
            `crew`       VARCHAR(64) NOT NULL,
            `label`      VARCHAR(32) NOT NULL,
            `color`      CHAR(7)     NOT NULL DEFAULT '#ffffff',
            `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`crew`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

        -- Crews : les données vues avant le chargement (plus fraîches) sont prioritaires.
        for _, row in ipairs(MySQL.query.await('SELECT `crew`, `label`, `color` FROM `pop_territories_crews`') or {}) do
            if type(row.crew) == 'string' and not crews[row.crew] and not disbandedEarly[row.crew] then
                crews[row.crew] = Crew.Make(row.crew, row.label, row.color)
            end
        end

        -- Influence : les zones absentes de la config sont ignorées (pas supprimées).
        for _, row in ipairs(MySQL.query.await('SELECT `zone`, `crew`, `influence`, `owner` FROM `pop_territories`') or {}) do
            local zinf = influence[row.zone]
            local v = tonumber(row.influence)
            if zinf and type(row.crew) == 'string' and not disbandedEarly[row.crew] and v and v == v then
                v = math.max(0, math.min(100, v))
                if v >= 0.01 then zinf[row.crew] = v end
                if tonumber(row.owner) == 1 and not owners[row.zone] then owners[row.zone] = row.crew end
            end
        end
    end)
    if not ok then
        -- NOTE: sans base lisible, l'influence reste figée (aucune écriture qui écraserait les données).
        print(('[%s] database load failed: %s'):format(RES, tostring(err)))
        return
    end

    -- Sécurité : une somme > 100 (base modifiée à la main) est ramenée à 100 proportionnellement.
    for zoneId, zinf in pairs(influence) do
        local sum = 0
        for _, v in pairs(zinf) do sum = sum + v end
        if sum > 100 then
            for k, v in pairs(zinf) do
                zinf[k] = v * 100 / sum
                markDirty(zoneId, k)
            end
        end
    end

    loaded = true
    disbandedEarly = {}
    saveCrews()
    flush()
    log('loaded %d zones', #Zones.List)

    -- NOTE: les clients ont pu demander leur état avant la fin du chargement : on leur renvoie l'état complet.
    for _, src in ipairs(Bridge.GetPlayers()) do
        if crewOf[src] ~= nil then
            TriggerClientEvent('pop_territories:client:state', src, BuildState(src))
        end
    end
end)

------------------------------------------------------------------------
-- Callback (lecture seule)
------------------------------------------------------------------------

Callback.Register('pop_territories:getState', function(src)
    refreshCrew(src)
    return BuildState(src)
end)

------------------------------------------------------------------------
-- Tick (60 s)
------------------------------------------------------------------------

local function tick()
    local players = Bridge.GetPlayers()
    if #players == 0 then return end

    -- 1-2. Crews et présence (joueurs chargés et vivants).
    local present = {} -- [zoneId][crewKey] = true
    for _, src in ipairs(players) do
        local crew, changed = refreshCrew(src)
        if changed then
            TriggerClientEvent('pop_territories:client:state', src, BuildState(src))
        end
        if crew then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                -- Bridge.IsDead (état mort / à terre du framework) si disponible, sinon santé du ped.
                local dead = Bridge.IsDead and Bridge.IsDead(src) or GetEntityHealth(ped) <= 0
                local zone = not dead and Zones.At(GetEntityCoords(ped)) or nil
                if zone then
                    present[zone.id] = present[zone.id] or {}
                    present[zone.id][crew.key] = true
                end
            end
        end
    end

    -- 3. Mode désactivé ou base non chargée : l'influence ne bouge pas.
    if not loaded or Crew.Mode() == 'disabled' then return end

    -- 4. Présence (+PerTick, plafonnée sous Capture sauf pour le propriétaire) et déclin des absents.
    for _, zone in ipairs(Zones.List) do
        local zoneId = zone.id
        local zinf = influence[zoneId]
        local here = present[zoneId] or {}
        local owner = owners[zoneId]

        local absent = {}
        for key in pairs(zinf) do
            if not here[key] then absent[#absent + 1] = key end
        end

        for key in pairs(here) do
            local crew = crews[key]
            if crew and INF.PerTick > 0 then
                Territories.AddInfluence(zoneId, crew, INF.PerTick, key == owner and 100 or INF.Capture - 0.01)
            end
        end

        if INF.Decay > 0 then
            for _, key in ipairs(absent) do
                local v = zinf[key]
                if v then
                    v = v - INF.Decay
                    zinf[key] = v >= 0.01 and v or nil
                    markDirty(zoneId, key)
                end
            end
        end

        Territories.UpdateOwner(zoneId)
    end

    -- 5. Labels/couleurs des propriétaires : re-diffusés par seeCrew dès qu'un changement est vu.
    -- 6. Écriture différée (et nouvel essai des labels de crews en échec).
    saveCrews()
    flush()
end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        local ok, err = pcall(tick)
        if not ok then print(('[%s] tick error: %s'):format(RES, tostring(err))) end
    end
end)

------------------------------------------------------------------------
-- Export : RecordDrugSale (appelé par pop_dealing avant de payer)
------------------------------------------------------------------------

-- Position (x, y, z) d'un vector3 ou d'une table, sinon nil.
local function toVec3(c)
    local t = type(c)
    if t ~= 'vector3' and t ~= 'vector4' and t ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z) or 0.0
    if not x or not y or x ~= x or y ~= y or z ~= z then return nil end
    return vector3(x, y, z)
end

local function recordDrugSale(src, coords, amount)
    -- 1. Montant et vendeur.
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount < 0 or amount > 1e9 then
        return 0, { mult = 1.0, rival = false }
    end
    local base = math.floor(amount + 0.5)
    src = toInt(src)
    if not src or not GetPlayerName(src) then
        return base, { mult = 1.0, rival = false }
    end

    -- 2. Position : serveur d'abord ; coords ignoré s'il est à plus de 30 m.
    local pos = Bridge.GetCoords(src)
    local given = toVec3(coords)
    if given and (not pos or #(pos - given) <= SALE_MAX_DIST) then pos = given end
    if not pos then return base, { mult = 1.0, rival = false } end

    -- 3. Zone.
    local zone = Zones.At(pos)
    if not zone then return base, { mult = 1.0, rival = false } end

    -- 4. Crew (lecture fraîche) et propriétaire avant la vente.
    local crew, changed = refreshCrew(src)
    if changed then TriggerClientEvent('pop_territories:client:state', src, BuildState(src)) end
    local owner = loaded and ownerCrew(zone.id) or nil

    -- 5. Multiplicateur.
    local mult, rival = zone.price, false
    if owner and crew and owner.key == crew.key then
        mult = mult * Config.Prices.Owner
    elseif owner then
        mult = mult * Config.Prices.Rival
        rival = true
    end
    mult = math.floor(mult * 100 + 0.5) / 100

    -- 6. Influence, limitée par joueur.
    -- NOTE: lastSale n'est mis à jour que pour une vente comptée (une vente comptée max par SaleCooldown).
    -- Une vente à 0 (amount <= 0) ne compte pas.
    local now = os.time()
    if crew and loaded and amount > 0 and Crew.Mode() ~= 'disabled' and (not lastSale[src] or now - lastSale[src] >= INF.SaleCooldown) then
        lastSale[src] = now
        if INF.PerSale > 0 then
            Territories.AddInfluence(zone.id, crew, INF.PerSale)
            Territories.UpdateOwner(zone.id)
        end
    end

    -- 7. Alerte au crew propriétaire (position approximative).
    local cd = Config.RivalAlertCooldown
    if rival and cd > 0 and (not lastAlert[zone.id] or now - lastAlert[zone.id] >= cd) then
        lastAlert[zone.id] = now
        local approx = vector3(pos.x + math.random(-ALERT_OFFSET, ALERT_OFFSET), pos.y + math.random(-ALERT_OFFSET, ALERT_OFFSET), pos.z)
        for _, memberSrc in ipairs(membersOf(owner.key)) do
            TriggerClientEvent('pop_territories:client:alert', memberSrc, zone.id, approx)
        end
    end

    local final = math.max(0, math.floor(amount * mult + 0.5))
    log('sale src=%d zone=%s crew=%s mult=%.2f amount=%d', src, zone.id, crew and crew.key or '-', mult, final)
    return final, { zone = zone.id, owner = owner, mult = mult, rival = rival }
end

exports('RecordDrugSale', recordDrugSale)

exports('GetZoneAt', function(coords)
    local zone = Zones.At(toVec3(coords))
    if not zone then return nil end
    return zone.id, L(zone.label)
end)

exports('GetZoneOwner', function(zoneId)
    if type(zoneId) ~= 'string' or not influence[zoneId] or not loaded then return nil end
    return ownerCrew(zoneId)
end)

------------------------------------------------------------------------
-- Events de pop_crew (locaux au serveur, jamais RegisterNetEvent)
------------------------------------------------------------------------

AddEventHandler('pop_crew:changed', function(src, crewId)
    if GetInvokingResource() ~= 'pop_crew' then return end
    src = toInt(src)
    if not src or not GetPlayerName(src) then return end
    if crewId ~= nil then
        crewId = toInt(crewId)
        if not crewId then return end
    end

    local newKey = crewId and ('crew:' .. crewId) or false
    if crewId then
        local crew = Crew.Get(src)
        if crew and crew.key == newKey then seeCrew(crew) end
    end
    local old = crewOf[src]
    crewOf[src] = newKey
    if old ~= newKey then
        TriggerClientEvent('pop_territories:client:state', src, BuildState(src))
    end
end)

AddEventHandler('pop_crew:disbanded', function(crewId)
    if GetInvokingResource() ~= 'pop_crew' then return end
    crewId = toInt(crewId)
    if not crewId then return end

    local key = 'crew:' .. crewId
    local touched = {}
    for zoneId, zinf in pairs(influence) do
        local hadInfluence = zinf[key] ~= nil
        zinf[key] = nil
        if dirty[zoneId] then dirty[zoneId][key] = nil end
        if owners[zoneId] == key then
            local oldCrew = ownerCrew(zoneId)
            owners[zoneId] = nil
            TriggerClientEvent('pop_territories:client:owner', -1, zoneId, nil)
            TriggerEvent('pop_territories:ownerChanged', zoneId, nil, oldCrew)
            hadInfluence = true
        end
        if hadInfluence then touched[#touched + 1] = zoneId end
    end
    crews[key] = nil
    crewsDirty[key] = nil
    lastSent[key] = nil
    for src, k in pairs(crewOf) do
        if k == key then crewOf[src] = false end
    end

    if not loaded then disbandedEarly[key] = true end
    enqueue({
        { query = 'DELETE FROM `pop_territories` WHERE `crew` = ?', values = { key } },
        { query = 'DELETE FROM `pop_territories_crews` WHERE `crew` = ?', values = { key } },
    })
    log('crew %s disbanded, %d zones touched', key, #touched)

    -- Un autre crew >= Capture peut récupérer la zone.
    for _, zoneId in ipairs(touched) do Territories.UpdateOwner(zoneId) end
end)

------------------------------------------------------------------------
-- Joueurs et arrêt
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src)
    crewOf[src] = nil
    lastSale[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    -- Au mieux : la file peut ne pas aboutir si la ressource ou oxmysql s'arrête avant.
    saveCrews()
    flush()
end)
