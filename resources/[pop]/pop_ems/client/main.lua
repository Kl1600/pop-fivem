-- pop_ems : client. État local (service), vestiaire et tenue, garage, blips des hôpitaux,
-- exports client et nettoyage. Le serveur décide de tout : le client affiche et demande.

Ems = {
    onDuty = false,
    station = nil,
    busy = false, -- une requête serveur à la fois
}

local dutyHooks = {}     -- fn(state) appelées à chaque changement de service
local stationBlips = {}
local civilOutfit = nil  -- [component] = { drawable, texture }
local jobName = nil      -- cache du job (canInteract est appelé souvent par les targets)
local zonesAdded = false

local VEHICLE_HASHES = {}
for _, v in ipairs(Config.Vehicles) do VEHICLE_HASHES[joaat(v.model)] = true end
Ems.vehicleHashes = VEHICLE_HASHES

------------------------------------------------------------------------
-- Helpers partagés entre les fichiers client
------------------------------------------------------------------------

--- fn(state) à chaque prise (true) / fin (false) de service.
function Ems.OnDuty(fn)
    dutyHooks[#dutyHooks + 1] = fn
end

--- Affiche l'erreur renvoyée par le serveur (clé de locale). item = nom d'objet pour missing_item.
function Ems.NotifyError(key, item)
    if type(key) ~= 'string' then key = 'error' end
    if key == 'missing_item' then
        Bridge.Notify(L(key, tostring(item or '')), 'error')
    else
        Bridge.Notify(L(key), 'error')
    end
end

--- Appelle un callback serveur (dans un thread), une requête à la fois. Renvoie ok, data.
function Ems.Request(name, ...)
    if Ems.busy then return false, 'busy' end
    Ems.busy = true
    local ok, data = Callback.Await(name, ...)
    Ems.busy = false
    if ok == nil then return false, 'error' end
    return ok == true, data
end

--- Ambulance de service la plus proche de coords (à moins de maxDist m), ou nil.
function Ems.NearestAmbulance(coords, maxDist)
    local best, bestDist = nil, maxDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if VEHICLE_HASHES[GetEntityModel(veh)] then
            local d = #(coords - GetEntityCoords(veh))
            if d <= bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

local function isMedicJob()
    -- Standalone : ACE vérifiée par le serveur, on affiche les options.
    if Bridge.Framework == 'standalone' then return true end
    return jobName == Config.Job.name
end
Ems.IsMedicJob = isMedicJob

------------------------------------------------------------------------
-- Tenue
------------------------------------------------------------------------

local function outfitForPed(ped)
    local female = GetEntityModel(ped) == joaat('mp_f_freemode_01')
    return female and Config.Outfits.female or Config.Outfits.male
end

local function applyServiceOutfit()
    local ped = PlayerPedId()
    local outfit = outfitForPed(ped)
    civilOutfit = {}
    for comp in pairs(outfit) do
        civilOutfit[comp] = { GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp) }
    end
    for comp, v in pairs(outfit) do
        SetPedComponentVariation(ped, comp, v[1], v[2], 0)
    end
end

local function restoreCivilOutfit()
    if not civilOutfit then return end
    local ped = PlayerPedId()
    for comp, v in pairs(civilOutfit) do
        SetPedComponentVariation(ped, comp, v[1], v[2], 0)
    end
    civilOutfit = nil
end

------------------------------------------------------------------------
-- Service
------------------------------------------------------------------------

local function setLocalDuty(state, stationIndex)
    if Ems.onDuty == state then return end
    Ems.onDuty = state
    Ems.station = state and stationIndex or nil
    if state then applyServiceOutfit() else restoreCivilOutfit() end
    for _, fn in ipairs(dutyHooks) do
        local ok, err = pcall(fn, state)
        if not ok and Config.Debug then print(('[pop_ems] duty hook error: %s'):format(err)) end
    end
end

local function requestDuty(stationIndex, state)
    local ok, data = Ems.Request('pop_ems:setDuty', stationIndex, state)
    if not ok then return Ems.NotifyError(data) end
    local newState = data == true
    setLocalDuty(newState, stationIndex)
    Bridge.Notify(L(newState and 'duty_on' or 'duty_off'), newState and 'success' or 'info')
