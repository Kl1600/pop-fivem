-- pop_bennys : serveur.
-- Sessions d'atelier, achat (prix recalculé depuis la config), sauvegarde framework facultative.
-- Le client n'envoie que des clés et des valeurs : prix, palette, niveaux et compte viennent de config.lua.

local RES = GetCurrentResourceName()

-- Plaque comparable (même règle que pop_vehiclekeys) : sans espaces, majuscules, 1 à 8 alphanumériques.
local Plate = {}
function Plate.Normalize(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('%s+', ''):upper()
    if plate == '' or #plate > 8 or plate:find('[^%w]') then return nil end
    return plate
end

local Sessions = {}      -- [src] = { netId, veh, plate, shop, original, raw, owned, t }
local SessionByVeh = {}  -- [veh] = src
local busy = {}          -- [src] = true pendant un traitement (verrou)

-- Requêtes framework (paramétrées, chaînes constantes). Paramètres : plaque brute (index), puis normalisée.
local SQL = {
    esx = {
        col    = 'vehicle',
        select = "SELECT vehicle FROM owned_vehicles WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1",
        update = "UPDATE owned_vehicles SET vehicle = ? WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1",
    },
    qbcore = {
        col    = 'mods',
        select = "SELECT mods FROM player_vehicles WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1",
        update = "UPDATE player_vehicles SET mods = ? WHERE plate = ? OR REPLACE(plate, ' ', '') = ? LIMIT 1",
    },
}
SQL.qbox = SQL.qbcore

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

-- Requêtes framework possibles : oxmysql démarré et framework connu.
local function frameworkSql()
    if GetResourceState('oxmysql') ~= 'started' or type(MySQL) ~= 'table' then return nil end
    return SQL[Bridge.Framework]
end

CreateThread(function()
    if SQL[Bridge.Framework] and GetResourceState('oxmysql') ~= 'started' then
        print(('[%s] WARNING: oxmysql is not started: owned vehicles are priced from the client state and purchases are not written to the %s vehicle table.')
            :format(RES, Bridge.Framework))
    end
end)

-- Compte débité : seulement 'cash' ou 'bank'.
-- NOTE: valeur de config inattendue -> 'bank' (option la plus sûre, jamais 'black').
local function account()
    return Config.Account == 'cash' and 'cash' or 'bank'
end

-- Source de joueur valide et chargé, sinon nil.
local function validPlayer(src)
    src = tonumber(src)
    if not src or math.type(src) ~= 'integer' or src <= 0 then return nil end
    if not GetPlayerName(src) or not Bridge.GetPlayer(src) then return nil end
    return src
end

-- Véhicule serveur valide à partir d'un netId entier, sinon nil.
local function vehicleFromNet(netId)
    if math.type(netId) ~= 'integer' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function removeSession(src)
    local s = Sessions[src]
    if not s then return end
    if SessionByVeh[s.veh] == src then SessionByVeh[s.veh] = nil end
    Sessions[src] = nil
end

local function expired(s)
    return os.time() - s.t > Bennys.SESSION_TIMEOUT
end

-- Vérifie atelier, job et place du conducteur. Renvoie une raison (clé de locale) ou nil.
local function checkContext(src, shopIndex, veh)
    local shop = math.type(shopIndex) == 'integer' and Config.Shops[shopIndex] or nil
    if type(shop) ~= 'table' or not shop.coords then return 'error' end
    if not Bridge.IsNear(src, shop.coords, (tonumber(shop.radius) or 0) + Bennys.ZONE_TOLERANCE) then
        return 'too_far'
    end
    if shop.jobs then
        local job = Bridge.GetJob(src)
        if not Bridge.HasJob(src, shop.jobs) or not (job and job.onDuty) then return 'wrong_job' end
    end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return 'not_driver' end
    return nil
end

-- Lit la colonne JSON du framework pour cette plaque : table décodée, ou nil (non possédé / illisible).
local function readOwned(rawPlate, plate)
    local q = frameworkSql()
    if not q then return nil end
    local ok, row = pcall(MySQL.single.await, q.select, { rawPlate, plate })
    if not ok then
        print(('[%s] SQL error (read %s): %s'):format(RES, plate, tostring(row)))
        return nil
    end
    local data = type(row) == 'table' and row[q.col] or nil
    if type(data) ~= 'string' then return nil end
    local okj, raw = pcall(json.decode, data)
    if okj and type(raw) == 'table' then return raw end
    return nil
end

-- Écrit la colonne JSON du framework, sans bloquer l'achat (erreur = log console).
local function writeOwned(rawPlate, plate, data)
    local q = frameworkSql()
    if not q then return end
    local payload = json.encode(data)
    CreateThread(function()
        local ok, err = pcall(MySQL.update.await, q.update, { payload, rawPlate, plate })
        if not ok then
            print(('[%s] SQL error (save %s): %s'):format(RES, plate, tostring(err)))
        else
            log('framework table updated for %s (%s row)', plate, tostring(err))
        end
    end)
end

-- Exécute fn sous le verrou du joueur ; toute erreur Lua devient 'error'.
local function locked(src, fn, ...)
    busy[src] = true
    local res = table.pack(pcall(fn, src, ...))
    busy[src] = nil
    if not res[1] then
        print(('[%s] error: %s'):format(RES, tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

------------------------------------------------------------------------
-- Ouverture
------------------------------------------------------------------------

local function openSession(src, netId, shop, current)
    if math.type(shop) ~= 'integer' or not Config.Shops[shop] then return false, 'error' end

    local veh = vehicleFromNet(netId)
    if not veh then return false, 'error' end

    local reason = checkContext(src, shop, veh)
    if reason then return false, reason end

    if not Bennys.TYPES[GetVehicleType(veh) or ''] then return false, 'vehicle_not_allowed' end

    -- Session d'un autre joueur sur ce véhicule (nettoyée si périmée).
    local other = SessionByVeh[veh]
    if other then
        local prev = Sessions[other]
        if prev and prev.veh == veh and not expired(prev) and GetPlayerName(other) then
            return false, 'vehicle_in_use'
        end
        if prev and prev.veh == veh then removeSession(other) end
        SessionByVeh[veh] = nil
    end

    local text = GetVehicleNumberPlateText(veh)
    local plate = Plate.Normalize(text)
    if not plate then return false, 'error' end
    local rawPlate = text:match('^%s*(.-)%s*$')

    -- Référence de prix : table du framework si le véhicule y est (jamais l'état du client).
    local raw = readOwned(rawPlate, plate)
    local owned = raw ~= nil
    local original = (owned and Props.Sanitize(raw)) or Props.Sanitize(current) or {}

    -- Revérification après la lecture SQL asynchrone (le joueur a pu partir).
    if not validPlayer(src) then return false, 'error' end
    if not DoesEntityExist(veh) or SessionByVeh[veh] or Sessions[src] then return false, 'vehicle_in_use' end

    Sessions[src] = {
        netId = netId, veh = veh, plate = plate, rawPlate = rawPlate, shop = shop,
        original = original, raw = raw, owned = owned, t = os.time(),
    }
    SessionByVeh[veh] = src
    log('session opened: src %s, plate %s, shop %s, owned %s', src, plate, shop, tostring(owned))
    return true
end

Callback.Register('pop_bennys:open', function(source, netId, shop, current)
    local src = validPlayer(source)
    if not src then return false, 'error' end
    if Sessions[src] or busy[src] then return false, 'busy' end
    return locked(src, openSession, netId, shop, current)
end)

------------------------------------------------------------------------
-- Achat
------------------------------------------------------------------------

-- Valide la liste du client (tout ou rien). Renvoie { [key] = valeur normalisée } ou nil.
local function readChanges(changes)
    if type(changes) ~= 'table' then return nil end
    local n = #changes
    if n < 1 or n > Bennys.MAX_CHANGES then return nil end
    local count = 0
    for _ in pairs(changes) do count = count + 1 end
    if count ~= n then return nil end

    local out = {}
    for i = 1, n do
        local e = changes[i]
        if type(e) ~= 'table' or type(e.key) ~= 'string' or out[e.key] ~= nil then return nil end
        local ok, value = Bennys.Valid(e.key, e.value)
        if not ok then return nil end
        out[e.key] = value
    end
    return out
end

local function buy(src, netId, changes)
    local s = Sessions[src]
    local veh = vehicleFromNet(netId)
    if not s or s.netId ~= netId or veh ~= s.veh then return false, 'error' end
    if expired(s) then
        removeSession(src)
        return false, 'error'
    end

    local reason = checkContext(src, s.shop, veh)
    if reason then return false, reason end
    if Plate.Normalize(GetVehicleNumberPlateText(veh)) ~= s.plate then return false, 'error' end

    -- Moto : même règle que le client (type de jante 6 uniquement).
    local bike = GetVehicleType(veh) == 'bike'
    local valid = readChanges(changes)
    if not valid or (bike and valid.wheels ~= nil and valid.wheels ~= 6) then
        s.t = os.time()
        return false, 'invalid_change'
    end

    -- Lignes réellement modifiées et total (prix relus dans la config serveur).
    local lines, total, any = {}, 0, false
    for key, value in pairs(valid) do
        if not Bennys.Equal(s.original[key], value) then
            lines[key] = value
            total = total + Bennys.Price(key, value)
            any = true
        end
    end
    if not any then return false, 'no_changes' end
    total = math.floor(total)

    -- Nouveau type de jante : la jante l'accompagne toujours (d'origine si non choisie).
    if lines.wheels ~= nil and lines.modFrontWheels == nil then
        if valid.modFrontWheels ~= nil then lines.modFrontWheels = valid.modFrontWheels else lines.modFrontWheels = -1 end
    end
    if bike and lines.modFrontWheels ~= nil then lines.modBackWheels = lines.modFrontWheels end

    if total > 0 and not Bridge.RemoveMoney(src, account(), total, 'pop_bennys') then
        s.t = os.time()
        return false, 'not_enough_money'
    end

    -- Props finales : seulement les clés de l'atelier. Véhicule non possédé : seulement les lignes payées
    -- (l'état envoyé par le client n'est jamais transmis comme référence).
    local editable = Bennys.Editable()
    local final = {}
    for key, value in pairs(Props.Merge(s.owned and s.original or nil, lines)) do
        if editable[key] then final[key] = value end
    end

    -- Table du framework : on garde les clés inconnues du garage, plate et model d'origine.
    -- Couleur de palette achetée : la couleur RGB personnalisée enregistrée est retirée.
    if Config.SaveToFramework and s.owned and type(s.raw) == 'table' then
        local data = Props.Merge(s.raw, lines)
        if lines.color1 ~= nil then data.customPrimaryColor = nil end
        if lines.color2 ~= nil then data.customSecondaryColor = nil end
        writeOwned(s.rawPlate, s.plate, data)
    end
    if lines.color1 ~= nil then final.customPrimaryColor = nil end
    if lines.color2 ~= nil then final.customSecondaryColor = nil end

    local plate, owned = s.plate, s.owned
    removeSession(src)
    TriggerEvent('pop_bennys:saved', src, plate, final, owned)
    Bridge.Notify(src, L('paid', total), 'success')
    log('purchase: src %s (%s), plate %s, total %s, account %s',
        src, tostring(Bridge.GetIdentifier(src)), plate, total, account())
    return true, nil, total
end

Callback.Register('pop_bennys:buy', function(source, netId, changes)
    local src = validPlayer(source)
    if not src then return false, 'error' end
    if busy[src] then return false, 'busy' end
    return locked(src, buy, netId, changes)
end)

------------------------------------------------------------------------
-- Annulation et nettoyage
------------------------------------------------------------------------

Callback.Register('pop_bennys:close', function(source, netId)
    local src = tonumber(source)
    local s = src and Sessions[src]
    if s and s.netId == netId then
        removeSession(src)
        log('session closed: src %s', src)
    end
    return true
end)

local function cleanup(src)
    removeSession(src)
    busy[src] = nil
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)

-- Sessions expirées ou véhicule disparu (client planté sans déconnexion) : balayage lent.
CreateThread(function()
    while true do
        Wait(60000)
        for src, s in pairs(Sessions) do
            if not busy[src] and (expired(s) or not DoesEntityExist(s.veh) or not GetPlayerName(src)) then
                removeSession(src)
                log('session expired: src %s', src)
            end
        end
    end
end)
