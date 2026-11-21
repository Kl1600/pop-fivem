-- pop_bikerental : serveur. Le client n'envoie que deux index (point, véhicule) :
-- modèle, prix, caution, place et plaque viennent de la config et du serveur.

local ACTION_DISTANCE = 2.0
local RETURN_DISTANCE = 10.0
local SPAWN_CLEAR     = 2.5
local SPAWN_TIMEOUT   = 3000
local WARN_BEFORE     = 120
local MIN_HEALTH      = 300.0
local TICK            = 15000

local RES = GetCurrentResourceName()

local Rentals = {} -- [src] = { plate, entity, expires, deposit, warned }
local busy = {}    -- [src] = true pendant un callback
local ticking = false

local function log(fmt, ...)
    if Config.Debug then print(('[%s] ' .. fmt):format(RES, ...)) end
end

-- Montant de la config ramené à un entier >= 0.
local function amount(n)
    n = tonumber(n) or 0
    if n ~= n or n < 0 then return 0 end
    return math.floor(n)
end

local function isOnline(src)
    return GetPlayerName(src) ~= nil
end

local function keysStarted()
    return GetResourceState('pop_vehiclekeys') == 'started'
end

local function trimPlate(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function isIndex(n, list)
    return math.type(n) == 'integer' and list[n] ~= nil
end

-- Plaque 'RENT' + 4 chiffres, absente des locations et des véhicules existants.
local function generatePlate()
    local used = {}
    for _, r in pairs(Rentals) do used[r.plate] = true end
    for _, veh in ipairs(GetAllVehicles()) do used[trimPlate(GetVehicleNumberPlateText(veh))] = true end
    for _ = 1, 10 do
        local plate = ('RENT%04d'):format(math.random(0, 9999))
        if not used[plate] then return plate end
    end
    return nil
end

local function spawnClear(spawn)
    local pos = vec3(spawn.x, spawn.y, spawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - pos) < SPAWN_CLEAR then return false end
    end
    return true
end

-- Reprise de clé, indépendante de l'event client (aussi à la déconnexion et à l'arrêt de la ressource).
local function takeKey(src, plate)
    if keysStarted() then
        pcall(function() exports.pop_vehiclekeys:RemoveKey(src, plate, true) end)
    end
end

-- Épave : moteur détruit ou carrosserie à zéro (véhicule explosé).
local function isWreck(veh)
    return GetVehicleEngineHealth(veh) <= -3999.0 or GetVehicleBodyHealth(veh) <= 0.0
end

-- Supprime une entité créée trop tard (après SPAWN_TIMEOUT) dès qu'elle apparaît.
local function deleteLate(veh)
    if not veh or veh == 0 then return end
    CreateThread(function()
        local limit = GetGameTimer() + 10000
        while GetGameTimer() < limit do
            if DoesEntityExist(veh) then DeleteEntity(veh) return end
            Wait(250)
        end
    end)
end

-- Termine une location : retirée de Rentals AVANT toute suppression (pas de double fin / caution).
local function finish(src, notifyKey, online)
    local r = Rentals[src]
    if not r then return nil end
    Rentals[src] = nil

    if r.entity and DoesEntityExist(r.entity) then DeleteEntity(r.entity) end
    takeKey(src, r.plate)

    if online == nil then online = isOnline(src) end
    if online then
        TriggerClientEvent('pop_bikerental:client:ended', src)
        if notifyKey then Bridge.Notify(src, L(notifyKey), 'error') end
    end
    log('rental ended src=%s plate=%s reason=%s', src, r.plate, notifyKey or 'returned')
    return r
end

-- Boucle de surveillance : ne tourne que s'il y a des locations.
local function startTick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(Rentals) do
            Wait(TICK)
            local now = os.time()
            for src, r in pairs(Rentals) do
                if not DoesEntityExist(r.entity) or isWreck(r.entity) then
                    finish(src, 'lost')
                elseif now >= r.expires then
                    finish(src, 'expired')
                elseif not r.warned and r.expires - now <= WARN_BEFORE then
                    r.warned = true
                    Bridge.Notify(src, L('expiring'), 'warning')
                end
            end
        end
        ticking = false
    end)
end

-- Exécute fn avec un verrou par joueur, libéré dans tous les cas.
local function locked(src, fn, ...)
    if busy[src] then return false, 'busy' end
    busy[src] = true
    local ok, a, b, c, d = pcall(fn, src, ...)
    busy[src] = nil
    if not ok then
        print(('[%s] ^1error^7: %s'):format(RES, a))
        return false, 'error'
    end
    return a, b, c, d
end

