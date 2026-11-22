-- Opérations sur les crews + pont NUI (callback d'état, évènements d'action).

local Notify = Crew.Notify
local IdentifierOf = Crew.IdentifierOf
local crewsById, memberOf, invites = Crew.crewsById, Crew.memberOf, Crew.invites

-- ─────────────────────────────────────────────
-- Opérations
-- ─────────────────────────────────────────────

local function createCrew(src, tag, label)
    local identifier = IdentifierOf(src)
    if not identifier then return end
    if memberOf[identifier] then
        return Notify(src, L('already_in_crew'), 'error')
    end

    if type(tag) ~= 'string' then return end
    tag = Crew.CleanTag(tag)
    label = Crew.CleanLabel(label)
    if label == '' then label = tag end
    if #tag < 2 then
        return Notify(src, L('invalid_tag', Config.MaxTagLen), 'error')
    end

    local exists = MySQL.scalar.await('SELECT id FROM crews WHERE name = ?', { tag })
    if exists then
        return Notify(src, L('tag_taken'), 'error')
    end

    local color = json.encode(Config.DefaultColor)
    local crewId = MySQL.insert.await(
        'INSERT INTO crews (name, label, owner, color) VALUES (?, ?, ?, ?)',
        { tag, label, identifier, color }
    )
    if not crewId then
        return Notify(src, L('create_error'), 'error')
    end

    MySQL.insert.await(
        'INSERT INTO crew_members (identifier, crew_id, `rank`, name) VALUES (?, ?, ?, ?)',
        { identifier, crewId, 'owner', Crew.NameOf(src) }
    )

    crewsById[crewId] = { id = crewId, name = tag, label = label, owner = identifier, color = Config.DefaultColor }
    memberOf[identifier] = crewId
    Notify(src, L('crew_created', label, tag), 'success')
    Crew.PushState(src)
end

local function inviteToCrew(src, targetId)
    local identifier = IdentifierOf(src)
    local crewId = identifier and memberOf[identifier]
    if not crewId then return Notify(src, L('not_in_crew'), 'error') end
    local myCrew = crewsById[crewId]
    if not myCrew or myCrew.owner ~= identifier then
        return Notify(src, L('owner_only_recruit'), 'error')
    end

    targetId = tonumber(targetId)
    if not targetId then return Notify(src, L('invalid_player_id'), 'error') end
    local targetIdent = IdentifierOf(targetId)
    if not targetIdent then return Notify(src, L('player_not_found'), 'error') end
    -- Le recrutement se fait via ox_target : la cible doit être proche du chef
    if not Bridge.IsNear(src, Bridge.GetCoords(targetId), Config.RecruitMaxDistance) then
        return Notify(src, L('player_too_far'), 'error')
    end
    if memberOf[targetIdent] then return Notify(src, L('target_in_crew'), 'error') end

    invites[targetIdent] = crewId
    local c = crewsById[crewId]
    Notify(src, L('invite_sent'), 'success')
    Notify(targetId, L('invite_received', c.label, Config.Command), 'inform')
    Crew.PushState(targetId)
end

