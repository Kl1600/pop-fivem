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

-- --- RÉGLAGES DE SÉCURITÉ ---
local MAX_DISTANCE = 30.0          -- distance max du joueur au tableau (pose, peinture)
local MAX_IMAGE_LEN = 10000000     -- ~10 Mo par image
local MAX_BOARDS_PER_PLAYER = 5    -- tableaux posés par joueur (admins illimités)
local SAVE_COOLDOWN = 3000         -- ms entre deux sauvegardes d'un même joueur
local REQUEST_COOLDOWN = 5000      -- ms entre deux demandes du même tableau par un joueur
local REQUEST_MAX_PER_10S = 12     -- demandes de tableaux max par joueur sur 10 s
local FIT_TYPES = { fill = true, cover = true, contain = true }

-- Colonne propriétaire (ajoutée si absente)
CreateThread(function()
    Wait(1000)
    pcall(function()
        MySQL.query.await('ALTER TABLE pop_boards ADD COLUMN IF NOT EXISTS owner VARCHAR(64) DEFAULT NULL')
    end)
end)

local lastSave = {}       -- [src] = ms
local requestLog = {}     -- [src] = { t = début fenêtre, n = nombre, boards = { [dbId] = ms } }
local sending = {}        -- [src] = true pendant un envoi d'image

local function IsAdmin(src)
    if IsPlayerAceAllowed(src, 'pop.admin') then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    local group = xPlayer and xPlayer.getGroup()
    return group == 'admin' or group == 'superadmin'
end

local function IsNum(v, min, max)
    return type(v) == 'number' and v == v and v >= min and v <= max
end

local function IsVec(t)
    return type(t) == 'table' and IsNum(t.x, -100000, 100000) and IsNum(t.y, -100000, 100000) and IsNum(t.z, -100000, 100000)
end

local function CleanVec(t) return { x = t.x, y = t.y, z = t.z } end

-- Image : dessin (data:image) ou toile d'origine du script
local function IsValidUrl(url)
    if type(url) ~= 'string' or url == '' or #url > MAX_IMAGE_LEN then return false end
    if url:sub(1, 11) == 'data:image/' then return not url:find('[%s"\'<>`]', 1, false) end
    return url:match('^nui://pop_boards/html/[%w_%-%./%?=&]+$') ~= nil
end

local function CleanCorners(c)
    if c == nil then return nil end
    if type(c) ~= 'table' then return false end
    local out, n = {}, 0
    for k, v in pairs(c) do
        n = n + 1
        if n > 8 then return false end
        if IsNum(v, -10000, 10000) then
            out[k] = v
        elseif type(v) == 'table' then
            if not (IsNum(v.x, -10000, 10000) and IsNum(v.y, -10000, 10000)) then return false end
            out[k] = { x = v.x, y = v.y }
        else
            return false
        end
    end
    return out
end

local function PlayerNear(src, p)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) <= MAX_DISTANCE
end

local function GetBoardRow(dbId)
    local row = MySQL.single.await('SELECT id, pos, owner FROM pop_boards WHERE id = ?', { dbId })
    if row and type(row.pos) == 'string' then row.pos = json.decode(row.pos) end
    return row
end

lib.callback.register('pop_boards:server:getBoards', function(source)
    local result = MySQL.query.await('SELECT id, pos, normal, width, height, resW, resH, fitType, corners FROM pop_boards')
    return result
end)

