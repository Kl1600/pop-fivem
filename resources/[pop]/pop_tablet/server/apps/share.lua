-- Partage de proximité (fichier, photo, note, tableau). Offres en mémoire (30 s), une par expéditeur ; la distance est
-- revérifiée côté serveur à l'envoi et à l'acceptation. Le destinataire reçoit une copie, jamais un accès à l'original.

Tablet = Tablet or {}
Tablet.Share = {}
local S = Tablet.Share
local M = Tablet.Media

local KINDS = { file = true, photo = true, note = true, board = true, contact = true }
local offers = {} -- [offerId] = { from, to, kind, id, name, expires }
local nextOffer = 0

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

--- Distance (m) entre deux joueurs d'après les positions serveur, nil si l'une est inconnue.
local function distance(a, b)
    local pa, pb = Bridge.GetCoords(a), Bridge.GetCoords(b)
    if not pa or not pb then return nil end
    local dx, dy, dz = pa.x - pb.x, pa.y - pb.y, pa.z - pb.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function near(a, b)
    local d = distance(a, b)
    return d ~= nil and d <= Config.Share.Distance
end

local function receives(session) return session.settings == nil or session.settings.share ~= false end

--- Élément à partager, lu chez l'expéditeur : renvoie nom + données de copie, ou nil.
local function source(serial, kind, rid)
    local DB = Tablet.DB
    if kind == 'file' then
        local f = DB.GetFile(serial, rid)
        if not f or f.kind ~= 'doc' then return nil end
        return f.name, { body = f.body or '' }
    elseif kind == 'photo' then
        local p = DB.GetPhoto(serial, rid)
        if not p or not p.data then return nil end
        return 'Photo', { data = p.data, kind = p.kind or 'photo' }
    elseif kind == 'note' then
        local n = DB.GetNote(serial, rid)
        if not n then return nil end
        return n.title, { body = n.body }
    elseif kind == 'board' then
        local b = DB.GetBoard(serial, rid)
        if not b then return nil end
        return b.title, { strokes = b.strokes or '' }
    elseif kind == 'contact' then
        local c = DB.GetContact(serial, rid)
        if not c then return nil end
        return c.name, { phone = c.phone or '', mail = c.mail }
    end
end

--- pop_tablet:share:nearby : tablettes à proximité (nom d'appareil, jamais le nom du personnage), 8 au plus
function S.Nearby(src)
    local s, err = Tablet.Guard(src, nil, { name = 'shareNearby', rate = 2 })
    if not s then return Tablet.Fail(err) end
    local out = {}
    for _, other in ipairs(Tablet.Device.Sources()) do
        local o = other ~= src and Tablet.Device.GetSession(other)
        if o and receives(o) and near(src, other) then
            local row = Tablet.DB.GetDevice(o.serial)
            out[#out + 1] = { id = other, name = row and row.name or '' }
            if #out >= 8 then break end
        end
    end
    return { ok = true, items = out }
end

--- pop_tablet:share:send  { target, kind, id }
function S.Send(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'shareSend', rate = 1, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not KINDS[data.kind] then return Tablet.Fail('err_payload') end
    local target, rid = Tablet.Limits.Int(data.target, 1, 65535), id(data.id)
    if not target or not rid or target == src then return Tablet.Fail('err_payload') end
    local t = Tablet.Device.GetSession(target)
    if not t or not receives(t) then return Tablet.Fail('err_not_found') end
    if not near(src, target) then return Tablet.Fail('err_far') end
    local name = source(s.serial, data.kind, rid)
    if not name then return Tablet.Fail('err_not_found') end
    for k, o in pairs(offers) do if o.from == src or o.expires <= Tablet.Now() then offers[k] = nil end end
    nextOffer = nextOffer + 1
    offers[nextOffer] = { from = src, to = target, kind = data.kind, id = rid, name = name, expires = Tablet.Now() + M.shareSeconds }
    Tablet.Push.To(target, 'share', { offerId = nextOffer, kind = data.kind, name = name:sub(1, 40) })
    return { ok = true, offerId = nextOffer }
end

local function take(src, offerId)
    offerId = id(offerId)
    local o = offerId and offers[offerId]
    if not o or o.to ~= src then return nil, 'err_not_found' end
    offers[offerId] = nil
    if o.expires <= Tablet.Now() then return nil, 'err_offer' end
    return o
end

--- pop_tablet:share:accept  offerId : copie chez le destinataire
function S.Accept(src, offerId)
    local s, err = Tablet.Guard(src, nil, { name = 'shareAccept', rate = 2, payload = offerId, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    local o, oerr = take(src, offerId)
    if not o then return Tablet.Fail(oerr) end
    local from = Tablet.Device.GetSession(o.from)
    if not from or not Tablet.Device.Carries(o.from, from.serial) then return Tablet.Fail('err_offer') end
    if not near(src, o.from) then return Tablet.Fail('err_far') end
    local name, copy = source(from.serial, o.kind, o.id)
    if not name then return Tablet.Fail('err_not_found') end
    local DB, now = Tablet.DB, Tablet.Now()
    if o.kind == 'file' then
        if #DB.ListFiles(s.serial) >= M.files then return Tablet.Fail('err_limit') end
        DB.InsertFile(s.serial, { kind = 'doc', name = name, body = copy.body, size = #copy.body }, now)
    elseif o.kind == 'photo' then
        if DB.CountPhotos(s.serial) >= Config.Photos.Max then return Tablet.Fail('err_photos_full') end
        DB.InsertPhoto(s.serial, copy.data, now, copy.kind)
    elseif o.kind == 'note' then
        if DB.CountNotes(s.serial) >= M.notes then return Tablet.Fail('err_limit') end
        DB.InsertNote(s.serial, { title = name, excerpt = '', hint = '', body = copy.body, pinned = false }, now)
    elseif o.kind == 'contact' then
        if DB.CountContacts(s.serial) >= Tablet.Comm.contacts then return Tablet.Fail('err_limit') end
        DB.InsertContact(s.serial, { name = name, phone = copy.phone, mail = copy.mail, note = nil, favorite = false })
    else
        if DB.CountBoards(s.serial) >= M.boards then return Tablet.Fail('err_limit') end
        DB.InsertBoard(s.serial, name, copy.strokes, now)
    end
    return { ok = true, kind = o.kind }
end

--- pop_tablet:share:refuse  offerId
function S.Refuse(src, offerId)
    local s, err = Tablet.Guard(src, nil, { name = 'shareAccept', rate = 2, payload = offerId, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    take(src, offerId)
    return { ok = true }
end

function S.Forget(src)
    for k, o in pairs(offers) do if o.from == src or o.to == src then offers[k] = nil end end
end

Callback.Register('pop_tablet:share:nearby', function(src) return S.Nearby(src) end)
Callback.Register('pop_tablet:share:send', function(src, data) return S.Send(src, data) end)
Callback.Register('pop_tablet:share:accept', function(src, offerId) return S.Accept(src, offerId) end)
Callback.Register('pop_tablet:share:refuse', function(src, offerId) return S.Refuse(src, offerId) end)
