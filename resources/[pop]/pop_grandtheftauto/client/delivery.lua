local convoy = {}
local truckModelName = 'mule2'
local pedModelName = 'a_m_m_mexlabor_01'
local MAX_REVERSE_DIST = 6.5

local randomDestinations = Config.Positions.TruckLeaveTo

-- ============================================================
-- FONCTIONS DE SYNCHRO
-- ============================================================


local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- Porte arrière du camion (relayée aux coéquipiers)
AddEventHandler('mission:client:syncTruckDoor', function(netId, state)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if state == 'open' then SetVehicleDoorOpen(veh, 5, false, false) else SetVehicleDoorShut(veh, 5, false) end
end)

-- ============================================================
-- LOGIQUE DE DÉPART ET SUPPRESSION FINALE
-- ============================================================
local function StartTruckJourney(group)
    local ped = group.driver
    local veh = group.vehicle
    if not DoesEntityExist(ped) or not DoesEntityExist(veh) then return end

    if group.blip and DoesBlipExist(group.blip) then RemoveBlip(group.blip) end

    -- Fermeture impérative de la porte (Synchro + Locale)
    Wait(5000)
    if not DoesEntityExist(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    Relay("event", { name = "mission:client:syncTruckDoor", args = { netId, "close" } }, true)
    SetVehicleDoorShut(veh, 5, false)

    SetVehicleHandbrake(veh, false)
    SetVehicleEngineOn(veh, true, true, false)

    CreateThread(function()
        -- Le chauffeur monte et s'assure que la porte est bien fermée
        TaskEnterVehicle(ped, veh, 12000, -1, 1.0, 16, 0)
        local timeout = GetGameTimer() + 10000
        while DoesEntityExist(ped) and not IsPedInVehicle(ped, veh, false) and GetGameTimer() < timeout do Wait(500) end
        if not DoesEntityExist(ped) or not DoesEntityExist(veh) then return end
        if not IsPedInVehicle(ped, veh, false) then TaskWarpPedIntoVehicle(ped, veh, -1) end

        SetVehicleDoorShut(veh, 5, false)
        Wait(1000)

        -- Phase de recul (8 s max)
        local startCoords = GetEntityCoords(veh)
        local limit = GetGameTimer() + 8000
        while DoesEntityExist(veh) and #(startCoords - GetEntityCoords(veh)) < MAX_REVERSE_DIST and GetGameTimer() < limit do
            TaskVehicleTempAction(ped, veh, 28, 500)
            Wait(250)
        end

        ClearPedTasks(ped)
        Wait(1000)

        -- Trajet vers la destination
        local destination = randomDestinations[math.random(#randomDestinations)]
        TaskVehicleDriveToCoord(ped, veh, destination.x, destination.y, destination.z, 20.0, 0, GetEntityModel(veh), 786603, 5.0, true)

        -- Supprime le camion une fois arrivé, loin du joueur, ou après 3 min
        local endAt = GetGameTimer() + 180000
        while true do
            Wait(5000)
            if not DoesEntityExist(veh) then break end
            local coords = GetEntityCoords(veh)
            if #(coords - destination) < 10.0 or #(coords - GetEntityCoords(PlayerPedId())) > 150.0 or GetGameTimer() > endAt then
                if DoesEntityExist(ped) then DeleteEntity(ped) end
                DeleteEntity(veh)
                break
            end
        end
        for i, g in ipairs(convoy) do
            if g == group then table.remove(convoy, i) break end
        end
    end)
end

-- ============================================================
-- SPAWN DU CAMION (emplacement attribué par le serveur)
-- ============================================================
RegisterNetEvent('mission:client:receiveDeliverySlot')
AddEventHandler('mission:client:receiveDeliverySlot', function(slotIndex)
    if not slotIndex then
        MissionNotify(L('truck_busy'), 7000)
        return
    end

    local selectedSlot = Config.DeliverySlots[slotIndex]
    if not selectedSlot then return end

    local truckModel = LoadModel(truckModelName)
    local pedModel = LoadModel(pedModelName)
    if not truckModel or not pedModel then return end

    local veh = CreateVehicle(truckModel, selectedSlot.pos.x, selectedSlot.pos.y, selectedSlot.pos.z, selectedSlot.heading, true, true)
    local ped = CreatePed(4, pedModel, selectedSlot.pos.x - 2.0, selectedSlot.pos.y, selectedSlot.pos.z + 0.5, selectedSlot.heading, true, true)
    SetModelAsNoLongerNeeded(truckModel)
    SetModelAsNoLongerNeeded(pedModel)

    if DoesEntityExist(veh) and DoesEntityExist(ped) then
        SetEntityInvincible(veh, true)
        SetEntityCanBeDamaged(veh, false)
        SetVehicleDoorBreakable(veh, 5, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        local truckBlip = AddBlipForEntity(veh)
        SetBlipSprite(truckBlip, 477)
        SetBlipColour(truckBlip, 2)
        SetBlipScale(truckBlip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(L('blip_truck'))
        EndTextCommandSetBlipName(truckBlip)
        -- Itinéraire jusqu'au camion
        Guide.ClearRoute()
        SetBlipRoute(truckBlip, true)
        SetBlipRouteColour(truckBlip, 5)
        TriggerEvent('mission:local:guide', 'truck')
        Debug(('camion de livraison prêt (emplacement %d)'):format(slotIndex))

        SetVehicleDoorOpen(veh, 5, false, false)
        table.insert(convoy, { vehicle = veh, driver = ped, isLoaded = false, blip = truckBlip, slot = slotIndex, nextTry = 0 })
        MissionNotify(L('truck_ready'), 7000)
    end
end)

-- ============================================================
-- DÉTECTION CHARGEMENT (seulement les sportives Benefactor, validées par le serveur)
-- ============================================================
local PendingDelivery = {}
RegisterNetEvent('mission:client:deliveredResult')
AddEventHandler('mission:client:deliveredResult', function(slotIndex, ok)
    if slotIndex then PendingDelivery[slotIndex] = { ok = ok == true } end
end)

local function FindStolenCarNear(pos, radius)
    for _, veh in ipairs(GetGamePool("CVehicle")) do
        local plate = trim(GetVehicleNumberPlateText(veh))
        if plate:find("BEN") and #(GetEntityCoords(veh) - pos) < radius then
            return veh
        end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(1000)
        for _, group in ipairs(convoy) do
            if group and not group.isLoaded and DoesEntityExist(group.vehicle) and GetGameTimer() > group.nextTry then
                local backPos = GetOffsetFromEntityInWorldCoords(group.vehicle, 0.0, -3.5, 0.0)
                local stolen = FindStolenCarNear(backPos, 3.5)

                if stolen then
                    group.isLoaded = true
                    PendingDelivery[group.slot] = nil
                    TriggerServerEvent('mission:server:delivered', NetworkGetNetworkIdFromEntity(stolen), group.slot)

                    local limit = GetGameTimer() + 5000
                    while not PendingDelivery[group.slot] and GetGameTimer() < limit do Wait(100) end
                    local res = PendingDelivery[group.slot]
                    PendingDelivery[group.slot] = nil

                    if res and res.ok then
                        MissionNotify(L('delivered'), 7000)
                        StartTruckJourney(group)
                    else
                        -- Refusé (voiture non piratée, déjà livrée...) : on réessaiera plus tard
                        group.isLoaded = false
                        group.nextTry = GetGameTimer() + 5000
                    end
                end
            end
        end
    end
end)

-- (Commande de test /test_livraison retirée.)

-- ============================================================
-- FIN DE MISSION / ARRÊT : suppression des camions restants
-- ============================================================
local function ClearConvoy()
    for _, group in ipairs(convoy) do
        if group.blip and DoesBlipExist(group.blip) then RemoveBlip(group.blip) end
        if DoesEntityExist(group.driver) then DeleteEntity(group.driver) end
        if DoesEntityExist(group.vehicle) then DeleteEntity(group.vehicle) end
    end
    convoy = {}
end

AddEventHandler('mission:local:reset', ClearConvoy)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ClearConvoy() end
end)
