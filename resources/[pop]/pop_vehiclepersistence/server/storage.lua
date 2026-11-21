-- pop_vehiclepersistence — serveur : sauvegarde en base, chargement, oubli (export Forget) et expiration.

local P = Persist
local allVehicles, spawnedPlates, lastSnapshots = P.allVehicles, P.spawnedPlates, P.lastSnapshots
local originalOwner, lastSeen, lastRespawn, current = P.originalOwner, P.lastSeen, P.lastRespawn, P.current
local normalPlate, num, gridUpdate, gridRemove = P.normalPlate, P.num, P.gridUpdate, P.gridRemove
local isForgotten, isDriven, maxDays = P.isForgotten, P.isDriven, P.maxDays
local forgotten, DAY = P.forgotten, P.DAY

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

    MySQL.update(
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
    MySQL.update('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
    return true
end
exports('Forget', Forget)
exports('IsTracked', function(plate) return allVehicles[normalPlate(plate)] ~= nil end)

-- ── Base de données ──────────────────────────────────────────────────────────
local function loadAll()
    MySQL.query('SELECT plate, owner_id, vehicle_data, last_seen FROM persistent_vehicles', {}, function(rows)
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
            MySQL.update('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
        end
        P.Debug('%d véhicule(s) chargé(s), %d expiré(s) supprimé(s).', count, #expired)
        P.ready = true
    end)
end

local function initDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS persistent_vehicles (
            plate        VARCHAR(64)  NOT NULL,
            owner_id     VARCHAR(250),
            vehicle_data LONGTEXT,
            last_seen    BIGINT       NOT NULL DEFAULT 0,
            PRIMARY KEY (plate),
            INDEX idx_owner (owner_id)
        )
    ]], {}, function()
        MySQL.scalar([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'persistent_vehicles' AND COLUMN_NAME = 'last_seen'
        ]], {}, function(c)
            if (tonumber(c) or 0) > 0 then
                loadAll()
            else
                MySQL.query('ALTER TABLE persistent_vehicles ADD COLUMN last_seen BIGINT NOT NULL DEFAULT 0', {}, loadAll)
            end
        end)
    end)
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
        MySQL.update('DELETE FROM persistent_vehicles WHERE plate = ?', { plate })
    end
    if #toRemove > 0 then
        P.Debug('Purge : %d véhicule(s) expiré(s) supprimé(s).', #toRemove)
    end
end

P.snapshot, P.needsSave, P.saveVehicle, P.saveAllFor = snapshot, needsSave, saveVehicle, saveAllFor
P.forget, P.findEntityByPlate, P.initDatabase, P.purgeExpired = forget, findEntityByPlate, initDatabase, purgeExpired
