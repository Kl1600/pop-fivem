-- Pose, peinture et envoi des images (par morceaux) des tableaux.

local pendingUploads = {} -- [src] = { morceaux }
local lastSave = {}       -- [src] = ms

Callback.Register('pop_boards:getBoards', function()
    return MySQL.query.await('SELECT id, pos, normal, width, height, resW, resH, fitType, corners FROM pop_boards')
end)

-- Mise à jour d'un tableau existant (peinture ouverte à tous ; géométrie : propriétaire ou admin)
local function UpdateBoard(src, data, url, admin, identifier)
    local row = Boards.GetBoardRow(data.dbId)
    if not row or not Boards.IsVec(row.pos) or not Boards.PlayerNear(src, row.pos) then return end

    local geometry = data.pos ~= nil or data.normal ~= nil or data.width ~= nil or data.height ~= nil
        or data.resW ~= nil or data.resH ~= nil or data.fitType ~= nil or data.corners ~= nil
    if geometry and not admin and row.owner ~= identifier then geometry = false end

    local fields, params = { 'url = ?' }, { url }
    local meta = { dbId = data.dbId }
    if geometry then
        if data.pos ~= nil then
            if not Boards.IsVec(data.pos) or not Boards.PlayerNear(src, data.pos) then return end
            table.insert(fields, 'pos = ?'); table.insert(params, json.encode(Boards.CleanVec(data.pos))); meta.pos = Boards.CleanVec(data.pos)
        end
        if data.normal ~= nil then
            if not Boards.IsVec(data.normal) then return end
            table.insert(fields, 'normal = ?'); table.insert(params, json.encode(Boards.CleanVec(data.normal))); meta.normal = Boards.CleanVec(data.normal)
        end
        if data.width ~= nil then
            if not Boards.IsNum(data.width, 0.01, 20.0) then return end
            table.insert(fields, 'width = ?'); table.insert(params, data.width); meta.width = data.width
        end
        if data.height ~= nil then
            if not Boards.IsNum(data.height, 0.01, 20.0) then return end
            table.insert(fields, 'height = ?'); table.insert(params, data.height); meta.height = data.height
        end
        if data.resW ~= nil then
            if not Boards.IsNum(data.resW, 1, 4096) then return end
            table.insert(fields, 'resW = ?'); table.insert(params, math.floor(data.resW)); meta.resW = math.floor(data.resW)
        end
        if data.resH ~= nil then
            if not Boards.IsNum(data.resH, 1, 4096) then return end
            table.insert(fields, 'resH = ?'); table.insert(params, math.floor(data.resH)); meta.resH = math.floor(data.resH)
        end
        if data.fitType ~= nil then
            if not Boards.FIT_TYPES[data.fitType] then return end
            table.insert(fields, 'fitType = ?'); table.insert(params, data.fitType); meta.fitType = data.fitType
        end
        if data.corners ~= nil then
            local corners = Boards.CleanCorners(data.corners)
            if corners == false then return end
            table.insert(fields, 'corners = ?'); table.insert(params, json.encode(corners)); meta.corners = corners
        end
    end

    table.insert(params, data.dbId)
    MySQL.update.await('UPDATE pop_boards SET ' .. table.concat(fields, ', ') .. ' WHERE id = ?', params)
    -- Version légère, sans l'image, avec des champs propres uniquement
    TriggerClientEvent('pop_boards:client:notifyUpdate', -1, meta)
end

-- Nouveau tableau : position près du joueur, tailles bornées, quota par joueur
local function CreateBoard(src, data, url, admin, identifier)
    if not Boards.IsVec(data.pos) or not Boards.IsVec(data.normal) or not Boards.PlayerNear(src, data.pos) then return end
    if not Boards.IsNum(data.width, 0.01, 20.0) or not Boards.IsNum(data.height, 0.01, 20.0) then return end
    local resW = Boards.IsNum(data.resW, 1, 4096) and math.floor(data.resW) or 1024
    local resH = Boards.IsNum(data.resH, 1, 4096) and math.floor(data.resH) or 1024
    local fitType = Boards.FIT_TYPES[data.fitType] and data.fitType or 'fill'
    local corners = Boards.CleanCorners(data.corners)
    if corners == false then return end

    if not admin then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM pop_boards WHERE owner = ?', { identifier }) or 0
        if count >= Config.MaxBoardsPerPlayer then
            Boards.Notify(src, L('board_max_reached', Config.MaxBoardsPerPlayer))
            return
        end
    end

    local pos, normal = Boards.CleanVec(data.pos), Boards.CleanVec(data.normal)
    local insertId = MySQL.insert.await([[
        INSERT INTO pop_boards (url, pos, normal, width, height, resW, resH, fitType, corners, owner)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { url, json.encode(pos), json.encode(normal), data.width, data.height, resW, resH, fitType,
          corners and json.encode(corners) or nil, identifier })
    if not insertId then return end

    TriggerClientEvent('pop_boards:client:notifyUpdate', -1, {
        dbId = insertId, pos = pos, normal = normal, width = data.width, height = data.height,
        resW = resW, resH = resH, fitType = fitType, corners = corners,
    })
end

RegisterNetEvent('pop_boards:server:saveBoard', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if data.dbId ~= nil and (type(data.dbId) ~= 'number' or data.dbId < 1) then return end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    -- Délai entre deux sauvegardes
    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < Config.SaveCooldown then
        pendingUploads[src] = nil
        return
    end
    lastSave[src] = now

    -- Image : morceaux envoyés avant (dessin) ou lien court (toile de départ)
    local url
    if data.useChunks then
        url = pendingUploads[src] and table.concat(pendingUploads[src]) or nil
        pendingUploads[src] = nil
    else
        url = data.url
    end
    if not Boards.IsValidUrl(url) then return end

    local admin = Bridge.IsAdmin(src)
    if data.dbId then
        UpdateBoard(src, data, url, admin, identifier)
    else
        CreateBoard(src, data, url, admin, identifier)
    end
end)

RegisterNetEvent('pop_boards:server:uploadChunk', function(chunk, isFirst)
    local src = source
    if type(chunk) ~= 'string' or #chunk > 16000 then pendingUploads[src] = nil return end
    if isFirst then
        pendingUploads[src] = { chunk }
    elseif pendingUploads[src] then
        table.insert(pendingUploads[src], chunk)
        -- Sécurité anti-overflow mémoire par joueur (max ~10 Mo de morceaux en cours d'assemblage)
        if #pendingUploads[src] > 1500 then pendingUploads[src] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingUploads[src] = nil
    lastSave[src] = nil
end)
