-- pop_vehiclepersistence — serveur
-- Portage Lua du serveur C# d'origine (Server.cs) : même logique (grille spatiale,
-- spawn/despawn autour des joueurs, auto-save, expiration), sans DLL à compiler.
-- Les options viennent de config.lua (Config.*), partagé avec bridge.lua.

local CULL_RADIUS        = 250.0
local CULL_RADIUS_SQ     = CULL_RADIUS * CULL_RADIUS
local DESPAWN_RADIUS_SQ  = (CULL_RADIUS + 50.0) * (CULL_RADIUS + 50.0)
local CULL_INTERVAL_MS   = 2000
local CULL_CREATE_BUDGET = 10
local RESPAWN_RESEND_MS  = 10000
local GRID_SIZE          = 300.0
local MAX_CLIENT_DIST    = 75.0 -- distance max joueur <-> données véhicule envoyées

local floor, DAY = math.floor, 86400

-- ── État ─────────────────────────────────────────────────────────────────────
local allVehicles   = {}  -- [plate] = vData
local spawnedPlates = {}  -- [plate] = pid
local lastSnapshots = {}  -- [plate] = { x, y, z, fuel, bodyHealth, engineHealth }
local originalOwner = {}  -- [plate] = owner_id
local lastSeen      = {}  -- [plate] = unix
local lastRespawn   = {}  -- [plate] = GetGameTimer()
local current       = {}  -- [pid] = { identifier, vehicles = {[plate]=vData}, active }
local requested     = {}  -- [pid] = true (anti-spam requestSavedVehicle)
local grid          = {}  -- ["cx:cy"] = { [plate] = vData }
local vehicleCell   = {}  -- [plate] = "cx:cy"
local ready         = false

local function maxDays() return tonumber(Config.MaxPersistenceDays) or 30 end

local function normalPlate(plate)
    return string.upper(string.gsub(tostring(plate or ''), '%s+', ''))
end

local function num(v) return tonumber(v) or 0.0 end

local function cellKey(x, y)
    return floor(num(x) / GRID_SIZE) .. ':' .. floor(num(y) / GRID_SIZE)
end

-- ── Grille spatiale ──────────────────────────────────────────────────────────
local function gridRemove(plate)
    local key = vehicleCell[plate]
    if not key then return end
    local cell = grid[key]
    if cell then
        cell[plate] = nil
        if next(cell) == nil then grid[key] = nil end
    end
    vehicleCell[plate] = nil
end

local function gridUpdate(plate, v)
    if not v then return end
    local key = cellKey(v.x, v.y)
    if vehicleCell[plate] ~= key then gridRemove(plate) end
    local cell = grid[key]
    if not cell then cell = {}; grid[key] = cell end
    cell[plate] = v
    vehicleCell[plate] = key
end

local function isDriven(plate)
    for _, e in pairs(current) do
        if e.active == plate then return true end
    end
    return false
end

-- ── Validation des données client ────────────────────────────────────────────
-- Plaques retirées volontairement (rangement garage, export Forget) : on ignore
-- pendant un moment les dernières données envoyées par le client pour cette plaque.
local forgotten = {}  -- [plate] = os.time() d'expiration
local function isForgotten(plate)
    local t = forgotten[plate]
    if not t then return false end
    if os.time() > t then forgotten[plate] = nil return false end
    return true
end

local function clamp(x, a, b) x = tonumber(x) or a; if x ~= x then return a end; return math.max(a, math.min(b, x)) end

-- Nettoyage récursif : nombres finis et bornés, chaînes courtes, profondeur et taille limitées.
local function cleanValue(val, depth, budget)
    local t = type(val)
    if t == 'number' then
        if val ~= val or val == math.huge or val == -math.huge then return nil end
        return math.max(-100000, math.min(100000, val))
    elseif t == 'boolean' then
        return val
    elseif t == 'string' then
        return val:sub(1, 64)
    elseif t == 'table' then
        if depth >= 4 then return nil end
        local out = {}
        for k, sub in pairs(val) do
            budget.n = budget.n - 1
            if budget.n < 0 then break end
            local key = type(k) == 'number' and k or tostring(k):sub(1, 32)
            local c = cleanValue(sub, depth + 1, budget)
            if c ~= nil then out[key] = c end
        end
        return out
    end
    return nil
end