local function acceptInvite(src)
    local identifier = IdentifierOf(src)
    if not identifier then return end
    if memberOf[identifier] then return Notify(src, L('already_in_crew'), 'error') end
    local crewId = invites[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return Notify(src, L('no_invite'), 'error') end

    MySQL.insert.await(
        'INSERT INTO crew_members (identifier, crew_id, `rank`, name) VALUES (?, ?, ?, ?)',
        { identifier, crewId, 'member', Crew.NameOf(src) }
    )
    memberOf[identifier] = crewId
    invites[identifier] = nil
    Notify(src, L('crew_joined', c.label), 'success')
    Crew.PushState(src)
end

local function declineInvite(src)
    local identifier = IdentifierOf(src)
    if identifier then invites[identifier] = nil end
    Notify(src, L('invite_declined'), 'inform')
    Crew.PushState(src)
end

local function leaveCrew(src)
    local identifier = IdentifierOf(src)
    local crewId = identifier and memberOf[identifier]
    if not crewId then return Notify(src, L('not_in_crew'), 'error') end
    local c = crewsById[crewId]
    if c and c.owner == identifier then
        return Notify(src, L('owner_cant_leave', Config.Command), 'error')
    end

    MySQL.query.await('DELETE FROM crew_members WHERE identifier = ?', { identifier })
    memberOf[identifier] = nil
    Notify(src, L('crew_left'), 'inform')
    Crew.PushState(src)
end

local function disbandCrew(src)
    local identifier = IdentifierOf(src)
    local crewId = identifier and memberOf[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return Notify(src, L('not_in_crew'), 'error') end
    if c.owner ~= identifier then return Notify(src, L('owner_only_disband'), 'error') end

    -- Membres en ligne (avant suppression) pour notif + refresh menu
    local onlineMembers = Crew.GetOnlineMemberSources(crewId)
    for _, msrc in ipairs(onlineMembers) do
        Notify(msrc, L('crew_disbanded_by', c.label), 'error')
    end

    MySQL.query.await('DELETE FROM crew_members WHERE crew_id = ?', { crewId })
    MySQL.query.await('DELETE FROM crews WHERE id = ?', { crewId })
    for ident, cid in pairs(memberOf) do
        if cid == crewId then memberOf[ident] = nil end
    end
    crewsById[crewId] = nil

    -- pop_territories nettoie les parts de territoire de ce crew
    TriggerEvent('pop_crew:disbanded', crewId)
    Notify(src, L('crew_disbanded'), 'success')
    for _, msrc in ipairs(onlineMembers) do Crew.PushState(msrc) end
end

local function setColor(src, color)
    local identifier = IdentifierOf(src)
    local crewId = identifier and memberOf[identifier]
    local c = crewId and crewsById[crewId]
    if not c then return Notify(src, L('not_in_crew'), 'error') end
    if c.owner ~= identifier then return Notify(src, L('owner_only_color'), 'error') end

    if type(color) ~= 'table' then return end
    local def = Config.DefaultColor
    local rgb = {
        math.max(0, math.min(255, math.floor(tonumber(color[1]) or def[1]))),
        math.max(0, math.min(255, math.floor(tonumber(color[2]) or def[2]))),
        math.max(0, math.min(255, math.floor(tonumber(color[3]) or def[3]))),
    }

    c.color = rgb
    MySQL.query('UPDATE crews SET color = ? WHERE id = ?', { json.encode(rgb), crewId })

    -- Les territoires contrôlés par ce crew peuvent se recolorer (hook)
    TriggerEvent('pop_crew:colorChanged', crewId, rgb)

    -- Refresh du menu pour tous les membres en ligne
    for _, msrc in ipairs(Crew.GetOnlineMemberSources(crewId)) do
        Crew.PushState(msrc)
    end
end

-- La commande /crew est gérée côté client (ouvre le menu NUI) ; voir client/main.lua.

-- ─────────────────────────────────────────────
-- Pont NUI : callback d'état + actions
-- ─────────────────────────────────────────────

Callback.Register('pop_crew:getState', function(source)
    return Crew.BuildState(source)
end)

RegisterNetEvent('pop_crew:create',  function(tag, label) createCrew(source, tag, label) end)
RegisterNetEvent('pop_crew:accept',  function() acceptInvite(source) end)
RegisterNetEvent('pop_crew:decline', function() declineInvite(source) end)
RegisterNetEvent('pop_crew:leave',   function() leaveCrew(source) end)
RegisterNetEvent('pop_crew:disband', function() disbandCrew(source) end)
RegisterNetEvent('pop_crew:invite',  function(targetId) inviteToCrew(source, targetId) end)
RegisterNetEvent('pop_crew:setColor', function(color) setColor(source, color) end)

AddEventHandler('playerDropped', function()
    local identifier = IdentifierOf(source)
    if identifier then invites[identifier] = nil end
end)
