-- Fichiers : arborescence (dossiers, documents texte, raccourcis vers photos, enregistrements et tableaux), tags, favoris,
-- partage par jeton. Toutes les entrées d'une tablette (500 au plus, sans corps) tiennent en une requête : profondeur,
-- cycles et plafonds se calculent ici, jamais d'après le client.

Tablet = Tablet or {}
Tablet.Files = {}
local F = Tablet.Files
local M = Tablet.Media

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local function flag(v) return v == 1 or v == true end

local function entry(r)
    return { id = r.id, parent = r.parent_id, kind = r.kind, name = r.name, ref = r.ref_id, size = r.size or 0,
        shared = r.share_token ~= nil, token = r.share_token, tag = r.tag, fav = flag(r.fav), updated = r.updated_at }
end

--- Index des entrées : par id, et enfants par parent (0 = racine).
local function index(rows)
    local byId, kids = {}, {}
    for _, r in ipairs(rows) do
        byId[r.id] = r
        local p = r.parent_id or 0
        kids[p] = kids[p] or {}
        kids[p][#kids[p] + 1] = r
    end
    return byId, kids
end

--- Profondeur d'une entrée (un dossier de la racine = 1). 0 = racine. Nil si la chaîne boucle.
local function depthOf(byId, nodeId)
    local d, cur, guard = 0, nodeId, 0
    while cur do
        local r = byId[cur]
        if not r then return nil end
        d, cur, guard = d + 1, r.parent_id, guard + 1
        if guard > 50 then return nil end
    end
    return d
end

--- Hauteur du sous-arbre d'une entrée (elle-même = 1).
local function height(kids, nodeId, level)
    level = level or 1
    if level > 20 then return level end
    local h = 1
    for _, c in ipairs(kids[nodeId] or {}) do
        local ch = 1 + height(kids, c.id, level + 1)
        if ch > h then h = ch end
    end
    return h
end

--- Le raccourci pointe vers un élément de la même tablette.
local function refOwned(serial, kind, ref)
    if kind == 'photo' then return Tablet.DB.PhotoOwned(serial, ref) end
    if kind == 'board' then return Tablet.DB.BoardOwned(serial, ref) end
    if kind == 'audio' then return Tablet.DB.RecordingOwned(serial, ref) end
    return false
end

local function cleanTag(v)
    if v == nil or v == '' then return nil, true end
    if type(v) == 'string' and M.fileTags[v] then return v, true end
    return nil, false
end

--- pop_tablet:files:list  { parentId? } : sans parentId, toutes les entrées (l'interface bâtit l'arbre, trie et cherche)
function F.List(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'filesList', rate = 4, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    local rows = Tablet.DB.ListFiles(s.serial)
    local items = {}
    local filter = nil
    if type(data) == 'table' and data.parentId ~= nil then
        filter = id(data.parentId)
        if not filter then return Tablet.Fail('err_payload') end
    end
    for _, r in ipairs(rows) do
        if filter == nil or r.parent_id == filter then items[#items + 1] = entry(r) end
    end
    return { ok = true, items = items, limit = M.files }
end

--- pop_tablet:files:get  id : une entrée avec le corps d'un document
function F.Get(src, fid)
    local s, err = Tablet.Guard(src, nil, { name = 'filesGet', rate = 10, payload = fid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    fid = id(fid)
    if not fid then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetFile(s.serial, fid)
    if not r then return Tablet.Fail('err_not_found') end
    local e = entry(r)
    e.body = r.body
    return { ok = true, file = e }
end

--- pop_tablet:files:save  { id?, parentId?, kind, name, body?, refId?, tag?, fav? }
function F.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'filesSave', rate = 4, payload = data, maxBytes = Tablet.Max.payload })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('title', data.name, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local tag, tagOk = cleanTag(data.tag)
    if not tagOk then return Tablet.Fail('err_payload') end
    if data.fav ~= nil and type(data.fav) ~= 'boolean' then return Tablet.Fail('err_payload') end

    local rows = Tablet.DB.ListFiles(s.serial)
    local byId = index(rows)
    local name = Tablet.Limits.Trim(data.name)
    if data.id ~= nil then
        local fid = id(data.id)
        local cur = fid and byId[fid]
        if not cur then return Tablet.Fail('err_not_found') end
        local body = nil
        if cur.kind == 'doc' then
            local full = Tablet.DB.GetFile(s.serial, fid)
            body = full and full.body or ''
            if data.body ~= nil then
                local bok, berr = Tablet.Limits.Field('doc', data.body, { multiline = true })
                if not bok then return Tablet.Fail(berr) end
                body = data.body
            end
        end
        local fav = cur.fav == 1 or cur.fav == true
        if data.fav ~= nil then fav = data.fav end
        if data.tag == nil then tag = cur.tag end
        Tablet.DB.UpdateFile(s.serial, fid, { name = name, body = body, size = body and #body or cur.size, tag = tag, fav = fav }, Tablet.Now())
        return { ok = true, id = fid }
    end

    local kind = data.kind
    if type(kind) ~= 'string' or not M.fileKinds[kind] then return Tablet.Fail('err_payload') end
    if #rows >= M.files then return Tablet.Fail('err_limit') end
    local parent
    if data.parentId ~= nil then
        parent = id(data.parentId)
        local p = parent and byId[parent]
        if not p or p.kind ~= 'folder' then return Tablet.Fail('err_not_found') end
        local d = depthOf(byId, parent)
        if not d or d + (kind == 'folder' and 1 or 0) > M.depth then return Tablet.Fail('err_depth') end
    end
    local f = { parent = parent, kind = kind, name = name, tag = tag, fav = data.fav == true, size = 0 }
    if kind == 'doc' then
        local body = data.body == nil and '' or data.body
        local bok, berr = Tablet.Limits.Field('doc', body, { multiline = true })
        if not bok then return Tablet.Fail(berr) end
        f.body, f.size = body, #body
    elseif kind ~= 'folder' then
        local ref = id(data.refId)
        if not ref or not refOwned(s.serial, kind, ref) then return Tablet.Fail('err_not_found') end
        f.ref = ref
    end
    return { ok = true, id = Tablet.DB.InsertFile(s.serial, f, Tablet.Now()) }
end

--- pop_tablet:files:delete  id : un dossier emporte son contenu (clé étrangère en cascade)
function F.Delete(src, fid)
    local s, err = Tablet.Guard(src, nil, { name = 'filesSave', rate = 4, payload = fid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    fid = id(fid)
    if not fid or not Tablet.DB.DeleteFile(s.serial, fid) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:files:move  { id, parentId? } : jamais dans soi-même ni dans un descendant, profondeur <= 6
function F.Move(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'filesSave', rate = 4, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local fid = id(data.id)
    local byId, kids = index(Tablet.DB.ListFiles(s.serial))
    if not fid or not byId[fid] then return Tablet.Fail('err_not_found') end
    local parent
    local base = 0
    if data.parentId ~= nil then
        parent = id(data.parentId)
        local p = parent and byId[parent]
        if not p or p.kind ~= 'folder' then return Tablet.Fail('err_not_found') end
        local cur, guard = parent, 0
        while cur do
            if cur == fid then return Tablet.Fail('err_depth') end
            cur = byId[cur] and byId[cur].parent_id
            guard = guard + 1
            if guard > 50 then return Tablet.Fail('err_depth') end -- chaîne anormale (boucle en base) : jamais de boucle infinie
        end
        base = depthOf(byId, parent) or 99
    end
    -- Seuls les dossiers comptent dans la profondeur : un document peut vivre dans un dossier de niveau 6.
    local h = byId[fid].kind == 'folder' and height(kids, fid) or 0
    if base + h > M.depth then return Tablet.Fail('err_depth') end
    Tablet.DB.MoveFile(s.serial, fid, parent, Tablet.Now())
    return { ok = true }
end

local function newToken()
    local chars, t = Tablet.SerialChars, {}
    for i = 1, 12 do
        local k = math.random(1, #chars)
        t[i] = chars:sub(k, k)
    end
    return table.concat(t)
end

--- pop_tablet:files:share  id : crée le jeton de partage (12 caractères) et le renvoie
function F.Share(src, fid)
    local s, err = Tablet.Guard(src, nil, { name = 'filesShare', rate = 2, payload = fid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    fid = id(fid)
    local r = fid and Tablet.DB.GetFile(s.serial, fid)
    if not r or r.kind == 'folder' then return Tablet.Fail('err_not_found') end
    if r.share_token then return { ok = true, token = r.share_token } end
    for _ = 1, 5 do
        local token = newToken()
        if Tablet.DB.SetShareToken(s.serial, fid, token) then return { ok = true, token = token } end
    end
    return Tablet.Fail('err_db')
end

--- pop_tablet:files:unshare  id
function F.Unshare(src, fid)
    local s, err = Tablet.Guard(src, nil, { name = 'filesShare', rate = 2, payload = fid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    fid = id(fid)
    if not fid or not Tablet.DB.GetFile(s.serial, fid) then return Tablet.Fail('err_not_found') end
    Tablet.DB.SetShareToken(s.serial, fid, nil)
    return { ok = true }
end

--- pop_tablet:files:open  token : lecture seule d'un élément partagé (document, photo) ; 2 essais par seconde
function F.Open(src, token)
    local s, err = Tablet.Guard(src, nil, { name = 'filesOpen', rate = 2, payload = token, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(token) ~= 'string' or not token:match('^[A-Z2-9]+$') or #token ~= 12 then return Tablet.Fail('err_token') end
    local r = Tablet.DB.FileByToken(token)
    if not r then return Tablet.Fail('err_token') end
    local out = { kind = r.kind, name = r.name, size = r.size, updated = r.updated_at }
    if r.kind == 'doc' then out.body = r.body end
    if r.kind == 'photo' and r.ref_id then out.photo = Tablet.DB.PhotoData(r.ref_id) end
    return { ok = true, file = out }
end

Callback.Register('pop_tablet:files:list', function(src, data) return F.List(src, data) end)
Callback.Register('pop_tablet:files:get', function(src, fid) return F.Get(src, fid) end)
Callback.Register('pop_tablet:files:save', function(src, data) return F.Save(src, data) end)
Callback.Register('pop_tablet:files:delete', function(src, fid) return F.Delete(src, fid) end)
Callback.Register('pop_tablet:files:move', function(src, data) return F.Move(src, data) end)
Callback.Register('pop_tablet:files:share', function(src, fid) return F.Share(src, fid) end)
Callback.Register('pop_tablet:files:unshare', function(src, fid) return F.Unshare(src, fid) end)
Callback.Register('pop_tablet:files:open', function(src, token) return F.Open(src, token) end)