-- Le véhicule doit exister côté serveur (netId), avoir le même modèle et la même plaque.
-- La position vient de l'entité serveur, pas du client.
local function sanitize(v)
    if type(v) ~= 'table' or type(v.plate) ~= 'string' or #v.plate > 12 then return nil end
    if not tonumber(v.model) or not tonumber(v.netId) then return nil end

    local entity = NetworkGetEntityFromNetworkId(tonumber(v.netId))
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return nil end
    -- Hash signé (client) ou non signé (serveur) : on compare modulo 2^32
    if math.tointeger(GetEntityModel(entity) % 4294967296) ~= math.tointeger(math.floor(tonumber(v.model)) % 4294967296) then return nil end
    if normalPlate(GetVehicleNumberPlateText(entity)) ~= normalPlate(v.plate) then return nil end

    local model = math.tointeger(math.floor(tonumber(v.model)))
    v = cleanValue(v, 0, { n = 600 })
    if not v then return nil end
    v.model = model -- le hash dépasse les bornes du nettoyage
    v.netId = nil

    local pos = GetEntityCoords(entity)
    v.x, v.y, v.z = pos.x, pos.y, pos.z
    v.heading = GetEntityHeading(entity)

    if v.fuel ~= nil then v.fuel = clamp(v.fuel, 0.0, 100.0) end
    if v.fuelLevel ~= nil then v.fuelLevel = clamp(v.fuelLevel, 0.0, 100.0) end
    if v.bodyHealth ~= nil then v.bodyHealth = clamp(v.bodyHealth, 0.0, 1000.0) end
    if v.engineHealth ~= nil then v.engineHealth = clamp(v.engineHealth, -4000.0, 1000.0) end
    if v.tankHealth ~= nil then v.tankHealth = clamp(v.tankHealth, -1000.0, 1000.0) end
    if v.health ~= nil then v.health = clamp(v.health, 0.0, 1000.0) end

    -- Clés numériques creuses -> chaînes (encodage JSON sûr ; le client fait tonumber()).
    if type(v.tyres) == 'table' then
        local t = {}
        for k, b in pairs(v.tyres) do
            local idx = tonumber(k)
            if idx and idx >= 0 and idx <= 7 and b then t[tostring(idx)] = true end
        end
        v.tyres = t
    end
    return v
end

local function isNearPlayer(src, v)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(num(v.x), num(v.y), num(v.z))) <= MAX_CLIENT_DIST
end

local function getIdentifier(pid)
    local ok, id = pcall(Bridge.GetIdentifier, pid)
    return ok and id or nil
end

local function hasKey(pid, plate)
    local ok, res = pcall(Bridge.PlayerHasKeyCached, pid, plate)
    if not ok then return true end
    return res == true
end

-- ── Sauvegarde ───────────────────────────────────────────────────────────────
local function snapshot(v)
    return {
        x = num(v.x), y = num(v.y), z = num(v.z),
        fuel = num(v.fuel or v.fuelLevel),
        bodyHealth = num(v.bodyHealth), engineHealth = num(v.engineHealth),
    }
end

local function needsSave(v)
    if not v or not v.plate then return false end
    local last = lastSnapshots[normalPlate(v.plate)]
    if not last then return true end
    local s = snapshot(v)
    return math.abs(s.x - last.x) > 0.5 or math.abs(s.y - last.y) > 0.5 or math.abs(s.z - last.z) > 0.5
        or math.abs(s.fuel - last.fuel) > 0.01 or math.abs(s.bodyHealth - last.bodyHealth) > 0.01
        or math.abs(s.engineHealth - last.engineHealth) > 0.01
end

local function bumpLastSeen(plate, touch)
    if touch or not lastSeen[plate] then lastSeen[plate] = os.time() end
    return lastSeen[plate]
end

local function saveVehicle(identifier, v, touch)
    if not v or not v.plate then return end
    if touch == nil then touch = true end
    local plate = normalPlate(v.plate)
    if isForgotten(plate) then return end

    local owner = originalOwner[plate] or identifier
    originalOwner[plate] = owner
    allVehicles[plate] = v
    local seen = bumpLastSeen(plate, touch)
    gridUpdate(plate, v)

    exports.oxmysql:execute(
        'REPLACE INTO persistent_vehicles (plate, owner_id, vehicle_data, last_seen) VALUES (?, ?, ?, ?)',
        { plate, owner, json.encode(v), seen },
        function()
            lastSnapshots[plate] = snapshot(v)
        end
    )
