local ESX = exports['es_extended']:getSharedObject()

local panels = {} -- [dbId] = duiId
local panelData = {} -- [dbId] = { ... }

local placingMode = false
local previewPanelId = nil
local currentEditingId = nil
local OpenEditor, RegisterPanelInteraction, RequestBoardData -- déclarations anticipées

local LOAD_DISTANCE = 40.0
local UNLOAD_DISTANCE = 60.0
local FIT_TYPES = { fill = true, cover = true, contain = true }

-- --- HELPERS ---
local function IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
end

-- Image acceptée : dessin (data:image) ou fichier du script
local function IsSafeUrl(url)
    if type(url) ~= 'string' or url == '' then return false end
    return url:sub(1, 11) == 'data:image/' or url:sub(1, 22) == 'nui://pop_boards/html/'
end

-- Détruit le panneau DUI (mémoire GPU) ; il sera recréé à l'approche
local function UnloadBoard(dbId)
    if panels[dbId] then
        exports["pop_duiengine"]:DestroyPanel(panels[dbId])
        panels[dbId] = nil
        exports.ox_target:removeZone('board_' .. dbId)
    end
end

local function RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function RaycastFromCamera(dist)
    local camPos = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local dir = RotToDir(rot)
    local dest = camPos + dir * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, _ = GetShapeTestResult(ray)
    return hit == 1, endCoords, surfaceNormal
end

local function URLEncode(str)
    if str then
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- --- CORE LOGIC ---
function RegisterPanelInteraction(dbId, pos, width, height, normal)
    -- On utilise un boxZone précis pour éviter que les zones de différents tableaux ne s'overlap
    local heading = 0.0
    if normal then
        heading = math.deg(math.atan2(normal.x, -normal.y))
    end

    exports.ox_target:addBoxZone({
        name = 'board_' .. dbId,
        coords = pos,
        size = vec3(width, 0.1, height),
        rotation = heading,
        debug = false,
        options = {
            {
                name = 'edit_board_' .. dbId,
                icon = 'fas fa-palette',
                label = 'Peindre',
                onSelect = function()
                    OpenEditor(dbId)
                end
            }
        }
    })
end

function OpenEditor(dbId)
    dbId = tonumber(dbId)
    local data = panelData[dbId]
    if not data then 
        print("^1[Boards-Error]^7 Tentative d'ouverture de l'éditeur pour un ID inconnu : " .. tostring(dbId))
        return 
    end
    
    currentEditingId = dbId
    SetNuiFocus(true, true)
    
    -- Un léger délai permet au focus de s'installer avant d'envoyer les données
    Wait(200)
    
    
    SendNUIMessage({
        action = "openMenu",
        dbId = dbId,
        url = data.url,
        resW = data.resW or 1024,
        resH = data.resH or 1024
    })
end

RegisterNUICallback("saveBoard", function(data, cb)
    SetNuiFocus(false, false)
    
    if currentEditingId and data.image then
        local pData = panelData[currentEditingId]
        if pData then
            -- Mise à jour locale visuelle immédiate
            pData.url = data.image
            local duiId = panels[currentEditingId]
            if duiId then
                exports["pop_duiengine"]:SendMessage(duiId, { type = "updateTexture", url = data.image })
            end

            -- Système d'envoi par morceaux (Chunking) ultra-sécurisé (8KB)
            local imageData = data.image
            local chunkSize = 8000 
            local len = string.len(imageData)

            local chunkCount = 0
            for i = 1, len, chunkSize do
                local isFirst = (i == 1)
                local chunk = string.sub(imageData, i, i + chunkSize - 1)
                TriggerServerEvent('pop_boards:server:uploadChunk', chunk, isFirst)
                chunkCount = chunkCount + 1
                Wait(50) -- On laisse plus de temps au réseau (50ms)
            end

            -- On déclenche la sauvegarde finale
            TriggerServerEvent('pop_boards:server:saveBoard', { 
                dbId = currentEditingId, 
                useChunks = true 
            })
            currentEditingId = nil -- On nettoie ici
        else
            print("^1[Boards]^7 Erreur: panelData introuvable pour ID " .. tostring(currentEditingId))
        end
    else
        print("^1[Boards]^7 Erreur: ID ou Image invalide.")
    end
    cb('ok')
end)

