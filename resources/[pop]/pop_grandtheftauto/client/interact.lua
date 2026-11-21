local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function CheckItem(item, cb)
    if Config.Framework == 'esx' and ESX then
        ESX.TriggerServerCallback('grandtheftauto:hasItem', cb, item)
    elseif Config.Framework == 'qbcore' and QBCore then
        QBCore.Functions.TriggerCallback('grandtheftauto:hasItem', cb, item)
    else
        cb(false)
    end
end

local svetlanaInteracting = false
local canHack = false

-- ============================================================
-- SYNCHRO (COOP)
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
    return EnsureMissionSync().active == true
end

local function IsOwner()
    local MS = EnsureMissionSync()
    if not MS.active then return true end
    return MS.isOwner == true
end

local function Relay(action, data, includeSender)
    local MS = EnsureMissionSync()
    if MS.active then 
        TriggerServerEvent('mission:server:relay', action, data, includeSender == true)
    end
end

------------------------------------------------------------
-- Thread 1: Spawn le NPC Svetlana (Début)
------------------------------------------------------------
Citizen.CreateThread(function()
    local anim = "amnilka@photopose@female@homepack001"
    RequestAnimDict(anim)
    while not HasAnimDictLoaded(anim) do
        Wait(1)
    end

    local hash = GetHashKey("ig_valentina")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(1)
    end

    local ped = CreatePed(4, hash, -50.9760, -2523.6348, 7.1, 347.2004, false, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    TaskPlayAnim(ped, anim, "amnilka_femalehome_photopose_004", 15.0, 8.0, -1, 1, 0, 0, 0, 0)
end)

------------------------------------------------------------
-- Thread 2: Interaction Proximité Svetlana
------------------------------------------------------------
-- Utilisation de ShowPrompt et HidePrompt globaux (depuis utils.lua)

------------------------------------------------------------
-- Thread 2: Interaction Proximité Svetlana
------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local plyCoords = GetEntityCoords(PlayerPedId())
        local svetlanaPos = vector3(-51.8229, -2523.5183, 7.4012)
        local dist = #(plyCoords - svetlanaPos)

        if dist <= 3.0 and not svetlanaInteracting then
            wait = 0
            ShowPrompt("svetlana", svetlanaPos + vector3(0,0,1.0), "PARLER", "fas fa-comments")
            if IsControlJustReleased(0, 38) then
                svetlanaInteracting = true
                HidePrompt("svetlana")
                -- Logique d'interaction conservée
                TriggerServerEvent('mission:server:requestDeliverySlot')
            end
        else
            HidePrompt("svetlana")
            if dist > 3.0 then svetlanaInteracting = false end
        end
        Citizen.Wait(wait)
    end
end)

------------------------------------------------------------
-- Gestion du Véhicule de Thornton (veh2)
------------------------------------------------------------
local veh2 = nil

AddEventHandler('mission:entity:thornton_vehicle', function(payload)
    local netId = payload
    if type(payload) == "table" then
        netId = payload.netId or payload.id or payload.net
    end
    if not netId then return end

    local v = NetToVeh(netId)
    if v and DoesEntityExist(v) then
        veh2 = v
    end
end)

-- Définition GLOBALE de EntrerVoiture (Fixé ici)
function EntrerVoiture(ped)
    if IsCoopActive() and not IsOwner() then
        -- En coop, demande à l'owner de piloter le PNJ
        Relay("event", { name = "mission:forceThorntonExit", args = {} }, false)
        return
    end

    if not veh2 or not DoesEntityExist(veh2) then return end

    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskWarpPedIntoVehicle(ped, veh2, -1)

    local destination = vector3(-370.2602, 148.7482, 65.8740)
    TaskVehicleDriveToCoord(ped, veh2, destination.x, destination.y, destination.z, 20.0, 1, GetHashKey('turismoo'), 786603, 5.0, 1)

    Citizen.CreateThread(function()
        local fini = false
        while not fini do
            Wait(5000)
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                if #(coords - destination) < 10.0 or #(coords - GetEntityCoords(PlayerPedId())) > 150.0 then
                    DeleteEntity(ped)
                    DeleteEntity(veh2)
                    fini = true
                end
            else
                fini = true
            end
        end
    end)
end

AddEventHandler('startheist', function()
    -- Seul l'owner crée le véhicule physique
    if IsCoopActive() and not IsOwner() then
        return
    end

    local model2 = GetHashKey('turismoo')
    RequestModel(model2)
    while not HasModelLoaded(model2) do Wait(10) end
    
    local v = CreateVehicle(model2, -72.3226, 87.3146, 71.5315, 68.2418, true, false)
    veh2 = v

    if IsCoopActive() and DoesEntityExist(v) then
        local netId = NetworkGetNetworkIdFromEntity(v)
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
        SetEntityAsMissionEntity(v, true, true)
        TriggerServerEvent('mission:server:registerEntity', 'thornton_vehicle', { netId = netId })
    end
end)

