local denied = {}

function AdminLog(src, action, target, details)
    local actor = src == 0 and 'System' or (GetPlayerName(src) or '?')
    local message = ('%s (#%s) %s'):format(actor, src, action)
    if target then message = message .. (' -> %s (#%s)'):format(GetPlayerName(target) or '?', target) end
    if details then message = message .. ' | ' .. tostring(details) end
    message = message:gsub('%c', ' ')
    print('[pop_admin] ' .. message)
    local webhook = Config.Webhook
    if not webhook:match('^https://') then return end
    if not utf8.len(message) then message = message:gsub('[\128-\255]', '') end
    local offset = utf8.offset(message, 1001)
    if offset then message = message:sub(1, offset - 1) end
    local payload = json.encode({
        username = 'pop_admin',
        allowed_mentions = { parse = {} },
        embeds = { {
            title = action, description = message:gsub('@', '@\u{200B}'),
            color = tonumber(Config.AccentColor:sub(2), 16), timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
    PerformHttpRequest(webhook, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

function AdminDenied(src, action)
    local now = GetGameTimer()
    if denied[src] and now - denied[src] < 10000 then return end
    denied[src] = now
    print(('[pop_admin] DENIED #%s %s'):format(src, action))
end

Bridge.OnPlayerDropped(function(src) denied[src] = nil end)
