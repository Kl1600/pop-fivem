local resource = GetCurrentResourceName()
local active, requests = {}, {}
local ready = false

local function itemFor(variant)
    if variant ~= 'us' and variant ~= 'mx' then return end
    return Config.Items[variant]
end

local function trim(value, limit)
    if type(value) ~= 'string' or not utf8.len(value) then return end
    value = value:gsub('%c+', ' '):match('^%s*(.-)%s*$')
    if value == '' then return end
    local offset = utf8.offset(value, limit + 1)
    return offset and value:sub(1, offset - 1) or value
end

local function identityFor(src)
    local profile
    if GetResourceState('pop_charcreator') == 'started' then
        local ok, data = pcall(function() return exports.pop_charcreator:GetIdentity(src) end)
        if ok and type(data) == 'table' then profile = data end
    end
    if profile then
        local first = trim(profile.firstName, 48)
        local last = trim(profile.lastName, 48)
        if first and last then
            local birth = type(profile.dateOfBirth) == 'string' and profile.dateOfBirth:match('^%d%d%d%d%-%d%d%-%d%d$')
            local sex = profile.model == 'mp_m_freemode_01' and 'male' or profile.model == 'mp_f_freemode_01' and 'female'
            return first .. ' ' .. last, birth or '', sex or ''
        end
    end
    return trim(Bridge.GetName(src), 100) or trim(GetPlayerName(src), 100), '', ''
end

local function getRecord(owner, variant)
    return MySQL.single.await(
        [[SELECT serial, display_name, birth_date, sex, issued_at, expires_at
        FROM pop_idcard_documents WHERE owner = ? AND variant = ?]], { owner, variant }
    )
end

local function hasDocument(src, item, serial)
    if not Bridge.SupportsMetadata() then return Bridge.HasItem(src, item, 1) end
    for _, stack in ipairs(Bridge.GetItems(src, item)) do
        if stack.count > 0 and tonumber(stack.metadata.serial) == serial then return true end
    end
    return false
end

local function playerConnected(src)
    return math.type(src) == 'integer' and src > 0 and src <= 65535 and GetPlayerName(src) ~= nil
end

local function issue(src, variant)
    local item = itemFor(variant)
    if not item then return false, 'invalid_variant' end
    if not ready then return false, 'busy' end
    if not playerConnected(src) then return false, 'invalid_viewer' end
    local owner = Bridge.GetIdentifier(src)
    if not owner then return false, 'missing_identity' end
    if active[owner] then return false, 'busy' end
    active[owner] = true

    local called, ok, reason = pcall(function()
        local record = getRecord(owner, variant)
        local now = os.time()
        if not record or (record.expires_at and record.expires_at <= now) then
            local person, birth, sex = identityFor(src)
            if not person or Bridge.GetIdentifier(src) ~= owner then return false, 'missing_identity' end
            local expiry = Config.ValidDays > 0 and now + Config.ValidDays * 86400 or 0
            MySQL.insert.await(
                [[INSERT INTO pop_idcard_documents
                    (owner, variant, display_name, birth_date, sex, issued_at, expires_at)
                VALUES (?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, NULLIF(?, 0))
                ON DUPLICATE KEY UPDATE display_name = VALUES(display_name), birth_date = VALUES(birth_date),
                    sex = VALUES(sex), issued_at = VALUES(issued_at), expires_at = VALUES(expires_at)]],
                { owner, variant, person, birth, sex, now, expiry }
            )
            record = getRecord(owner, variant)
        end
        if not record or not playerConnected(src) or Bridge.GetIdentifier(src) ~= owner then return false, 'error' end
        local serial = tonumber(record.serial)
        if not serial then return false, 'error' end
        local existing = hasDocument(src, item, serial)
        if not playerConnected(src) or Bridge.GetIdentifier(src) ~= owner then return false, 'error' end
        if existing then return true, 'document_ready' end
        if not Bridge.CanCarry(src, item, 1) then return false, 'inventory_full' end
        if not playerConnected(src) or Bridge.GetIdentifier(src) ~= owner then return false, 'error' end
        if not Bridge.AddItem(src, item, 1, { serial = serial, name = record.display_name, variant = variant }) then
            return false, 'inventory_full'
        end
        return true, 'document_ready'
    end)

    active[owner] = nil
    if not called then
        print(('[%s] Document issuance failed: %s'):format(resource, tostring(ok)))
        return false, 'error'
    end
    return ok, reason
