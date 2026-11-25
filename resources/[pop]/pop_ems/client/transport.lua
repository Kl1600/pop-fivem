-- pop_ems : transport à l'hôpital. Côté secouriste : target ambulance (sortir le patient) et
-- zones d'admission (en service). Côté patient : attache / détache / admission.

local vehicleTarget = nil
local admitZones = {}
local attachedVeh = nil  -- véhicule auquel le patient (moi) est attaché
local admitting = false

local VEHICLE_MODELS = {}
for i, v in ipairs(Config.Vehicles) do VEHICLE_MODELS[i] = v.model end

------------------------------------------------------------------------
-- Secouriste
------------------------------------------------------------------------

local function unloadPatient(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local ok, data = Ems.Request('pop_ems:unloadPatient', NetworkGetNetworkIdFromEntity(veh))
    if not ok then return Ems.NotifyError(data) end
    Bridge.Notify(L('patient_unloaded'), 'success')
end

local function admit(stationIndex)
    local ok, data = Ems.Request('pop_ems:admit', stationIndex)
    if not ok then return Ems.NotifyError(data) end
    -- Le serveur notifie patient_admitted (avec le nom de l'hôpital).
end

local function addTargets()
    if vehicleTarget then return end
    vehicleTarget = Bridge.Target.AddModel(VEHICLE_MODELS, {
        {
            label = L('target_unload'), icon = 'fas fa-person-arrow-down-to-line', distance = Config.Distances.vehicle,
            canInteract = function(veh) return veh ~= nil and Entity(veh).state.popEmsPatient ~= nil end,
            onSelect = unloadPatient,
        },
    })
    for i, station in ipairs(Config.Stations) do
        local id = ('pop_ems_admit_%d'):format(i)
        Bridge.Target.AddBoxZone(id, station.dropoff, vec3(2.0, 2.0, 2.0), 0.0, {
            {
                label = L('target_admit'), icon = 'fas fa-hospital', distance = Config.Distances.zone,
                onSelect = function() admit(i) end,
            },
        })
        admitZones[#admitZones + 1] = id
    end
end

local function removeTargets()
    if vehicleTarget then Bridge.Target.Remove(vehicleTarget) end
    vehicleTarget = nil
    for _, id in ipairs(admitZones) do Bridge.Target.Remove(id) end
    admitZones = {}
end

Ems.OnDuty(function(state)
    if state then addTargets() else removeTargets() end
end)

------------------------------------------------------------------------
-- Patient
------------------------------------------------------------------------

--- Détache le joueur local s'il est dans une ambulance. place = le poser derrière le véhicule.
function Ems.DetachSelf(place)
    local ped = PlayerPedId()
    local veh = attachedVeh
    attachedVeh = nil
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    if place and veh and DoesEntityExist(veh) then
        local pos = GetOffsetFromEntityInWorldCoords(veh, 0.0, -4.0, 0.0)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    end
end

-- Pendant le transport seulement : si le patient revient à la vie par un autre moyen
-- (réapparition pop_death, admin...), on le détache. Wait long, thread arrêté à la descente.
local function watchTransport()
    CreateThread(function()
        while attachedVeh do
            Wait(1000)
            if not attachedVeh then break end
            local ped = PlayerPedId()
            if not admitting and (not DoesEntityExist(attachedVeh) or not IsEntityDead(ped)) then
                Ems.DetachSelf(false)
            end
        end
    end)
end

RegisterNetEvent('pop_ems:client:attach', function(vehicleNetId)
    if math.type(vehicleNetId) ~= 'integer' then return end
    local timeout = GetGameTimer() + 3000
    while not NetworkDoesEntityExistWithNetworkId(vehicleNetId) and GetGameTimer() < timeout do Wait(50) end
    if not NetworkDoesEntityExistWithNetworkId(vehicleNetId) then return end
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if veh == 0 or not DoesEntityExist(veh) then return end

    local ped = PlayerPedId()
    local off = Config.PatientOffset
    local wasWatching = attachedVeh ~= nil
    AttachEntityToEntity(ped, veh, 0, off.x, off.y, off.z, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
    attachedVeh = veh
    if not wasWatching then watchTransport() end
end)

RegisterNetEvent('pop_ems:client:detach', function()
    Ems.DetachSelf(true)
end)

RegisterNetEvent('pop_ems:client:admitted', function(bed)
    if type(bed) ~= 'vector4' and type(bed) ~= 'table' then return end
    admitting = true
    DoScreenFadeOut(800)
    local timeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(50) end

    Ems.DetachSelf(false)
    NetworkResurrectLocalPlayer(bed.x, bed.y, bed.z, bed.w, true, false)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, bed.x, bed.y, bed.z, false, false, false)
    SetEntityHeading(ped, bed.w)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    Ems.ClearInjuries()

    Wait(500)
    DoScreenFadeIn(800)
    admitting = false
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if attachedVeh then Ems.DetachSelf(false) end
    if admitting then DoScreenFadeIn(0) end
end)
