-- État partagé, outils et affichage des panneaux DUI des tableaux.

Boards = {
    panels = {},     -- [dbId] = duiId
    data = {},       -- [dbId] = { ... }
    placing = false,
    editingId = nil,
}

Boards.FIT_TYPES = { fill = true, cover = true, contain = true }

function Boards.IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
end

-- Image acceptée : dessin (data:image) ou fichier du script
function Boards.IsSafeUrl(url)
    if type(url) ~= 'string' or url == '' then return false end
    return url:sub(1, 11) == 'data:image/' or url:sub(1, 22) == 'nui://pop_boards/html/'
end

function Boards.URLEncode(str)
    if str then
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

function Boards.Notify(message)
    Bridge.Notify({ title = L('board_title'), message = message, image = Config.NotifyImage, duration = 4000 })
end

function Boards.Debug(msg, ...)
    if Config.Debug then print(('^1[Boards]^7 ' .. msg):format(...)) end
end

-- Détruit le panneau DUI (mémoire GPU) ; il sera recréé à l'approche
function Boards.UnloadBoard(dbId)
    if Boards.panels[dbId] then
        exports["pop_duiengine"]:DestroyPanel(Boards.panels[dbId])
        Boards.panels[dbId] = nil
        Bridge.Target.Remove('board_' .. dbId)
    end
end

-- Zone « Peindre » précise, orientée comme le tableau
local function RegisterPanelInteraction(dbId, pos, width, height, normal)
    local heading = 0.0
    if normal then
        heading = math.deg(math.atan(normal.x, -normal.y))
    end
    Bridge.Target.AddBoxZone('board_' .. dbId, pos, vec3(width, 0.1, height), heading, {
        {
            icon = 'fas fa-palette',
            label = L('board_paint'),
            onSelect = function() Boards.OpenEditor(dbId) end,
        },
    })
end

RegisterNUICallback("duiReady", function(data, cb)
    local dbId = tonumber(data.dbId)
    local board = dbId and Boards.data[dbId]
    if board and board.url and Boards.panels[dbId] then
        exports["pop_duiengine"]:SendMessage(Boards.panels[dbId], { type = "updateTexture", url = board.url })
    end
    cb('ok')
end)

RegisterNetEvent('pop_boards:client:addBoard', function(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)
    if not data.dbId or Boards.panels[data.dbId] then return end
    if not Boards.IsSafeUrl(data.url) then return end
    if not Boards.IsVec(data.pos) or not Boards.IsVec(data.normal) or type(data.width) ~= 'number' or type(data.height) ~= 'number' then return end
    if not Boards.FIT_TYPES[data.fitType] then data.fitType = 'fill' end
    data.resW = tonumber(data.resW) or 1024
    data.resH = tonumber(data.resH) or 1024

    local pos = vector3(data.pos.x, data.pos.y, data.pos.z)
    local normal = vector3(data.normal.x, data.normal.y, data.normal.z)

    local urlParam = ""
    local isShortUrl = not string.find(data.url, "data:")
    if isShortUrl and data.url ~= "" then urlParam = "&url=" .. Boards.URLEncode(data.url) end

    -- dbId passé dans l'URL pour le handshake duiReady
    local finalUrl = "nui://pop_boards/html/index.html?dbId=" .. data.dbId .. "&resW=" .. data.resW .. "&resH=" .. data.resH .. "&fit=" .. data.fitType .. urlParam

    Boards.panels[data.dbId] = exports["pop_duiengine"]:CreatePanel({
        url = finalUrl,
        pos = pos,
        normal = normal,
        width = data.width,
        height = data.height,
        alpha = 255,
        resW = data.resW,
        resH = data.resH,
        faceCamera = false,
        zOffset = 0.002 -- sortir du mur pour éviter le clipping
    })

    RegisterPanelInteraction(data.dbId, pos, data.width, data.height, normal)
end)

RegisterNetEvent('pop_boards:client:removeBoard', function(dbId)
    dbId = tonumber(dbId)
    if not dbId then return end
    Boards.UnloadBoard(dbId)
    Boards.data[dbId] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Boards.panels) do Boards.UnloadBoard(id) end
end)
