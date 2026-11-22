-- pop_vehiclepersistence — serveur : état partagé et fonctions communes (chargé en premier).
-- Portage Lua du serveur C# d'origine (Server.cs) : même logique (grille spatiale,
-- spawn/despawn autour des joueurs, auto-save, expiration), sans DLL à compiler.

Persist = {}
local P = Persist

P.CULL_RADIUS        = tonumber(Config.CullRadius) or 250.0
P.CULL_RADIUS_SQ     = P.CULL_RADIUS * P.CULL_RADIUS
P.DESPAWN_RADIUS_SQ  = (P.CULL_RADIUS + 50.0) * (P.CULL_RADIUS + 50.0)
P.CULL_INTERVAL_MS   = 2000
P.CULL_CREATE_BUDGET = 10
P.RESPAWN_RESEND_MS  = 10000
P.GRID_SIZE          = 300.0
P.MAX_CLIENT_DIST    = tonumber(Config.MaxClientDistance) or 75.0 -- distance max joueur <-> données véhicule envoyées
P.DAY                = 86400

local floor = math.floor
local GRID_SIZE, MAX_CLIENT_DIST = P.GRID_SIZE, P.MAX_CLIENT_DIST

-- ── État ─────────────────────────────────────────────────────────────────────
-- Les tables ne sont jamais remplacées (seulement vidées) : les autres fichiers en gardent la référence.
P.allVehicles   = {}  -- [plate] = vData
P.spawnedPlates = {}  -- [plate] = pid
P.lastSnapshots = {}  -- [plate] = { x, y, z, fuel, bodyHealth, engineHealth }
P.originalOwner = {}  -- [plate] = owner_id
P.lastSeen      = {}  -- [plate] = unix
P.lastRespawn   = {}  -- [plate] = GetGameTimer()
P.current       = {}  -- [pid] = { identifier, vehicles = {[plate]=vData}, active }
P.requested     = {}  -- [pid] = true (anti-spam requestSavedVehicle)
P.grid          = {}  -- ["cx:cy"] = { [plate] = vData }
P.vehicleCell   = {}  -- [plate] = "cx:cy"
P.forgotten     = {}  -- [plate] = os.time() d'expiration
P.ready         = false

local current, grid, vehicleCell, forgotten = P.current, P.grid, P.vehicleCell, P.forgotten

function P.Debug(msg, ...)
    if Config.Debug then print(('[Persistence] ' .. msg):format(...)) end
end

function P.maxDays() return tonumber(Config.MaxPersistenceDays) or 30 end

local function normalPlate(plate)
    return string.upper(string.gsub(tostring(plate or ''), '%s+', ''))
end
P.normalPlate = normalPlate

local function num(v) return tonumber(v) or 0.0 end
P.num = num

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
P.gridRemove, P.gridUpdate = gridRemove, gridUpdate

local function isDriven(plate)
    for _, e in pairs(current) do
        if e.active == plate then return true end
    end
    return false
end
P.isDriven = isDriven

-- ── Validation des données client ────────────────────────────────────────────
-- Plaques retirées volontairement (rangement garage, export Forget) : on ignore
-- pendant un moment les dernières données envoyées par le client pour cette plaque.
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
P.isForgotten, P.sanitize, P.isNearPlayer = isForgotten, sanitize, isNearPlayer

