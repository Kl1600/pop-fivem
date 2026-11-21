-- pop_crew : serveur. Cache mémoire chargé une fois, écritures SQL ponctuelles, callbacks, exports.
-- Le serveur décide de tout : le client n'envoie que des noms, couleurs, ids serveur, memberId et rangs cibles,
-- tous revalidés ici à partir du cache (voir SPEC.md §11 et §12).

local RES = GetCurrentResourceName()

local EV_UPDATE    = 'pop_crew:client:update'
local EV_CHANGED   = 'pop_crew:changed'
local EV_DISBANDED = 'pop_crew:disbanded'

local ACTION_DELAY = 1000  -- ms minimum entre deux actions de mutation d'un même joueur
local NAME_COLUMN  = 64    -- taille de pop_crew_members.name
local NAME_RAW_MAX = 128   -- octets max acceptés avant normalisation (anti-payload)

------------------------------------------------------------------------
-- État
------------------------------------------------------------------------

local loaded = false
local crews = {}      -- [crewId] = { id, name, color, members = { [identifier] = { id, name, rank } }, count, closing? }
local crewOf = {}     -- [identifier] = crewId
local nameIndex = {}  -- [nom en minuscules] = crewId (0 = nom réservé pendant une création)
local identOf = {}    -- [src] = identifier
local srcOf = {}      -- [identifier] = src
local invites = {}    -- [identifier] = { crewId, expires }
local lastAction = {} -- [src] = GetGameTimer() de la dernière mutation
local locks = {}      -- [src] = true pendant une mutation (attente SQL)
local unloadedCrew = {} -- [src] = crewId | false : crew du personnage déchargé (multichar), lu au playerLoaded suivant
local validColor = {} -- [hex] = true

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

-- Exécute une requête oxmysql (forme .await) protégée ; nil en cas d'erreur.
local function db(fn, query, params)
    local ok, res = pcall(fn, query, params)
    if not ok then
        print(('[%s] SQL error: %s'):format(RES, tostring(res)))
        return nil
    end
    return res
end

-- Entier strict (accepte 3 ou 3.0, refuse 3.5, NaN, inf, chaînes non numériques).
-- NOTE: math.tointeger plutôt que math.type == 'integer' : un entier peut arriver en flottant via JSON/NUI.
local function int(v)
    v = tonumber(v)
    return v and math.tointeger(v) or nil
end

-- Coupe une chaîne UTF-8 à n caractères.
local function cut(s, n)
    local len = utf8.len(s)
    if not len then return s:sub(1, n) end
    if len <= n then return s end
    return s:sub(1, utf8.offset(s, n + 1) - 1)
end

local function playerName(src)
    local n = Bridge.GetName(src)
    if type(n) ~= 'string' then return '' end
    return cut(n, NAME_COLUMN)
end

local function rankLabel(rank)
    local r = Config.Ranks[rank]
    return r and L('rank_' .. tostring(r.name)) or tostring(rank)
end

-- Permissions recalculées depuis Config.Ranks ; le rang 1 a toujours tout.
local function perms(rank)
    if rank == 1 then return { invite = true, kick = true, manage = true, disband = true } end
    local r = Config.Ranks[rank] or {}
    return { invite = r.invite == true, kick = r.kick == true, manage = r.manage == true, disband = false }
end

local function createCost()
    if Bridge.Framework == 'standalone' then return 0 end
    return Config.CreateCost
end

-- Invitation encore valide (supprimée si expirée).
local function validInvite(ident)
    local inv = invites[ident]
    if inv and inv.expires <= os.time() then
        invites[ident] = nil
        return nil
    end
    return inv
end