end

RegisterNetEvent('pop_ems:client:dutyOff', function()
    if not Ems.onDuty then return end
    setLocalDuty(false)
    Bridge.Notify(L('duty_off'), 'info')
end)

------------------------------------------------------------------------
-- Garage
------------------------------------------------------------------------

local function takeVehicle(stationIndex, vehicleIndex)
    local ok, netId = Ems.Request('pop_ems:spawnVehicle', stationIndex, vehicleIndex)
    if not ok then return Ems.NotifyError(netId) end
    local timeout = GetGameTimer() + 3000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < timeout do Wait(50) end
    if NetworkDoesEntityExistWithNetworkId(netId) then
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh ~= 0 and DoesEntityExist(veh) then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
    end
    Bridge.Notify(L('vehicle_out'), 'success')
end

local function returnVehicle()
    local ok, data = Ems.Request('pop_ems:returnVehicle')
    if not ok then return Ems.NotifyError(data) end
    Bridge.Notify(L('vehicle_returned'), 'success')
end

------------------------------------------------------------------------
-- Zones et blips (au chargement)
------------------------------------------------------------------------

local ZONE_SIZE = vec3(2.0, 2.0, 2.0)

local function addStationZones()
    for i, station in ipairs(Config.Stations) do
        Bridge.Target.AddBoxZone(('pop_ems_locker_%d'):format(i), station.locker, ZONE_SIZE, 0.0, {
            {
                label = L('duty_on_label'), icon = 'fas fa-shirt', distance = Config.Distances.zone,
                canInteract = function() return isMedicJob() and not Ems.onDuty end,
                onSelect = function() requestDuty(i, true) end,
            },
            {
                label = L('duty_off_label'), icon = 'fas fa-shirt', distance = Config.Distances.zone,
                canInteract = function() return isMedicJob() and Ems.onDuty end,
                onSelect = function() requestDuty(i, false) end,
            },
        })

        local options = {}
        for v, vehicle in ipairs(Config.Vehicles) do
            options[#options + 1] = {
                label = L('garage_take', vehicle.label), icon = 'fas fa-truck-medical', distance = Config.Distances.zone,
                canInteract = function() return isMedicJob() and Ems.onDuty end,
                onSelect = function() takeVehicle(i, v) end,
            }
        end
        options[#options + 1] = {
            label = L('garage_return'), icon = 'fas fa-square-parking', distance = Config.Distances.zone,
            canInteract = function() return isMedicJob() and Ems.onDuty end,
            onSelect = returnVehicle,
        }
        Bridge.Target.AddBoxZone(('pop_ems_garage_%d'):format(i), station.garage, ZONE_SIZE, 0.0, options)
    end
    zonesAdded = true
end

local function addStationBlips()
    if #stationBlips > 0 then return end
    local cfg = Config.Blips.station
    for _, station in ipairs(Config.Stations) do
        local blip = AddBlipForCoord(station.locker.x, station.locker.y, station.locker.z)
        SetBlipSprite(blip, cfg.sprite)
        SetBlipColour(blip, cfg.color)
        SetBlipScale(blip, cfg.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
        stationBlips[#stationBlips + 1] = blip
    end
end

Bridge.OnPlayerLoaded(function()
    jobName = Bridge.GetJob().name
    addStationBlips()
    if not zonesAdded then addStationZones() end
end)

Bridge.OnJobUpdate(function(job)
    jobName = job.name
end)

------------------------------------------------------------------------
-- Exports et nettoyage
------------------------------------------------------------------------

exports('isOnDuty', function() return Ems.onDuty end)
exports('getInjuries', function()
    if Ems.GetInjuries then return Ems.GetInjuries() end
    return { bleeding = false, limp = false }
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Ems.onDuty then restoreCivilOutfit() end
    for _, blip in ipairs(stationBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    stationBlips = {}
    SetNuiFocus(false, false)
end)