end

local function nearby(src, viewer)
    if not playerConnected(src) or not playerConnected(viewer) then return false end
    if src == viewer then return true end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(viewer) then return false end
    local coords = Bridge.GetCoords(viewer)
    return coords ~= nil and Bridge.IsNear(src, coords, Config.ShowDistance)
end

local function show(src, variant, viewer)
    local item = itemFor(variant)
    if not item then return false, 'invalid_variant' end
    if not ready then return false, 'busy' end
    if not playerConnected(src) or Bridge.IsDead(src) then return false, 'error' end
    local now = GetGameTimer()
    if requests[src] and now - requests[src] < 750 then return false, 'busy' end
    requests[src] = now

    viewer = viewer == nil and src or viewer
    if not playerConnected(viewer) then return false, 'invalid_viewer' end
    if not nearby(src, viewer) then return false, 'too_far' end
    local viewerIdentity = Bridge.GetIdentifier(viewer)
    local owner = Bridge.GetIdentifier(src)
    if not owner or not viewerIdentity then return false, 'missing_identity' end
    if not Bridge.HasItem(src, item, 1) then return false, 'no_document' end
    local record = getRecord(owner, variant)
    local serial = record and tonumber(record.serial)
    if not serial or not hasDocument(src, item, serial) then return false, 'no_document' end
    if Bridge.GetIdentifier(src) ~= owner or Bridge.GetIdentifier(viewer) ~= viewerIdentity
        or Bridge.IsDead(src) or not nearby(src, viewer) then return false, 'too_far' end
    if record.expires_at and record.expires_at <= os.time() then return false, 'document_expired' end
    TriggerClientEvent('pop_idcard:client:show', viewer, {
        name = record.display_name, variant = variant,
        serial = ('%s-%08d'):format(variant:upper(), serial),
        birthDate = record.birth_date, sex = record.sex,
        issuedAt = os.date('!%Y-%m-%d', record.issued_at),
        expiresAt = record.expires_at and os.date('!%Y-%m-%d', record.expires_at),
    })
    return true
end

RegisterCommand(Config.Command .. '_issue', function(src, args)
    if src ~= 0 and not Bridge.IsAdmin(src) and not IsPlayerAceAllowed(src, 'pop.idcard.issue') then
        return Bridge.Notify(src, L('no_permission'), 'error')
    end
    local ok, reason = issue(math.tointeger(tonumber(args[1])), args[2] and args[2]:lower())
    if src == 0 then
        print(('[%s] %s'):format(resource, L(reason)))
    else
        Bridge.Notify(src, L(reason), ok and 'success' or 'error')
    end
end, false)

exports('Issue', issue)
Callback.Register('pop_idcard:show', show)

local function clear(src)
    src = tonumber(src)
    if src then requests[src] = nil end
end
Bridge.OnPlayerDropped(clear)
Bridge.OnPlayerUnloaded(clear)

MySQL.ready(function()
    local sql = assert(LoadResourceFile(resource, 'sql/install.sql'))
    MySQL.query.await(sql)
    ready = true
    for _, variant in ipairs({ 'us', 'mx' }) do
        Bridge.RegisterUsableItem(Config.Items[variant], function(src)
            local invoked, ok, reason = pcall(show, src, variant)
            if not invoked or not ok then Bridge.Notify(src, L(invoked and reason or 'error'), 'error') end
        end)
    end
end)