RegisterNUICallback("closeMenu", function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- --- PLACEMENT ---
RegisterNetEvent('pop_boards:client:placement', function()
    if placingMode then return end
    placingMode = true
    
    local defaultRes = 1024
    local defaultWidth = 0.76
    local defaultHeight = 0.95
    local initialUrl = "nui://pop_boards/html/toile.png"
    
    local finalUrl = "nui://pop_boards/html/index.html?url=" .. URLEncode(initialUrl) .. "&fit=fill&resW=" .. defaultRes .. "&resH=" .. defaultRes
    
    local id = exports["pop_duiengine"]:CreatePanel({
        url = finalUrl,
        pos = vector3(0,0,0),
        normal = vector3(0,1,0),
        width = defaultWidth,
        height = defaultHeight,
        alpha = 150,
        resW = defaultRes,
        resH = defaultRes,
        faceCamera = false,
        zOffset = 0.0
    })
    previewPanelId = id
    
    local alreadyConfirmed = false

    CreateThread(function()
        local scaleW = 1.0
        local scaleH = 1.0
        while placingMode do
            Wait(0)
            local hit, hitPos, hitNormal = RaycastFromCamera(10.0)
            if hit then
                local pos = hitPos + (hitNormal * 0.01)
                exports["pop_duiengine"]:SetPanelTransform(previewPanelId, pos, hitNormal)
                
                -- Resize Uniforme (Molette)
                local changed = false
                if IsControlJustPressed(0, 15) then scaleW = scaleW + 0.1; scaleH = scaleH + 0.1; changed = true end
                if IsControlJustPressed(0, 14) then scaleW = math.max(0.1, scaleW - 0.1); scaleH = math.max(0.1, scaleH - 0.1); changed = true end

                -- Resize Indépendant (Flèches)
                if IsControlPressed(0, 172) then scaleH = scaleH + 0.05; changed = true end 
                if IsControlPressed(0, 173) then scaleH = math.max(0.1, scaleH - 0.05); changed = true end 
                if IsControlPressed(0, 174) then scaleW = math.max(0.1, scaleW - 0.05); changed = true end 
                if IsControlPressed(0, 175) then scaleW = scaleW + 0.05; changed = true end 

                if changed then
                    exports["pop_duiengine"]:SetPanelSize(previewPanelId, defaultWidth * scaleW, defaultHeight * scaleH)
                end
                
                -- Confirm (ENTREE ou CLIC GAUCHE)
                if not alreadyConfirmed and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 24)) then
                    alreadyConfirmed = true
                    exports['pop_notify']:ShowNotify({
                        title = "Tableau",
                        message = "Placement du tableau en cours...",
                        image = "https://static.wikia.nocookie.net/gta/images/9/91/Auction-GTAO.png",
                        duration = 4000
                    })
                    placingMode = false
                    exports["pop_duiengine"]:DestroyPanel(previewPanelId)
                    
                    -- Calcul de la résolution optimale selon le ratio
                    local finalW, finalH = 1024, 1024
                    local w = defaultWidth * scaleW
                    local h = defaultHeight * scaleH
                    
                    if w > h * 1.2 then -- Paysage
                        finalW, finalH = 1920, 1080
                    elseif h > w * 1.2 then -- Portrait
                        finalW, finalH = 1080, 1920
                    end

                    TriggerServerEvent('pop_boards:server:saveBoard', {
                        url = initialUrl .. "?t=" .. GetGameTimer(), -- Salt to prevent caching
                        pos = pos,
                        normal = hitNormal,
                        width = w,
                        height = h,
                        resW = finalW,
                        resH = finalH,
                        fitType = 'cover'
                    })
                    Wait(500)
                    break
                end
            end
            
            -- Cancel
            if IsControlJustPressed(0, 177) then 
                placingMode = false
                exports["pop_duiengine"]:DestroyPanel(previewPanelId)
                break
            end
        end
    end)
