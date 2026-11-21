-- pop_inventory : coffre et boîte à gants, par plaque (SPEC §11.2.3, §12).

Containers = Containers or {}
Containers.Types = Containers.Types or {}

local TOLERANCE = 1.0              -- m : marge serveur (latence)
local TRUNK_SERVER_DISTANCE = 6.0  -- m : du joueur au centre du véhicule
local OWNED_CACHE_TTL = 600        -- s : cache « plaque possédée » (résultat positif)
local NOT_OWNED_CACHE_TTL = 30     -- s : cache court d'un résultat négatif (véhicule acheté entre-temps)
local PLATE_MAX = 16
local NO_GLOVEBOX = { bike = true, quadbike = true }

-- Hash 32 bits non signé (GetEntityModel et joaat peuvent différer de signe).
local function u32(n)
    return math.tointeger(n) and (n & 0xFFFFFFFF) or n
end

-- Surcharges de coffre par modèle : joaat(nom) -> taille (construit au démarrage).
local modelSizes = {}
for model, size in pairs(Config.Vehicles.Models or {}) do
    local hash = type(model) == 'number' and model or joaat(model)
    modelSizes[u32(hash)] = size
end

local owned = {} -- [plaque] = { value = bool, expires = os.time() }

local function normalizePlate(text)
    if type(text) ~= 'string' then return nil end
    local plate = text:match('^%s*(.-)%s*$'):upper()
    if plate == '' or #plate > PLATE_MAX then return nil end
    return plate
end

local function plateOf(veh)
    return normalizePlate(GetVehicleNumberPlateText(veh))
end

local function getVehicle(netId)
    if math.type(netId) ~= 'integer' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

-- Véhicule existant portant cette plaque (ouvertures forcées par plaque uniquement).
local function findByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and plateOf(veh) == plate then
            return veh, NetworkGetNetworkIdFromEntity(veh)
        end
    end
    return nil, nil
end

local function trunkSize(veh)
    return modelSizes[u32(GetEntityModel(veh))] or Config.Vehicles.Trunk[GetVehicleType(veh) or '']
end

-- Plaque possédée (table du framework) ; standalone : toujours ; erreur SQL : true (on ne perd rien, non mis en cache).
-- TRIM : les plaques ESX sont enregistrées avec des espaces (8 caractères), quelle que soit la collation.
local function isOwned(plate)
    if Bridge.Framework == 'standalone' then return true end
    local now = os.time()
    local c = owned[plate]
    if c and c.expires > now then return c.value end
    local query = Bridge.Framework == 'esx'
        and 'SELECT 1 FROM `owned_vehicles` WHERE TRIM(`plate`) = ? LIMIT 1'
        or 'SELECT 1 FROM `player_vehicles` WHERE TRIM(`plate`) = ? LIMIT 1'
    local ok, res = pcall(function() return MySQL.scalar.await(query, { plate }) end)
    if not ok then
        Containers.Warn('vehicle ownership query failed for plate %s: %s', plate, tostring(res))
        return true
    end
    local value = res ~= nil
    owned[plate] = { value = value, expires = now + (value and OWNED_CACHE_TTL or NOT_OWNED_CACHE_TTL) }
    return value
end

-- Règles d'accès communes (s.netId / s.plate fixés à l'ouverture).
local function access(kind, src, s)
    if not s.netId then
        -- Ouverture forcée par plaque sans véhicule présent.
        if s.forced then return true end
        return false, 'error'
    end
    local veh = getVehicle(s.netId)
    if not veh or plateOf(veh) ~= s.plate then return false, 'error' end -- véhicule supprimé ou plaque changée
    if kind == 'glovebox' then
        if NO_GLOVEBOX[GetVehicleType(veh)] then return false, 'cannot_now' end
        if s.forced then return true end
        if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return false, 'cannot_now' end
        return true
    end
    if not trunkSize(veh) then return false, 'no_trunk' end
    if s.forced then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'error' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'cannot_now' end
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > TRUNK_SERVER_DISTANCE + TOLERANCE then return false, 'too_far' end
    -- NOTE: dépend de la synchro du verrouillage par le script de clés (0 = aucun, 1 = déverrouillé).
    if GetVehicleDoorLockStatus(veh) > 1 then return false, 'vehicle_locked' end
    return true
end

local function makeType(kind)
    local isTrunk = kind == 'trunk'
    return {
        open = function(src, request, s)
            local veh
            if request.netId ~= nil then
                veh = getVehicle(request.netId)
                if not veh then return nil, 'error' end
                s.netId = request.netId
                s.plate = plateOf(veh)
            elseif s.forced then
                s.plate = normalizePlate(request.plate)
                if s.plate then veh, s.netId = findByPlate(s.plate) end
            end
            if not s.plate then return nil, 'error' end

            -- Contrôle avant tout chargement (pas de lecture SQL pour une demande refusée).
            local ok, why = access(kind, src, s)
            if not ok then return nil, why end

            local id = kind .. ':' .. s.plate
            local inv = Inventory.Get(id)
            if inv then
                if s.netId then inv.netId = s.netId end
                return inv
            end

            local size
            if isTrunk then
                -- NOTE: ouverture forcée sans véhicule présent : taille d'une automobile.
                size = veh and trunkSize(veh) or Config.Vehicles.Trunk.automobile
            else
                size = Config.Vehicles.Glovebox
            end
            local slots, weight = math.tointeger(tonumber(size and size.slots)), math.tointeger(tonumber(size and size.weight))
            if not slots or slots < 1 or not weight or weight < 0 then return nil, isTrunk and 'no_trunk' or 'error' end

            local persist = isOwned(s.plate) -- peut attendre (SQL)
            return Inventory.Load(id, {
                type = kind, label = L(isTrunk and 'inv_trunk' or 'inv_glovebox'),
                slots = slots, maxWeight = weight,
                netId = s.netId, plate = s.plate, persist = persist,
            })
        end,

        access = function(src, _, s)
            return access(kind, src, s)
        end,

        -- Boîte à gants : pas de watch (le joueur est dans le véhicule).
        -- NOTE: distance du watch mesurée au centre du véhicule côté client : TRUNK_SERVER_DISTANCE + 1.0.
        watch = function(_, _, s)
            if not isTrunk or not s.netId then return nil end
            return { netId = s.netId, distance = TRUNK_SERVER_DISTANCE + 1.0 }
        end,

        -- Coffre non possédé vide sans spectateur : déchargé tout de suite.
        changed = function(inv)
            if not inv.persist and not Containers.HasViewers(inv) and Inventory.IsEmpty(inv) then
                Inventory.Remove(inv.id, false)
            end
        end,

        unloadable = function() return true end,

        -- Non possédé : conservé en mémoire tant que le véhicule existe (sinon le contenu serait perdu).
        keep = function(inv)
            if inv.persist then return false end
            local veh = getVehicle(inv.netId)
            return veh ~= nil and plateOf(veh) == inv.plate
        end,

        -- data = plaque (ou netId).
        forceRequest = function(data)
            if type(data) == 'string' then return { plate = data } end
            if math.type(data) == 'integer' then return { netId = data } end
            return nil
        end,
    }
end

Containers.Types.trunk = makeType('trunk')
Containers.Types.glovebox = makeType('glovebox')
