-- Messages : conversations à deux et de groupe entre tablettes (texte, photo, position), accusés, non-lus, épinglées.
-- Les messages sont liés aux numéros. Un groupe est adressé 'g<id>'. Le serveur donne la position (jamais le client) et vérifie
-- que la photo appartient à l'expéditeur. Aucun envoi sans événement : pas de boucle, pas de polling.

Tablet = Tablet or {}
Tablet.Messages = {}
local M = Tablet.Messages
local P = Tablet.Peer
local C = Tablet.Comm

local BIG = 4294967295
local KINDS = { text = true, photo = true, location = true }

local function phoneOk(p) return type(p) == 'string' and Tablet.Device.PhoneValid(p, Config.Phone.Format) end
local function groupId(to)
    local n = type(to) == 'string' and to:match('^g(%d+)$')
    return n and Tablet.Limits.Int(tonumber(n), 1, BIG) or nil
end

local function member(gid, phone)
    for _, m in ipairs(Tablet.DB.GroupMembers(gid)) do if m.phone == phone then return true end end
    return false
end

local function preview(kind, body)
    if kind == 'photo' then return L('msg_photo') end
    if kind == 'location' then return L('msg_location') end
    return (body or ''):sub(1, C.preview)
end

local function pins(serial)
    local d = Tablet.AppData.Get(serial, 'messages', {})
    local out = {}
    for _, p in ipairs(type(d.pins) == 'table' and d.pins or {}) do if type(p) == 'string' and #out < C.pins then out[#out + 1] = p end end
    return out
end

--- pop_tablet:messages:threads : conversations (dernier message, non-lus, épinglées), la plus récente d'abord
function M.Threads(src)
    local s, err = Tablet.Guard(src, nil, { name = 'msgThreads', rate = 3, online = true })
    if not s then return Tablet.Fail(err) end
    local me = P.PhoneOf(s)
    local unread = {}
    for _, r in ipairs(Tablet.DB.UnreadDirect(me)) do unread[r.from_phone] = tonumber(r.n) or 0 end
    local items = {}
    for _, m in ipairs(Tablet.DB.LastDirect(me)) do
        local mine = m.from_phone == me
        local peer = mine and m.to_phone or m.from_phone
        items[#items + 1] = { _id = tonumber(m.id) or 0, id = peer, group = false, unread = unread[peer] or 0,
            last = { kind = m.kind, body = preview(m.kind, m.body), me = mine, at = m.sent_at, read = m.read_at ~= nil } }
    end
    for _, g in ipairs(Tablet.DB.GroupsOf(me)) do
        local l = Tablet.DB.GroupLast(g.id)
        items[#items + 1] = { _id = l and tonumber(l.id) or 0, id = 'g' .. g.id, group = true, name = g.name, unread = tonumber(g.unread) or 0,
            last = l and { kind = l.kind, body = preview(l.kind, l.body), me = l.from_phone == me, at = l.sent_at, from = l.from_phone, read = false } or nil }
    end
    table.sort(items, function(a, b) return a._id > b._id end)
    for _, it in ipairs(items) do it._id = nil end
    return { ok = true, items = items, pins = pins(s.serial), me = me }
end

