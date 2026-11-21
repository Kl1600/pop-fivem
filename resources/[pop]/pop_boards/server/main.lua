local ESX = exports['es_extended']:getSharedObject()
local pendingUploads = {}

-- --- DATABASE INITIALIZATION ---
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pop_boards (
            id INT AUTO_INCREMENT PRIMARY KEY,
            url LONGTEXT NOT NULL,
            pos VARCHAR(255) NOT NULL,
            normal VARCHAR(255) NOT NULL,
            width FLOAT NOT NULL,
            height FLOAT NOT NULL,
            resW INT DEFAULT 1024,
            resH INT DEFAULT 1024,
            fitType VARCHAR(50) DEFAULT 'fill',
            corners LONGTEXT
        )
    ]])
end)

lib.callback.register('pop_boards:server:getBoards', function(source)
    local result = MySQL.query.await('SELECT id, pos, normal, width, height, resW, resH, fitType, corners FROM pop_boards')
    return result
end)

RegisterNetEvent('pop_boards:server:saveBoard', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if data.dbId ~= nil and type(data.dbId) ~= 'number' then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Validation des données de placement (types, tailles, distance du joueur)
    if data.pos ~= nil or not data.dbId then
        local p = data.pos
        if type(p) ~= 'table' or type(p.x) ~= 'number' or type(p.y) ~= 'number' or type(p.z) ~= 'number' then return end
        local ped = GetPlayerPed(src)
        if ped == 0 or #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) > 30.0 then return end
        if type(data.normal) ~= 'table' then return end
    end
    if data.width ~= nil and (type(data.width) ~= 'number' or data.width <= 0 or data.width > 20.0) then return end
    if data.height ~= nil and (type(data.height) ~= 'number' or data.height <= 0 or data.height > 20.0) then return end
    if data.resW ~= nil and (type(data.resW) ~= 'number' or data.resW < 1 or data.resW > 4096) then return end
    if data.resH ~= nil and (type(data.resH) ~= 'number' or data.resH < 1 or data.resH > 4096) then return end
    if data.fitType ~= nil and (type(data.fitType) ~= 'string' or #data.fitType > 50) then return end
    if data.corners ~= nil and type(data.corners) ~= 'table' then return end
    if data.url ~= nil and type(data.url) ~= 'string' then return end

    -- Image lourde (chunks) ?
    local totalLen = 0
    if data.useChunks then
        if pendingUploads[src] then
            data.url = table.concat(pendingUploads[src])
            totalLen = string.len(data.url)
            pendingUploads[src] = nil
        else
            data.url = ""
        end
    else
        totalLen = string.len(data.url or "")
    end

    -- Protection : Limite 10MB pour éviter les crashs de données sur les grands dessins
    if totalLen > 10000000 then 
        return 
    end

    if not data.url or data.url == "" then 
        return 
    end

    local function broadcastUpdate(syncData)
        -- On prépare une version légère sans l'image pour notifier tout le monde
        local meta = {}
        for k, v in pairs(syncData) do if k ~= "url" then meta[k] = v end end
        
        -- On envoie les infos de position et taille à tout le monde
        TriggerClientEvent('pop_boards:client:notifyUpdate', -1, meta)
    end

    if data.dbId then -- Update existing
        local updateFields = { "url = ?" }
        local updateParams = { data.url }

        if data.pos then table.insert(updateFields, "pos = ?"); table.insert(updateParams, json.encode(data.pos)) end
        if data.normal then table.insert(updateFields, "normal = ?"); table.insert(updateParams, json.encode(data.normal)) end
        if data.width then table.insert(updateFields, "width = ?"); table.insert(updateParams, data.width) end
        if data.height then table.insert(updateFields, "height = ?"); table.insert(updateParams, data.height) end
        if data.resW then table.insert(updateFields, "resW = ?"); table.insert(updateParams, data.resW) end
        if data.resH then table.insert(updateFields, "resH = ?"); table.insert(updateParams, data.resH) end
        if data.fitType then table.insert(updateFields, "fitType = ?"); table.insert(updateParams, data.fitType) end
        if data.corners then table.insert(updateFields, "corners = ?"); table.insert(updateParams, json.encode(data.corners)) end

        table.insert(updateParams, data.dbId)
        local query = 'UPDATE pop_boards SET ' .. table.concat(updateFields, ", ") .. ' WHERE id = ?'
        
        MySQL.update.await(query, updateParams)
        broadcastUpdate(data)
    else -- Create new
        local posStr = json.encode(data.pos)
        local normStr = json.encode(data.normal)
        local cornersStr = data.corners and json.encode(data.corners) or nil
        
        local insertId = MySQL.insert.await([[
            INSERT INTO pop_boards (url, pos, normal, width, height, resW, resH, fitType, corners)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { data.url, posStr, normStr, data.width, data.height, data.resW, data.resH, data.fitType, cornersStr })
        
        data.dbId = insertId
        broadcastUpdate(data)
    end
end)

-- Système de synchronisation à la demande (Proximity-based Fetch)
RegisterNetEvent('pop_boards:server:requestData', function(dbId)
    local src = source
    if type(dbId) ~= 'number' then return end
    local result = MySQL.single.await('SELECT * FROM pop_boards WHERE id = ?', { dbId })
    if not result then return end
    
    local imageData = result.url
    local totalSize = string.len(imageData or "")
    local chunkSize = 4000 -- Chunks plus petits (4KB) pour une sécurité absolue

    -- 1. Envoi des métadonnées d'abord (sans l'image)
    result.url = nil
    TriggerClientEvent('pop_boards:client:receiveMetadata', src, result)
    
    -- 2. Envoi progressif de l'image seulement au demandeur
    Wait(100)
    for i = 1, totalSize, chunkSize do
        local chunk = string.sub(imageData, i, i + chunkSize - 1)
        local isLast = (i + chunkSize >= totalSize)
        TriggerClientEvent('pop_boards:client:syncBoardUrlChunk', src, dbId, chunk, isLast)
        if i % (chunkSize * 8) == 0 then Wait(0) end -- Repos CPU léger
    end
end)

RegisterNetEvent('pop_boards:server:uploadChunk', function(chunk, isFirst)
    local src = source
    if type(chunk) ~= 'string' or #chunk > 16000 then pendingUploads[src] = nil return end
    if isFirst then
        pendingUploads[src] = { chunk }
    else
        if pendingUploads[src] then
            table.insert(pendingUploads[src], chunk)
            -- Securité anti-overflow mémoire par joueur (max ~10MB de chunks en cours d'assemblage)
            if #pendingUploads[src] > 1500 then pendingUploads[src] = nil end
        end
    end
end)

-- Nettoyage mémoire lors d'une déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if pendingUploads[src] then
        pendingUploads[src] = nil
    end
end)

RegisterNetEvent('pop_boards:server:deleteBoard', function(dbId)
    -- Suppression réservée aux administrateurs (événement non utilisé par le client)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(dbId) ~= 'number' then return end
    local group = xPlayer.getGroup()
    if group ~= 'admin' and group ~= 'superadmin' then return end
    MySQL.update('DELETE FROM pop_boards WHERE id = ?', { dbId })
    TriggerClientEvent('pop_boards:client:removeBoard', -1, dbId)
end)
