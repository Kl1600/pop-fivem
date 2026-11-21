-- ─────────────────────────────────────────────
-- pop_crew - système de crew minimal
-- Base d'appartenance pour la guerre de territoires (pop_territories)
-- ─────────────────────────────────────────────

local ESX = exports['es_extended']:getSharedObject()

local crewsById = {}   -- [crewId]      = { id, name, label, owner, color = {r,g,b} }
local memberOf  = {}   -- [identifier]  = crewId
local invites   = {}   -- [identifier]  = crewId (invitation en attente)

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function notify(src, title, message, ntype)
    local icon = 'fas fa-circle-info'
    if ntype == 'success' then icon = 'fas fa-check'
    elseif ntype == 'error' then icon = 'fas fa-triangle-exclamation' end
    TriggerClientEvent('notification:client:ShowNotify', src, {
        title = title, message = message, icon = icon, duration = 5000,
    })
end

local function identifierOf(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function nameOf(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getName then return xPlayer.getName() end
    return ('Joueur %s'):format(src)
end

local function decodeColor(raw)
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
local function cleanTag(tag)
    if type(tag) ~= 'string' then return '' end
    return tag:upper():gsub('[^%w]', ''):sub(1, Config.MaxTagLen)
end

-- Label : sans balises, sans caractères de contrôle, espaces normalisés
local function cleanLabel(label)
    if type(label) ~= 'string' then return '' end
    label = label:gsub('[%c<>"`\\]', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return utf8Cut(label, Config.MaxLabelLen)
end

-- ─────────────────────────────────────────────
-- Chargement DB
-- ─────────────────────────────────────────────

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crews (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            name       VARCHAR(16) NOT NULL UNIQUE,
            label      VARCHAR(32) NOT NULL,
            owner      VARCHAR(64) NOT NULL,
            color      VARCHAR(24) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_members (
            identifier VARCHAR(64) PRIMARY KEY,
            crew_id    INT NOT NULL,
            `rank`     VARCHAR(16) DEFAULT 'member',
            name       VARCHAR(64) DEFAULT NULL,
            joined_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    -- Compat anciennes installs : ajoute la colonne name si absente
    pcall(function() MySQL.query.await('ALTER TABLE crew_members ADD COLUMN name VARCHAR(64) DEFAULT NULL') end)

    for _, c in ipairs(MySQL.query.await('SELECT * FROM crews') or {}) do
        c.color = decodeColor(c.color)
        -- Crews créés avant le filtrage : on nettoie l'affichage
        local lbl = cleanLabel(c.label)
        c.label = (lbl ~= '' and lbl) or c.name
        crewsById[c.id] = c
    end
    for _, m in ipairs(MySQL.query.await('SELECT identifier, crew_id FROM crew_members') or {}) do
        memberOf[m.identifier] = m.crew_id
    end
end)

-- ─────────────────────────────────────────────
-- Exports
-- ─────────────────────────────────────────────

-- Crew d'un joueur (par source). Retourne nil si sans crew.
exports('getCrew', function(src)
    local id = identifierOf(src)
    if not id then return nil end
    local cid = memberOf[id]
    local c = cid and crewsById[cid]
    if not c then return nil end
    return { id = c.id, name = c.name, label = c.label, color = c.color }
end)

exports('getCrewById', function(crewId)
    local c = crewsById[crewId]
    if not c then return nil end
    return { id = c.id, name = c.name, label = c.label, color = c.color }
end)

exports('getCrewIdByIdentifier', function(identifier)
    return memberOf[identifier]
end)

-- Sources des membres du crew actuellement connectés (pour notifications)
exports('getOnlineMemberSources', function(crewId)
    local out = {}
    for _, src in ipairs(GetPlayers()) do
        local id = identifierOf(tonumber(src))
        if id and memberOf[id] == crewId then
            out[#out + 1] = tonumber(src)
        end
    end
    return out
end)

-- ─────────────────────────────────────────────
-- État (pour le menu NUI)
-- ─────────────────────────────────────────────

local function buildState(src)
    local identifier = identifierOf(src)
    local state = { inCrew = false, isOwner = false, invite = nil }
    if not identifier then return state end

    local crewId = memberOf[identifier]
    if crewId and crewsById[crewId] then
        local c = crewsById[crewId]
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
        local invId = invites[identifier]
        if invId and crewsById[invId] then
            state.invite = crewsById[invId].label
        end
    end
    return state
end

local function pushState(src)
    TriggerClientEvent('pop_crew:state', src, buildState(src))
end

-- ─────────────────────────────────────────────
-- Opérations
-- ─────────────────────────────────────────────

local function createCrew(src, tag, label)
    local identifier = identifierOf(src)
    if not identifier then return end
    if memberOf[identifier] then
        return notify(src, 'Crew', 'Tu es déjà dans un crew.', 'error')
    end

    if type(tag) ~= 'string' then return end
    tag = cleanTag(tag)
    label = cleanLabel(label)
    if label == '' then label = tag end
    if #tag < 2 then
        return notify(src, 'Crew', 'Tag invalide (2-' .. Config.MaxTagLen .. ' caractères).', 'error')
    end

    local exists = MySQL.scalar.await('SELECT id FROM crews WHERE name = ?', { tag })
    if exists then
        return notify(src, 'Crew', 'Ce tag de crew est déjà pris.', 'error')
    end

    local color = json.encode(Config.DefaultColor)
    local crewId = MySQL.insert.await(
        'INSERT INTO crews (name, label, owner, color) VALUES (?, ?, ?, ?)',
        { tag, label, identifier, color }
    )
    if not crewId then
        return notify(src, 'Crew', 'Erreur lors de la création.', 'error')
    end

    MySQL.insert.await(
        'INSERT INTO crew_members (identifier, crew_id, `rank`, name) VALUES (?, ?, ?, ?)',
        { identifier, crewId, 'owner', nameOf(src) }
    )

    crewsById[crewId] = { id = crewId, name = tag, label = label, owner = identifier, color = Config.DefaultColor }
    memberOf[identifier] = crewId
    notify(src, 'Crew', ('Crew "%s" [%s] créé. Tu en es le chef.'):format(label, tag), 'success')
    pushState(src)
end

local function inviteToCrew(src, targetId)
    local identifier = identifierOf(src)
    local crewId = identifier and memberOf[identifier]
    if not crewId then return notify(src, 'Crew', 'Tu n\'es dans aucun crew.', 'error') end
    local myCrew = crewsById[crewId]
    if not myCrew or myCrew.owner ~= identifier then
        return notify(src, 'Crew', 'Seul le chef du crew peut recruter.', 'error')
    end

    targetId = tonumber(targetId)
    if not targetId then return notify(src, 'Crew', 'ID joueur invalide.', 'error') end
    local targetIdent = identifierOf(targetId)
    if not targetIdent then return notify(src, 'Crew', 'Joueur introuvable.', 'error') end
    -- Le recrutement se fait via ox_target : la cible doit être proche du chef
    local ped, tped = GetPlayerPed(src), GetPlayerPed(targetId)
    if ped == 0 or tped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(tped)) > 10.0 then
        return notify(src, 'Crew', 'Joueur trop loin.', 'error')
    end
    if memberOf[targetIdent] then return notify(src, 'Crew', 'Ce joueur est déjà dans un crew.', 'error') end

    invites[targetIdent] = crewId
    local c = crewsById[crewId]
    notify(src, 'Crew', 'Invitation envoyée.', 'success')
    notify(targetId, 'Crew', ('Invitation au crew "%s". Ouvre /%s pour accepter.'):format(c.label, Config.Command), 'inform')
    pushState(targetId)
end

local function acceptInvite(src)
    local identifier = identifierOf(src)
    if not identifier then return end
    if memberOf[identifier] then return notify(src, 'Crew', 'Tu es déjà dans un crew.', 'error') end
    local crewId = invites[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return notify(src, 'Crew', 'Aucune invitation en attente.', 'error') end

    MySQL.insert.await(
        'INSERT INTO crew_members (identifier, crew_id, `rank`, name) VALUES (?, ?, ?, ?)',
        { identifier, crewId, 'member', nameOf(src) }
    )
    memberOf[identifier] = crewId
    invites[identifier] = nil
    notify(src, 'Crew', ('Tu as rejoint "%s".'):format(c.label), 'success')
    pushState(src)
end

local function declineInvite(src)
    local identifier = identifierOf(src)
    if identifier then invites[identifier] = nil end
    notify(src, 'Crew', 'Invitation refusée.', 'inform')
    pushState(src)
end

local function leaveCrew(src)
    local identifier = identifierOf(src)
    local crewId = identifier and memberOf[identifier]
    if not crewId then return notify(src, 'Crew', 'Tu n\'es dans aucun crew.', 'error') end
    local c = crewsById[crewId]
    if c and c.owner == identifier then
        return notify(src, 'Crew', 'Le chef ne peut pas quitter : utilise /' .. Config.Command .. ' disband.', 'error')
    end

    MySQL.query.await('DELETE FROM crew_members WHERE identifier = ?', { identifier })
    memberOf[identifier] = nil
    notify(src, 'Crew', 'Tu as quitté le crew.', 'inform')
    pushState(src)
end

local function disbandCrew(src)
    local identifier = identifierOf(src)
    local crewId = identifier and memberOf[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return notify(src, 'Crew', 'Tu n\'es dans aucun crew.', 'error') end
    if c.owner ~= identifier then return notify(src, 'Crew', 'Seul le chef peut dissoudre le crew.', 'error') end

    -- Membres en ligne (avant suppression) pour notif + refresh menu
    local onlineMembers = exports.pop_crew:getOnlineMemberSources(crewId)
    for _, msrc in ipairs(onlineMembers) do
        notify(msrc, 'Crew', ('Le crew "%s" a été dissous.'):format(c.label), 'error')
    end

    MySQL.query.await('DELETE FROM crew_members WHERE crew_id = ?', { crewId })
    MySQL.query.await('DELETE FROM crews WHERE id = ?', { crewId })
    for ident, cid in pairs(memberOf) do
        if cid == crewId then memberOf[ident] = nil end
    end
    crewsById[crewId] = nil

    -- pop_territories nettoie les parts de territoire de ce crew
    TriggerEvent('pop_crew:disbanded', crewId)
    notify(src, 'Crew', 'Crew dissous.', 'success')
    for _, msrc in ipairs(onlineMembers) do pushState(msrc) end
end

local function setColor(src, color)
    local identifier = identifierOf(src)
    local crewId = identifier and memberOf[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return notify(src, 'Crew', 'Tu n\'es dans aucun crew.', 'error') end
    if c.owner ~= identifier then return notify(src, 'Crew', 'Seul le chef peut changer la couleur.', 'error') end

    if type(color) ~= 'table' then return end
    local rgb = {
        math.max(0, math.min(255, math.floor(tonumber(color[1]) or 200))),
        math.max(0, math.min(255, math.floor(tonumber(color[2]) or 70))),
        math.max(0, math.min(255, math.floor(tonumber(color[3]) or 190))),
    }

    c.color = rgb
    MySQL.query('UPDATE crews SET color = ? WHERE id = ?', { json.encode(rgb), crewId })

    -- Les territoires contrôlés par ce crew peuvent se recolorer (hook)
    TriggerEvent('pop_crew:colorChanged', crewId, rgb)

    -- Refresh du menu pour tous les membres en ligne
    for _, msrc in ipairs(exports.pop_crew:getOnlineMemberSources(crewId)) do
        pushState(msrc)
    end
end

-- La commande /crew est gérée côté client (ouvre le menu NUI) ; voir client.lua.

-- ─────────────────────────────────────────────
-- Pont NUI : callback d'état + actions
-- ─────────────────────────────────────────────

ESX.RegisterServerCallback('pop_crew:getState', function(source, cb)
    cb(buildState(source))
end)

RegisterNetEvent('pop_crew:create',  function(tag, label) createCrew(source, tag, label) end)
RegisterNetEvent('pop_crew:accept',  function() acceptInvite(source) end)
RegisterNetEvent('pop_crew:decline', function() declineInvite(source) end)
RegisterNetEvent('pop_crew:leave',   function() leaveCrew(source) end)
RegisterNetEvent('pop_crew:disband', function() disbandCrew(source) end)
RegisterNetEvent('pop_crew:invite',  function(targetId) inviteToCrew(source, targetId) end)
RegisterNetEvent('pop_crew:setColor', function(color) setColor(source, color) end)

AddEventHandler('playerDropped', function()
    local identifier = identifierOf(source)
    if identifier then invites[identifier] = nil end
end)
