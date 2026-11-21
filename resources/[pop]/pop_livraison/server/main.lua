-- pop_livraison : serveur. Le client n'envoie que `withVehicle` : adresses, paie, temps et caution
-- viennent de la config et du serveur.

local ACTION_DISTANCE  = 6.0   -- joueur <-> porte / PNJ
local VEHICLE_DISTANCE = 40.0  -- camionnette <-> porte
local RETURN_DISTANCE  = 20.0  -- camionnette <-> Config.Vehicle.spawn
local MAX_SPEED        = 70.0  -- m/s, anti-téléportation
local SPAWN_CLEAR      = 3.0
local SPAWN_TIMEOUT    = 2000
local TICK             = 30000

local RES = GetCurrentResourceName()

local runs = {}      -- [src] = voir SPEC §3
local busy = {}      -- [src] = true pendant un callback
local cooldowns = {} -- [identifier] = os.time() de fin du délai
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

local function toVec3(v)
    return vector3(v.x, v.y, v.z)
end

local function trimPlate(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

------------------------------------------------------------------------
-- Clés de la camionnette
------------------------------------------------------------------------

local function giveKey(src, veh, plate)
    if GetResourceState('pop_vehiclekeys') == 'started' then
        pcall(function() exports.pop_vehiclekeys:GiveKey(src, plate) end)
    elseif GetResourceState('qbx_vehiclekeys') == 'started' then
        -- NOTE: export à confirmer selon la version de qbx_vehiclekeys.
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    end
end

-- Reprise de clé : indépendante du client (fin, abandon, expiration, déconnexion, arrêt).
local function takeKey(src, plate)
    if plate and GetResourceState('pop_vehiclekeys') == 'started' then
        pcall(function() exports.pop_vehiclekeys:RemoveKey(src, plate, true) end)
    end
end

------------------------------------------------------------------------
-- Camionnette
------------------------------------------------------------------------

-- Épave : explosée, moteur détruit ou carrosserie à zéro.
local function isWreck(veh)
    return GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= -3999.0 or GetVehicleBodyHealth(veh) <= 0.0
end

local function vehicleOk(veh)
    return veh and veh ~= 0 and DoesEntityExist(veh) and not isWreck(veh)
end

local function deleteVehicle(veh)
    if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
end

-- Supprime une entité créée après SPAWN_TIMEOUT dès qu'elle apparaît.
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

local function spawnClear(spawn)
    local pos = toVec3(spawn)
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - pos) < SPAWN_CLEAR then return false end
    end
    return true
end

-- Plaque 'POPL' + 4 chiffres, absente des véhicules existants.
local function generatePlate()
    local used = {}
    for _, veh in ipairs(GetAllVehicles()) do used[trimPlate(GetVehicleNumberPlateText(veh))] = true end
    for _ = 1, 10 do
        local plate = ('POPL%04d'):format(math.random(0, 9999))
        if not used[plate] then return plate end
    end
    return nil
end

------------------------------------------------------------------------
-- Tournées
------------------------------------------------------------------------

local function setCooldown(identifier)
    if identifier then cooldowns[identifier] = os.time() + amount(Config.Cooldown) end
end

