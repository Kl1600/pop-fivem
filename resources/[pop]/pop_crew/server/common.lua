-- ─────────────────────────────────────────────
-- pop_crew - système de crew minimal
-- Base d'appartenance pour la guerre de territoires (pop_territories)
-- Fonctions communes du serveur (chargé en premier, voir fxmanifest).
-- ─────────────────────────────────────────────

Crew = {}

Crew.crewsById = {}   -- [crewId]      = { id, name, label, owner, color = {r,g,b} }
Crew.memberOf  = {}   -- [identifier]  = crewId
Crew.invites   = {}   -- [identifier]  = crewId (invitation en attente)

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

--- Notification au style d'origine (titre « Crew », icône selon le type).
function Crew.Notify(src, message, ntype)
    local icon = 'fas fa-circle-info'
    if ntype == 'success' then icon = 'fas fa-check'
    elseif ntype == 'error' then icon = 'fas fa-triangle-exclamation' end
    Bridge.Notify(src, {
        title = L('crew_title'), message = message, icon = icon, duration = Config.NotifyDuration,
    })
end

function Crew.IdentifierOf(src)
    return Bridge.GetIdentifier(src)
end

function Crew.NameOf(src)
    return Bridge.GetName(src) or L('player_fallback', src)
end

function Crew.DecodeColor(raw)
    if type(raw) ~= 'string' or raw == '' then return Config.DefaultColor end
    local ok, c = pcall(json.decode, raw)
    if ok and type(c) == 'table' and #c == 3 then return c end
    return Config.DefaultColor
end

-- Coupe une chaîne UTF-8 à maxChars caractères (sans casser un caractère accentué)
local function utf8Cut(str, maxChars)
    if not utf8.len(str) then
        str = str:gsub('[\128-\255]', '') -- UTF-8 invalide : on garde l'ASCII
    end
    local cut = utf8.offset(str, maxChars + 1)
    if cut then str = str:sub(1, cut - 1) end
    return str
end

-- Tag : lettres et chiffres uniquement, majuscules
function Crew.CleanTag(tag)
    if type(tag) ~= 'string' then return '' end
    return tag:upper():gsub('[^%w]', ''):sub(1, Config.MaxTagLen)
end

-- Label : sans balises, sans caractères de contrôle, espaces normalisés
function Crew.CleanLabel(label)
    if type(label) ~= 'string' then return '' end
    label = label:gsub('[%c<>"`\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return utf8Cut(label, Config.MaxLabelLen)
end

-- Sources des membres du crew actuellement connectés (pour notifications)
function Crew.GetOnlineMemberSources(crewId)
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        local id = Crew.IdentifierOf(tonumber(src))
        if id and Crew.memberOf[id] == crewId then
            out[#out + 1] = tonumber(src)
        end
    end
    return out
end

-- ─────────────────────────────────────────────
-- État (pour le menu NUI)
-- ─────────────────────────────────────────────

function Crew.BuildState(src)
    local identifier = Crew.IdentifierOf(src)
    local state = { inCrew = false, isOwner = false, invite = nil }
    if not identifier then return state end

    local crewId = Crew.memberOf[identifier]
    if crewId and Crew.crewsById[crewId] then
        local c = Crew.crewsById[crewId]
        state.inCrew  = true
        state.isOwner = (c.owner == identifier)
        state.tag     = c.name
        state.label   = c.label
        state.color   = c.color
        state.members = {}
        for _, m in ipairs(MySQL.query.await('SELECT name, `rank` FROM crew_members WHERE crew_id = ?', { crewId }) or {}) do
            state.members[#state.members + 1] = { name = m.name or '—', rank = m.rank or 'member' }
        end
        state.memberCount = #state.members
    else
        local invId = Crew.invites[identifier]
        if invId and Crew.crewsById[invId] then
            state.invite = Crew.crewsById[invId].label
        end
    end
    return state
end

function Crew.PushState(src)
    TriggerClientEvent('pop_crew:state', src, Crew.BuildState(src))
end
