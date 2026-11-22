-- Chargement des tableaux : liste au démarrage, images à la demande selon la distance.

local boardSyncData = {}   -- [dbId] = { morceaux }
local requestedBoards = {} -- [dbId] = ms

local function RequestBoardData(dbId)
    if requestedBoards[dbId] and (GetGameTimer() - requestedBoards[dbId] < 10000) then return end
    requestedBoards[dbId] = GetGameTimer()
    TriggerServerEvent('pop_boards:server:requestData', dbId)
end

-- Boucle de proximité (chargement/déchargement dynamique), toutes les secondes
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        local count = 0
        for dbId, data in pairs(Boards.data) do
            local boardId = tonumber(dbId)
            if boardId and Boards.IsVec(data.pos) and Boards.panels[boardId] then
                -- Trop loin : on libère le DUI
                if #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z)) > Config.UnloadDistance then
                    Boards.UnloadBoard(boardId)
                end
            elseif boardId and Boards.IsVec(data.pos) then
                local dist = #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z))
                if dist < Config.LoadDistance then
                    if data.url and data.url ~= "" then
                        TriggerEvent('pop_boards:client:addBoard', data)
                    else
                        RequestBoardData(boardId)
                        count = count + 1
                        if count % 2 == 0 then Wait(100) end
                    end
                end
            end
        end
        Wait(1000)
    end
end)

RegisterNetEvent('pop_boards:client:notifyUpdate', function(data)
    if type(data) ~= 'table' or not data.dbId then return end
    local dbId = tonumber(data.dbId)
    if not dbId then return end
    data.url = nil -- l'image n'arrive que par requestData

    if type(data.pos) == 'string' then data.pos = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end

    if not Boards.data[dbId] then
        Boards.data[dbId] = data
    else
        for k, v in pairs(data) do
            Boards.data[dbId][k] = v
        end
        -- On invalide l'image sauf pour le joueur qui vient de sauvegarder
        if Boards.editingId ~= dbId then
            Boards.data[dbId].url = nil
            -- Panneau affiché : on recrée avec la nouvelle position/taille et on redemande l'image
            if Boards.panels[dbId] then
                Boards.UnloadBoard(dbId)
                requestedBoards[dbId] = nil
                RequestBoardData(dbId)
            end
        end
    end
    Boards.data[dbId].dbId = dbId
end)

RegisterNetEvent('pop_boards:client:receiveMetadata', function(data)
    if not data or not data.id then return end
    local dbId = tonumber(data.id)

    if type(data.pos) == 'string' then data.pos = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end

    Boards.data[dbId] = data
    Boards.data[dbId].dbId = dbId
    boardSyncData[dbId] = nil -- nouvelle demande : on repart de zéro
end)

RegisterNetEvent('pop_boards:client:syncBoardUrlChunk', function(dbId, chunk, isLast)
    if type(dbId) ~= 'number' or type(chunk) ~= 'string' then return end
    if not boardSyncData[dbId] then boardSyncData[dbId] = {} end
    table.insert(boardSyncData[dbId], chunk)

    if isLast then
        local fullUrl = table.concat(boardSyncData[dbId])
        boardSyncData[dbId] = nil
        if not Boards.IsSafeUrl(fullUrl) then return end

        local board = Boards.data[dbId]
        if board then
            board.url = fullUrl
            local duiId = Boards.panels[dbId]
            if duiId then
                CreateThread(function()
                    Wait(500) -- délai de sécurité pour le chargement du DUI
                    exports["pop_duiengine"]:SendMessage(duiId, { type = "updateTexture", url = fullUrl })
                end)
            else
                TriggerEvent('pop_boards:client:addBoard', board)
            end
        end
    end
end)

RegisterNetEvent('pop_boards:client:updateBoardTexture', function(dbId, data)
    -- On invalide l'URL pour forcer un rechargement via proximité
    if not Boards.data[dbId] or type(data) ~= 'table' then return end
    for k, v in pairs(data) do
        Boards.data[dbId][k] = v
    end
    Boards.data[dbId].url = nil
end)

-- Chargement initial (une fois, quand le personnage est chargé)
local initialLoaded = false
Bridge.OnPlayerLoaded(function()
    if initialLoaded then return end
    initialLoaded = true
    Wait(5000) -- laisse tout s'initialiser (DUI, etc.)

    local allBoards = Callback.Await('pop_boards:getBoards')
    if allBoards then
        for _, board in ipairs(allBoards) do
            local dbId = board.id
            board.dbId = dbId
            if type(board.pos) == 'string' then board.pos = json.decode(board.pos) end
            if type(board.normal) == 'string' then board.normal = json.decode(board.normal) end
            Boards.data[dbId] = board -- le panneau sera créé par la boucle de proximité
        end
    end
end)