local function onlineIds(crew)
    local list = {}
    for ident in pairs(crew.members) do
        local s = srcOf[ident]
        if s then list[#list + 1] = s end
    end
    table.sort(list)
    return list
end

local function buildSummary(crew, m, ids)
    return {
        id = crew.id, name = crew.name, color = crew.color,
        rank = m.rank, rankLabel = rankLabel(m.rank),
        perms = perms(m.rank),
        onlineIds = ids,
    }
end

-- CrewSummary d'un identifiant, ou nil.
local function summary(ident)
    local crew = ident and crews[crewOf[ident]]
    if not crew then return nil end
    return buildSummary(crew, crew.members[ident], onlineIds(crew))
end

local function pushTo(src)
    TriggerClientEvent(EV_UPDATE, src, summary(identOf[src]))
end

-- Envoie à chaque membre en ligne son propre CrewSummary.
local function pushCrew(crew)
    local ids = onlineIds(crew)
    for ident, m in pairs(crew.members) do
        local s = srcOf[ident]
        if s then
            local copy = {}
            for i = 1, #ids do copy[i] = ids[i] end
            TriggerClientEvent(EV_UPDATE, s, buildSummary(crew, m, copy))
        end
    end
end

-- Après un échec (SQL) : renvoie l'état réel du cache au crew (s'il existe encore) et aux sources listées
-- qui n'en font pas (ou plus) partie, pour que leurs clients ne gardent pas un état optimiste faux.
local function resync(crew, ...)
    local alive = crew and crews[crew.id] == crew
    if alive then pushCrew(crew) end
    for i = 1, select('#', ...) do
        local s = select(i, ...)
        local ident = s and identOf[s]
        if ident and not (alive and crewOf[ident] == crew.id) then pushTo(s) end
    end
end

-- Notifie les membres en ligne du crew, sauf les sources listées dans `except`.
local function notifyCrew(crew, except, key, ...)
    local msg = L(key, ...)
    for ident in pairs(crew.members) do
        local s = srcOf[ident]
        if s and not except[s] then Bridge.Notify(s, msg, 'info') end
    end
end

local function findMember(crew, memberId)
    for ident, m in pairs(crew.members) do
        if m.id == memberId then return ident, m end
    end
    return nil
end

local function attach(crew, ident, m)
    crew.members[ident] = m
    crew.count = crew.count + 1
    crewOf[ident] = crew.id
end

local function detach(crew, ident)
    if not crew.members[ident] then return end
    crew.members[ident] = nil
    crew.count = crew.count - 1
    if crewOf[ident] == crew.id then crewOf[ident] = nil end
end

-- identifier, crew, membre du demandeur (crew / membre nil s'il n'a pas de crew).
local function context(src)
    local ident = identOf[src]
    if not ident then return nil end
    local crew = crews[crewOf[ident]]
    return ident, crew, crew and crew.members[ident]
end

-- Comme context, mais exige un crew utilisable. En cas d'échec : nil, clé d'erreur.
local function memberCtx(src)
    local ident, crew, me = context(src)
    if not crew then return nil, 'not_in_crew' end
    -- NOTE: crew en cours de suppression ou de transfert de chef (attente SQL) : on refuse toute autre action dessus.
    if crew.closing or crew.busy then return nil, 'error' end
    return ident, crew, me
end

-- Même routing bucket et positions serveur à portée d'invitation.
local function near(a, b)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local pa, pb = Bridge.GetCoords(a), Bridge.GetCoords(b)
    return pa ~= nil and pb ~= nil and #(pa - pb) <= Config.InviteDistance
end

-- Caractères invisibles / de contrôle bidi (usurpation de nom) : refusés.
local function isInvisible(cp)
    return (cp >= 0x200B and cp <= 0x200F) or (cp >= 0x202A and cp <= 0x202E)
        or (cp >= 0x2066 and cp <= 0x2069) or cp == 0xFEFF or cp == 0x00A0
end

-- true si la chaîne est de l'UTF-8 valide sans caractère invisible.
local function cleanCodes(s)
    local ok, bad = pcall(function()
        for _, cp in utf8.codes(s) do
            if isInvisible(cp) then return true end
        end
        return false
    end)
    return ok and not bad
end

-- Nom normalisé (trim, espaces simples) ou nil s'il est invalide.
local function normalizeName(raw)
    if #raw > NAME_RAW_MAX then return nil end
    -- NOTE: le SPEC liste <>"'\`% ; on refuse à la fois l'antislash et l'accent grave (option la plus sûre).
    if raw:find('%c') or raw:find('[<>"\'`%%\\]') then return nil end
    if not cleanCodes(raw) then return nil end
    local n = raw:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    local len = utf8.len(n)
    if not len or len < Config.NameLength.min or len > Config.NameLength.max then return nil end
    return n
end

------------------------------------------------------------------------
-- Config : bornes au démarrage
------------------------------------------------------------------------

