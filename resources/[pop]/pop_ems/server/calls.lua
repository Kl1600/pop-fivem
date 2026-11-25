-- pop_ems : appels d'urgence (création, prise, fermeture automatique).

local lastCallId = 0
local loopRunning = false

------------------------------------------------------------------------
-- Boucle de fermeture : un seul thread, actif seulement s'il y a des appels ou des transports.
------------------------------------------------------------------------

local function shouldClose(c)
    local patient = c.patient
    if not GetPlayerName(patient) then return true end
    if not Ems.isDead(patient) then return true end
    if os.time() - c.time > Config.Calls.expire then return true end
    if c.status == 'taken' and c.medic then
        local medicPos = Bridge.GetCoords(c.medic)
        local target = Bridge.GetCoords(patient) or c.coords
        if medicPos and target and #(medicPos - target) < Config.Calls.arrive then return true end
    end
    return false
end

local function tick()
    local changed = false
    for id, c in pairs(Ems.calls) do
        if shouldClose(c) then
            Ems.calls[id] = nil
            changed = true
            Ems.log('call #%d closed', id)
        end
    end
    -- Transport libéré si l'ambulance n'existe plus.
    for patient, t in pairs(Ems.transported) do
        local veh = NetworkGetEntityFromNetworkId(t.vehicle)
        if not veh or veh == 0 or not DoesEntityExist(veh) then
            Ems.releaseTransport(patient, true)
        end
    end
    if changed then Ems.broadcastCalls(nil) end
end

--- Démarre la boucle si elle ne tourne pas déjà.
function Ems.ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while next(Ems.calls) ~= nil or next(Ems.transported) ~= nil do
            Wait(10000)
            tick()
        end
        loopRunning = false
    end)
end

------------------------------------------------------------------------
-- Création d'un appel (pop_death ou export)
------------------------------------------------------------------------

--- Crée (ou met à jour) l'appel du patient. Renvoie l'id de l'appel, ou nil.
function Ems.createCall(src, coords)
    src = math.tointeger(tonumber(src))
    if not src or not GetPlayerName(src) then return nil end
    if type(coords) ~= 'vector3' then coords = Bridge.GetCoords(src) end
    if not coords then return nil end

    if Ems.dutyCount() == 0 then
        Bridge.Notify(src, L('no_medic_available'), 'warning')
        return nil
    end

    -- Un seul appel ouvert par patient : on met à jour la position et l'heure.
    for id, c in pairs(Ems.calls) do
        if c.patient == src then
            c.coords, c.time = coords, os.time()
            Ems.broadcastCalls(c.status == 'pending' and id or nil)
            return id
        end
    end

    lastCallId = lastCallId + 1
    local id = lastCallId
    Ems.calls[id] = { id = id, patient = src, coords = coords, time = os.time(), status = 'pending' }
    Ems.broadcastCalls(id)
    Ems.ensureLoop()
    Ems.log('call #%d created for %s', id, src)
    return id
end

-- NOTE: AddEventHandler uniquement (jamais RegisterNetEvent) : un client ne peut pas créer d'appel.
AddEventHandler('pop_death:emsCalled', function(src, coords)
    Ems.createCall(src, coords)
end)

exports('createCall', function(src, coords)
    return Ems.createCall(src, coords)
end)

------------------------------------------------------------------------
-- Prise d'un appel
------------------------------------------------------------------------

Callback.Register('pop_ems:acceptCall', function(src, callId)
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    if math.type(callId) ~= 'integer' then return false, 'error' end
    local call = Ems.calls[callId]
    if not call then return false, 'call_none' end
    if call.status ~= 'pending' then return false, 'call_already_taken' end

    -- Un seul appel pris par secouriste : l'ancien repasse en attente.
    Ems.releaseCallsOf(src)
    call.status = 'taken'
    call.medic = src
    call.medicName = Bridge.GetName(src) or GetPlayerName(src)

    Bridge.Notify(call.patient, L('call_accepted_patient'), 'info')
    Ems.broadcastCalls(nil)
    Ems.log('call #%d taken by %s', callId, src)
    return true, callId
end)
