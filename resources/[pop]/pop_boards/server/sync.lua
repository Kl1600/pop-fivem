-- Envoi à la demande de l'image d'un tableau (joueur proche) et suppression (admins).

local requestLog = {}     -- [src] = { t = début fenêtre, n = nombre, boards = { [dbId] = ms } }
local sending = {}        -- [src] = true pendant un envoi d'image

RegisterNetEvent('pop_boards:server:requestData', function(dbId)
    local src = source
    if type(dbId) ~= 'number' then return end

    -- Limites : un tableau toutes les 5 s, 12 demandes / 10 s, un envoi à la fois
    local now = GetGameTimer()
    local log = requestLog[src]
    if not log or now - log.t > 10000 then
        log = { t = now, n = 0, boards = log and log.boards or {} }
        requestLog[src] = log
    end
    if log.boards[dbId] and now - log.boards[dbId] < Config.RequestCooldown then return end
    if log.n >= Config.RequestMaxPer10s or sending[src] then return end
    log.n = log.n + 1
    log.boards[dbId] = now

    local result = MySQL.single.await('SELECT id, url, pos, normal, width, height, resW, resH, fitType, corners FROM pop_boards WHERE id = ?', { dbId })
    if not result then return end

    -- Seulement pour un joueur proche du tableau (comme la boucle de proximité du client)
    local pos = type(result.pos) == 'string' and json.decode(result.pos) or result.pos
    if not Boards.IsVec(pos) or not Bridge.IsNear(src, pos, Config.RequestDistance) then return end

    local imageData = result.url or ""
    local totalSize = string.len(imageData)
    local chunkSize = 4000 -- morceaux de 4 Ko

    -- 1. Envoi des métadonnées d'abord (sans l'image)
    result.url = nil
    TriggerClientEvent('pop_boards:client:receiveMetadata', src, result)

    -- 2. Envoi progressif de l'image seulement au demandeur
    sending[src] = true
    Wait(100)
    for i = 1, totalSize, chunkSize do
        if not GetPlayerName(src) then break end
        local chunk = string.sub(imageData, i, i + chunkSize - 1)
        local isLast = (i + chunkSize > totalSize)
        TriggerClientEvent('pop_boards:client:syncBoardUrlChunk', src, dbId, chunk, isLast)
        if i % (chunkSize * 8) == 1 then Wait(0) end -- repos CPU léger
    end
    sending[src] = nil
end)

RegisterNetEvent('pop_boards:server:deleteBoard', function(dbId)
    -- Suppression réservée aux administrateurs (événement non utilisé par le client)
    local src = source
    if not Bridge.GetPlayer(src) or type(dbId) ~= 'number' then return end
    if not Bridge.IsAdmin(src) then return end
    MySQL.update('DELETE FROM pop_boards WHERE id = ?', { dbId })
    TriggerClientEvent('pop_boards:client:removeBoard', -1, dbId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    requestLog[src] = nil
    sending[src] = nil
end)
