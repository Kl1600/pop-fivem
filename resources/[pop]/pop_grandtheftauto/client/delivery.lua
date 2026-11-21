local convoy = {}
local truckModel = GetHashKey('mule2')
local pedModel = GetHashKey('a_m_m_mexlabor_01')
local MAX_REVERSE_DIST = 6.5

-- Table persistante pour marquer les slots utilisés durant la session
local usedSlotIndices = {}

local randomDestinations = {
    vec3(-198.6980, -2624.9761, 5.2923),
}

-- Emplacements de spawn
local deliverySlots = {
    {pos = vec3(-455.0746, -2799.6641, 6.2348), heading = 224.6269},
    {pos = vec3(-393.7933, -2833.2856, 6.2378), heading = 315.8362},
    {pos = vec3(-509.3272, -2852.3975, 6.2344), heading = 225.9956},
    {pos = vec3(-415.8460, -2788.2461, 6.2344), heading = 136.7724}
}

-- ============================================================
-- FONCTIONS DE SYNCHRO
-- ============================================================
local function EnsureMissionSync()
    _G.MissionSync = _G.MissionSync or { active = false, id = nil, owner = nil, isOwner = false, entities = {}, flags = {} }
    return _G.MissionSync
end

local function IsCoopActive() return EnsureMissionSync().active == true end
local function IsOwner()
    local MS = EnsureMissionSync()
    if not MS.active then return true end
    return MS.isOwner == true
end

local function Relay(action, data, includeSender)
    local MS = EnsureMissionSync()
    if MS.active then TriggerServerEvent('mission:server:relay', action, data, includeSender == true) end
end

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
    local netId = NetworkGetNetworkIdFromEntity(veh)
    Relay("event", { name = "mission:client:syncTruckDoor", args = { netId, "close" } }, true)
    SetVehicleDoorShut(veh, 5, false)

    SetVehicleHandbrake(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
    
    CreateThread(function()
        -- Le chauffeur monte et s'assure que la porte est bien fermée
        TaskEnterVehicle(ped, veh, 12000, -1, 1.0, 16, 0)
        local timeout = GetGameTimer() + 10000
        while not IsPedInVehicle(ped, veh, false) and GetGameTimer() < timeout do Wait(500) end
        
        -- Double vérification de la fermeture avant de bouger
        SetVehicleDoorShut(veh, 5, false)
        Wait(1000)

        -- Phase de recul
        local startCoords = GetEntityCoords(veh)
        local isReversing = true
        while isReversing do
            Wait(0)
            if #(startCoords - GetEntityCoords(veh)) >= MAX_REVERSE_DIST then isReversing = false
            else TaskVehicleTempAction(ped, veh, 28, 500) end
        end

        ClearPedTasks(ped)
        Wait(1000)

        -- Trajet vers la destination
        local destination = randomDestinations[math.random(#randomDestinations)]
        TaskVehicleDriveToCoord(ped, veh, destination.x, destination.y, destination.z, 20.0, 0, truckModel, 786603, 5.0, true)

        -- BOUCLE DE SUPPRESSION : Supprime le camion une fois arrivé ou loin du joueur
        local traveling = true
        while traveling do
            Wait(5000)
            if DoesEntityExist(veh) then
                local coords = GetEntityCoords(veh)
                local distToDest = #(coords - destination)
                local distToPlayer = #(coords - GetEntityCoords(PlayerPedId()))

                -- Si le camion est arrivé ou s'il est très loin des joueurs
                if distToDest < 10.0 or distToPlayer > 150.0 then
                    DeleteEntity(ped)
                    DeleteEntity(veh)
                    traveling = false
                end
            else
                traveling = false
            end
        end
    end)
end

-- ============================================================
-- SPAWN AVEC SLOTS PERSISTANTS ET INVINCIBILITÉ TOTALE
-- ============================================================
-- delivery.lua

-- Supprimez ou commentez l'ancien RegisterNetEvent('ondelivery')

RegisterNetEvent('mission:client:receiveDeliverySlot')
AddEventHandler('mission:client:receiveDeliverySlot', function(slotIndex)
    if not slotIndex then
        --ESX.ShowNotification("~r~Toutes les zones de déchargement ont été utilisées.")
        print('erreur de logique')
        return
    end

    RequestModel(truckModel)
    RequestModel(pedModel)
    while not HasModelLoaded(truckModel) or not HasModelLoaded(pedModel) do Wait(10) end

    -- On utilise l'index envoyé par le serveur
    local selectedSlot = deliverySlots[slotIndex]

    local veh = CreateVehicle(truckModel, selectedSlot.pos.x, selectedSlot.pos.y, selectedSlot.pos.z, selectedSlot.heading, true, true)
    local ped = CreatePed(4, pedModel, selectedSlot.pos.x - 2.0, selectedSlot.pos.y, selectedSlot.pos.z + 0.5, selectedSlot.heading, true, true)
    
    if DoesEntityExist(veh) and DoesEntityExist(ped) then
        -- [Le reste de votre code d'invincibilité et de blips reste identique]
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
        AddTextComponentString("Camion de chargement")
        EndTextCommandSetBlipName(truckBlip)

        SetVehicleDoorOpen(veh, 5, false, false)
        table.insert(convoy, { vehicle = veh, driver = ped, isLoaded = false, blip = truckBlip })
        --ESX.ShowNotification("Le camion de chargement est arrivé.")
        ShowNotification("Un <span style='color:#ECA95D; font-weight:bold;'>camion de chargement</span> vous attend pour la livraison.", 7000)
    end
end)

-- ============================================================
-- DÉTECTION CHARGEMENT
-- ============================================================
CreateThread(function()
    while true do
        Wait(1000)
        for _, group in ipairs(convoy) do
            if group and not group.isLoaded and DoesEntityExist(group.vehicle) then
                local backPos = GetOffsetFromEntityInWorldCoords(group.vehicle, 0.0, -3.5, 0.0)
                local nearbyVeh = GetClosestVehicle(backPos.x, backPos.y, backPos.z, 3.5, 0, 71)

                if DoesEntityExist(nearbyVeh) and nearbyVeh ~= group.vehicle then
                    group.isLoaded = true
                    
                    NetworkRequestControlOfEntity(nearbyVeh)
                    local t = 0
                    while not NetworkHasControlOfEntity(nearbyVeh) and t < 50 do Wait(10); t = t + 1 end
                    
                    SetEntityAsMissionEntity(nearbyVeh, true, true)
                    DeleteEntity(nearbyVeh)

                    --ESX.ShowNotification("Vous avez ~g~livré le véhicule.")
                    ShowNotification("Vous venez de <span style='color:#2ecc71; font-weight:bold;'>livrer le véhicule.</span>", 7000)
                    StartTruckJourney(group)
                end
            end
        end
    end
end)

RegisterCommand('test_livraison', function() TriggerEvent('ondelivery') end, true)