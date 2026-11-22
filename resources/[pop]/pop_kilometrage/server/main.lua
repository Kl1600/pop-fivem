-- pop_kilometrage — serveur
-- Sauvegarde le kilometrage de chaque vehicule (par plaque) en base de donnees.
-- Les mises a jour sont mises en tampon et ecrites en une seule requete groupee.

local FLUSH_INTERVAL = tonumber(Config.FlushInterval) or 60000 -- ms entre deux ecritures groupees
local MAX_STEP_KM    = tonumber(Config.MaxStepKm) or 10.0      -- saut maximal accepte entre deux mises a jour

local pending = {}  -- [plate] = mileage a ecrire
local known   = {}  -- [plate] = dernier kilometrage connu (anti-triche)
local loading = {}  -- [plate] = true pendant la lecture en base
local lastAsk = {}  -- [src] = GetGameTimer() de la derniere demande
local ASK_COOLDOWN_MS = 1000

local function normalPlate(plate)
    return string.upper(string.gsub(tostring(plate or ''), '%s+', ''))
end

local function flush()
    local params, rows = {}, 0
    for plate, mileage in pairs(pending) do
        params[#params + 1] = plate
        params[#params + 1] = mileage
        rows = rows + 1
    end
    if rows == 0 then return end
    pending = {}
    local query = 'INSERT INTO vehicle_mileage (plate, mileage) VALUES '
        .. string.rep('(?, ?)', rows, ', ')
        .. ' ON DUPLICATE KEY UPDATE mileage = VALUES(mileage)'
    MySQL.update(query, params)
end

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS vehicle_mileage (
            plate   VARCHAR(12) NOT NULL PRIMARY KEY,
            mileage FLOAT NOT NULL DEFAULT 0
        )
    ]])
    while true do
        Wait(FLUSH_INTERVAL)
        flush()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then flush() end
end)

-- Redémarrage / arrêt par txAdmin : écriture avant l'arrêt, quand la base répond encore.
AddEventHandler('txAdmin:events:serverShuttingDown', flush)

AddEventHandler('playerDropped', function() lastAsk[source] = nil end)

RegisterNetEvent('pop_kilometrage:server:requestMileage', function(plate)
    local src = source
    plate = normalPlate(plate)
    if plate == '' or #plate > 12 then return end
    -- Limite : une demande par seconde et par joueur
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < ASK_COOLDOWN_MS then return end
    lastAsk[src] = now

    if pending[plate] then
        TriggerClientEvent('pop_kilometrage:client:receiveMileage', src, plate, pending[plate])
        return
    end
    MySQL.scalar('SELECT mileage FROM vehicle_mileage WHERE plate = ?', { plate }, function(mileage)
        if known[plate] == nil then known[plate] = tonumber(mileage) or 0 end
        TriggerClientEvent('pop_kilometrage:client:receiveMileage', src, plate, known[plate])
    end)
end)

-- Applique une valeur apres verification (le kilometrage connu vient toujours de la base)
local function applyMileage(plate, mileage)
    local prev = known[plate] or 0
    -- Le kilometrage ne peut qu'augmenter, et par pas raisonnables.
    if mileage < prev - 0.01 or mileage - prev > MAX_STEP_KM then return end
    known[plate]   = mileage
    pending[plate] = mileage
end

RegisterNetEvent('pop_kilometrage:server:updateMileage', function(plate, mileage)
    local src = source
    plate = normalPlate(plate)
    mileage = tonumber(mileage)
    if plate == '' or not mileage or mileage ~= mileage or mileage < 0 or mileage > 1e7 then return end

    -- Le joueur doit conduire un vehicule portant cette plaque.
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 or normalPlate(GetVehicleNumberPlateText(veh)) ~= plate then return end

    if known[plate] ~= nil then
        applyMileage(plate, mileage)
        return
    end
    -- Premiere valeur : on lit d'abord la base (plus de valeur acceptee les yeux fermes)
    if loading[plate] then return end
    loading[plate] = true
    MySQL.scalar('SELECT mileage FROM vehicle_mileage WHERE plate = ?', { plate }, function(dbMileage)
        loading[plate] = nil
        if known[plate] == nil then known[plate] = tonumber(dbMileage) or 0 end
        applyMileage(plate, mileage)
    end)
end)

--------------------
-- EXPORT SERVEUR --
--------------------

---@param plate string
---@param cb fun(mileage: number)
exports('GetMileage', function(plate, cb)
    plate = normalPlate(plate)
    if pending[plate] then return cb(pending[plate]) end
    MySQL.scalar('SELECT mileage FROM vehicle_mileage WHERE plate = ?', { plate }, function(mileage)
        cb(mileage or 0)
    end)
end)