local function rent(src, location, index)
    if not Bridge.GetPlayer(src) then return false, 'error' end
    if not isIndex(location, Config.Locations) or not isIndex(index, Config.Vehicles) then return false, 'error' end
    local loc, v = Config.Locations[location], Config.Vehicles[index]

    if not Bridge.IsNear(src, loc.coords, ACTION_DISTANCE + 1.0) then return false, 'too_far' end
    if Rentals[src] then return false, 'already_renting' end
    if not spawnClear(loc.spawn) then return false, 'spawn_blocked' end

    -- NOTE: plaque générée avant l'encaissement (aucun remboursement nécessaire si elle échoue).
    local plate = generatePlate()
    if not plate then return false, 'error' end

    local deposit = amount(Config.Deposit)
    local total = amount(v.price) + deposit
    if total > 0 and not Bridge.RemoveMoney(src, Config.Account, total, 'pop_bikerental') then
        return false, 'not_enough_money'
    end

    local s = loc.spawn
    local veh = CreateVehicleServerSetter(joaat(v.model), v.type or 'bike', s.x, s.y, s.z, s.w)
    local deadline = GetGameTimer() + SPAWN_TIMEOUT
    while not (veh and veh ~= 0 and DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(50) end

    if not (veh and veh ~= 0 and DoesEntityExist(veh)) then
        deleteLate(veh) -- supprimé s'il apparaît après coup, avant tout remboursement
        if total > 0 then Bridge.AddMoney(src, Config.Account, total, 'pop_bikerental') end
        return false, 'error'
    end

    -- Le joueur a pu partir pendant l'attente : location annulée, remboursée si son objet joueur existe
    -- encore côté framework ; sinon le remboursement est impossible (documenté dans le README).
    if not isOnline(src) then
        DeleteEntity(veh)
        if total > 0 and Bridge.GetPlayer(src) then
            Bridge.AddMoney(src, Config.Account, total, 'pop_bikerental')
        end
        log('rent cancelled src=%s (player left during spawn)', src)
        return false, 'error'
    end

    SetEntityOrphanMode(veh, 2)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDoorsLocked(veh, 1)
    local state = Entity(veh).state
    state:set('pop_temporary', true, true)
    state:set('fuel', 100.0, true)

    local duration = math.max(1, amount(Config.Duration))
    Rentals[src] = { plate = plate, entity = veh, expires = os.time() + duration * 60, deposit = deposit, warned = false }
    startTick()

    if keysStarted() then
        pcall(function() exports.pop_vehiclekeys:GiveKey(src, plate) end)
    end

    log('rented src=%s model=%s plate=%s paid=%d', src, v.model, plate, total)
    if deposit > 0 then
        Bridge.Notify(src, L('rented', duration, deposit), 'success')
    else
        Bridge.Notify(src, L('rented_plain', duration), 'success')
    end
    return true, nil, NetworkGetNetworkIdFromEntity(veh), duration * 60
end

-- Véhicule libre : aucun joueur à bord (parcours des joueurs, fiable côté serveur).
local function seatsFree(veh)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == veh then return false end
    end
    return true
end

local function giveBack(src, location)
    if not isIndex(location, Config.Locations) then return false, 'error' end
    local loc = Config.Locations[location]
    local r = Rentals[src]
    if not r then return false, 'no_rental' end
    if not Bridge.IsNear(src, loc.coords, ACTION_DISTANCE + 1.0) then return false, 'too_far' end

    local veh = r.entity
    if not DoesEntityExist(veh) or isWreck(veh) then
        finish(src, 'lost')
        return false, 'no_rental'
    end
    if #(GetEntityCoords(veh) - loc.coords) > RETURN_DISTANCE then return false, 'vehicle_not_here' end
    if not seatsFree(veh) then return false, 'vehicle_occupied' end

    local intact = GetVehicleEngineHealth(veh) > MIN_HEALTH and GetVehicleBodyHealth(veh) > MIN_HEALTH
    local done = finish(src)
    if not done then return false, 'no_rental' end

    if done.deposit <= 0 then
        Bridge.Notify(src, L('returned_plain'), 'success')
    elseif intact then
        Bridge.AddMoney(src, Config.Account, done.deposit, 'pop_bikerental')
        Bridge.Notify(src, L('returned', done.deposit), 'success')
    else
        Bridge.Notify(src, L('returned_damaged'), 'error')
    end
    log('returned src=%s plate=%s intact=%s', src, done.plate, tostring(intact))
    return true
end

Callback.Register('pop_bikerental:rent', function(src, location, index)
    return locked(src, rent, location, index)
end)

Callback.Register('pop_bikerental:giveBack', function(src, location)
    return locked(src, giveBack, location)
end)

-- Départ / changement de personnage : véhicule supprimé, caution perdue.
Bridge.OnPlayerDropped(function(src)
    finish(src, nil, false)
    busy[src] = nil
end)

Bridge.OnPlayerUnloaded(function(src)
    finish(src)
    busy[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for src, r in pairs(Rentals) do
        Rentals[src] = nil
        if r.entity and DoesEntityExist(r.entity) then DeleteEntity(r.entity) end
        takeKey(src, r.plate)
    end
end)

exports('GetRental', function(src)
    local r = Rentals[tonumber(src)]
    if not r then return nil end
    return { plate = r.plate, expires = r.expires }
end)

exports('IsRental', function(plate)
    plate = trimPlate(plate)
    for _, r in pairs(Rentals) do
        if r.plate == plate then return true end
    end
    return false
end)
