-- Tableau : dessins et post-it enregistrés. Le contenu est un texte JSON `{ items, strokes }` (points entiers) validé ici,
-- jamais cru : <= 128 Ko, <= 10 000 points, <= 30 tableaux par tablette.

Tablet = Tablet or {}
Tablet.Board = {}
local B = Tablet.Board
local M = Tablet.Media

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local ITEM_TYPES = { note = true, shape = true, text = true, image = true, arrow = true }
local SHAPES = { rect = true, circle = true }
local W, H = 1348, 1019

local function num(v, lo, hi) return math.type(v) ~= nil and v >= lo and v <= hi end

--- Valide le texte JSON d'un tableau. Renvoie true, ou false + clé d'erreur.
function B.Validate(text)
    if type(text) ~= 'string' or #text > Tablet.Max.board then return false, 'err_too_large' end
    local ok, doc = pcall(json.decode, text)
    if not ok or type(doc) ~= 'table' or type(doc.items) ~= 'table' or type(doc.strokes) ~= 'table' then return false, 'err_payload' end
    if #doc.items > M.boardItems then return false, 'err_limit' end
    for _, it in ipairs(doc.items) do
        if type(it) ~= 'table' or not ITEM_TYPES[it.type] or not num(it.col, 0, 5) then return false, 'err_payload' end
        if it.text ~= nil and (type(it.text) ~= 'string' or #it.text > 500) then return false, 'err_payload' end
        if it.type == 'arrow' then
            if not (num(it.x1, -W, 2 * W) and num(it.y1, -H, 2 * H) and num(it.x2, -W, 2 * W) and num(it.y2, -H, 2 * H)) then return false, 'err_payload' end
        else
            if not (num(it.x, -W, 2 * W) and num(it.y, -H, 2 * H) and num(it.w, 10, W) and num(it.h, 10, H)) then return false, 'err_payload' end
            if it.shape ~= nil and not SHAPES[it.shape] then return false, 'err_payload' end
        end
    end
    local points = 0
    for _, st in ipairs(doc.strokes) do
        if type(st) ~= 'table' or not num(st.col, 0, 5) or type(st.pts) ~= 'table' then return false, 'err_payload' end
        for _, p in ipairs(st.pts) do
            if type(p) ~= 'table' or not num(p[1], 0, W) or not num(p[2], 0, H) then return false, 'err_payload' end
            points = points + 1
            if points > M.boardPoints then return false, 'err_too_large' end
        end
    end
    return true
end

--- pop_tablet:board:list : tableaux (sans contenu)
function B.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'boardList', rate = 4 })
    if not s then return Tablet.Fail(err) end
    local items = {}
    for i, r in ipairs(Tablet.DB.ListBoards(s.serial)) do items[i] = { id = r.id, title = r.title, updated = r.updated_at } end
    return { ok = true, items = items, limit = M.boards }
end

--- pop_tablet:board:get  id
function B.Get(src, bid)
    local s, err = Tablet.Guard(src, nil, { name = 'boardGet', rate = 6, payload = bid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    bid = id(bid)
    local r = bid and Tablet.DB.GetBoard(s.serial, bid)
    if not r then return Tablet.Fail('err_not_found') end
    return { ok = true, board = { id = r.id, title = r.title, strokes = r.strokes or '', updated = r.updated_at } }
end

--- pop_tablet:board:save  { id?, title, strokes }
function B.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'boardSave', rate = 3, payload = data, maxBytes = Tablet.Max.board + 2048 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('title', data.title, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local vok, verr = B.Validate(data.strokes)
    if not vok then return Tablet.Fail(verr) end
    local title = Tablet.Limits.Trim(data.title)
    if data.id ~= nil then
        local bid = id(data.id)
        if not bid or not Tablet.DB.UpdateBoard(s.serial, bid, title, data.strokes, Tablet.Now()) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = bid }
    end
    if Tablet.DB.CountBoards(s.serial) >= M.boards then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertBoard(s.serial, title, data.strokes, Tablet.Now()) }
end

--- pop_tablet:board:delete  id : emporte aussi les raccourcis de Fichiers
function B.Delete(src, bid)
    local s, err = Tablet.Guard(src, nil, { name = 'boardSave', rate = 3, payload = bid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    bid = id(bid)
    if not bid or not Tablet.DB.DeleteBoard(s.serial, bid) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

Callback.Register('pop_tablet:board:list', function(src) return B.List(src) end)
Callback.Register('pop_tablet:board:get', function(src, bid) return B.Get(src, bid) end)
Callback.Register('pop_tablet:board:save', function(src, data) return B.Save(src, data) end)
Callback.Register('pop_tablet:board:delete', function(src, bid) return B.Delete(src, bid) end)