AddEventHandler("mission:forceThorntonExit", function()
    if IsCoopActive() and not IsOwner() then return end
    if _G.npcHandle and DoesEntityExist(_G.npcHandle) then
        EntrerVoiture(_G.npcHandle)
    end
end)

------------------------------------------------------------
-- Hack Terminal & Verrous
------------------------------------------------------------
local terminalHackActive = false -- Ancien canHack déplacé plus haut
RegisterNetEvent('mission:setupBlips')
AddEventHandler('mission:setupBlips', function()
    canHack = true
end)

local keyBlip = nil
local function CreateKeysBlip()
    if keyBlip then return end
    keyBlip = AddBlipForCoord(-69.8501, 76.5493, 71.4452)
    SetBlipSprite(keyBlip, 134)
    SetBlipColour(keyBlip, 2)
    SetBlipScale(keyBlip, 0.4)
    SetBlipAsShortRange(keyBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Clés de la porte de garage")
    EndTextCommandSetBlipName(keyBlip)
end

local function RemoveKeysBlip()
    if keyBlip and DoesBlipExist(keyBlip) then
        RemoveBlip(keyBlip)
        keyBlip = nil
    end
end

 Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local plyCoords = GetEntityCoords(PlayerPedId())
        local terminalCoords = vector3(-54.7984, 78.8763, 71.6531)
        local dist = #(plyCoords - terminalCoords)

        if dist <= 10.0 and canHack then
            wait = 0
            DrawMarker(24, -54.4972, 79.1231, 72.4629, 0.2, 0.5, 0, 0, 0, 0, 0.4, 0.4, 0.4, 175, 75, 75, 200, 0, 0, 2, 0, 0, 0, 0)

            if dist <= 2.0 then
                ShowPrompt("hack_terminal", vector3(-54.4972, 79.1231, 72.4629) + vector3(0,0,0.0), "PIRATER", "fas fa-laptop-code")
                if IsControlJustReleased(0, 38) then
                    HidePrompt("hack_terminal")
                    canHack = false -- Empêche la réapparition immédiate le temps du callback / mini-jeu
                    CheckItem('flipper', function(hasItem)
                            if hasItem then
                                TriggerEvent('ultra-voltlab', 40, function(outcome, reason)
                                    if outcome == 1 then
                                        canHack = false
                                        ExecuteCommand('removeblip1')
                                        if IsCoopActive() then Relay("command", { cmd = "removeblip1" }, false) end

                                        CreateKeysBlip()
                                        if IsCoopActive() then Relay("event", { name = "mission:keysBlipOn", args = {} }, false) end

                                        if _G.npcHandle and DoesEntityExist(_G.npcHandle) then EntrerVoiture(_G.npcHandle) end

                                        ShowSubtitle("Attendez la ~y~coupure de courant~w~ pour entrer dans le showroom.", 8500)
                                        Wait(6000)
                                        ExecuteCommand('open1')
                                        TriggerEvent('__chHyperSound:play', 0, 'unlock', false, vector3(-54.4972, 79.1231, 72.4629), 30.0)
                                        PlaySoundFrontend(-1, "Challenge_Unlock", "HUD_AWARDS", true)
                                        Wait(3000)
                                        TriggerEvent('__chHyperSound:play', 0, 'shutdown', false, vector3(-54.4972, 79.1231, 72.4629), 50.0)
                                        PlaySoundFrontend(-1, "Power_Down", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
                                        ExecuteCommand('blc')
                                        ExecuteCommand('laseroff')
                                        Wait(900)
                                        -- Voix off svetlana_line3 retirée
                                        ShowNotification("Forcez une <span style='color:#ECA95D; font-weight:bold;'>voiture</span> en utilisant votre module pirate à proximité.", 10000)
                                        StartMissionTimer()

                                        if IsCoopActive() then
                                            Relay("subtitle", { text = "Attendez la coupure...", duration = 8500 }, false)
                                            Relay("command", { cmd = "open1" }, false)
                                            Relay("hypersound", { sound = "unlock", coords = vector3(-54.4972, 79.1231, 72.4629), distance = 30.0 }, false)
                                            Relay("hypersound", { sound = "shutdown", coords = vector3(-54.4972, 79.1231, 72.4629), distance = 50.0 }, false)
                                            Relay("command", { cmd = "blc" }, false)
                                            Relay("command", { cmd = "laseroff" }, false)
                                            Relay("event", { name = "StartMissionTimer", args = {} }, false)
                                            -- Voix off relayée svetlana_line3 retirée
                                        end
                                    else
                                        canHack = true -- Permet de réessayer si échec
                                        ShowNotification("Le <span style='color:#E74C3C; font-weight:bold;'>piratage a échoué</span>.", 5000)
                                    end
                                end)
                            else
                                canHack = true -- Item manquant, on pourra revenir
                                ShowNotification("Vous avez besoin d'un <span style='color:#E74C3C; font-weight:bold;'>Flipper Zero</span> pour faire ça.", 5000)
                            end
                        end, 'flipper')
                    end
                else
                    HidePrompt("hack_terminal")
                end
            else
                HidePrompt("hack_terminal")
            end
        --end
        Wait(wait)
    end
end)

AddEventHandler("mission:keysBlipOn", function() CreateKeysBlip() end)

------------------------------------------------------------
-- Clés & Porte Blanche (Interaction)
------------------------------------------------------------
local keysTaken = false
local doorOpened = false
local keysPos = vector3(-69.8501, 76.5493, 71.4452)
local doorPos = vector3(-78.4765, 79.3014, 71.6154)

AddEventHandler("mission:setKeysTaken", function()
    keysTaken = true
    RemoveKeysBlip()
    
    -- Suppression locale pour les autres clients
    local keysEntity = GetClosestObjectOfType(keysPos.x, keysPos.y, keysPos.z, 2.0, GetHashKey('prop_cuff_keys_01'), false, false, false)
    if DoesEntityExist(keysEntity) then
        SetEntityAsMissionEntity(keysEntity, true, true)
        DeleteObject(keysEntity)
        DeleteEntity(keysEntity)
    end
end)

AddEventHandler("mission:setDoorOpened", function()
    doorOpened = true
    TriggerEvent('openwhitegaragedoor')
end)

-- Modification de la boucle de détection des clés dans interact.lua
CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- AFFICHAGE DU MARKER 20 (Flèche jaune au-dessus des clés)
        -- On l'affiche si les clés ne sont pas prises ET que le blip des clés existe (hack réussi)
        if not keysTaken  then
            wait = 0
            DrawMarker(20, keysPos.x, keysPos.y, keysPos.z + 0.6, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, 89, 213, 156, 150, true, true, 2, nil, nil, false)
        end

        if not keysTaken then
            if #(coords - keysPos) < 1.8 then
                wait = 0
                ShowPrompt("keys", keysPos + vector3(0,0,0.5), "RAMASSER", "fas fa-key")
                if IsControlJustPressed(0, 38) then
                    HidePrompt("keys")
                    TakeMappedKeys(ped)
                end
            else
                HidePrompt("keys")
            end
        else
            HidePrompt("keys")
        end

        if keysTaken and not doorOpened then
            if #(coords - doorPos) < 2.0 then
                wait = 0
                ShowPrompt("door", doorPos + vector3(0,0,1.0), "OUVRIR", "fas fa-door-open")
                if IsControlJustPressed(0, 38) then
                    ExecuteCommand('e mechanic4')
                    Wait(1000)
                    ClearPedTasks(ped)
                    TriggerEvent('openwhitegaragedoor')
                    doorOpened = true
                    HidePrompt("door")
                    if IsCoopActive() then Relay("event", { name = "mission:setDoorOpened", args = {} }, false) end
                end
            else
                HidePrompt("door")
            end
        else
            HidePrompt("door")
        end
        Wait(wait)
    end
end)

