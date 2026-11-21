-- pop_kilometrage — serveur
-- Sauvegarde le kilometrage de chaque vehicule (par plaque) en base de donnees.
-- Les mises a jour sont mises en tampon et ecrites en une seule requete groupee.

local FLUSH_INTERVAL = 60000 -- ms entre deux ecritures groupees
local MAX_STEP_KM    = 10.0  -- saut maximal accepte entre deux mises a jour

local pending = {}  -- [plate] = mileage a ecrire
local known   = {}  -- [plate] = dernier kilometrage connu (anti-triche)

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
    exports.oxmysql:execute(query, params)
end

CreateThread(function()
    exports.oxmysql:execute([[
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

RegisterNetEvent('pop_kilometrage:server:requestMileage', function(plate)
    local src = source
    plate = normalPlate(plate)

    if pending[plate] then
        TriggerClientEvent('pop_kilometrage:client:receiveMileage', src, plate, pending[plate])
        return
    end
    exports.oxmysql:scalar('SELECT mileage FROM vehicle_mileage WHERE plate = ?', { plate }, function(mileage)
        known[plate] = mileage or 0
        TriggerClientEvent('pop_kilometrage:client:receiveMileage', src, plate, mileage or 0)
    end)
end)

RegisterNetEvent('pop_kilometrage:server:updateMileage', function(plate, mileage)
    local src = source
    plate = normalPlate(plate)
    mileage = tonumber(mileage)
    if plate == '' or not mileage or mileage ~= mileage or mileage < 0 or mileage > 1e7 then return end

    -- Le joueur doit conduire un vehicule portant cette plaque.
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 or normalPlate(GetVehicleNumberPlateText(veh)) ~= plate then return end

    -- Le kilometrage ne peut qu'augmenter, et par pas raisonnables.
    local prev = known[plate]
    if prev and (mileage < prev - 0.01 or mileage - prev > MAX_STEP_KM) then return end

    known[plate]   = mileage
    pending[plate] = mileage
end)

--------------------
-- EXPORT SERVEUR --
--------------------

---@param plate string
---@param cb fun(mileage: number)
exports('GetMileage', function(plate, cb)
    plate = normalPlate(plate)
    if pending[plate] then return cb(pending[plate]) end
    exports.oxmysql:scalar('SELECT mileage FROM vehicle_mileage WHERE plate = ?', { plate }, function(mileage)
        cb(mileage or 0)
    end)
end)
