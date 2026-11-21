local ped
Citizen.CreateThread(function()
    while 1 do
        ped = PlayerPedId()
        Wait(5000)
    end
end)

spawned = nil

-- ============================================================
-- SYNCHRO (COOP)
-- Objectif:
--  - Solo: aucune différence.
--  - Multi: un seul joueur (owner) spawn les voitures showroom,
--    et les autres clients reçoivent les NetID.
-- ============================================================

local function EnsureMissionSync()
    _G.MissionSync = _G.MissionSync or {
        active = false,
        id = nil,
        owner = nil,
        isOwner = false,
        entities = {},
        flags = {}
    }
    return _G.MissionSync
end

local function IsCoopActive()
    local MS = EnsureMissionSync()
    return MS.active == true
end

local function IsOwner()
    local MS = EnsureMissionSync()
    if not MS.active then return true end
    return MS.isOwner == true
end

-- Expose Cars global comme avant (utile pour crack.lua qui check _G.Cars)
_G.Cars = Cars

-- Handlers de réception NetID des voitures showroom
local function RegisterShowroomEntityHandlers()
    for i = 1, #Cars do
        local key = 'showroom_car_' .. i
        AddEventHandler('mission:entity:' .. key, function(payload)
            local netId = payload
            if type(payload) == "table" then
                netId = payload.netId or payload.id or payload.net
            end
            if not netId then return end

            local veh = NetToVeh(netId)
            if veh and DoesEntityExist(veh) then
                Cars[i].spawned = veh
            end
        end)
    end
end
RegisterShowroomEntityHandlers()

AddEventHandler('startheist', function(res)
    -- Coop: seul l'owner spawn. Les autres attendent les NetID.
    if IsCoopActive() and not IsOwner() then
        return
    end

    for i = 1, #Cars do
        SpawnLocalCar(i)
    end
end)

Citizen.CreateThread(function()
    while 1 do
        -- Coop: un seul contrôleur doit faire tourner les véhicules
        if IsCoopActive() and not IsOwner() then
            Wait(250)
        else
            for i = 1, #Cars do
                if Cars[i].spawned ~= nil and Cars[i].spin then
                    SetEntityHeading(Cars[i].spawned, GetEntityHeading(Cars[i].spawned) - 0.3)
                end
            end
            Wait(5)
        end
    end
end)

function SpawnLocalCar(i)
    Citizen.CreateThread(function()
        local hash = GetHashKey(Cars[i].model)
        RequestModel(hash)
        local attempt = 0
        while not HasModelLoaded(hash) do
            attempt = attempt + 1
            if attempt > 2000 then return end
            Wait(0)
        end

        -- Spawn vehicle (Mis en réseau avec 'true' pour que la police voit le GPS)
        local veh = CreateVehicle(hash, Cars[i].pos.x, Cars[i].pos.y, Cars[i].pos.z - 1, Cars[i].heading, true, false)
        SetModelAsNoLongerNeeded(hash)

        -- Configuration réseau
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetEntityAsMissionEntity(veh, true, true)

        SetVehicleDamage(veh, 0, 0, 0)

        local primaryColor = math.random(0, 159)
        local secondaryColor = math.random(0, 159)
        SetVehicleColours(veh, primaryColor, secondaryColor)
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleNumberPlateText(veh, Cars[i].plate)

        Cars[i].spawned = veh
        vehcoords = GetEntityCoords(veh, true)

        -- Coop: envoi NetID à tous
        if IsCoopActive() then
            TriggerServerEvent('mission:server:registerEntity', 'showroom_car_' .. i, { netId = netId, idx = i })
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    -- Coop: seul l'owner nettoie réellement
    if IsCoopActive() and not IsOwner() then
        return
    end

    for i = 1, #Cars do
        if Cars[i].spawned ~= nil then
            DeleteEntity(Cars[i].spawned)
        end
    end
end)

RegisterNetEvent('mission:setupBlips')
AddEventHandler('mission:setupBlips', function()
    for i = 1, #Cars do
        if Cars[i].spawned ~= nil then
            local blipId = AddBlipForEntity(Cars[i].spawned)
            SetBlipSprite(blipId, 875)
            SetBlipScale(blipId, 0.5)
            SetBlipColour(blipId, 2)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString('Sportive Benefactor')
            EndTextCommandSetBlipName(blipId)

            Cars[i].blipId = blipId
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local playerPed = PlayerPedId()

        if IsPedInAnyVehicle(playerPed, false) then
            wait = 500
            local currentVeh = GetVehiclePedIsIn(playerPed, false)

            for i = 1, #Cars do
                if Cars[i].spawned == currentVeh and Cars[i].blipId ~= nil then
                    if DoesBlipExist(Cars[i].blipId) then
                        RemoveBlip(Cars[i].blipId)
                        Cars[i].blipId = nil
                    end
                end
            end
        end
        Wait(wait)
    end
end)
