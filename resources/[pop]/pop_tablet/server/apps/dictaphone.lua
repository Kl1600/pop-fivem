-- Dictaphone : enregistrements audio (si le micro de la NUI est accordé) et mémos dictés (texte). `data` contient soit une
-- data URI audio, soit 'memo:<texte>'. Envoi par morceaux de 32 Ko assemblés ici (un seul envoi en cours par joueur).
-- <= 30 enregistrements, <= 120 s, <= 400 Ko.

Tablet = Tablet or {}
Tablet.Recorder = {}
local R = Tablet.Recorder
local M = Tablet.Media

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local pending = {} -- [src] = { serial, total, nextIndex, parts, bytes }

local function isMemo(data) return type(data) == 'string' and data:sub(1, 5) == 'memo:' end

--- pop_tablet:rec:list
function R.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'recList', rate = 4 })
    if not s then return Tablet.Fail(err) end
    local items = {}
    for i, r in ipairs(Tablet.DB.ListRecs(s.serial)) do
        items[i] = { id = r.id, title = r.title, seconds = r.seconds, created = r.created_at, memo = r.memo == 1 or r.memo == true }
    end
    return { ok = true, items = items, limit = M.recs }
end

--- pop_tablet:rec:get  id : contenu (data URI audio ou texte du mémo)
function R.Get(src, rid)
    local s, err = Tablet.Guard(src, nil, { name = 'recGet', rate = 4, payload = rid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    rid = id(rid)
    local r = rid and Tablet.DB.GetRec(s.serial, rid)
    if not r then return Tablet.Fail('err_not_found') end
    local memo = isMemo(r.data)
    return { ok = true, rec = { id = r.id, title = r.title, seconds = r.seconds, created = r.created_at, memo = memo,
        text = memo and r.data:sub(6) or nil, audio = (not memo) and r.data or nil } }
end

--- pop_tablet:rec:save  { title, seconds, memo } (mémo texte) ou { title, seconds, index, total, chunk } (audio par morceaux)
function R.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'recSave', rate = 6, payload = data, maxBytes = M.recChunk + 2048 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('title', data.title, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local seconds = Tablet.Limits.Int(data.seconds, 0, M.recSeconds)
    if not seconds then return Tablet.Fail('err_too_large') end
    local title = Tablet.Limits.Trim(data.title)
    if Tablet.DB.CountRecs(s.serial) >= M.recs then return Tablet.Fail('err_limit') end

    if data.memo ~= nil then
        local mok, merr = Tablet.Limits.Field('doc', data.memo, { min = 1, multiline = true })
        if not mok then return Tablet.Fail(merr) end
        return { ok = true, id = Tablet.DB.InsertRec(s.serial, title, seconds, 'memo:' .. data.memo, Tablet.Now()) }
    end

    local index, total = Tablet.Limits.Int(data.index, 1, 20), Tablet.Limits.Int(data.total, 1, 20)
    if not index or not total or index > total or type(data.chunk) ~= 'string' or #data.chunk == 0 or #data.chunk > M.recChunk then
        return Tablet.Fail('err_payload')
    end
    local p = pending[src]
    if index == 1 then
        p = { serial = s.serial, total = total, nextIndex = 1, parts = {}, bytes = 0 }
        pending[src] = p
    end
    if not p or p.serial ~= s.serial or p.total ~= total or p.nextIndex ~= index then pending[src] = nil return Tablet.Fail('err_payload') end
    p.bytes = p.bytes + #data.chunk
    if p.bytes > M.recBytes then pending[src] = nil return Tablet.Fail('err_too_large') end
    p.parts[index], p.nextIndex = data.chunk, index + 1
    if index < total then return { ok = true, partial = true } end
    pending[src] = nil
    local audio = table.concat(p.parts)
    if audio:sub(1, 11) ~= 'data:audio/' then return Tablet.Fail('err_payload') end
    return { ok = true, id = Tablet.DB.InsertRec(s.serial, title, seconds, audio, Tablet.Now()) }
end

--- pop_tablet:rec:rename  { id, title }
function R.Rename(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'recSave', rate = 6, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('title', data.title, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local rid = id(data.id)
    if not rid or not Tablet.DB.RenameRec(s.serial, rid, Tablet.Limits.Trim(data.title)) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:rec:delete  id
function R.Delete(src, rid)
    local s, err = Tablet.Guard(src, nil, { name = 'recSave', rate = 6, payload = rid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    rid = id(rid)
    if not rid or not Tablet.DB.DeleteRec(s.serial, rid) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

function R.Forget(src) pending[src] = nil end

Callback.Register('pop_tablet:rec:list', function(src) return R.List(src) end)
Callback.Register('pop_tablet:rec:get', function(src, rid) return R.Get(src, rid) end)
Callback.Register('pop_tablet:rec:save', function(src, data) return R.Save(src, data) end)
Callback.Register('pop_tablet:rec:rename', function(src, data) return R.Rename(src, data) end)
Callback.Register('pop_tablet:rec:delete', function(src, rid) return R.Delete(src, rid) end)