function TakeMappedKeys(ped)
    if keysTaken then return end
    keysTaken = true
    RemoveKeysBlip()
    --ESX.ShowNotification("Vous avez ~g~récupéré les clés !")
    ShowNotification("Vous avez <span style='color:#ECA95D; font-weight:bold;'>récupéré les clées</span> de la porte de garage.", 7000)

    -- Animation de ramassage
    RequestAnimDict("pickup_object")
    while not HasAnimDictLoaded("pickup_object") do Wait(10) end
    TaskPlayAnim(ped, "pickup_object", "putdown_low", 8.0, -8.0, 700, 49)
    Wait(700)

    -- RECHERCHE ET SUPPRESSION DE L'OBJET
    local keysEntity = GetClosestObjectOfType(keysPos.x, keysPos.y, keysPos.z, 2.0, GetHashKey('prop_cuff_keys_01'), false, false, false)
    if DoesEntityExist(keysEntity) then
        -- On force le contrôle et le statut de mission pour pouvoir supprimer
        SetEntityAsMissionEntity(keysEntity, true, true)
        DeleteObject(keysEntity)
        DeleteEntity(keysEntity) -- Double sécurité
    end

    Wait(300)
    ClearPedTasksImmediately(ped)
    
    -- Synchronisation coop
    if IsCoopActive() then 
        Relay("event", { name = "mission:setKeysTaken", args = {} }, false) 
    end
end