--- pop_tablet:messages:thread  { phone, before? } : 30 messages, du plus ancien au plus récent
function M.Thread(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'msgThread', rate = 4, payload = data, maxBytes = 256, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local me = P.PhoneOf(s)
    local before = data.before ~= nil and Tablet.Limits.Int(data.before, 1, BIG) or BIG
    if not before then return Tablet.Fail('err_payload') end
    local rows, gid = nil, groupId(data.phone)
    if gid then
        if not member(gid, me) then return Tablet.Fail('err_not_found') end
        rows = Tablet.DB.GroupThread(gid, before)
    elseif phoneOk(data.phone) then
        rows = Tablet.DB.DirectThread(me, data.phone, before)
    else
        return Tablet.Fail('err_payload')
    end
    local items = {}
    for i = #rows, 1, -1 do
        local m = rows[i]
        items[#items + 1] = { id = tonumber(m.id), me = m.from_phone == me, from = m.from_phone, kind = m.kind, body = m.body, ref = m.ref,
            at = m.sent_at, read = m.read_at ~= nil, vm = m.ref == 'vm' or nil }
    end
    return { ok = true, items = items, more = #rows >= 30 }
end

--- pop_tablet:messages:send  { to, body, kind?, ref? } : texte, photo (id de Photos) ou position (donnée par le serveur)
function M.Send(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'msgSend', rate = 1, payload = data, maxBytes = 2048, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local kind = data.kind == nil and 'text' or data.kind
    if not Tablet.Limits.Enum(kind, KINDS) then return Tablet.Fail('err_payload') end
    local me = P.PhoneOf(s)
    local gid = groupId(data.to)
    local targets = {}
    if gid then
        if not member(gid, me) then return Tablet.Fail('err_not_found') end
        for _, m in ipairs(Tablet.DB.GroupMembers(gid)) do if m.phone ~= me then targets[#targets + 1] = m.phone end end
    else
        if not phoneOk(data.to) or data.to == me then return Tablet.Fail('err_payload') end
        if not Tablet.DB.PhoneExists(data.to) then return Tablet.Fail('err_not_found') end
        targets[1] = data.to
    end
    local body, ref = '', nil
    if kind == 'text' then
        local ok, ferr = Tablet.Limits.Field('message', data.body, { min = 1, multiline = true })
        if not ok then return Tablet.Fail(ferr) end
        body = data.body
    elseif kind == 'photo' then
        local pid = Tablet.Limits.Int(data.ref, 1, BIG)
        if not pid or not Tablet.DB.PhotoOwned(s.serial, pid) then return Tablet.Fail('err_not_found') end
        ref = tostring(pid)
    else
        local pos = Bridge.GetCoords(src)
        if not pos then return Tablet.Fail('err_not_found') end
        ref = ('%.1f,%.1f'):format(pos.x, pos.y)
    end
    local to = gid and ('g' .. gid) or data.to
    local now = Tablet.Now()
    local id = Tablet.DB.InsertMessage(me, to, body, kind, ref, now)
    if not id then return Tablet.Fail('err_db') end
    local pv = preview(kind, body)
    for _, phone in ipairs(targets) do
        P.Alert(phone, 'messages', { name = 'message', data = { id = id, from = me, to = to, kind = kind, body = pv, at = now } }, L('msg_notif', me, pv))
    end
    return { ok = true, msg = { id = id, me = true, from = me, kind = kind, body = body, ref = ref, at = now, read = false } }
end

--- pop_tablet:messages:read  { phone } : marque lu ; prévient l'expéditeur (accusé « Lu ») si sa tablette est ouverte
function M.Read(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'msgRead', rate = 4, payload = data, maxBytes = 256, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local me = P.PhoneOf(s)
    local gid = groupId(data.phone)
    if gid then
        if not member(gid, me) then return Tablet.Fail('err_not_found') end
        Tablet.DB.GroupMarkRead(gid, me)
        return { ok = true }
    end
    if not phoneOk(data.phone) then return Tablet.Fail('err_payload') end
    local n = Tablet.DB.MarkRead(me, data.phone, Tablet.Now())
    if n > 0 then P.Quiet(data.phone, 'message', { read = me }) end
    return { ok = true }
end

--- pop_tablet:messages:pin  { phone, on } : conversations épinglées (12 au plus), propres à la tablette
function M.Pin(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'msgPin', rate = 3, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' or not (phoneOk(data.phone) or groupId(data.phone)) then return Tablet.Fail('err_payload') end
    local out = {}
    for _, p in ipairs(pins(s.serial)) do if p ~= data.phone then out[#out + 1] = p end end
    if data.on then
        if #out >= C.pins then return Tablet.Fail('err_limit') end
        out[#out + 1] = data.phone
    end
    Tablet.AppData.Set(s.serial, 'messages', { pins = out })
    return { ok = true, pins = out }
end

--- pop_tablet:messages:group  { name, members } : crée une conversation de groupe (3 à 8 numéros avec le créateur)
function M.Group(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'msgGroup', rate = 1, payload = data, maxBytes = 512, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.members) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('folder', data.name, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local me = P.PhoneOf(s)
    local list, seen = { me }, { [me] = true }
    for _, p in ipairs(data.members) do
        if not phoneOk(p) or not Tablet.DB.PhoneExists(p) then return Tablet.Fail('err_not_found') end
        if not seen[p] then seen[p] = true list[#list + 1] = p end
    end
    if #list < 3 or #list > C.group then return Tablet.Fail('err_payload') end
    local gid = Tablet.DB.CreateGroup(data.name, Tablet.Now())
    if not gid then return Tablet.Fail('err_db') end
    for _, p in ipairs(list) do Tablet.DB.AddMember(gid, p) end
    for _, p in ipairs(list) do
        if p ~= me then
            P.Alert(p, 'messages', { name = 'message', data = { id = 0, from = me, to = 'g' .. gid, kind = 'group', body = data.name, at = Tablet.Now() } }, L('msg_group', data.name))
        end
    end
    return { ok = true, id = 'g' .. gid }
end

--- pop_tablet:messages:media  id : photo d'un message reçu ou envoyé (lue chez l'expéditeur, jamais copiée)
function M.Media(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'msgMedia', rate = 4, payload = id, maxBytes = 64, online = true })
    if not s then return Tablet.Fail(err) end
    local mid = Tablet.Limits.Int(id, 1, BIG)
    local m = mid and Tablet.DB.GetMessage(mid)
    if not m or m.kind ~= 'photo' then return Tablet.Fail('err_not_found') end
    local me = P.PhoneOf(s)
    local gid = groupId(m.to_phone)
    local allowed = m.from_phone == me or m.to_phone == me or (gid ~= nil and member(gid, me))
    if not allowed then return Tablet.Fail('err_not_found') end
    local owner = Tablet.DB.SerialOfPhone(m.from_phone)
    local photo = owner and Tablet.DB.GetPhoto(owner, tonumber(m.ref) or 0)
    if not photo or not photo.data then return Tablet.Fail('err_not_found') end
    return { ok = true, data = photo.data, kind = photo.kind or 'photo' }
end

Tablet.BootHooks[#Tablet.BootHooks + 1] = function(_, boot)
    if not boot.phone then return end
    local n = 0
    for _, r in ipairs(Tablet.DB.UnreadDirect(boot.phone)) do n = n + (tonumber(r.n) or 0) end
    for _, g in ipairs(Tablet.DB.GroupsOf(boot.phone)) do n = n + (tonumber(g.unread) or 0) end
    boot.badges = boot.badges or {}
    if n > 0 then boot.badges.messages = n end
end

Callback.Register('pop_tablet:messages:threads', function(src) return M.Threads(src) end)
Callback.Register('pop_tablet:messages:thread', function(src, data) return M.Thread(src, data) end)
Callback.Register('pop_tablet:messages:send', function(src, data) return M.Send(src, data) end)
Callback.Register('pop_tablet:messages:read', function(src, data) return M.Read(src, data) end)
Callback.Register('pop_tablet:messages:pin', function(src, data) return M.Pin(src, data) end)
Callback.Register('pop_tablet:messages:group', function(src, data) return M.Group(src, data) end)
Callback.Register('pop_tablet:messages:media', function(src, id) return M.Media(src, id) end)