end

local function saveAllFor(entry, touch)
    if not entry or not entry.identifier then return end
    for _, v in pairs(entry.vehicles) do saveVehicle(entry.identifier, v, touch) end
end

local function forget(plate)
    allVehicles[plate], originalOwner[plate], spawnedPlates[plate] = nil, nil, nil
    lastSnapshots[plate], lastSeen[plate], lastRespawn[plate] = nil, nil, nil
    gridRemove(plate)
end

-- Recherche l'entité réseau d'une plaque (coûteux : usage ponctuel seulement)
local function findEntityByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and normalPlate(GetVehicleNumberPlateText(veh)) == plate then
            return veh
        end
    end
    return nil
end

-- Export : retire définitivement une plaque de la persistance (mémoire + base).
-- Utilisé par pop_enterprisegarage au rangement.
local function Forget(plate)
    plate = normalPlate(plate)
    if plate == '' then return false end
    forgotten[plate] = os.time() + 120
    local claimer = spawnedPlates[plate]
    if claimer and GetPlayerName(claimer) then
        TriggerClientEvent('pop_vehiclepersistence:despawnVehicle', claimer, plate)
    end
    for _, e in pairs(current) do
        if e.vehicles then e.vehicles[plate] = nil end
        if e.active == plate then e.active = nil end
    end
    forget(plate)
    exports.oxmysql:execute('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
    return true
end
exports('Forget', Forget)
exports('IsTracked', function(plate) return allVehicles[normalPlate(plate)] ~= nil end)

-- ── Base de données ──────────────────────────────────────────────────────────
local function loadAll()
    exports.oxmysql:query('SELECT plate, owner_id, vehicle_data, last_seen FROM persistent_vehicles', {}, function(rows)
        rows = rows or {}
        local days, now = maxDays(), os.time()
        local cutoff = days > 0 and (now - days * DAY) or 0
        local count, expired = 0, {}
        for _, row in ipairs(rows) do
            local ok, v = pcall(json.decode, row.vehicle_data or '')
            if ok and type(v) == 'table' and v.plate then
                local plate = normalPlate(v.plate)
                local seen = tonumber(row.last_seen) or 0
                if seen == 0 then seen = now end
                if days > 0 and seen < cutoff then
                    expired[#expired + 1] = plate
                else
                    allVehicles[plate] = v
                    originalOwner[plate] = row.owner_id
                    lastSeen[plate] = seen
                    gridUpdate(plate, v)
                    count = count + 1
                end
            end
        end
        for _, plate in ipairs(expired) do
            exports.oxmysql:execute('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
        end
        print(('[Persistence] %d véhicule(s) chargé(s), %d expiré(s) supprimé(s).'):format(count, #expired))
        ready = true
    end)
end

local function initDatabase()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS persistent_vehicles (
            plate        VARCHAR(64)  NOT NULL,
            owner_id     VARCHAR(250),
            vehicle_data LONGTEXT,
            last_seen    BIGINT       NOT NULL DEFAULT 0,
            PRIMARY KEY (plate),
            INDEX idx_owner (owner_id)
        )
    ]], {}, function()
        exports.oxmysql:scalar([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'persistent_vehicles' AND COLUMN_NAME = 'last_seen'
        ]], {}, function(c)
            if (tonumber(c) or 0) > 0 then
                loadAll()
            else
                exports.oxmysql:execute('ALTER TABLE persistent_vehicles ADD COLUMN last_seen BIGINT NOT NULL DEFAULT 0', {}, loadAll)
            end
        end)
    end)
end

-- ── Boucle spatiale (toutes les 2 s) ─────────────────────────────────────────
local function spatialTick()
    local players, cells = {}, {}
    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            local pos = GetEntityCoords(ped)
            if pos.x ~= 0.0 or pos.y ~= 0.0 then
                players[#players + 1] = { pid = pid, pos = pos }
                local cx, cy = floor(pos.x / GRID_SIZE), floor(pos.y / GRID_SIZE)
                for dx = -1, 1 do
                    for dy = -1, 1 do cells[(cx + dx) .. ':' .. (cy + dy)] = true end
                end
            end
        end
    end

    if #players == 0 then
        spawnedPlates = {}
        return
    end

    local candidates = {}
    for key in pairs(cells) do
        local cell = grid[key]
        if cell then
            for plate, v in pairs(cell) do
                local vx, vy, vz = num(v.x), num(v.y), num(v.z)
                local best, bestPid = math.huge, nil
                for i = 1, #players do
                    local p = players[i].pos
                    local dx, dy, dz = p.x - vx, p.y - vy, p.z - vz
                    local d = dx * dx + dy * dy + dz * dz
                    if d < best then best, bestPid = d, players[i].pid end
                end
                if bestPid and best < DESPAWN_RADIUS_SQ then
                    candidates[plate] = { v = v, pid = bestPid, d = best }
                end
            end
        end
    end

    local budget, now = CULL_CREATE_BUDGET, GetGameTimer()
    for plate, c in pairs(candidates) do
        local claimer = spawnedPlates[plate]
        if claimer then
            if c.d < CULL_RADIUS_SQ and not isDriven(plate)
                and (not lastRespawn[plate] or now - lastRespawn[plate] > RESPAWN_RESEND_MS) then
                if GetPlayerName(claimer) then
                    TriggerClientEvent('respawnPlayerInVehicle', claimer, c.v, false)
                end
                lastRespawn[plate] = now
            end
        elseif c.d < CULL_RADIUS_SQ and budget > 0 then
            spawnedPlates[plate] = c.pid
            TriggerClientEvent('respawnPlayerInVehicle', c.pid, c.v, false)
            lastRespawn[plate] = now
            budget = budget - 1
        end
    end

    for plate, claimer in pairs(spawnedPlates) do
        if not candidates[plate] and not isDriven(plate) then
            spawnedPlates[plate] = nil
            lastRespawn[plate] = nil
            if GetPlayerName(claimer) then
                TriggerClientEvent('pop_vehiclepersistence:despawnVehicle', claimer, plate)
            end
        end
    end
end

local function purgeExpired()
    local days = maxDays()
    if days <= 0 then return end
    local now = os.time()
    local cutoff = now - days * DAY
    local toRemove = {}
    for plate in pairs(allVehicles) do
        local ls = lastSeen[plate]
        if not ls then
            lastSeen[plate] = now
        elseif ls < cutoff and not isDriven(plate) then
            toRemove[#toRemove + 1] = plate
        end
    end
    for _, plate in ipairs(toRemove) do
        local claimer = spawnedPlates[plate]
        if claimer and GetPlayerName(claimer) then
            TriggerClientEvent('pop_vehiclepersistence:despawnVehicle', claimer, plate)
        end
        forget(plate)
        exports.oxmysql:execute('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
    end
    if #toRemove > 0 then
        print(('[Persistence] Purge : %d véhicule(s) expiré(s) supprimé(s).'):format(#toRemove))
    end
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(500) end
    Wait(1000)
    initDatabase()

    -- Boucle spatiale
    CreateThread(function()
        while true do
            Wait(CULL_INTERVAL_MS)
            if ready then spatialTick() end
        end
    end)

    -- Auto-save (60 s, uniquement les véhicules modifiés, écritures espacées)
    CreateThread(function()
        while true do
            Wait(60000)
            local queue = {}
            for _, e in pairs(current) do
                if e.identifier then
                    for plate, v in pairs(e.vehicles) do
                        -- Seul le véhicule conduit compte comme une interaction
                        queue[#queue + 1] = { e.identifier, v, e.active == plate }
                    end
                end
            end
            for i = 1, #queue do
                if needsSave(queue[i][2]) then
                    saveVehicle(queue[i][1], queue[i][2], queue[i][3])
                    Wait(500)
                end
            end
        end
    end)

    -- Expiration (horaire)
    CreateThread(function()
        while true do
            Wait(3600000)
            purgeExpired()
        end
    end)
end)

-- ── Événements ───────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local pid = source
    local claimed = {}
    for plate, claimer in pairs(spawnedPlates) do
        if claimer == pid then claimed[#claimed + 1] = plate end
    end
    -- Anti-doublon : si l'entité a migré vers un autre joueur, il devient le détenteur ;
    -- sinon la plaque est libérée et la boucle spatiale la refera apparaître.
    if #claimed > 0 then
        SetTimeout(3000, function()
            for _, plate in ipairs(claimed) do
                if spawnedPlates[plate] == pid then
                    local ent = findEntityByPlate(plate)
                    local owner = ent and NetworkGetEntityOwner(ent) or nil
                    if owner and owner > 0 and GetPlayerName(owner) then
                        spawnedPlates[plate] = owner
                    else
                        spawnedPlates[plate] = nil
                    end
                end
            end
        end)
    end
    local entry = current[pid]
    if entry then
        saveAllFor(entry, false)
        current[pid] = nil
    end
    requested[pid] = nil
end)

local function track(pid, plate, v)
    if isForgotten(plate) then return end
    spawnedPlates[plate] = pid
    allVehicles[plate] = v
    gridUpdate(plate, v)
end

RegisterNetEvent('saveVehicleToDatabase', function(v)
    local pid = source
    v = sanitize(v)
    if not v or not isNearPlayer(pid, v) then return end
    local plate = normalPlate(v.plate)
    if isForgotten(plate) or not hasKey(pid, plate) then return end
    local id = getIdentifier(pid)
    if not id then return end

    saveVehicle(id, v)
    local entry = current[pid]
    if not entry then
        entry = { identifier = id, vehicles = {} }
        current[pid] = entry
    end
    entry.vehicles[plate] = v
    entry.active = plate
    spawnedPlates[plate] = pid
end)

RegisterNetEvent('CurrentVehicle', function(v)
    local pid = source
    local entry = current[pid]

    if v == nil then
        if entry and entry.active then
            local data = entry.vehicles[entry.active]
            if data then saveVehicle(entry.identifier, data) end
            entry.active = nil
        end
        return
    end

    v = sanitize(v)
    if not v or not isNearPlayer(pid, v) then return end
    local plate = normalPlate(v.plate)
    if isForgotten(plate) then return end

    if entry then
        local old = entry.active
        if old == plate then
            entry.vehicles[plate] = v
            allVehicles[plate] = v
            gridUpdate(plate, v)
            -- Écriture SQL seulement si l'état a réellement changé.
            if needsSave(v) then saveVehicle(entry.identifier, v) end
            return
        end
        if old and entry.vehicles[old] then saveVehicle(entry.identifier, entry.vehicles[old]) end
        if entry.vehicles[plate] or hasKey(pid, plate) then
            entry.vehicles[plate] = v
            entry.active = plate
            track(pid, plate, v)
        else
            entry.active = nil
        end
    elseif hasKey(pid, plate) then
        local id = getIdentifier(pid)
        if id then
            current[pid] = { identifier = id, vehicles = { [plate] = v }, active = plate }
            track(pid, plate, v)
        end
    end
end)

-- Le joueur doit être près du véhicule connu, et ne pas voler la plaque d'un autre détenteur en ligne.
local function canClaim(src, plate)
    local v = allVehicles[plate]
    if not v or isForgotten(plate) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local dist = #(GetEntityCoords(ped) - vector3(num(v.x), num(v.y), num(v.z)))
    if dist > CULL_RADIUS + 100.0 then return false end
    local claimer = spawnedPlates[plate]
    return not claimer or claimer == src or not GetPlayerName(claimer)
end

RegisterNetEvent('pop_vehiclepersistence:vehicleSpawned', function(plate)
    local src = source
    plate = normalPlate(plate)
    if canClaim(src, plate) then spawnedPlates[plate] = src end
end)

RegisterNetEvent('pop_vehiclepersistence:despawnFailed', function(plate)
    local src = source
    plate = normalPlate(plate)
    if canClaim(src, plate) then spawnedPlates[plate] = src end
end)

-- Liste complète / stats : outil de debug (/showvehicles), réservé aux admins (ace 'command').
RegisterNetEvent('pop_vehiclepersistence:requestAllVehicles', function()
    local pid = source
    if not IsPlayerAceAllowed(pid, 'command') then return end
    local list, days, now = {}, maxDays(), os.time()
    for plate, v in pairs(allVehicles) do
        local expiresIn = nil
        if days > 0 then
            local ls = lastSeen[plate] or now
            expiresIn = math.max(0, floor((ls + days * DAY - now) / DAY))
        end
        list[#list + 1] = {
            plate = plate, x = num(v.x), y = num(v.y), z = num(v.z),
            model = tonumber(v.model) or 0, active = spawnedPlates[plate] ~= nil, expiresIn = expiresIn,
        }
    end
    TriggerClientEvent('pop_vehiclepersistence:receiveAllVehicles', pid, list)
end)

RegisterNetEvent('pop_vehiclepersistence:requestStats', function()
    local pid = source
    if not IsPlayerAceAllowed(pid, 'command') then return end
    local total, driven, seen, spawned = 0, 0, {}, 0
    for _ in pairs(allVehicles) do total = total + 1 end
    for _ in pairs(spawnedPlates) do spawned = spawned + 1 end
    for _, e in pairs(current) do
        if e.active and not seen[e.active] then seen[e.active] = true; driven = driven + 1 end
    end
    local owned, id = 0, getIdentifier(pid)
    if id then
        for _, o in pairs(originalOwner) do if o == id then owned = owned + 1 end end
    end
    TriggerClientEvent('pop_vehiclepersistence:receiveStats', pid, {
        total = total, driven = driven, spawnedServer = spawned, placeholders = 0,
        owned = owned, onlinePlayers = #GetPlayers(), cullRadius = CULL_RADIUS,
        promoteRadius = 30.0, autoSave = 1, maxPersistenceDays = maxDays(),
    })
end)

RegisterNetEvent('requestSavedVehicle', function()
    local pid = source
    if requested[pid] then return end
    requested[pid] = true
    local id = getIdentifier(pid)
    if not id then return end

    exports.oxmysql:query('SELECT vehicle_data, last_seen FROM persistent_vehicles WHERE owner_id = ?', { id }, function(rows)
        if not rows or #rows == 0 then return end
        current[pid] = current[pid] or { identifier = id, vehicles = {} }
        local days, now = maxDays(), os.time()
        local ped = GetPlayerPed(pid)
        local ppos = ped ~= 0 and GetEntityCoords(ped) or nil
        local cutoff = days > 0 and (now - days * DAY) or 0

        -- Spawn séquentiel (500 ms entre chaque) pour ne pas inonder le client.
        CreateThread(function()
            for i, row in ipairs(rows) do
                if not GetPlayerName(pid) or not current[pid] then return end
                local ok, v = pcall(json.decode, row.vehicle_data or '')
                if ok and type(v) == 'table' and v.plate then
                    local plate = normalPlate(v.plate)
                    local seen = tonumber(row.last_seen) or 0
                    if seen == 0 then seen = now end
                    if (days <= 0 or seen >= cutoff) and not isForgotten(plate) then
                        lastSeen[plate] = seen
                        allVehicles[plate] = v
                        originalOwner[plate] = id
                        current[pid].vehicles[plate] = v
                        gridUpdate(plate, v)
                        -- La connexion n'est pas une interaction : pas de sauvegarde (ni last_seen) ensuite.
                        lastSnapshots[plate] = snapshot(v)

                        -- Seulement les véhicules proches ; les autres apparaîtront via la boucle
                        -- spatiale quand un joueur s'en approchera (plus de véhicules partout).
                        local near = ppos and #(ppos - vector3(num(v.x), num(v.y), num(v.z))) < CULL_RADIUS
                        local claimer = spawnedPlates[plate]
                        if near and not (claimer and GetPlayerName(claimer)) then
                            spawnedPlates[plate] = pid
                            TriggerClientEvent('respawnPlayerInVehicle', pid, v, i == #rows)
                        end
                    end
                end
                Wait(500)
            end
        end)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(current) do saveAllFor(e, false) end
end)

-- Commande console (debug) : état de la persistance.
RegisterCommand('debug_persistence', function(src)
    if src ~= 0 then
        local e = current[src]
        local msg = 'Aucun véhicule traqué.'
        if e then
            local n = 0
            for _ in pairs(e.vehicles) do n = n + 1 end
            msg = ('Traqués: %d | Actif: %s'):format(n, e.active or 'aucun')
        end
        TriggerClientEvent('pop_vehiclepersistence:notify', src, msg)
        return
    end
    local total, spawned = 0, 0
    for _ in pairs(allVehicles) do total = total + 1 end
    for _ in pairs(spawnedPlates) do spawned = spawned + 1 end
    print(('[Persistence] DB:%d  RealSpawned:%d'):format(total, spawned))
end, true)