end)

-- --- SYNC ---
local boardSyncData = {} -- [dbId] = { chunks = {} }
local requestedBoards = {} -- [dbId] = timestamp

function RequestBoardData(dbId)
    if requestedBoards[dbId] and (GetGameTimer() - requestedBoards[dbId] < 10000) then return end
    requestedBoards[dbId] = GetGameTimer()
    TriggerServerEvent('pop_boards:server:requestData', dbId)
end

-- Boucle de vérification de proximité (chargement/déchargement dynamique)
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        local count = 0
        for dbId, data in pairs(panelData) do
            local boardId = tonumber(dbId)
            if boardId and IsVec(data.pos) and panels[boardId] then
                -- Trop loin : on libère le DUI
                if #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z)) > UNLOAD_DISTANCE then
                    UnloadBoard(boardId)
                end
            elseif boardId and IsVec(data.pos) then
                local bPos = vector3(data.pos.x, data.pos.y, data.pos.z)
                local dist = #(pCoords - bPos)
                
                if dist < LOAD_DISTANCE then
                    if data.url and data.url ~= "" then
                        -- On a déjà l'URL (nouveau board ou déjà fetch), on l'affiche
                        TriggerEvent('pop_boards:client:addBoard', data)
                    else
                        -- On n'a pas l'URL, on demande au serveur
                        RequestBoardData(boardId)
                        count = count + 1
                        if count % 2 == 0 then Wait(100) end
                    end
                end
            end
        end
        Wait(1000) -- Vérification toutes les secondes
    end
end)

RegisterNetEvent('pop_boards:client:notifyUpdate', function(data)
    if type(data) ~= 'table' or not data.dbId then return end
    local dbId = tonumber(data.dbId)
    if not dbId then return end
    data.url = nil -- l'image n'arrive que par requestData
    
    -- On décode les positions si nécessaire
    if type(data.pos) == 'string' then data.pos = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end
    
    if not panelData[dbId] then
        panelData[dbId] = data
    else
        for k, v in pairs(data) do 
            panelData[dbId][k] = v 
        end
        -- Only invalidate the URL if it wasn't the player who just saved it
        if currentEditingId ~= dbId then
            panelData[dbId].url = nil 
            -- Panneau affiché : on recrée avec la nouvelle position/taille et on redemande l'image
            if panels[dbId] then
                UnloadBoard(dbId)
                requestedBoards[dbId] = nil
                RequestBoardData(dbId)
            end
        end
    end
    panelData[dbId].dbId = dbId
end)

RegisterNetEvent('pop_boards:client:receiveMetadata', function(data)
    if not data or not data.id then return end
    local dbId = tonumber(data.id)

    -- On parse les positions si nécessaire
    if type(data.pos) == 'string' then data.pos = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end
    
    panelData[dbId] = data
    panelData[dbId].dbId = dbId
    boardSyncData[dbId] = nil -- Reset des chunks en cas de nouvelle demande pour ce board
end)

RegisterNetEvent('pop_boards:client:syncBoardUrlChunk', function(dbId, chunk, isLast)
    if type(dbId) ~= 'number' or type(chunk) ~= 'string' then return end
    if not boardSyncData[dbId] then boardSyncData[dbId] = {} end
    table.insert(boardSyncData[dbId], chunk)
    
    if isLast then
        local fullUrl = table.concat(boardSyncData[dbId])
        boardSyncData[dbId] = nil
        if not IsSafeUrl(fullUrl) then return end
        
        if panelData[dbId] then
            panelData[dbId].url = fullUrl
            local duiId = panels[dbId]
            if duiId then
                CreateThread(function()
                    Wait(500) -- Délai de sécurité pour le chargement du DUI
                    exports["pop_duiengine"]:SendMessage(duiId, { type = "updateTexture", url = fullUrl })
                end)
            else
                TriggerEvent('pop_boards:client:addBoard', panelData[dbId])
            end
        end
    end
end)