-- Clôt une tournée : retirée de `runs` AVANT toute suppression (pas de double fin).
-- `clientReason` : clé de locale envoyée via runEnded (nil = nettoyage silencieux, false = pas d'event).
local function closeRun(src, clientReason)
    local run = runs[src]
    if not run then return nil end
    runs[src] = nil

    deleteVehicle(run.vehicle)
    takeKey(src, run.plate)
    setCooldown(run.identifier)

    if clientReason ~= false and isOnline(src) then
        TriggerClientEvent('pop_livraison:client:runEnded', src, clientReason)
    end
    log('run closed src=%s paid=%d reason=%s', src, run.paid, tostring(clientReason))
    return run
end

-- Surveillance : un SetTimeout toutes les 30 s, seulement s'il existe des tournées.
local function tick()
    local now = os.time()
    for src, run in pairs(runs) do
        if now >= run.expiresAt then
            closeRun(src, 'run_expired')
        elseif run.vehicle and not vehicleOk(run.vehicle) then
            -- Épave ou camionnette disparue : tournée terminée, caution perdue.
            closeRun(src, 'vehicle_missing')
        end
    end
    if next(runs) then
        SetTimeout(TICK, tick)
    else
        ticking = false
    end
end

local function startTick()
    if ticking then return end
    ticking = true
    SetTimeout(TICK, tick)
end

local function runData(run)
    local dests = {}
    for i, idx in ipairs(run.dests) do
        local d = Config.Destinations[idx]
        dests[i] = { x = d.x, y = d.y, z = d.z, w = d.w }
    end
    return {
        destinations = dests,
        index = run.index,
        total = #run.dests,
        timeLeft = math.max(0, run.expiresAt - os.time()),
        netId = run.vehicle and NetworkGetNetworkIdFromEntity(run.vehicle) or nil,
    }
end

-- Fisher-Yates : `count` index distincts de Config.Destinations.
local function pickDestinations(count)
    local pool = {}
    for i = 1, #Config.Destinations do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local out = {}
    for i = 1, count do out[i] = pool[i] end
    return out
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

-- Exécute fn avec un verrou par joueur, libéré dans tous les cas, après les contrôles communs.
local function locked(src, fn, ...)
    if busy[src] then return false, 'busy' end
    busy[src] = true
    local ok, a, b, c, d = pcall(function(...)
        local identifier = Bridge.GetIdentifier(src)
        if not identifier or Bridge.IsDead(src) then return false, 'error' end
        return fn(src, identifier, ...)
    end, ...)
    busy[src] = nil
    if not ok then
        print(('[%s] ^1error^7: %s'):format(RES, a))
        return false, 'error'
    end
    return a, b, c, d
end

local function start(src, identifier, withVehicle)
    if runs[src] then return false, 'already_on_run' end
    if Config.Job and not Bridge.HasJob(src, Config.Job) then return false, 'wrong_job' end

    local now = os.time()
    local cd = cooldowns[identifier]
    if cd and cd > now then return false, 'cooldown', cd - now end

    if not Bridge.IsNear(src, Config.Depot.coords, ACTION_DISTANCE) then return false, 'too_far' end
    if withVehicle ~= true and withVehicle ~= false then return false, 'error' end
    if withVehicle and not Config.Vehicle then return false, 'error' end

    local count = math.floor(tonumber(Config.Packages) or 0)
    if count < 1 or #Config.Destinations < count then
        print(('[%s] ^1Config.Packages must be between 1 and #Config.Destinations^7'):format(RES))
        return false, 'error'
    end

    local run = {
        identifier = identifier,
        dests = pickDestinations(count),
        index = 1,
        startedAt = now,
        lastAt = now,
        lastPos = toVec3(Config.Depot.coords),
        expiresAt = now + math.max(1, amount(Config.TimeLimit)),
        vehicle = nil,
        plate = nil,
        withVehicle = withVehicle,
        deposit = 0,
        paid = 0,
    }

    if withVehicle then
        local v = Config.Vehicle
        if not spawnClear(v.spawn) then return false, 'spawn_blocked' end
        local plate = generatePlate()
        if not plate then return false, 'error' end

        -- Caution retirée avant toute création ; toute erreur ensuite la rend.
        local deposit = amount(v.deposit)
        if deposit > 0 and not Bridge.RemoveMoney(src, Config.Account, deposit, 'pop_livraison') then
            return false, 'not_enough_money'
        end
        local function refund()
            if deposit > 0 and Bridge.GetPlayer(src) then
                Bridge.AddMoney(src, Config.Account, deposit, 'pop_livraison')
            end
        end

        local s = v.spawn
        local veh = CreateVehicleServerSetter(joaat(v.model), 'automobile', s.x, s.y, s.z, s.w)
        local deadline = GetGameTimer() + SPAWN_TIMEOUT
        while not (veh and veh ~= 0 and DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(50) end

        if not (veh and veh ~= 0 and DoesEntityExist(veh)) then
            deleteLate(veh)
            refund()
            return false, 'error'
        end
        if not isOnline(src) then
            DeleteEntity(veh)
            refund()
            return false, 'error'
        end

        SetEntityOrphanMode(veh, 2)
        SetVehicleNumberPlateText(veh, plate)
        local state = Entity(veh).state
        state:set('pop_temporary', true, true)
        state:set('fuel', 100.0, true)

        run.vehicle, run.plate, run.deposit = veh, plate, deposit
        giveKey(src, veh, plate)
    end

    runs[src] = run
    startTick()
    log('run started src=%s vehicle=%s plate=%s', src, tostring(withVehicle), tostring(run.plate))
    Bridge.Notify(src, L('run_started', count), 'success')
    return true, nil, nil, runData(run)
end

local function deliver(src)
    local run = runs[src]
    if not run or run.index > #run.dests then return false, 'no_run' end

    local dest = toVec3(Config.Destinations[run.dests[run.index]])
    if not Bridge.IsNear(src, dest, ACTION_DISTANCE) then return false, 'too_far' end
    if os.time() - run.lastAt < #(dest - run.lastPos) / MAX_SPEED then return false, 'too_fast' end

    if run.withVehicle then
        if not vehicleOk(run.vehicle) then
            -- Épave ou camionnette disparue : la tournée ne peut plus continuer.
            closeRun(src, false)
            return false, 'vehicle_missing'
        end
        if #(GetEntityCoords(run.vehicle) - dest) > VEHICLE_DISTANCE then return false, 'vehicle_too_far' end
    end

    local pay = amount(Config.Pay.base) + math.floor(#(dest - run.lastPos) / 1000 * (tonumber(Config.Pay.perKm) or 0))
    pay = amount(pay)

    -- Index incrémenté AVANT la paie (pas de double paie).
    run.index = run.index + 1
    run.lastPos, run.lastAt = dest, os.time()
    run.paid = run.paid + pay
    if pay > 0 and not Bridge.AddMoney(src, Config.Account, pay, 'pop_livraison') then
        log('AddMoney failed src=%s pay=%d (standalone?)', src, pay)
    end
    Bridge.Notify(src, L('delivered', pay), 'success')
    log('delivered src=%s index=%d pay=%d', src, run.index - 1, pay)

    local index = run.index
    if index > #run.dests then
        if run.withVehicle then
            Bridge.Notify(src, L('return_van'), 'info')
        else
            local done = closeRun(src, false)
            Bridge.Notify(src, L('run_completed', done and done.paid or 0), 'success')
        end
    end
    return true, nil, nil, index
end

local function finish(src)
    local run = runs[src]
    if not run or not run.withVehicle then return false, 'no_run' end
    if run.index <= #run.dests then return false, 'run_not_done' end
    if not Bridge.IsNear(src, Config.Depot.coords, ACTION_DISTANCE) then return false, 'too_far' end

    local veh = run.vehicle
    local intact = vehicleOk(veh)
    -- NOTE: camionnette intacte mais loin du point de spawn → refus (tournée conservée) plutôt que caution perdue.
    if intact and #(GetEntityCoords(veh) - toVec3(Config.Vehicle.spawn)) > RETURN_DISTANCE then
        return false, 'vehicle_too_far'
    end

    local done = closeRun(src, false)
    if not done then return false, 'no_run' end
    if intact and done.deposit > 0 then
        Bridge.AddMoney(src, Config.Account, done.deposit, 'pop_livraison')
        Bridge.Notify(src, L('deposit_returned', done.deposit), 'success')
    end
    Bridge.Notify(src, L('run_completed', done.paid), 'success')
    return true
end

local function cancel(src)
    if not runs[src] then return false, 'no_run' end
    if not Bridge.IsNear(src, Config.Depot.coords, ACTION_DISTANCE) then return false, 'too_far' end
    closeRun(src, false)
    Bridge.Notify(src, L('run_cancelled'), 'info')
    return true
end

Callback.Register('pop_livraison:start', function(src, withVehicle)
    return locked(src, start, withVehicle)
end)

Callback.Register('pop_livraison:deliver', function(src)
    return locked(src, deliver)
end)

Callback.Register('pop_livraison:finish', function(src)
    return locked(src, finish)
end)

Callback.Register('pop_livraison:cancel', function(src)
    return locked(src, cancel)
end)

------------------------------------------------------------------------
-- Départ, changement de personnage, arrêt
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src)
    closeRun(src, false)
    busy[src] = nil
end)

Bridge.OnPlayerUnloaded(function(src)
    closeRun(src) -- event sans raison : le client nettoie sans notification
    busy[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for src, run in pairs(runs) do
        runs[src] = nil
        deleteVehicle(run.vehicle)
        takeKey(src, run.plate)
    end
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('IsOnRun', function(src)
    return runs[tonumber(src)] ~= nil
end)

exports('GetRun', function(src)
    local run = runs[tonumber(src)]
    if not run then return nil end
    return {
        index = run.index,
        total = #run.dests,
        timeLeft = math.max(0, run.expiresAt - os.time()),
        paid = run.paid,
    }
end)