RegisterNetEvent('pop_boards:server:saveBoard', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if data.dbId ~= nil and (type(data.dbId) ~= 'number' or data.dbId < 1) then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Délai entre deux sauvegardes
    local now = GetGameTimer()
    if lastSave[src] and now - lastSave[src] < SAVE_COOLDOWN then
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
    if not IsValidUrl(url) then return end

    local admin = IsAdmin(src)
    local identifier = xPlayer.identifier

    if data.dbId then
        -- Mise à jour : le tableau doit exister et le joueur doit être à côté
        local row = GetBoardRow(data.dbId)
        if not row or not IsVec(row.pos) or not PlayerNear(src, row.pos) then return end

        -- Peindre reste ouvert à tous (fonctionnement d'origine) ;
        -- déplacer ou redimensionner : propriétaire ou admin seulement.
        local geometry = data.pos ~= nil or data.normal ~= nil or data.width ~= nil or data.height ~= nil
            or data.resW ~= nil or data.resH ~= nil or data.fitType ~= nil or data.corners ~= nil
        if geometry and not admin and row.owner ~= identifier then geometry = false end

        local fields, params = { 'url = ?' }, { url }
        local meta = { dbId = data.dbId }
        if geometry then
            if data.pos ~= nil then
                if not IsVec(data.pos) or not PlayerNear(src, data.pos) then return end
                table.insert(fields, 'pos = ?'); table.insert(params, json.encode(CleanVec(data.pos))); meta.pos = CleanVec(data.pos)
            end
            if data.normal ~= nil then
                if not IsVec(data.normal) then return end
                table.insert(fields, 'normal = ?'); table.insert(params, json.encode(CleanVec(data.normal))); meta.normal = CleanVec(data.normal)
            end
            if data.width ~= nil then
                if not IsNum(data.width, 0.01, 20.0) then return end
                table.insert(fields, 'width = ?'); table.insert(params, data.width); meta.width = data.width
            end
            if data.height ~= nil then
                if not IsNum(data.height, 0.01, 20.0) then return end
                table.insert(fields, 'height = ?'); table.insert(params, data.height); meta.height = data.height
            end
            if data.resW ~= nil then
                if not IsNum(data.resW, 1, 4096) then return end
                table.insert(fields, 'resW = ?'); table.insert(params, math.floor(data.resW)); meta.resW = math.floor(data.resW)
            end
            if data.resH ~= nil then
                if not IsNum(data.resH, 1, 4096) then return end
                table.insert(fields, 'resH = ?'); table.insert(params, math.floor(data.resH)); meta.resH = math.floor(data.resH)
            end
            if data.fitType ~= nil then
                if not FIT_TYPES[data.fitType] then return end
                table.insert(fields, 'fitType = ?'); table.insert(params, data.fitType); meta.fitType = data.fitType
            end
            if data.corners ~= nil then
                local corners = CleanCorners(data.corners)
                if corners == false then return end
                table.insert(fields, 'corners = ?'); table.insert(params, json.encode(corners)); meta.corners = corners
            end
        end

        table.insert(params, data.dbId)
        MySQL.update.await('UPDATE pop_boards SET ' .. table.concat(fields, ', ') .. ' WHERE id = ?', params)
        -- Version légère, sans l'image, avec des champs propres uniquement
        TriggerClientEvent('pop_boards:client:notifyUpdate', -1, meta)
    else
        -- Nouveau tableau : position près du joueur, tailles bornées, quota par joueur
        if not IsVec(data.pos) or not IsVec(data.normal) or not PlayerNear(src, data.pos) then return end
        if not IsNum(data.width, 0.01, 20.0) or not IsNum(data.height, 0.01, 20.0) then return end
        local resW = IsNum(data.resW, 1, 4096) and math.floor(data.resW) or 1024
        local resH = IsNum(data.resH, 1, 4096) and math.floor(data.resH) or 1024
        local fitType = FIT_TYPES[data.fitType] and data.fitType or 'fill'
        local corners = CleanCorners(data.corners)
        if corners == false then return end

        if not admin then
            local count = MySQL.scalar.await('SELECT COUNT(*) FROM pop_boards WHERE owner = ?', { identifier }) or 0
            if count >= MAX_BOARDS_PER_PLAYER then
                TriggerClientEvent('notification:client:ShowNotify', src, {
                    title = "Tableau",
                    message = ("Vous avez déjà posé %d tableaux (maximum)."):format(MAX_BOARDS_PER_PLAYER),
                    duration = 5000
                })
                return
            end
        end

        local pos, normal = CleanVec(data.pos), CleanVec(data.normal)
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
end)

-- Système de synchronisation à la demande (Proximity-based Fetch)
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
    if log.boards[dbId] and now - log.boards[dbId] < REQUEST_COOLDOWN then return end
    if log.n >= REQUEST_MAX_PER_10S or sending[src] then return end
    log.n = log.n + 1
    log.boards[dbId] = now

    local result = MySQL.single.await('SELECT id, url, pos, normal, width, height, resW, resH, fitType, corners FROM pop_boards WHERE id = ?', { dbId })
    if not result then return end

    -- Seulement pour un joueur proche du tableau (comme la boucle de proximité du client)
    local pos = type(result.pos) == 'string' and json.decode(result.pos) or result.pos
    local ped = GetPlayerPed(src)
    if not IsVec(pos) or ped == 0 or #(GetEntityCoords(ped) - vector3(pos.x, pos.y, pos.z)) > 80.0 then return end

    local imageData = result.url or ""
    local totalSize = string.len(imageData)
    local chunkSize = 4000 -- Chunks plus petits (4KB) pour une sécurité absolue

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
        if i % (chunkSize * 8) == 1 then Wait(0) end -- Repos CPU léger
    end
    sending[src] = nil
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
    pendingUploads[src] = nil
    lastSave[src] = nil
    requestLog[src] = nil
    sending[src] = nil
end)

RegisterNetEvent('pop_boards:server:deleteBoard', function(dbId)
    -- Suppression réservée aux administrateurs (événement non utilisé par le client)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or type(dbId) ~= 'number' then return end
    if not IsAdmin(source) then return end
    MySQL.update('DELETE FROM pop_boards WHERE id = ?', { dbId })
    TriggerClientEvent('pop_boards:client:removeBoard', -1, dbId)
end)
