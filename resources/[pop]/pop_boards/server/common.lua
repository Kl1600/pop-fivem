-- Fonctions communes du serveur pop_boards (chargé en premier, voir fxmanifest).

Boards = {}

Boards.FIT_TYPES = { fill = true, cover = true, contain = true }

function Boards.IsNum(v, min, max)
    return type(v) == 'number' and v == v and v >= min and v <= max
end

function Boards.IsVec(t)
    return type(t) == 'table' and Boards.IsNum(t.x, -100000, 100000)
        and Boards.IsNum(t.y, -100000, 100000) and Boards.IsNum(t.z, -100000, 100000)
end

function Boards.CleanVec(t) return { x = t.x, y = t.y, z = t.z } end

-- Image : dessin (data:image) ou toile d'origine du script
function Boards.IsValidUrl(url)
    if type(url) ~= 'string' or url == '' or #url > Config.MaxImageLen then return false end
    if url:sub(1, 11) == 'data:image/' then return not url:find('[%s"\'<>`]', 1, false) end
    return url:match('^nui://pop_boards/html/[%w_%-%./%?=&]+$') ~= nil
end

function Boards.CleanCorners(c)
    if c == nil then return nil end
    if type(c) ~= 'table' then return false end
    local out, n = {}, 0
    for k, v in pairs(c) do
        n = n + 1
        if n > 8 then return false end
        if Boards.IsNum(v, -10000, 10000) then
            out[k] = v
        elseif type(v) == 'table' then
            if not (Boards.IsNum(v.x, -10000, 10000) and Boards.IsNum(v.y, -10000, 10000)) then return false end
            out[k] = { x = v.x, y = v.y }
        else
            return false
        end
    end
    return out
end

function Boards.PlayerNear(src, p)
    return Bridge.IsNear(src, p, Config.MaxDistance)
end

function Boards.GetBoardRow(dbId)
    local row = MySQL.single.await('SELECT id, pos, owner FROM pop_boards WHERE id = ?', { dbId })
    if row and type(row.pos) == 'string' then row.pos = json.decode(row.pos) end
    return row
end

--- Notification au style d'origine (titre « Tableau »).
function Boards.Notify(src, message)
    Bridge.Notify(src, { title = L('board_title'), message = message, duration = 5000 })
end
