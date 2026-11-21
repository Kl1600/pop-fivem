-- pop_kilometrage : compteur kilométrique par plaque, calculé uniquement côté serveur.

local TICK        = 2000   -- ms : mesure des distances
local SAVE_TICK   = 60000  -- ms : écriture des plaques modifiées
local MAX_SPEED   = 120.0  -- m/s : au-delà, l'échantillon est ignoré (téléportation, fourrière)
local MIN_SAVE_KM = 1.0    -- km minimum pour créer une ligne SQL
local STATE_STEP  = 0.1    -- km : pas du statebag (arrondi au dixième)
local CACHE_TTL   = 600    -- s : durée de vie d'une plaque inutilisée dans le cache
local MAX_KM      = 9999999
local EXCLUDED_TYPES = { heli = true, plane = true, boat = true, submarine = true, train = true }

local STATE_KEY = 'pop_kilometrage'
local RES = GetCurrentResourceName()

local SQL_CREATE = [[
CREATE TABLE IF NOT EXISTS `pop_kilometrage` (
    `plate`      VARCHAR(8)   NOT NULL,
    `km`         DOUBLE       NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`)
)]]
local SQL_SELECT = 'SELECT km FROM pop_kilometrage WHERE plate = ?'
local SQL_UPSERT = 'INSERT INTO pop_kilometrage (plate, km, updated_at) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE km = VALUES(km), updated_at = VALUES(updated_at)'

-- Même règle que pop_vehiclekeys : espaces retirés, majuscules, 1 à 8 caractères alphanumériques.
local Plate = {}
function Plate.Normalize(plate)
    if type(plate) ~= 'string' then return nil end
    plate = (plate:gsub('%s+', '')):upper()
    if plate == '' or #plate > 8 or plate:find('[^%w]') then return nil end
    return plate
end

local Cache = {} -- [plate] = { km, loaded, pending, dirty, row, used }
local Track = {} -- [src] = { veh, plate, pos, t }

local function debug(...)
    if Config.Debug then print(('[%s]'):format(RES), ...) end
end

-- Arrondi au dixième (pas STATE_STEP).
local function round(km)
    return math.floor(km / STATE_STEP + 0.5) * STATE_STEP
end

-- Écrit si la ligne existe déjà, si le seuil MIN_SAVE_KM est atteint ou si l'écriture est forcée.
local function save(plate, entry, force)
    if not entry.loaded or not entry.dirty then return end
    if not (entry.row or entry.km >= MIN_SAVE_KM or force) then return end
    entry.dirty = false
    MySQL.prepare(SQL_UPSERT, { plate, entry.km, os.time() }, function(result)
        if result == nil then
            -- Échec SQL : l'entrée sera réécrite au prochain passage (remise en cache si nettoyée entre-temps).
            entry.dirty = true
            if not Cache[plate] then Cache[plate] = entry end
            print(('[%s] ^1SQL save failed for %s^0'):format(RES, plate))
            return
        end
        entry.row = true
    end)
    debug('saved', plate, entry.km)
end

local function saveAll()
    for plate, entry in pairs(Cache) do save(plate, entry) end
end

-- Crée l'entrée de cache et lance le chargement SQL asynchrone.
local function getEntry(plate)
    local entry = Cache[plate]
    if entry then return entry end
    entry = { km = 0.0, loaded = false, pending = 0.0, dirty = false, row = false, used = os.time() }
    Cache[plate] = entry
    MySQL.scalar(SQL_SELECT, { plate }, function(km)
        if km ~= nil then entry.row = true end
        if entry.loaded then return end -- SetMileage est passé avant la réponse
        entry.km = (tonumber(km) or 0.0) + entry.pending
        entry.pending = 0.0
        entry.loaded = true
    end)
    return entry
end

local function stopTrack(src)
    local track = Track[src]
    if not track then return end
    Track[src] = nil
    local entry = Cache[track.plate]
    if entry then save(track.plate, entry) end
end

local function setState(veh, entry)
    if not DoesEntityExist(veh) then return end
    local value = round(entry.km)
    local state = Entity(veh).state
    -- Comparaison au statebag de l'entité : un véhicule recréé avec la même plaque reçoit sa valeur.
    if state[STATE_KEY] ~= value then
        state:set(STATE_KEY, value, true)
    end
end

local function tickPlayer(src, now)
    local ped = GetPlayerPed(src)
    local veh = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped
        or Entity(veh).state.pop_temporary
        or EXCLUDED_TYPES[GetVehicleType(veh)] then
        return stopTrack(src)
    end
    local plate = Plate.Normalize(GetVehicleNumberPlateText(veh))
    if not plate then return stopTrack(src) end

    local pos = GetEntityCoords(veh)
    local track = Track[src]
    local entry

    if not track or track.veh ~= veh or track.plate ~= plate then
        stopTrack(src)
        Track[src] = { veh = veh, plate = plate, pos = pos, t = now }
        entry = getEntry(plate)
    else
        entry = getEntry(plate)
        local d = #(pos - track.pos)
        local dt = (now - track.t) / 1000
        if dt > 0 and d > 0.5 and d <= MAX_SPEED * dt then
            if entry.loaded then
                entry.km = math.min(entry.km + d / 1000, MAX_KM)
            else
                entry.pending = entry.pending + d / 1000
            end
            entry.dirty = true
        end
        track.pos, track.t = pos, now
    end

    entry.used = os.time()
    if entry.loaded then setState(veh, entry) end
end

CreateThread(function()
    local ok, err = pcall(MySQL.query.await, SQL_CREATE)
    if not ok then
        print(('[%s] ^1CREATE TABLE failed (run sql/install.sql): %s^0'):format(RES, tostring(err)))
    end
    while true do
        Wait(TICK)
        local now = GetGameTimer()
        for _, src in ipairs(Bridge.GetPlayers()) do
            tickPlayer(tonumber(src), now)
        end
    end
end)

-- Écriture groupée et nettoyage du cache.
CreateThread(function()
    while true do
        Wait(SAVE_TICK)
        saveAll()
        local limit = os.time() - CACHE_TTL
        for plate, entry in pairs(Cache) do
            -- Inutilisée : retirée si rien à écrire, ou si elle n'atteindra jamais la base (pas de ligne, < MIN_SAVE_KM).
            if entry.used < limit
                and (not entry.dirty or (not entry.row and entry.km < MIN_SAVE_KM)) then
                Cache[plate] = nil
            end
        end
    end
end)

Bridge.OnPlayerDropped(stopTrack)
Bridge.OnPlayerUnloaded(stopTrack)

AddEventHandler('onResourceStop', function(res)
    if res == RES then saveAll() end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', saveAll)

------------------------------------------------------------------------
-- Exports (serveur uniquement)
------------------------------------------------------------------------

-- Bloquant si la plaque n'est pas en cache : appeler dans un thread.
exports('GetMileage', function(plate)
    plate = Plate.Normalize(plate)
    if not plate then return 0 end
    local entry = Cache[plate]
    if entry and entry.loaded then return round(entry.km) end
    local km = tonumber(MySQL.scalar.await(SQL_SELECT, { plate })) or 0.0
    return round(km + (entry and entry.pending or 0.0))
end)

exports('SetMileage', function(plate, km)
    plate = Plate.Normalize(plate)
    km = tonumber(km)
    -- km ~= km : rejette NaN ; la borne haute rejette l'infini.
    if not plate or not km or km ~= km or km < 0 or km > MAX_KM then return false end

    local entry = getEntry(plate)
    entry.km, entry.pending, entry.loaded, entry.dirty = km + 0.0, 0.0, true, true
    entry.used = os.time()
    save(plate, entry, true)

    for _, track in pairs(Track) do
        if track.plate == plate then setState(track.veh, entry) end
    end
    debug('SetMileage', plate, km)
    return true
end)
