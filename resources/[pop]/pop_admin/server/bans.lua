Bans = { Ready = false }
local bans, byIdentifier, warnings, changing = {}, {}, {}, {}
local allowed = { license = true, license2 = true, steam = true, discord = true, fivem = true, xbl = true, live = true }

function Bans.Identifiers(src)
    local license, ids = nil, {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local kind = identifier:match('^([%w]+):')
        if allowed[kind] then
            ids[#ids + 1] = identifier
            if kind == 'license' then license = identifier end
        end
    end
    return license, ids
end

local function index(ban)
    bans[ban.id] = ban
    for _, identifier in ipairs(ban.identifiers) do
        if not byIdentifier[identifier] then byIdentifier[identifier] = {} end
        byIdentifier[identifier][ban.id] = true
    end
end

function Bans.Load()
    local schema = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql'))
    for statement in schema:gmatch('([^;]+);') do MySQL.query.await(statement) end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM pop_admin_bans WHERE active = 1')) do
        index({
            id = row.id, name = row.name, reason = row.reason, admin = row.admin,
            identifiers = json.decode(row.identifiers), createdAt = row.created_at, expiresAt = row.expires_at,
        })
    end
    for _, row in ipairs(MySQL.query.await('SELECT license, COUNT(*) AS n FROM pop_admin_warns GROUP BY license')) do
        warnings[row.license] = tonumber(row.n)
    end
end

local function active(ban)
    return not ban.expiresAt or ban.expiresAt > os.time()
end

function Bans.Find(ids)
    local best
    for _, identifier in ipairs(ids) do
        for id in pairs(byIdentifier[identifier] or {}) do
            local ban = bans[id]
            if active(ban) and (not best or id > best.id) then best = ban end
        end
    end
    return best
end

function Bans.ToRow(ban)
    return {
        id = ban.id, name = ban.name, reason = ban.reason, admin = ban.admin,
        createdAt = os.date('%Y-%m-%d %H:%M', ban.createdAt),
        expiresAt = ban.expiresAt and os.date('%Y-%m-%d %H:%M', ban.expiresAt),
    }
end

function Bans.List()
    local list = {}
    for id, ban in pairs(bans) do if active(ban) then list[#list + 1] = id end end
    table.sort(list, function(a, b) return a > b end)
    local rows = {}
    for i = 1, math.min(#list, 100) do rows[i] = Bans.ToRow(bans[list[i]]) end
    return rows
end

function Bans.Message(ban)
    return L('ban_message', ban.reason, Bans.ToRow(ban).expiresAt or L('ban_permanent'), ban.id)
end

local function playerName(src)
    local name = Bridge.GetName(src) or GetPlayerName(src) or ''
    if not utf8.len(name) then name = name:gsub('[\128-\255]', '') end
    local offset = utf8.offset(name, 65)
    return offset and name:sub(1, offset - 1) or name
end

function Bans.Add(src, reason, hours, admin, adminLicense)
    if not Bans.Ready then return end
    local license, ids = Bans.Identifiers(src)
    if not license or changing[license] then return end
    local now = os.time()
    local expiresAt = hours > 0 and now + hours * 3600 or nil
    local name = playerName(src)
    local encoded = json.encode(ids)
    changing[license] = true
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO pop_admin_bans (license, identifiers, name, reason, admin, admin_license, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), ?, NULLIF(?, 0))
    ]], { license, encoded, name, reason, admin, adminLicense or '', now, expiresAt or 0 })
    changing[license] = nil
    if not ok or not id or id <= 0 then return end
    local ban = { id = id, name = name, reason = reason, admin = admin,
        identifiers = ids, createdAt = now, expiresAt = expiresAt }
    index(ban)
    return ban
end

function Bans.Remove(id)
    local ban = bans[id]
    if not ban or changing[id] then return false end
    changing[id] = true
    local ok, count = pcall(MySQL.update.await, 'UPDATE pop_admin_bans SET active = 0 WHERE id = ?', { id })
    changing[id] = nil
    if not ok or count ~= 1 then return false end
    for _, identifier in ipairs(ban.identifiers) do
        local matches = byIdentifier[identifier]
        matches[id] = nil
        if not next(matches) then byIdentifier[identifier] = nil end
    end
    bans[id] = nil
    return true
end

function Bans.Warn(src, reason, admin, adminLicense)
    if not Bans.Ready then return false end
    local license = Bans.Identifiers(src)
    if not license then return false end
    local id = MySQL.insert.await([[
        INSERT INTO pop_admin_warns (license, name, reason, admin, admin_license, created_at)
        VALUES (?, ?, ?, ?, NULLIF(?, ''), ?)
    ]], { license, playerName(src), reason, admin, adminLicense or '', os.time() })
    if not id or id <= 0 then return false end
    warnings[license] = (warnings[license] or 0) + 1
    return true
end

function Bans.WarnCount(license)
    return warnings[license] or 0
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(L('ban_checking'))
    Wait(0)
    local timeout = GetGameTimer() + 10000
    while not Bans.Ready and GetGameTimer() < timeout do Wait(100) end
    if not Bans.Ready then
        print('[pop_admin] Ban cache unavailable during player connection')
        return deferrals.done(L('error'))
    end
    local _, ids = Bans.Identifiers(src)
    local ban = Bans.Find(ids)
    if ban then deferrals.done(Bans.Message(ban)) else deferrals.done() end
end)
