-- pop_sabot : logique serveur. Aucune boucle, aucun event client -> serveur (callbacks uniquement).
-- Le serveur est le seul à écrire le statebag Clamp.STATE (réplication true).

local RES = GetCurrentResourceName()

local busy = {}       -- [src] = true pendant le traitement d'un callback
local cutStart = {}   -- [src] = { netId = int, t = GetGameTimer() } pendant une découpe
local clampedNet = {} -- [netId] = true : référence serveur (le statebag n'en est que la copie répliquée)

local CUT_GRACE = 10000 -- ms : une découpe commencée expire après Config.Durations.cut + 10 s

-- NOTE: SPEC ne prévoit pas de clé webhook ; les actions sensibles sont journalisées en console si Config.Debug.
local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

-- Description courte d'un joueur pour les logs (calculée seulement si Config.Debug).
local function who(src)
    if not Config.Debug then return '' end
    return ('%s (%s, %s)'):format(tostring(src), tostring(Bridge.GetName(src)), tostring(Bridge.GetIdentifier(src)))
end

-- Agent autorisé : job de Config.Jobs et en service.
local function isAgent(src)
    if not Bridge.HasJob(src, Config.Jobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

-- Véhicule existant pour ce netId (entier), sinon nil.
local function getVehicle(netId)
    if math.type(netId) ~= 'integer' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function isClamped(netId)
    return clampedNet[netId] == true
end

-- Pose (true) ou retire (false) le sabot : table de référence, puis statebag répliqué.
-- FreezeEntityPosition côté serveur est seulement demandé au propriétaire actuel du véhicule ;
-- le gel est ensuite maintenu par les clients (boucle du propriétaire). Retirer ne dégèle que si sabot.
local function setClamp(veh, netId, state)
    if state then
        clampedNet[netId] = true
    else
        if not clampedNet[netId] then return end
        clampedNet[netId] = nil
    end
    Entity(veh).state:set(Clamp.STATE, state and true or nil, true)
    FreezeEntityPosition(veh, state == true)
end

-- Un client ne peut pas modifier l'état : toute valeur différente de la référence est rétablie.
AddStateBagChangeHandler(Clamp.STATE, nil, function(bagName, _, value)
    local netId = tonumber(bagName:match('^entity:(%d+)$'))
    if not netId then return end
    local expected = clampedNet[netId] or nil
    if value == expected then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    Entity(veh).state:set(Clamp.STATE, expected, true)
    log('statebag %s restored on vehicle %d (client wrote %s)', tostring(expected), netId, tostring(value))
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId then clampedNet[netId] = nil end
end)

local function plate(veh)
    if not Config.Debug then return '' end
    return GetVehicleNumberPlateText(veh) or '?'
end

------------------------------------------------------------------------
-- Contrôles communs aux 3 callbacks (SPEC §12) puis handler(src, veh, netId, ...)
------------------------------------------------------------------------

local function register(name, handler)
    Callback.Register(name, function(src, netId, ...)
        local veh = getVehicle(netId)
        if not veh then return false, 'no_vehicle' end
        if not Bridge.IsNear(src, GetEntityCoords(veh), Clamp.ACTION_DISTANCE) then return false, 'too_far' end
        if busy[src] then return false, 'busy' end

        busy[src] = true
        local res = table.pack(pcall(function(...)
            if Bridge.IsDead(src) or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then
                return false, 'error'
            end
            return handler(src, veh, netId, ...)
        end, ...))
        busy[src] = nil -- libéré dans tous les cas

        if not res[1] then
            print(('[%s] %s error: %s'):format(RES, name, tostring(res[2])))
            return false, 'error'
        end
        return table.unpack(res, 2, res.n)
    end)
end

------------------------------------------------------------------------
-- Item utilisable : rien n'est retiré ici, seulement l'ordre de lancer la pose
------------------------------------------------------------------------

Bridge.RegisterUsableItem(Config.Items.clamp, function(src)
    if not isAgent(src) then
        Bridge.Notify(src, L('wrong_job'), 'error')
        return
    end
    TriggerClientEvent('pop_sabot:client:startPlace', src)
end)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

register('pop_sabot:place', function(src, veh, netId)
    if not isAgent(src) then return false, 'wrong_job' end
    if isClamped(netId) then return false, 'already_clamped' end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return false, 'vehicle_occupied' end
    if not Bridge.RemoveItem(src, Config.Items.clamp, 1) then
        return false, 'missing_item', L('item_clamp')
    end

    setClamp(veh, netId, true)
    Bridge.Notify(src, L('placed'), 'success')
    log('place: %s clamped vehicle %d [%s]', who(src), netId, plate(veh))
    return true
end)

register('pop_sabot:remove', function(src, veh, netId)
    if not isAgent(src) then return false, 'wrong_job' end
    if not isClamped(netId) then return false, 'not_clamped' end

    setClamp(veh, netId, false)
    -- Statebag effacé avant de rendre l'item : un second appel tombe sur not_clamped (jamais de doublon).
    local given = Bridge.AddItem(src, Config.Items.clamp, 1)
    Bridge.Notify(src, L('removed'), 'success')
    if not given then Bridge.Notify(src, L('inventory_full'), 'warning') end
    log('remove: %s unclamped vehicle %d [%s] (item returned: %s)', who(src), netId, plate(veh), tostring(given))
    return true
end)

register('pop_sabot:cut', function(src, veh, netId, phase)
    if phase ~= 'start' and phase ~= 'finish' then return false, 'error' end
    if Config.Items.cutter == nil then return false, 'error' end
    if not isClamped(netId) then return false, 'not_clamped' end
    if not Bridge.HasItem(src, Config.Items.cutter) then
        return false, 'missing_item', L('item_cutter')
    end

    local now = GetGameTimer()
    local duration = tonumber(Config.Durations.cut) or 20000

    if phase == 'start' then
        local prev = cutStart[src]
        -- NOTE: anti-spam des alertes : pas de nouvelle alerte si la même découpe a été lancée il y a moins
        -- de Config.Durations.cut (relancer la découpe remet tout de même le chrono à zéro).
        local realert = not (prev and prev.netId == netId and now - prev.t < duration)
        cutStart[src] = { netId = netId, t = now }

        if Config.CutAlert and realert then
            local c = GetEntityCoords(veh)
            local coords = { x = c.x, y = c.y, z = c.z }
            for _, p in ipairs(Bridge.GetPlayers()) do
                if Bridge.HasJob(p, Config.PoliceJobs) then
                    local job = Bridge.GetJob(p)
                    if job and job.onDuty then
                        TriggerClientEvent('pop_sabot:client:cutAlert', p, coords)
                    end
                end
            end
        end
        log('cut start: %s on vehicle %d [%s]', who(src), netId, plate(veh))
        return true
    end

    -- finish : commencée sur ce véhicule, depuis assez longtemps (1 s de marge), et pas expirée.
    local started = cutStart[src]
    local elapsed = started and now - started.t
    if not started or started.netId ~= netId or elapsed < duration - 1000 or elapsed > duration + CUT_GRACE then
        if started and elapsed > duration + CUT_GRACE then cutStart[src] = nil end
        log('cut finish refused: %s on vehicle %d (too early, expired or not started)', who(src), netId)
        return false, 'error'
    end

    cutStart[src] = nil
    setClamp(veh, netId, false) -- aucun item rendu : le sabot est détruit
    Bridge.Notify(src, L('cut'), 'success')
    log('cut finish: %s cut the clamp of vehicle %d [%s]', who(src), netId, plate(veh))
    return true
end)

------------------------------------------------------------------------
-- Exports publics (ni job ni item)
------------------------------------------------------------------------

-- Les autres ressources peuvent passer un netId flottant (ex. 12.0) : converti en entier si exact.
local function toNetId(v)
    local n = tonumber(v)
    return n and math.tointeger(n) or nil
end

exports('IsClamped', function(netId)
    local id = toNetId(netId)
    return getVehicle(id) ~= nil and isClamped(id)
end)

exports('SetClamped', function(netId, state)
    local id = toNetId(netId)
    local veh = getVehicle(id)
    if not veh then return false end
    setClamp(veh, id, state == true)
    log('export SetClamped(%d, %s) by %s', id, tostring(state == true), tostring(GetInvokingResource()))
    return true
end)

------------------------------------------------------------------------
-- Nettoyage par joueur
------------------------------------------------------------------------

local function cleanup(src)
    busy[src] = nil
    cutStart[src] = nil
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