RegisterNUICallback("duiReady", function(data, cb)
    local dbId = tonumber(data.dbId)
    if dbId and panelData[dbId] and panelData[dbId].url then
        local duiId = panels[dbId]
        if duiId then
            exports["pop_duiengine"]:SendMessage(duiId, { type = "updateTexture", url = panelData[dbId].url })
        end
    end
    cb('ok')
end)

RegisterNetEvent('pop_boards:client:addBoard', function(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)
    if not data.dbId or panels[data.dbId] then return end
    if not IsSafeUrl(data.url) then return end
    if not IsVec(data.pos) or not IsVec(data.normal) or type(data.width) ~= 'number' or type(data.height) ~= 'number' then return end
    if not FIT_TYPES[data.fitType] then data.fitType = 'fill' end
    data.resW = tonumber(data.resW) or 1024
    data.resH = tonumber(data.resH) or 1024

    local pos = data.pos
    if type(pos) == 'table' then pos = vector3(pos.x, pos.y, pos.z) end
    
    local normal = data.normal
    if type(normal) == 'table' then normal = vector3(normal.x, normal.y, normal.z) end
    
    local urlParam = ""
    local isShortUrl = not string.find(data.url, "data:")
    if isShortUrl and data.url ~= "" then urlParam = "&url=" .. URLEncode(data.url) end

    -- On passe dbId dans l'URL pour faciliter le handshake
    local finalUrl = "nui://pop_boards/html/index.html?dbId=" .. data.dbId .. "&resW=" .. (data.resW or 1024) .. "&resH=" .. (data.resH or 1024) .. "&fit=" .. (data.fitType or 'fill') .. urlParam

    local id = exports["pop_duiengine"]:CreatePanel({
        url = finalUrl,
        pos = pos,
        normal = normal,
        width = data.width,
        height = data.height,
        alpha = 255,
        resW = data.resW or 1024,
        resH = data.resH or 1024,
        faceCamera = false,
        zOffset = 0.002 -- Sortir du mur d'au moins 1cm pour éviter le clipping
    })
    
    panels[data.dbId] = id
    
    -- Plus besoin de boucle d'essais ici, on utilise duiReady
    RegisterPanelInteraction(data.dbId, pos, data.width, data.height, normal)
end)

RegisterNetEvent('pop_boards:client:removeBoard', function(dbId)
    dbId = tonumber(dbId)
    if not dbId then return end
    UnloadBoard(dbId)
    panelData[dbId] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(panels) do UnloadBoard(id) end
end)

RegisterNetEvent('pop_boards:client:updateBoardTexture', function(dbId, data)
    -- On invalide l'URL pour forcer un rechargement via proximité
    if not panelData[dbId] then return end
    for k, v in pairs(data) do 
        panelData[dbId][k] = v 
    end
    panelData[dbId].url = nil
end)

-- --- COMMANDS ---
RegisterCommand('board_add', function()
    if not placingMode then
        TriggerEvent('pop_boards:client:placement')
    else
        print("^1[Boards]^7 Déjà en mode placement.")
        exports['pop_notify']:ShowNotify({
            title = "Tableau",
            message = "Vous êtes déjà en train de poser un tableau.",
            image = "https://static.wikia.nocookie.net/gta/images/9/91/Auction-GTAO.png",
            duration = 4000
        })
    end
end, false)

-- --- INITIAL LOAD ---
CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(100) end
    Wait(5000) -- Délai de sécurité accru (5s) pour laisser tout s'initialiser (DUI, ox_lib, etc)
    
    local allBoards = lib.callback.await('pop_boards:server:getBoards')
    if allBoards then
        for _, board in ipairs(allBoards) do
            local dbId = board.id
            board.dbId = dbId
             -- On décode les positions SQL
            if type(board.pos) == 'string' then board.pos = json.decode(board.pos) end
            if type(board.normal) == 'string' then board.normal = json.decode(board.normal) end
            
            panelData[dbId] = board
            -- Note: le panneau sera créé par la boucle de proximité
        end
    end
end)
