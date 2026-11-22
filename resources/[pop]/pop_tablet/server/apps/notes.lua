-- Notes : dossiers, notes riches (texte, liste à cocher, tableau, photo), épinglage, corbeille.
-- Le corps est une liste de blocs validée ici puis stockée en JSON ; la recherche se fait côté interface sur titre et extrait.

Tablet = Tablet or {}
Tablet.Notes = {}
local N = Tablet.Notes
local M = Tablet.Media

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local function str(v, max, multiline)
    if type(v) ~= 'string' or #v > max * 4 then return nil end
    local len = utf8.len(v)
    if not len or len > max then return nil end
    for i = 1, #v do
        local b = v:byte(i)
        if b == 127 or (b < 32 and not (multiline and (b == 10 or b == 9 or b == 13))) then return nil end
    end
    return v
end

--- Contrôle les blocs d'une note. Renvoie les blocs propres, l'extrait et l'indice de contenu, ou nil + clé d'erreur.
--- Aucun champ inconnu n'est conservé.
function N.CleanBlocks(serial, blocks)
    if type(blocks) ~= 'table' or #blocks > M.noteBlocks then return nil, 'err_payload' end
    local out, excerpt, hint = {}, '', ''
    local total = 0 -- octets de texte de toute la note (indépendant de l'encodeur JSON)
    for i = 1, #blocks do
        local b = blocks[i]
        if type(b) ~= 'table' then return nil, 'err_payload' end
        if b.type == 'text' then
            local v = str(b.value, M.textBlock, true)
            if not v then return nil, 'err_payload' end
            out[i] = { type = 'text', value = v }
            total = total + #v
            if excerpt == '' and v:find('%S') then
                excerpt = v:gsub('%s+', ' ')
                excerpt = Tablet.Limits.Trim(excerpt)
                if utf8.len(excerpt) > 120 then excerpt = excerpt:sub(1, utf8.offset(excerpt, 121) - 1) end
            end
            if hint == '' then hint = 'text' end
        elseif b.type == 'todo' then
            if type(b.items) ~= 'table' or #b.items > M.todoItems then return nil, 'err_payload' end
            local items = {}
            for j = 1, #b.items do
                local it = b.items[j]
                if type(it) ~= 'table' or type(it.done) ~= 'boolean' then return nil, 'err_payload' end
                local t = str(it.t, M.todoText)
                if not t then return nil, 'err_payload' end
                items[j] = { t = t, done = it.done }
                total = total + #t
            end
            out[i] = { type = 'todo', items = items }
            if hint == '' then hint = 'todo' end
        elseif b.type == 'table' then
            if type(b.rows) ~= 'table' or #b.rows < 1 or #b.rows > M.tableRows then return nil, 'err_payload' end
            local rows, cols = {}, nil
            for r = 1, #b.rows do
                local row = b.rows[r]
                if type(row) ~= 'table' or #row < 1 or #row > M.tableCols or (cols and #row ~= cols) then return nil, 'err_payload' end
                cols = #row
                rows[r] = {}
                for c = 1, #row do
                    local v = str(row[c], M.cellText)
                    if not v then return nil, 'err_payload' end
                    rows[r][c] = v
                    total = total + #v
                end
            end
            out[i] = { type = 'table', rows = rows }
            if hint == '' then hint = 'table' end
        elseif b.type == 'photo' then
            local pid = id(b.id)
            if not pid or not Tablet.DB.PhotoOwned(serial, pid) then return nil, 'err_not_found' end
            out[i] = { type = 'photo', id = pid }
            if hint == '' then hint = 'photo' end
        else
            return nil, 'err_payload'
        end
    end
    if total > Tablet.Max.note then return nil, 'err_too_large' end
    return out, excerpt, hint
end

local function noteRow(r)
    return { id = r.id, folder = r.folder_id, title = r.title, excerpt = r.excerpt, hint = r.hint, pinned = r.pinned == 1 or r.pinned == true,
        deleted = r.deleted_at ~= nil, updated = r.updated_at }
end

--- pop_tablet:notes:list : notes sans corps, dossiers ; la corbeille de plus de 30 jours est vidée au passage.
function N.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'notesList', rate = 4 })
    if not s then return Tablet.Fail(err) end
    Tablet.DB.PurgeNoteTrash(s.serial, Tablet.Now() - M.trashDays * 86400)
    local notes, folders = {}, {}
    for i, r in ipairs(Tablet.DB.ListNotes(s.serial)) do notes[i] = noteRow(r) end
    for i, f in ipairs(Tablet.DB.ListNoteFolders(s.serial)) do folders[i] = { id = f.id, name = f.name } end
    return { ok = true, notes = notes, folders = folders }
end

