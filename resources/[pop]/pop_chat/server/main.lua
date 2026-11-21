local lastAction = {}
local replaced = {
    [0x061c] = true, [0x200e] = true, [0x200f] = true,
    [0x202a] = true, [0x202b] = true, [0x202c] = true, [0x202d] = true, [0x202e] = true,
    [0x2066] = true, [0x2067] = true, [0x2068] = true, [0x2069] = true,
}

local function sanitize(raw)
    -- Limit the raw UTF-8 buffer before iterating and normalize ASCII controls and bidi formatting.
    if #raw > Config.MaxLength * 4 then return end
    local length = utf8.len(raw)
    if not length then return end
    local out = {}
    for _, code in utf8.codes(raw) do
        if code < 0x20 or (code >= 0x7f and code <= 0x9f) or code == 0x2028 or code == 0x2029 or replaced[code] then
            out[#out + 1] = ' '
        else
            out[#out + 1] = utf8.char(code)
        end
    end
    local text = table.concat(out):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if text == '' or utf8.len(text) > Config.MaxLength then return end
    return text
end

RegisterCommand(Config.Command, function(src, args)
    src = tonumber(src)
    if not src or src <= 0 or not Bridge.GetPlayer(src) or Bridge.IsDead(src) then return end
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < Config.Cooldown then return end
    lastAction[src] = now
    local text = sanitize(table.concat(args, ' '))
    if not text then
        Bridge.Notify(src, L('action_invalid', Config.MaxLength), 'error')
        return
    end
    local pos = Bridge.GetCoords(src)
    if not pos then return end
    local ped = GetPlayerPed(src)
    local netId = ped ~= 0 and NetworkGetNetworkIdFromEntity(ped)
    if not netId or netId == 0 then return end
    local bucket = GetPlayerRoutingBucket(src)
    for _, target in ipairs(Bridge.GetPlayers()) do
        if GetPlayerRoutingBucket(target) == bucket and Bridge.IsNear(target, pos, Config.Distance) then
            TriggerClientEvent('pop_chat:client:action', target, src, netId, text, Config.Duration)
        end
    end
end, false)

local function cleanup(src)
    local player = tonumber(src)
    if player then lastAction[player] = nil end
end
Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