local function sanitizeConfig()
    if type(Config.Ranks) ~= 'table' or #Config.Ranks < 2 then
        print(('[%s] ERROR: Config.Ranks must contain at least 2 ranks, pop_crew is disabled'):format(RES))
        return false
    end
    local nl = type(Config.NameLength) == 'table' and Config.NameLength or {}
    local max = math.floor(tonumber(nl.max) or 20)
    local min = math.floor(tonumber(nl.min) or 3)
    max = math.max(1, math.min(32, max))
    min = math.max(1, math.min(min, max))
    Config.NameLength = { min = min, max = max }
    Config.MaxMembers = math.max(2, math.floor(tonumber(Config.MaxMembers) or 20))
    Config.InviteDistance = math.max(0.5, tonumber(Config.InviteDistance) or 5.0)
    Config.InviteTimeout = math.max(5, math.floor(tonumber(Config.InviteTimeout) or 60))
    Config.CreateCost = math.max(0, math.floor(tonumber(Config.CreateCost) or 0))
    if Config.CreateAccount ~= 'cash' and Config.CreateAccount ~= 'bank' then Config.CreateAccount = 'bank' end
    if type(Config.Command) ~= 'string' or Config.Command == '' then Config.Command = 'crew' end

    local colors = {}
    for _, c in ipairs(type(Config.Colors) == 'table' and Config.Colors or {}) do
        if type(c) == 'string' and c:match('^#%x%x%x%x%x%x$') then
            colors[#colors + 1] = c
            validColor[c] = true
        end
    end
    if #colors == 0 then
        colors[1] = '#ff2e88'
        validColor['#ff2e88'] = true
    end
    Config.Colors = colors
    return true
end

------------------------------------------------------------------------
-- Chargement (une seule fois)
------------------------------------------------------------------------

local SQL_CREWS = [[
CREATE TABLE IF NOT EXISTS `pop_crews` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`       VARCHAR(32)  NOT NULL,
    `color`      CHAR(7)      NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crews_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

local SQL_MEMBERS = [[
CREATE TABLE IF NOT EXISTS `pop_crew_members` (
    `id`         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `crew_id`    INT UNSIGNED     NOT NULL,
    `identifier` VARCHAR(64)      NOT NULL,
    `name`       VARCHAR(64)      NOT NULL DEFAULT '',
    `rank`       TINYINT UNSIGNED NOT NULL,
    `joined_at`  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crew_members_identifier` (`identifier`),
    KEY `idx_pop_crew_members_crew` (`crew_id`),
    CONSTRAINT `fk_pop_crew_members_crew` FOREIGN KEY (`crew_id`) REFERENCES `pop_crews` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]

local SQL_SET_RANK = 'UPDATE `pop_crew_members` SET `rank` = ? WHERE `id` = ?'

local function loadAll()
    -- Échec éventuel visible dans la console ; c'est la lecture qui décide si le chargement a réussi.
    db(MySQL.query.await, SQL_CREWS)
    db(MySQL.query.await, SQL_MEMBERS)
    local crewRows = db(MySQL.query.await, 'SELECT `id`, `name`, `color` FROM `pop_crews`')
    local memberRows = db(MySQL.query.await,
        'SELECT `id`, `crew_id`, `identifier`, `name`, `rank` FROM `pop_crew_members` ORDER BY `joined_at`, `id`')
    if not crewRows or not memberRows then return false end

    local last = #Config.Ranks
    for _, row in ipairs(crewRows) do
        crews[row.id] = { id = row.id, name = row.name, color = row.color, members = {}, count = 0 }
        nameIndex[row.name:lower()] = row.id
    end

    local fixes = {}
    for _, row in ipairs(memberRows) do
        local crew = crews[row.crew_id]
        if crew then
            local rank = tonumber(row.rank) or last
            if rank < 1 or rank > last then
                rank = last
                fixes[#fixes + 1] = { rank, row.id }
            end
            attach(crew, row.identifier, { id = row.id, name = row.name or '', rank = rank })
        end
    end

    for id, crew in pairs(crews) do
        if crew.count == 0 then
            -- Crew sans membre : supprimé.
            db(MySQL.update.await, 'DELETE FROM `pop_crews` WHERE `id` = ?', { id })
            nameIndex[crew.name:lower()] = nil
            crews[id] = nil
        else
            -- Exactement un rang 1 : le membre au plus petit rang, puis le plus ancien (id auto-incrémenté).
            local list = {}
            for _, m in pairs(crew.members) do list[#list + 1] = m end
            table.sort(list, function(a, b)
                if a.rank ~= b.rank then return a.rank < b.rank end
                return a.id < b.id
            end)
            if list[1].rank ~= 1 then
                list[1].rank = 1
                fixes[#fixes + 1] = { 1, list[1].id }
            end
            -- NOTE: plusieurs chefs en base (édition manuelle) : seul le plus ancien le reste, les autres passent rang 2.
            for i = 2, #list do
                if list[i].rank == 1 then
                    list[i].rank = 2
                    fixes[#fixes + 1] = { 2, list[i].id }
                end
            end
        end
    end

    for _, f in ipairs(fixes) do db(MySQL.update.await, SQL_SET_RANK, f) end
    if #fixes > 0 then log('%d rank(s) corrected in database', #fixes) end
    return true
end

------------------------------------------------------------------------
-- Suppression d'un crew (dissolution / chef seul qui quitte)
------------------------------------------------------------------------

-- Renvoie true si supprimé. Notifications, pushes et events gérés ici (src = chef demandeur).
local function disbandCrew(crew, src)
    crew.closing = true -- bloque les autres actions sur ce crew pendant l'attente SQL
    if not db(MySQL.update.await, 'DELETE FROM `pop_crews` WHERE `id` = ?', { crew.id }) then
        crew.closing = nil
        return false
    end

    local online = {}
    for ident in pairs(crew.members) do
        local s = srcOf[ident]
        if s then online[#online + 1] = s end
        if crewOf[ident] == crew.id then crewOf[ident] = nil end
    end
    crews[crew.id] = nil
    nameIndex[crew.name:lower()] = nil
    for ident, inv in pairs(invites) do
        if inv.crewId == crew.id then invites[ident] = nil end
    end

    log('crew %d "%s" disbanded by %s', crew.id, crew.name, src)
    local msg = L('disbanded', crew.name)
    for _, s in ipairs(online) do
        if s ~= src then Bridge.Notify(s, msg, 'error') end
    end
    for _, s in ipairs(online) do TriggerClientEvent(EV_UPDATE, s, nil) end
    for _, s in ipairs(online) do TriggerEvent(EV_CHANGED, s, nil) end
    TriggerEvent(EV_DISBANDED, crew.id)
    return true
end

------------------------------------------------------------------------
-- Callbacks de lecture
------------------------------------------------------------------------

Callback.Register('pop_crew:getMine', function(src)
    if not loaded then return nil end
    return summary(identOf[src])
end)

Callback.Register('pop_crew:getPanel', function(src)
    if not loaded then return nil end
    local ident, crew, me = context(src)
    if not ident then return nil end

    if crew then
        local p = perms(me.rank)
        local last = #Config.Ranks
        local members = {}
        for mi, m in pairs(crew.members) do
            local mine = mi == ident
            local below = not mine and m.rank > me.rank
            local manageable = below and p.manage
            local up = m.rank - 1
            members[#members + 1] = {
                id = m.id, name = m.name,
                rank = m.rank, rankLabel = rankLabel(m.rank),
                online = srcOf[mi] ~= nil,
                me = mine,
                canKick = below and p.kick or false,
                canPromote = manageable and (up > me.rank or (up == 1 and me.rank == 1)) or false,
                canDemote = manageable and m.rank + 1 <= last or false,
            }
        end
        table.sort(members, function(a, b)
            if a.online ~= b.online then return a.online end
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.name:lower() < b.name:lower()
        end)
        return {
            crew = {
                id = crew.id, name = crew.name, color = crew.color,
                rank = me.rank, rankLabel = rankLabel(me.rank),
                perms = p,
                maxMembers = Config.MaxMembers,
                members = members,
            },
        }
    end

    local colors = {}
    for i, c in ipairs(Config.Colors) do colors[i] = c end
    local data = {
        create = {
            cost = createCost(),
            colors = colors,
            nameMin = Config.NameLength.min,
            nameMax = Config.NameLength.max,
        },
    }
    local inv = validInvite(ident)
    local ic = inv and crews[inv.crewId]
    if ic and not ic.closing then
        data.invite = { crew = ic.name, color = ic.color, expires = math.max(0, inv.expires - os.time()) }
    end
    return data
end)

Callback.Register('pop_crew:getNearby', function(src)
    local list = {}
    if not loaded then return list end
    local _, crew, me = context(src)
    if not crew or not perms(me.rank).invite then return list end
    local pos = Bridge.GetCoords(src)
    if not pos then return list end
    local bucket = GetPlayerRoutingBucket(src)
    local found = {}
    for s in pairs(identOf) do
        if s ~= src and GetPlayerRoutingBucket(s) == bucket then
            local p = Bridge.GetCoords(s)
            if p then
                local d = #(pos - p)
                if d <= Config.InviteDistance then found[#found + 1] = { id = s, d = d } end
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    for i, f in ipairs(found) do list[i] = { id = f.id, dist = math.floor(f.d + 0.5) } end
    return list
end)

------------------------------------------------------------------------
-- Callbacks d'action (mutations)
------------------------------------------------------------------------

-- Enveloppe commune : chargé, joueur connu, délai d'1 s, une seule mutation à la fois par joueur.
-- NOTE: clés communes du template utilisées ici : 'busy' (mutation en cours) et 'cooldown' (délai interne).
local function registerAction(cbName, fn)
    Callback.Register(cbName, function(src, ...)
        if not loaded or not identOf[src] then return false, 'error' end
        if locks[src] then return false, 'busy' end
        local now = GetGameTimer()
        if lastAction[src] and now - lastAction[src] < ACTION_DELAY then return false, 'cooldown', 1 end
        lastAction[src] = now
        locks[src] = true
        local res = table.pack(pcall(fn, src, ...))
        locks[src] = nil
        if not res[1] then
            print(('[%s] %s error: %s'):format(RES, cbName, tostring(res[2])))
            return false, 'error'
        end
        return table.unpack(res, 2, res.n)
    end)
end

-- F1 : créer un crew.
registerAction('pop_crew:create', function(src, rawName, color)
    if type(rawName) ~= 'string' or type(color) ~= 'string' then return false, 'error' end
    local ident, crew = context(src)
    if crew or crewOf[ident] then return false, 'already_in_crew' end

    local crewName = normalizeName(rawName)
    if not crewName then return false, 'name_invalid', Config.NameLength.min, Config.NameLength.max end
    if not validColor[color] then return false, 'color_invalid' end
    local key = crewName:lower()
    if nameIndex[key] then return false, 'name_taken' end

    nameIndex[key] = 0 -- réservation du nom pendant l'attente SQL
    local function release()
        if nameIndex[key] == 0 then nameIndex[key] = nil end
    end

    -- La base tranche aussi (collation _ci : casse des lettres accentuées) avant tout débit.
    local taken = db(MySQL.query.await, 'SELECT 1 FROM `pop_crews` WHERE `name` = ? LIMIT 1', { crewName })
    if not taken then
        release()
        return false, 'error'
    end
    if taken[1] then
        release()
        return false, 'name_taken'
    end

    local memberName = playerName(src)
    local cost = createCost()
    if cost > 0 and not Bridge.RemoveMoney(src, Config.CreateAccount, cost, RES) then
        release()
        return false, 'not_enough_money'
    end

    local function rollback(crewId)
        if crewId then db(MySQL.update.await, 'DELETE FROM `pop_crews` WHERE `id` = ?', { crewId }) end
        if cost > 0 and not Bridge.AddMoney(src, Config.CreateAccount, cost, RES) then
            print(('[%s] WARNING: refund of %d failed for %s (%s)'):format(RES, cost, src, ident))
        end
        release()
        resync(nil, src)
    end

    -- NOTE: course résiduelle (nom pris entre le SELECT et l'INSERT) : la contrainte UNIQUE refuse, remboursement et 'error'.
    local crewId = db(MySQL.insert.await, 'INSERT INTO `pop_crews` (`name`, `color`) VALUES (?, ?)', { crewName, color })
    if not crewId then
        rollback()
        return false, 'error'
    end
    local memberId = db(MySQL.insert.await,
        'INSERT INTO `pop_crew_members` (`crew_id`, `identifier`, `name`, `rank`) VALUES (?, ?, ?, 1)',
        { crewId, ident, memberName })
    if not memberId then
        rollback(crewId)
        return false, 'error'
    end

    local newCrew = { id = crewId, name = crewName, color = color, members = {}, count = 0 }
    crews[crewId] = newCrew
    nameIndex[key] = crewId
    attach(newCrew, ident, { id = memberId, name = memberName, rank = 1 })
    invites[ident] = nil

    log('crew %d "%s" created by %s (%s), cost %d', crewId, crewName, src, ident, cost)
    pushTo(src)
    TriggerEvent(EV_CHANGED, src, crewId)
    return true, 'crew_created', crewName
end)

-- F2 : inviter un joueur proche.
registerAction('pop_crew:invite', function(src, targetId)
    targetId = int(targetId)
    if not targetId then return false, 'error' end
    local ident, crew, me = memberCtx(src)
    if not ident then return false, crew end
    if not perms(me.rank).invite then return false, 'no_permission' end
    if crew.count >= Config.MaxMembers then return false, 'crew_full' end

    local tIdent = targetId ~= src and identOf[targetId]
    if not tIdent then return false, 'target_not_found' end
    -- Distance d'abord : un joueur éloigné ne doit rien apprendre sur la cible (crew, invitation).
    if not near(src, targetId) then return false, 'too_far' end
    if crewOf[tIdent] then return false, 'target_in_crew' end
    if validInvite(tIdent) then return false, 'invite_pending' end

    invites[tIdent] = { crewId = crew.id, expires = os.time() + Config.InviteTimeout }
    log('%s invited %s to crew %d', src, targetId, crew.id)
    Bridge.Notify(targetId, L('invite_received', crew.name, Config.Command), 'info')
    TriggerClientEvent(EV_UPDATE, targetId, nil)
    return true, 'invite_sent'
end)

-- F3 : répondre à une invitation.
registerAction('pop_crew:respond', function(src, accept)
    if type(accept) ~= 'boolean' then return false, 'error' end
    local ident = identOf[src]
    local inv = validInvite(ident)
    if not inv then return false, 'invite_expired' end
    invites[ident] = nil
    if not accept then return true, 'invite_declined' end

    if crewOf[ident] then return false, 'already_in_crew' end
    local crew = crews[inv.crewId]
    -- NOTE: crew supprimé entre-temps : traité comme une invitation qui n'existe plus.
    if not crew or crew.closing then return false, 'invite_expired' end
    if crew.count >= Config.MaxMembers then return false, 'crew_full' end

    -- Cache d'abord (place réservée), puis SQL.
    local m = { id = 0, name = playerName(src), rank = #Config.Ranks }
    attach(crew, ident, m)
    local memberId = db(MySQL.insert.await,
        'INSERT INTO `pop_crew_members` (`crew_id`, `identifier`, `name`, `rank`) VALUES (?, ?, ?, ?)',
        { crew.id, ident, m.name, m.rank })
    if not memberId or crews[crew.id] ~= crew or crew.members[ident] ~= m then
        detach(crew, ident)
        resync(crew, src)
        return false, 'error'
    end
    m.id = memberId

    log('%s (%s) joined crew %d', src, ident, crew.id)
    notifyCrew(crew, { [src] = true }, 'member_joined', m.name)
    pushCrew(crew)
    TriggerEvent(EV_CHANGED, src, crew.id)
    return true, 'joined', crew.name
end)

-- F4 : quitter (chef seul = dissolution).
registerAction('pop_crew:leave', function(src)
    local ident, crew, me = memberCtx(src)
    if not ident then return false, crew end
    if me.rank == 1 then
        if crew.count > 1 then return false, 'leader_must_transfer' end
        if not disbandCrew(crew, src) then
            resync(crew, src)
            return false, 'error'
        end
        return true, 'disbanded', crew.name
    end

    detach(crew, ident)
    if not db(MySQL.update.await, 'DELETE FROM `pop_crew_members` WHERE `id` = ?', { me.id }) then
        if crews[crew.id] == crew and not crewOf[ident] then attach(crew, ident, me) end
        resync(crew, src)
        return false, 'error'
    end

    log('%s (%s) left crew %d', src, ident, crew.id)
    notifyCrew(crew, { [src] = true }, 'member_left', me.name)
    pushCrew(crew)
    TriggerClientEvent(EV_UPDATE, src, nil)
    TriggerEvent(EV_CHANGED, src, nil)
    return true, 'left'
end)

-- F5 : exclure un membre de rang inférieur (en ligne ou non).
registerAction('pop_crew:kick', function(src, memberId)
    memberId = int(memberId)
    if not memberId or memberId < 1 then return false, 'error' end
    local ident, crew, me = memberCtx(src)
    if not ident then return false, crew end
    local tIdent, target = findMember(crew, memberId)
    if not target or tIdent == ident then return false, 'no_permission' end
    if not perms(me.rank).kick or target.rank <= me.rank then return false, 'no_permission' end

    detach(crew, tIdent)
    if not db(MySQL.update.await, 'DELETE FROM `pop_crew_members` WHERE `id` = ?', { target.id }) then
        if crews[crew.id] == crew and not crewOf[tIdent] then attach(crew, tIdent, target) end
        resync(crew, src, srcOf[tIdent])
        return false, 'error'
    end

    log('%s kicked member %d (%s) from crew %d', src, target.id, tIdent, crew.id)
    local ts = srcOf[tIdent]
    if ts then Bridge.Notify(ts, L('kicked', crew.name), 'error') end
    notifyCrew(crew, { [src] = true }, 'member_kicked', target.name)
    pushCrew(crew)
    if ts then
        TriggerClientEvent(EV_UPDATE, ts, nil)
        TriggerEvent(EV_CHANGED, ts, nil)
    end
    return true, 'member_kicked', target.name
end)

-- F6 : promouvoir / rétrograder, ou transférer le rang de chef.
registerAction('pop_crew:setRank', function(src, memberId, rank)
    memberId, rank = int(memberId), int(rank)
    if not memberId or not rank or memberId < 1 then return false, 'error' end
    local ident, crew, me = memberCtx(src)
    if not ident then return false, crew end
    local tIdent, target = findMember(crew, memberId)
    if not target or tIdent == ident then return false, 'no_permission' end
    if not perms(me.rank).manage or target.rank <= me.rank then return false, 'no_permission' end
    if rank < 1 or rank > #Config.Ranks or rank == target.rank then return false, 'error' end

    local transfer = rank == 1
    if transfer then
        if me.rank ~= 1 then return false, 'no_permission' end
    elseif rank <= me.rank then
        return false, 'no_permission'
    end

    local oldTarget, oldMe = target.rank, me.rank
    target.rank = rank
    local ok
    if transfer then
        me.rank = 2
        crew.busy = true -- verrou du crew pendant le transfert (testé dans memberCtx)
        ok = db(MySQL.transaction.await, {
            { query = SQL_SET_RANK, values = { 1, target.id } },
            { query = SQL_SET_RANK, values = { 2, me.id } },
        })
        crew.busy = nil
    else
        ok = db(MySQL.update.await, SQL_SET_RANK, { rank, target.id })
    end
    if not ok then
        if crew.members[tIdent] == target then target.rank = oldTarget end
        if crew.members[ident] == me then me.rank = oldMe end
        resync(crew, src)
        return false, 'error'
    end

    local label = rankLabel(rank)
    log('%s set member %d (%s) of crew %d to rank %d%s', src, target.id, tIdent, crew.id, rank, transfer and ' (transfer)' or '')
    local ts = srcOf[tIdent]
    if ts and ts ~= src then Bridge.Notify(ts, L('rank_changed', target.name, label), 'info') end
    pushCrew(crew)
    return true, 'rank_changed', target.name, label
end)

-- F7 : dissoudre (chef uniquement).
registerAction('pop_crew:disband', function(src)
    local ident, crew, me = memberCtx(src)
    if not ident then return false, crew end
    if me.rank ~= 1 then return false, 'no_permission' end
    if not disbandCrew(crew, src) then
        resync(crew, src)
        return false, 'error'
    end
    return true, 'disbanded', crew.name
end)

------------------------------------------------------------------------
-- Joueurs
------------------------------------------------------------------------

Bridge.OnPlayerLoaded(function(playerId)
    local src = tonumber(playerId)
    if not src then return end
    CreateThread(function()
        local tries = 0
        while not loaded do
            tries = tries + 1
            if tries > 600 then return end -- chargement impossible (erreur SQL / config) : abandon après 60 s
            Wait(100)
        end
        if not GetPlayerName(src) then return end
        local ident = Bridge.GetIdentifier(src)
        if not ident then return end

        -- Changement de personnage (multichar) sur la même source.
        local oldIdent = identOf[src]
        local oldCrewId = oldIdent and crewOf[oldIdent] or nil
        -- Personnage déchargé proprement avant (Bridge.OnPlayerUnloaded) : son crew a été mémorisé.
        local hadPrevious = oldIdent ~= nil
        if not hadPrevious and unloadedCrew[src] ~= nil then
            hadPrevious = true
            oldCrewId = unloadedCrew[src] or nil
        end
        unloadedCrew[src] = nil
        if oldIdent and oldIdent ~= ident then
            if srcOf[oldIdent] == src then srcOf[oldIdent] = nil end
            invites[oldIdent] = nil
            local oldCrew = crews[oldCrewId]
            if oldCrew then pushCrew(oldCrew) end
        end

        identOf[src] = ident
        srcOf[ident] = src

        local crew = crews[crewOf[ident]]
        if crew then
            local m = crew.members[ident]
            local n = playerName(src)
            if n ~= '' and n ~= m.name and m.id > 0 then
                m.name = n
                db(MySQL.update.await, 'UPDATE `pop_crew_members` SET `name` = ? WHERE `id` = ?', { n, m.id })
            end
            pushCrew(crew)
        else
            pushTo(src)
        end

        local newCrewId = crew and crew.id or nil
        if hadPrevious and oldCrewId ~= newCrewId then
            TriggerEvent(EV_CHANGED, src, newCrewId)
        end
    end)
end)

-- Oublie la source (hors ligne pour son crew). Renvoie le crewId du personnage, false s'il n'en a pas, nil si inconnu.
local function forget(src)
    local ident = identOf[src]
    if not ident then return nil end
    identOf[src] = nil
    if srcOf[ident] == src then srcOf[ident] = nil end
    invites[ident] = nil
    local crew = crews[crewOf[ident]]
    if crew then pushCrew(crew) end
    return crew and crew.id or false
end

Bridge.OnPlayerDropped(function(playerId)
    local src = tonumber(playerId)
    if not src then return end
    lastAction[src] = nil
    locks[src] = nil
    unloadedCrew[src] = nil
    forget(src)
end)

-- Déconnexion du personnage (multichar / logout) : traité comme un départ, la source reste connectée.
if Bridge.OnPlayerUnloaded then
    Bridge.OnPlayerUnloaded(function(playerId)
        local src = tonumber(playerId)
        if not src then return end
        local crewId = forget(src)
        if crewId ~= nil then unloadedCrew[src] = crewId end
        TriggerClientEvent(EV_UPDATE, src, nil)
    end)
end

------------------------------------------------------------------------
-- Exports (lecture seule sur le cache, copies)
------------------------------------------------------------------------

exports('GetPlayerCrew', function(src)
    if not loaded then return nil end
    local ident = identOf[tonumber(src)]
    local crew = ident and crews[crewOf[ident]]
    if not crew then return nil end
    local m = crew.members[ident]
    return { id = crew.id, name = crew.name, color = crew.color, rank = m.rank, rankLabel = rankLabel(m.rank) }
end)

exports('GetCrewMembers', function(crewId)
    local list = {}
    local crew = loaded and crews[tonumber(crewId)]
    if not crew then return list end
    for ident, m in pairs(crew.members) do
        list[#list + 1] = {
            id = m.id, identifier = ident, name = m.name,
            rank = m.rank, rankLabel = rankLabel(m.rank),
            online = srcOf[ident] ~= nil, source = srcOf[ident],
        }
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.id < b.id
    end)
    return list
end)

exports('GetCrew', function(crewId)
    local crew = loaded and crews[tonumber(crewId)]
    if not crew then return nil end
    local online = 0
    for ident in pairs(crew.members) do
        if srcOf[ident] then online = online + 1 end
    end
    return { id = crew.id, name = crew.name, color = crew.color, memberCount = crew.count, onlineCount = online }
end)

exports('IsSameCrew', function(srcA, srcB)
    if not loaded then return false end
    local a, b = identOf[tonumber(srcA)], identOf[tonumber(srcB)]
    local ca, cb = a and crewOf[a], b and crewOf[b]
    return ca ~= nil and ca == cb
end)

------------------------------------------------------------------------
-- Démarrage et nettoyage périodique des invitations
------------------------------------------------------------------------

CreateThread(function()
    if not sanitizeConfig() then return end
    if not loadAll() then
        print(('[%s] ERROR: database load failed, pop_crew is disabled'):format(RES))
        return
    end
    loaded = true
    local n = 0
    for _ in pairs(crews) do n = n + 1 end
    log('%d crew(s) loaded', n)

    -- Invitations expirées (aussi vérifiées à chaque lecture) : un passage par minute suffit.
    while true do
        Wait(60000)
        local now = os.time()
        for ident, inv in pairs(invites) do
            if inv.expires <= now then invites[ident] = nil end
        end
    end
end)