--- pop_tablet:notes:get  id
function N.Get(src, nid)
    local s, err = Tablet.Guard(src, nil, { name = 'notesGet', rate = 10, payload = nid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    nid = id(nid)
    if not nid then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetNote(s.serial, nid)
    if not r then return Tablet.Fail('err_not_found') end
    local blocks = type(r.body) == 'string' and json.decode(r.body) or {}
    return { ok = true, note = { id = r.id, folder = r.folder_id, title = r.title, blocks = type(blocks) == 'table' and blocks or {},
        pinned = r.pinned == 1 or r.pinned == true, deleted = r.deleted_at ~= nil, updated = r.updated_at } }
end

--- pop_tablet:notes:save  { id?, title, blocks, pinned?, folder? } : création (<= 200 notes) ou mise à jour
function N.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'notesSave', rate = 5, payload = data, maxBytes = Tablet.Max.payload })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('title', data.title)
    if not ok then return Tablet.Fail(ferr) end
    if data.pinned ~= nil and type(data.pinned) ~= 'boolean' then return Tablet.Fail('err_payload') end
    local folder
    if data.folder ~= nil then
        folder = id(data.folder)
        if not folder or not Tablet.DB.NoteFolderOwned(s.serial, folder) then return Tablet.Fail('err_not_found') end
    end
    local blocks, excerpt, hint = N.CleanBlocks(s.serial, data.blocks)
    if not blocks then return Tablet.Fail(excerpt) end
    local body = json.encode(blocks)
    if #body > Tablet.Max.note then return Tablet.Fail('err_too_large') end
    local n = { folder = folder, title = data.title, excerpt = excerpt, hint = hint, body = body, pinned = data.pinned == true }
    if data.id ~= nil then
        local nid = id(data.id)
        if not nid or not Tablet.DB.UpdateNote(s.serial, nid, n, Tablet.Now()) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = nid, updated = Tablet.Now(), excerpt = excerpt, hint = hint }
    end
    if Tablet.DB.CountNotes(s.serial) >= M.notes then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertNote(s.serial, n, Tablet.Now()), updated = Tablet.Now(), excerpt = excerpt, hint = hint }
end

--- pop_tablet:notes:delete  id : première fois = corbeille, déjà en corbeille = suppression définitive
function N.Delete(src, nid)
    local s, err = Tablet.Guard(src, nil, { name = 'notesSave', rate = 5, payload = nid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    nid = id(nid)
    if not nid then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetNote(s.serial, nid)
    if not r then return Tablet.Fail('err_not_found') end
    if r.deleted_at == nil then
        Tablet.DB.SetNoteDeleted(s.serial, nid, Tablet.Now())
        return { ok = true, permanent = false }
    end
    Tablet.DB.DeleteNote(s.serial, nid)
    return { ok = true, permanent = true }
end

--- pop_tablet:notes:restore  id
function N.Restore(src, nid)
    local s, err = Tablet.Guard(src, nil, { name = 'notesSave', rate = 5, payload = nid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    nid = id(nid)
    if not nid or not Tablet.DB.SetNoteDeleted(s.serial, nid, nil) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:notes:folderSave  { id?, name } : <= 10 dossiers, nom <= 40 caractères
function N.FolderSave(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'noteFolder', rate = 3, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return Tablet.Fail('err_payload') end
    local name = Tablet.Limits.Trim(data.name)
    if not Tablet.Limits.Field('folder', name, { min = 1 }) then return Tablet.Fail('err_payload') end
    if data.id ~= nil then
        local fid = id(data.id)
        if not fid or not Tablet.DB.RenameNoteFolder(s.serial, fid, name) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = fid, name = name }
    end
    if #Tablet.DB.ListNoteFolders(s.serial) >= M.noteFolders then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertNoteFolder(s.serial, name, Tablet.Now()), name = name }
end

--- pop_tablet:notes:folderDelete  id : les notes du dossier retournent au dossier par défaut
function N.FolderDelete(src, fid)
    local s, err = Tablet.Guard(src, nil, { name = 'noteFolder', rate = 3, payload = fid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    fid = id(fid)
    if not fid or not Tablet.DB.DeleteNoteFolder(s.serial, fid) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

Callback.Register('pop_tablet:notes:list', function(src) return N.List(src) end)
Callback.Register('pop_tablet:notes:get', function(src, nid) return N.Get(src, nid) end)
Callback.Register('pop_tablet:notes:save', function(src, data) return N.Save(src, data) end)
Callback.Register('pop_tablet:notes:delete', function(src, nid) return N.Delete(src, nid) end)
Callback.Register('pop_tablet:notes:restore', function(src, nid) return N.Restore(src, nid) end)
Callback.Register('pop_tablet:notes:folderSave', function(src, data) return N.FolderSave(src, data) end)
Callback.Register('pop_tablet:notes:folderDelete', function(src, fid) return N.FolderDelete(src, fid) end)
