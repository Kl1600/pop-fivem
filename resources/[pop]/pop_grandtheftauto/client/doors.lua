-- ============================================================
-- SYNCHRO (COOP) - GESTION DES PORTES ET VÉHICULE DÉMO
-- ============================================================

local heistDemoVeh = nil

-- Utilisation du système de synchronisation global



-- Fonction de relais pour diffuser les actions aux autres joueurs

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
-- Raccourci admin : même départ que Svetlana.
-- Commande non « restricted » (sinon bloquée en mode production) : le serveur vérifie l'ACE
-- (mission:server:adminStart → command.startheist ou pop.admin).
RegisterCommand('startheist', function()
    TriggerServerEvent('mission:server:adminStart')
end, false)
TriggerEvent('chat:addSuggestion', '/startheist', 'Admin : lancer le casse Benefactor tout de suite')


RegisterNetEvent('spawncamion')
AddEventHandler('spawncamion', function()
    -- Notification pour informer le joueur que la mission est en attente


    -- Création d'une boucle qui vérifie la distance
    CreateThread(function()
        local showroomPos = Config.DeliveryPos -- zone de livraison
        local heistStarted = false

        while not heistStarted and _G.MissionSync and _G.MissionSync.active do
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

AddEventHandler('startheist', function()
    TriggerEvent('mission:client:lockShowroomDoors')

    if IsCoopActive() and not IsOwner() then return end

    local model = LoadModel('feltzer2')
    if not model then return end

    local veh = CreateVehicle(model, -54.7075, 75.3594, 71.2523, 66.4815, true, false)
    SetModelAsNoLongerNeeded(model)
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

AddEventHandler('mission:local:opencapot', function()
    if heistDemoVeh and DoesEntityExist(heistDemoVeh) then
        NetworkRequestControlOfEntity(heistDemoVeh)
        SetVehicleDoorOpen(heistDemoVeh, 4, false, false)
        SetVehicleDoorsLocked(heistDemoVeh, 2)
    end
end)

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

local deliveryBlip = nil
AddEventHandler('ondeliveryblip', function()
    local destination = Config.DeliveryPos
    if deliveryBlip and DoesBlipExist(deliveryBlip) then return end

    ClearGpsMultiRoute()
    SetWaypointOff()

    local blip = AddBlipForCoord(destination.x, destination.y, destination.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L('blip_delivery'))
    EndTextCommandSetBlipName(blip)

    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    deliveryBlip = blip

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
                MissionNotify(L('destination_reached'), 7000)

                -- SIGNAL DE FIN SYNCHRONISÉ : Coupe le GPS pour toute la police en même temps
                TriggerServerEvent('mission:server:stopPoliceTracking')
                break
            end
        end
    end)
end)
-- ============================================================
-- FIN DE MISSION : remise à zéro
-- ============================================================
AddEventHandler('mission:local:reset', function()
    heistDemoVeh = nil
    if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    deliveryBlip = nil
    -- Portes du showroom rendues au décor
    for _, d in ipairs({
        { -73.2972, 80.0848, 71.6245, -801051034 }, { -63.6140, 76.9211, 71.6374, -1655830399 },
        { -79.6979, 78.2398, 71.6227, 1630015542 }, { -69.0148, 64.5255, 71.9331, -1869234749 },
        { -68.4740, 64.3139, 71.9311, 925993716 }, { -61.5104, 74.5247, 71.6404, -1025911912 },
    }) do
        local door = GetClosestObjectOfType(d[1], d[2], d[3], 3.0, d[4])
        if DoesEntityExist(door) then FreezeEntityPosition(door, false) end
    end
end)
