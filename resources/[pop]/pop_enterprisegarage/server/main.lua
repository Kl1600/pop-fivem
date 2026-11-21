-- pop_enterprisegarage : serveur.
-- Le client n'envoie qu'un id de garage, un index ou un netId : modèle, type, place, plaque et grade
-- sont lus dans la config. Véhicules créés côté serveur (OneSync obligatoire).

local ACTION_DISTANCE = 3.0  -- + 1.0 de tolérance
local STORE_RADIUS    = 5.0  -- + 2.0 de tolérance
local SPAWN_CLEAR     = 3.0  -- aucun véhicule à moins de cette distance d'une place
local SPAWN_TIMEOUT   = 3000 -- ms
local CLEAN_TICK      = 30000

local RES = GetCurrentResourceName()

local Garages = {} -- [id] = garage
local Active = {}  -- [plate] = { src, identifier, garage, entity }
local busy = {}    -- [src] = true pendant une sortie
local reserved = {} -- [plate] = place : réservées pendant la création (deux sorties simultanées ne se gênent pas)
local cleaning = false

local function log(fmt, ...)
    if Config.Debug then print(('[%s] ' .. fmt):format(RES, ...)) end
end

------------------------------------------------------------------------
-- Validation de la config
------------------------------------------------------------------------

for i, g in ipairs(Config.Garages or {}) do
    if type(g.id) ~= 'string' then
        print(('[%s] ^3warning: garage #%d has no id, ignored^0'):format(RES, i))
    elseif Garages[g.id] then
        print(('[%s] ^3warning: duplicate garage id "%s", ignored^0'):format(RES, g.id))
    else
        if type(g.plate) ~= 'string' or not g.plate:match('^[A-Z0-9]+$') or #g.plate > 4 then
            print(('[%s] ^3warning: garage "%s" has an invalid plate prefix (1-4 uppercase letters/digits)^0'):format(RES, g.id))
        end
        if type(g.spawns) ~= 'table' or #g.spawns == 0 then
            print(('[%s] ^3warning: garage "%s" has no spawn point^0'):format(RES, g.id))
        end
        Garages[g.id] = g
    end
end

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function hasAccess(src, g)
    if not Bridge.HasJob(src, { [g.job] = 0 }) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

local function countOut(identifier)
    local n = 0
    for _, a in pairs(Active) do
        if a.identifier == identifier then n = n + 1 end
    end
    return n
end

local function keysStarted()
    return GetResourceState('pop_vehiclekeys') == 'started'
end

local function takeKey(a, plate)
    if a and keysStarted() and GetPlayerName(a.src) then
        pcall(function() exports.pop_vehiclekeys:RemoveKey(a.src, plate, true) end)
    end
end

-- Épave : moteur détruit ou carrosserie à zéro (véhicule explosé).
local function isWreck(veh)
    return GetVehicleEngineHealth(veh) <= -3999.0 or GetVehicleBodyHealth(veh) <= 0.0
end

local function isEmpty(veh)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == veh then return false end
    end
    return true
end

