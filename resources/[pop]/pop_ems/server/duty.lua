-- pop_ems : service, vestiaire, garage et nettoyage au départ d'un joueur.

local spawning = {} -- [src] = true pendant la création d'un véhicule (anti double appel)

local function station(index)
    return math.type(index) == 'integer' and Config.Stations[index] or nil
end

------------------------------------------------------------------------
-- Prendre / finir le service (vestiaire)
------------------------------------------------------------------------

Callback.Register('pop_ems:setDuty', function(src, stationIndex, state)
    local st = station(stationIndex)
    if not st or type(state) ~= 'boolean' then return false, 'error' end
    if not Ems.isMedic(src) then return false, 'wrong_job' end
    if not Bridge.IsNear(src, st.locker, Config.Distances.zone + 1.0) then return false, 'too_far' end

    if state then
        Ems.duty[src] = stationIndex
        Player(src).state:set('popEmsDuty', true, true)
        Ems.setFrameworkDuty(src, true)
        Ems.sendCalls(src, nil) -- appels déjà ouverts
        Ems.log('%s on duty (station %d)', src, stationIndex)
    else
        Ems.endDuty(src, false)
    end
    return true, state
end)

------------------------------------------------------------------------
-- Garage
------------------------------------------------------------------------

-- Vrai si un véhicule (autre que `ignore`) est à moins de 3 m de la place de sortie.
local function spawnBlocked(spawn, ignore)
    local pos = vector3(spawn.x, spawn.y, spawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if veh ~= ignore and DoesEntityExist(veh) and #(GetEntityCoords(veh) - pos) < 3.0 then
            return true
        end
    end
    return false
end

Callback.Register('pop_ems:spawnVehicle', function(src, stationIndex, vehicleIndex)
    local st = station(stationIndex)
    local vehicle = math.type(vehicleIndex) == 'integer' and Config.Vehicles[vehicleIndex] or nil
    if not st or not vehicle then return false, 'error' end
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    if spawning[src] then return false, 'busy' end
    if not Bridge.IsNear(src, st.garage, Config.Distances.zone + 1.0) then return false, 'too_far' end

    -- L'ancien véhicule du joueur ne bloque pas sa propre place : il va être remplacé.
    local old = Ems.vehicles[src] and NetworkGetEntityFromNetworkId(Ems.vehicles[src]) or 0
    if spawnBlocked(st.spawn, old) then return false, 'spawn_blocked' end

    spawning[src] = true
    Ems.deleteVehicle(src)

    local s = st.spawn
    local veh = CreateVehicleServerSetter(joaat(vehicle.model), 'automobile', s.x, s.y, s.z, s.w)
    local timeout = GetGameTimer() + 3000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < timeout do
        Wait(50)
    end
    spawning[src] = nil

    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'error' end

    -- Le joueur a pu partir ou quitter le service pendant l'attente.
    if not Ems.duty[src] or not GetPlayerName(src) then
        DeleteEntity(veh)
        return false, 'not_on_duty'
    end

    SetVehicleDoorsLocked(veh, 1)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    Ems.vehicles[src] = netId
    Ems.log('%s spawned %s (net %d)', src, vehicle.model, netId)
    return true, netId
end)

Callback.Register('pop_ems:returnVehicle', function(src)
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    local netId = Ems.vehicles[src]
    local veh = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if veh == 0 or not DoesEntityExist(veh) then
        Ems.vehicles[src] = nil
        return false, 'no_vehicle'
    end
    local pos = Bridge.GetCoords(src)
    if not pos or #(pos - GetEntityCoords(veh)) > 10.0 then return false, 'no_vehicle' end
    if Ems.patientInVehicle(netId) or Entity(veh).state.popEmsPatient ~= nil then return false, 'patient_busy' end
    Ems.deleteVehicle(src)
    return true
end)

------------------------------------------------------------------------
-- Nettoyage : départ d'un joueur (déconnexion ou retour au choix du personnage)
------------------------------------------------------------------------

local function onLeave(src)
    src = math.tointeger(tonumber(src))
    if not src then return end
    local changed = false

    -- Comme patient : appel et transport libérés.
    if Ems.closeCallOf(src) then changed = true end
    if Ems.transported[src] then Ems.releaseTransport(src, false) end

    -- Comme secouriste : service, véhicule, appels pris, action en cours.
    Ems.endDuty(src, false)
    if Ems.releaseCallsOf(src) then changed = true end
    Ems.actions[src] = nil
    Ems.lastAction[src] = nil
    spawning[src] = nil

    if changed then Ems.broadcastCalls(nil) end
end

Bridge.OnPlayerDropped(onLeave)
Bridge.OnPlayerUnloaded(onLeave)

-- Arrêt de la ressource : aucun véhicule fantôme.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, netId in pairs(Ems.vehicles) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
    end
    -- Statebags posés par pop_ems remis à zéro (le client détache lui-même son patient à l'arrêt).
    for patient in pairs(Ems.transported) do
        if GetPlayerName(patient) then Player(patient).state:set('popEmsTransport', nil, true) end
    end
    for src in pairs(Ems.duty) do
        if GetPlayerName(src) then Player(src).state:set('popEmsDuty', false, true) end
    end
end)
