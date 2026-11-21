-- ============================================================
-- SYNCHRO (COOP) - GESTION DES PORTES ET VÉHICULE DÉMO
-- ============================================================

local heistDemoVeh = nil

-- Utilisation du système de synchronisation global
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

-- Fonction de relais pour diffuser les actions aux autres joueurs
local function Relay(action, data, includeSender)
    local MS = EnsureMissionSync()
    if MS.active then
        TriggerServerEvent('mission:server:relay', action, data, includeSender == true)
    end
end

-- ============================================================
-- ACTIONS DE VERROUILLAGE (FONCTIONNALITÉS CONSERVÉES)
-- ============================================================

function Lockdoor1()
    local door = GetClosestObjectOfType(-73.2972, 80.0848, 71.6245, 3.0, -801051034)
    if DoesEntityExist(door) then
        SetEntityHeading(door, 155.0)
        FreezeEntityPosition(door, true)
    end
end

function Lockdoor2()
    local door2 = GetClosestObjectOfType(-63.6140, 76.9211, 71.6374, 3.0, -1655830399)
    if DoesEntityExist(door2) then
        SetEntityHeading(door2, 247.0)
        FreezeEntityPosition(door2, true)
    end
end

function Lockgarage1()
    local door3 = GetClosestObjectOfType(-62.4782, 79.9412, 71.6412, 3.0, -1797916783)
    if DoesEntityExist(door3) then
        SetEntityHeading(door3, 67.0)
        FreezeEntityPosition(door3, true)
    end
end

function Lockgarage2()
    local door4 = GetClosestObjectOfType(-79.6979, 78.2398, 71.6227, 3.0, 1630015542)
    if DoesEntityExist(door4) then
        SetEntityHeading(door4, -120.0)
        FreezeEntityPosition(door4, true)
    end
end

function Lockentreegauche()
    local door5 = GetClosestObjectOfType(-69.0148, 64.5255, 71.9331, 3.0, -1869234749)
    if DoesEntityExist(door5) then
        SetEntityHeading(door5, -30.0)
        FreezeEntityPosition(door5, true)
    end
end

function Lockentreedroite()
    local door6 = GetClosestObjectOfType(-68.4740, 64.3139, 71.9311, 3.0, 925993716)
    if DoesEntityExist(door6) then
        SetEntityHeading(door6, -30.0)
        FreezeEntityPosition(door6, true)
    end
end

function Lockinterieur()
    local door7 = GetClosestObjectOfType(-61.5104, 74.5247, 71.6404, 3.0, -1025911912)
    if DoesEntityExist(door7) then
        SetEntityHeading(door7, 157.0)
        FreezeEntityPosition(door7, true)
    end
end

-- ============================================================
-- ACTIONS D'OUVERTURE
-- ============================================================

function Opendoor1()
    local door = GetClosestObjectOfType(-73.2972, 80.0848, 71.6245, 3.0, -801051034)
    if DoesEntityExist(door) then
        SetEntityHeading(door, 160.0)
        FreezeEntityPosition(door, false)
    end
end

function Openinterieur()
    local door7 = GetClosestObjectOfType(-61.5104, 74.5247, 71.6404, 3.0, -1025911912)
    if DoesEntityExist(door7) then
        SetEntityHeading(door7, 150.0)
        FreezeEntityPosition(door7, false)
    end
end

-- ============================================================
-- ÉVÉNEMENTS RÉSEAU (SYNCHRONISATION)
-- ============================================================

RegisterNetEvent('mission:client:lockShowroomDoors')
AddEventHandler('mission:client:lockShowroomDoors', function()
    Lockdoor1()
    Lockdoor2()
    Lockgarage2()
    Lockentreegauche()
    Lockentreedroite()
    Lockinterieur()
end)

RegisterNetEvent('mission:client:openShowroomDoors')
AddEventHandler('mission:client:openShowroomDoors', function()
    Openinterieur()
    Opendoor1()
end)

RegisterNetEvent("grandtheftauto:opendoor")
AddEventHandler("grandtheftauto:opendoor", function(bankId)
    if type(OpenDoor) == "function" then OpenDoor(bankId) end
end)

-- ============================================================
-- COMMANDES ET DÉMARRAGE MISSION
-- ============================================================
RegisterCommand('startheist', function()
    -- Notification pour informer le joueur que la mission est en attente
    if ESX then 
        --ESX.ShowNotification("Vous avez ~HUD_COLOUR_MENU_GREY_LIGHT~lancé la mission.") 
        print('mission:on')
    end

    -- Création d'une boucle qui vérifie la distance
    CreateThread(function()
        local showroomPos = vector3(-69.0, 64.0, 71.9) -- Coordonnées centrales du Benefactor
        local heistStarted = false

        while not heistStarted do
            local playerPed = PlayerPedId()
            local plyCoords = GetEntityCoords(playerPed)
            local distance = #(plyCoords - showroomPos)

            -- Si le joueur est à moins de 50 mètres
            if distance <= 100.0 then
                -- On exécute la logique de démarrage originale
                TriggerServerEvent('mission:server:startHeist')
                TriggerEvent('mission:client:lockShowroomDoors')
                Relay("event", { name = 'mission:client:lockShowroomDoors', args = {} }, false)
                
                -- On sort de la boucle pour arrêter la vérification
                heistStarted = true
            end

            -- On attend 1 seconde entre chaque vérification pour ne pas surcharger le processeur
            Wait(1000)
        end
    end)
end, true)


