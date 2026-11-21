local incoming, outgoing, lastInvite, playing = {}, {}, {}, {}
local nextInvite = 0

local function eligible(src)
    if not GetPlayerName(src) or Bridge.IsDead(src) then return false end
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local metadata = player.PlayerData and player.PlayerData.metadata
        if metadata and metadata.ishandcuffed == true then return false end
    end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return false end
    if GetResourceState('pop_police') == 'started' then
        local ok, cuffed = pcall(function() return exports.pop_police:IsCuffed(src) end)
        if ok and cuffed then return false end
    end
    return Player(src).state.cuffed ~= true
end

local function canPlayTogether(src, target)
    if math.type(target) ~= 'integer' or target <= 0 or src == target or not eligible(src) or not eligible(target) then
        return false, 'unavailable'
    end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then return false, 'too_far' end
    local pos = Bridge.GetCoords(target)
    if not pos or not Bridge.IsNear(src, pos, Config.InviteDistance) then return false, 'too_far' end
    return true
end

local function close(offer)
    if incoming[offer.target] ~= offer or outgoing[offer.sender] ~= offer then return false end
    incoming[offer.target], outgoing[offer.sender] = nil, nil
    if GetPlayerName(offer.target) and Bridge.GetIdentifier(offer.target) == offer.targetId then
        TriggerClientEvent('pop_emotes:client:inviteClosed', offer.target, offer.ticket)
    end
    return true
end

Callback.Register('pop_emotes:invite', function(src, target, id)
    local choice = type(id) == 'string' and #id <= 32 and Config.Catalog[id]
    if not choice or choice.shared ~= true or math.type(choice.duration) ~= 'integer'
        or choice.duration < 1 or choice.duration > 15000 then return false, 'unavailable' end
    local valid, why = canPlayTogether(src, target)
    if not valid then return false, why end
    local now = GetGameTimer()
    local remaining = lastInvite[src] and Config.InviteCooldown * 1000 - (now - lastInvite[src]) or 0
    if remaining > 0 then return false, 'cooldown', math.ceil(remaining / 1000) end
    if incoming[src] or outgoing[src] or incoming[target] or outgoing[target]
        or playing[src] or playing[target] then return false, 'busy' end
    local sourceId, targetId = Bridge.GetIdentifier(src), Bridge.GetIdentifier(target)
    if not sourceId or not targetId then return false, 'unavailable' end

    nextInvite = nextInvite + 1
    local offer = {
        sender = src, target = target, sourceId = sourceId, targetId = targetId, id = id, duration = choice.duration,
        ticket = nextInvite, expires = now + Config.InviteSeconds * 1000,
    }
    incoming[target], outgoing[src], lastInvite[src] = offer, offer, now
    TriggerClientEvent('pop_emotes:client:invite', target, offer.ticket, Bridge.GetName(src) or '#' .. src, id, Config.InviteSeconds)
    SetTimeout(Config.InviteSeconds * 1000, function()
        if close(offer) and GetPlayerName(src) and Bridge.GetIdentifier(src) == offer.sourceId then
            Bridge.Notify(src, L('invite_expired'), 'info')
        end
    end)
    return true
end)

Callback.Register('pop_emotes:respond', function(src, ticket, accept)
    if type(accept) ~= 'boolean' or math.type(ticket) ~= 'integer' then return false, 'error' end
    local offer = incoming[src]
    if not offer or offer.ticket ~= ticket or offer.expires <= GetGameTimer() then return false, 'invite_missing' end
    local sender = offer.sender
    if Bridge.GetIdentifier(src) ~= offer.targetId or Bridge.GetIdentifier(sender) ~= offer.sourceId then
        close(offer)
        return false, 'invite_missing'
    end
    if accept then
        local allowed, reason = canPlayTogether(sender, src)
        if not allowed then
            close(offer)
            Bridge.Notify(sender, L(reason), 'error')
            return false, reason
        end
    end
    if not close(offer) then return false, 'invite_missing' end
    if not accept then
        Bridge.Notify(sender, L('invite_declined'), 'info')
        return true
    end
    playing[src], playing[sender] = offer, offer
    SetTimeout(offer.duration + 3000, function()
        if playing[src] == offer then playing[src] = nil end
        if playing[sender] == offer then playing[sender] = nil end
    end)
    TriggerClientEvent('pop_emotes:client:play', src, offer.id, sender, true)
    TriggerClientEvent('pop_emotes:client:play', sender, offer.id, src, false)
    return true
end)

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    local offer = incoming[src] or outgoing[src]
    if offer then close(offer) end
    local shared = playing[src]
    if shared then
        if playing[shared.sender] == shared then playing[shared.sender] = nil end
        if playing[shared.target] == shared then playing[shared.target] = nil end
    end
    lastInvite[src] = nil
end
Bridge.OnPlayerUnloaded(cleanup)
Bridge.OnPlayerDropped(cleanup)