--- Retire le véhicule de Active (d'abord) puis le supprime, et reprend la clé.
local function release(plate)
    local a = Active[plate]
    if not a then return end
    Active[plate] = nil
    if DoesEntityExist(a.entity) then DeleteEntity(a.entity) end
    takeKey(a, plate)
    log('released %s (garage %s, src %s)', plate, a.garage, a.src)
end

local function isReserved(spot)
    for _, s in pairs(reserved) do
        if s == spot then return true end
    end
    return false
end

local function findSpawn(g)
    local vehicles = GetAllVehicles()
    for _, s in ipairs(g.spawns or {}) do
        local pos = vec3(s.x, s.y, s.z)
        local free = not isReserved(s)
        for _, veh in ipairs(vehicles) do
            if #(GetEntityCoords(veh) - pos) < SPAWN_CLEAR then
                free = false
                break
            end
        end
        if free then return s end
    end
end

local function generatePlate(g)
    local prefix = ((g.plate or ''):upper():gsub('[^%w]', '')):sub(1, 4)
    local used = {}
    for _, veh in ipairs(GetAllVehicles()) do
        used[trim(GetVehicleNumberPlateText(veh))] = true
    end
    for _ = 1, 10 do
        local plate = prefix
        while #plate < 8 do plate = plate .. tostring(math.random(0, 9)) end
        if not Active[plate] and not reserved[plate] and not used[plate] then return plate end
    end
end

------------------------------------------------------------------------
-- Nettoyage (boucle active seulement s'il y a des véhicules sortis)
------------------------------------------------------------------------

local function cleanOnce()
    for plate, a in pairs(Active) do
        if not DoesEntityExist(a.entity) then
            Active[plate] = nil
            takeKey(a, plate)
            log('vehicle %s gone, slot freed', plate)
        elseif isWreck(a.entity) then
            release(plate)
            log('vehicle %s wrecked, slot freed', plate)
        else
            local g = Garages[a.garage]
            local online = GetPlayerName(a.src) ~= nil
            -- NOTE: on compare aussi l'identifiant : après un changement de personnage, le src reste le même.
            local valid = online and g and Bridge.GetIdentifier(a.src) == a.identifier and hasAccess(a.src, g)
            if not valid and isEmpty(a.entity) then release(plate) end
        end
    end
end

local function startCleaner()
    if cleaning then return end
    cleaning = true
    CreateThread(function()
        while next(Active) do
            Wait(CLEAN_TICK)
            cleanOnce()
        end
        cleaning = false
    end)
end

-- Libère les places des véhicules disparus ou détruits d'un employé.
local function purgeDead(identifier)
    for plate, a in pairs(Active) do
        if a.identifier == identifier and (not DoesEntityExist(a.entity) or isWreck(a.entity)) then
            release(plate)
        end
    end
end

local function onPlayerGone(src)
    busy[src] = nil
    for plate, a in pairs(Active) do
        if a.src == src then
            -- Clé reprise pour tous ses véhicules ; ceux encore occupés restent jusqu'au nettoyage.
            takeKey(a, plate)
            if DoesEntityExist(a.entity) and isEmpty(a.entity) then release(plate) end
        end
    end
end

Bridge.OnPlayerDropped(onPlayerGone)
Bridge.OnPlayerUnloaded(onPlayerGone)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_enterprisegarage:list', function(src, garage)
    local g = type(garage) == 'string' and Garages[garage]
    if not g then return false, 'error' end
    if not hasAccess(src, g) then return false, 'wrong_job' end
    if not Bridge.IsNear(src, g.coords, ACTION_DISTANCE + 1.0) then return false, 'too_far' end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    local grade = Bridge.GetJob(src).grade or 0

    local list = {}
    for i, v in ipairs(g.vehicles or {}) do
        if grade >= (v.grade or 0) then list[#list + 1] = { index = i, model = v.model } end
    end
    return true, nil, { vehicles = list, out = countOut(identifier), max = Config.MaxPerPlayer }
end)

-- Crée le véhicule ; nil si l'entité n'apparaît pas à temps (elle sera supprimée si elle apparaît plus tard).
local function spawnVehicle(v, spot)
    local veh = CreateVehicleServerSetter(joaat(v.model), v.type or 'automobile', spot.x, spot.y, spot.z, spot.w)
    local deadline = GetGameTimer() + SPAWN_TIMEOUT
    while not (veh and veh ~= 0 and DoesEntityExist(veh)) do
        if GetGameTimer() > deadline then
            if veh and veh ~= 0 then
                CreateThread(function()
                    local limit = GetGameTimer() + 10000
                    while GetGameTimer() < limit do
                        if DoesEntityExist(veh) then DeleteEntity(veh) return end
                        Wait(250)
                    end
                end)
            end
            return nil
        end
        Wait(50)
    end
    return veh
end

local function takeOut(src, g, index)
    local v = g.vehicles and g.vehicles[index]
    if not v then return false, 'error' end
    if not hasAccess(src, g) then return false, 'wrong_job' end
    if not Bridge.IsNear(src, g.coords, ACTION_DISTANCE + 1.0) then return false, 'too_far' end
    if (Bridge.GetJob(src).grade or 0) < (v.grade or 0) then return false, 'grade_too_low' end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    purgeDead(identifier)
    if countOut(identifier) >= Config.MaxPerPlayer then return false, 'limit_reached', Config.MaxPerPlayer end

    local spot = findSpawn(g)
    if not spot then return false, 'spawn_blocked' end

    local plate = generatePlate(g)
    if not plate then return false, 'error' end

    reserved[plate] = spot
    local okSpawn, veh = pcall(spawnVehicle, v, spot)
    reserved[plate] = nil
    if not okSpawn then error(veh, 0) end
    if not veh then return false, 'error' end

    SetEntityOrphanMode(veh, 2)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDoorsLocked(veh, 1)
    local state = Entity(veh).state
    state:set('pop_temporary', true, true)
    state:set('pop_enterprisegarage', g.id, true)
    state:set('fuel', 100.0, true)

    Active[plate] = { src = src, identifier = identifier, garage = g.id, entity = veh }
    startCleaner()

    if keysStarted() then
        pcall(function() exports.pop_vehiclekeys:GiveKey(src, plate) end)
    end

    log('src %s (%s) took out %s plate %s from %s', src, identifier, v.model, plate, g.id)
    Bridge.Notify(src, L('taken_out', plate), 'success')
    return true, nil, NetworkGetNetworkIdFromEntity(veh)
end

Callback.Register('pop_enterprisegarage:takeOut', function(src, garage, index)
    if busy[src] then return false, 'busy' end
    local g = type(garage) == 'string' and Garages[garage]
    if not g or math.type(index) ~= 'integer' then return false, 'error' end

    busy[src] = true
    local ok, a, b, c = pcall(takeOut, src, g, index)
    busy[src] = nil
    if not ok then
        print(('[%s] ^1takeOut error: %s^0'):format(RES, a))
        return false, 'error'
    end
    return a, b, c
end)

Callback.Register('pop_enterprisegarage:store', function(src, netId)
    if math.type(netId) ~= 'integer' then return false, 'error' end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'error' end

    -- NOTE: recherche par entité plutôt que par la plaque lue côté serveur (la plaque posée par
    -- SetVehicleNumberPlateText peut mettre un instant à être répliquée) : même résultat, plus fiable.
    local plate, a
    for p, data in pairs(Active) do
        if data.entity == veh then plate, a = p, data break end
    end
    if not a then return false, 'not_service_vehicle' end

    local g = Garages[a.garage]
    if not g then return false, 'error' end
    if not hasAccess(src, g) then return false, 'wrong_job' end
    if not Bridge.IsNear(src, g.store, STORE_RADIUS + 2.0) then
        for id, other in pairs(Garages) do
            if id ~= g.id and other.store and Bridge.IsNear(src, other.store, STORE_RADIUS + 2.0) then
                return false, 'wrong_garage'
            end
        end
        return false, 'too_far'
    end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return false, 'not_driver' end

    release(plate)
    log('src %s stored %s in %s', src, plate, g.id)
    Bridge.Notify(src, L('stored'), 'success')
    return true
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('IsServiceVehicle', function(plate)
    return Active[trim(plate):upper()] ~= nil
end)

exports('GetPlayerVehicles', function(src)
    src = tonumber(src)
    local list = {}
    for plate, a in pairs(Active) do
        if a.src == src then list[#list + 1] = plate end
    end
    return list
end)

------------------------------------------------------------------------
-- Arrêt
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for plate, a in pairs(Active) do
        Active[plate] = nil
        takeKey(a, plate)
        if DoesEntityExist(a.entity) then DeleteEntity(a.entity) end
    end
end)