RegisterNetEvent('spawncamion')
AddEventHandler('spawncamion', function()
    -- Notification pour informer le joueur que la mission est en attente


    -- Création d'une boucle qui vérifie la distance
    CreateThread(function()
        local showroomPos = vector3(-462.1116, -2805.2249, 5.9963) -- Coordonnées centrales du Benefactor
        local heistStarted = false

        while not heistStarted do
            local playerPed = PlayerPedId()
            local plyCoords = GetEntityCoords(playerPed)
            local distance = #(plyCoords - showroomPos)

            -- Si le joueur est à moins de 50 mètres
            if distance <= 150.0 then
                -- On exécute la logique de démarrage originale
                TriggerServerEvent('mission:server:requestDeliverySlot')
            
                
                -- On sort de la boucle pour arrêter la vérification
                heistStarted = true
            end

            -- On attend 1 seconde entre chaque vérification pour ne pas surcharger le processeur
            Wait(1000)
        end
    end)
end)

RegisterCommand('open1', function()
    TriggerEvent('mission:client:openShowroomDoors')
    Relay("event", { name = 'mission:client:openShowroomDoors', args = {} }, false)
end, false)

RegisterNetEvent('startheist')
AddEventHandler('startheist', function()
    TriggerEvent('mission:client:lockShowroomDoors')

    if IsCoopActive() and not IsOwner() then return end

    local model = GetHashKey('feltzer2')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local veh = CreateVehicle(model, -54.7075, 75.3594, 71.2523, 66.4815, true, false)
    Wait(100)
    SetVehicleEngineOn(veh, false, true, true)
    heistDemoVeh = veh

    if IsCoopActive() then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetEntityAsMissionEntity(veh, true, true)
        TriggerServerEvent('mission:server:registerEntity', 'heist_demo_feltzer2', { netId = netId })
    end
end)

AddEventHandler('mission:entity:heist_demo_feltzer2', function(payload)
    local netId = (type(payload) == "table") and (payload.netId or payload.id) or payload
    if not netId then return end

    local veh = NetToVeh(netId)
    if veh and DoesEntityExist(veh) then
        heistDemoVeh = veh
    end
end)

RegisterCommand('opencapot', function()
    if heistDemoVeh and DoesEntityExist(heistDemoVeh) then
        NetworkRequestControlOfEntity(heistDemoVeh)
        SetVehicleDoorOpen(heistDemoVeh, 4, false, false)
        SetVehicleDoorsLocked(heistDemoVeh, 2)
    end
end, false)

RegisterNetEvent('openwhitegaragedoor')
AddEventHandler('openwhitegaragedoor', function()
    local door4 = GetClosestObjectOfType(-79.6979, 78.2398, 71.6227, 3.0, 1630015542)
    if DoesEntityExist(door4) then
        FreezeEntityPosition(door4, false)
    end
end)

-- ============================================================
-- LOGIQUE DE LIVRAISON (DÉTAILS CONSERVÉS)
-- ============================================================

RegisterNetEvent('ondeliveryblip')
AddEventHandler('ondeliveryblip', function()
    local destination = vector3(-462.1116, -2805.2249, 5.9963)

    ClearGpsMultiRoute()
    SetWaypointOff()

    local blip = AddBlipForCoord(destination.x, destination.y, destination.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Livraison")
    EndTextCommandSetBlipName(blip)

    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)

    -- Thread de maintien du tracé GPS
    CreateThread(function()
        while DoesBlipExist(blip) do
            Wait(4000)
            SetBlipRoute(blip, true)
        end
    end)

    -- Thread de détection d'arrivée
    CreateThread(function()
        while DoesBlipExist(blip) do
            Wait(1000)
            if #(GetEntityCoords(PlayerPedId()) - destination) < 25.0 then
                RemoveBlip(blip)
                ClearGpsMultiRoute()
                ShowNotification("Vous avez <span style='color:#ECA95D; font-weight:bold;'>atteint votre destination.</span>", 7000)
                
                -- SIGNAL DE FIN SYNCHRONISÉ : Coupe le GPS pour toute la police en même temps
                TriggerServerEvent('mission:server:stopPoliceTracking')
                break
            end
        end
    end)
end)