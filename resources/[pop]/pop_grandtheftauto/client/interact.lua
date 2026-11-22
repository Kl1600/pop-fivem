local canHack = false

-- ============================================================
-- SYNCHRO (COOP)
-- ============================================================





------------------------------------------------------------
-- Thread 1: Spawn le NPC Svetlana (Début)
------------------------------------------------------------
local svetlanaPed = nil
Citizen.CreateThread(function()
    -- 'ig_valentina' et l'anim 'amnilka' viennent d'un pack : repli vanilla s'ils manquent
    local hash = LoadFirstModel({ 'ig_valentina', 'a_f_y_business_04' })
    if not hash then return end

    local ped = CreatePed(4, hash, -50.9760, -2523.6348, 7.1, 347.2004, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    svetlanaPed = ped

    local anim = "amnilka@photopose@female@homepack001"
    if LoadAnimDict(anim) then
        TaskPlayAnim(ped, anim, "amnilka_femalehome_photopose_004", 15.0, 8.0, -1, 1, 0, 0, 0, 0)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true)
    end
end)

------------------------------------------------------------
-- Thread 2: Interaction Proximité Svetlana -> lance (ou rejoint) le casse
------------------------------------------------------------
Citizen.CreateThread(function()
    local svetlanaPos = Config.SvetlanaPos
    local lastTalk = 0
    while true do
        local wait = 1000
        local dist = #(GetEntityCoords(PlayerPedId()) - svetlanaPos)

        if dist <= 3.0 then
            wait = 0
            ShowPrompt("svetlana", svetlanaPos + vector3(0,0,1.0), L('prompt_talk'), "fas fa-comments")
            if IsControlJustReleased(0, 38) and GetGameTimer() - lastTalk > 3000 then
                lastTalk = GetGameTimer()
                HidePrompt("svetlana")
                ShowSubtitle(L('svetlana_line'), 6000)
                TriggerServerEvent('mission:server:talkSvetlana')
            end
        else
            HidePrompt("svetlana")
            if dist > 30.0 then wait = 2000 end
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

local thorntonLeaving = false

-- Définition GLOBALE de EntrerVoiture (Fixé ici)
function EntrerVoiture(ped)
    if IsCoopActive() and not IsOwner() then
        -- En coop, demande à l'owner de piloter le PNJ
        Relay("event", { name = "mission:forceThorntonExit", args = {} }, false)
        return
    end

    if thorntonLeaving then return end
    if not veh2 or not DoesEntityExist(veh2) then return end
    thorntonLeaving = true

    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskWarpPedIntoVehicle(ped, veh2, -1)

    local destination = Config.Positions.ThorntonLeaveTo
    TaskVehicleDriveToCoord(ped, veh2, destination.x, destination.y, destination.z, 20.0, 1, GetEntityModel(veh2), 786603, 5.0, 1)

    local car = veh2
    Citizen.CreateThread(function()
        local limit = GetGameTimer() + 180000
        while true do
            Wait(5000)
            if not DoesEntityExist(ped) then break end
            local coords = GetEntityCoords(ped)
            if #(coords - destination) < 10.0 or #(coords - GetEntityCoords(PlayerPedId())) > 150.0 or GetGameTimer() > limit then
                DeleteEntity(ped)
                if DoesEntityExist(car) then DeleteEntity(car) end
                break
            end
        end
    end)
end

AddEventHandler('startheist', function()
    thorntonLeaving = false
    -- Seul l'owner crée le véhicule physique
    if IsCoopActive() and not IsOwner() then
        return
    end

    -- 'turismoo' n'existe pas : Turismo Omaggio (turismo3), sinon Turismo R
    local model2 = LoadFirstModel({ 'turismo3', 'turismor' })
    if not model2 then return end

    local v = CreateVehicle(model2, -72.3226, 87.3146, 71.5315, 68.2418, true, false)
    SetModelAsNoLongerNeeded(model2)
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
RegisterNetEvent('mission:setupBlips')
AddEventHandler('mission:setupBlips', function()
    if IsCoopActive() then canHack = true end
end)

local keyBlip = nil
local keysAvailable = false
local function CreateKeysBlip()
    keysAvailable = true
    if keyBlip then return end
    keyBlip = AddBlipForCoord(-69.8501, 76.5493, 71.4452)
    SetBlipSprite(keyBlip, 134)
    SetBlipColour(keyBlip, 2)
    SetBlipScale(keyBlip, 0.4)
    SetBlipAsShortRange(keyBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L('blip_keys'))
    EndTextCommandSetBlipName(keyBlip)
end

local function RemoveKeysBlip()
    if keyBlip and DoesBlipExist(keyBlip) then
        RemoveBlip(keyBlip)
    end
    keyBlip = nil
end

local hackPanelPos = Config.Positions.Panel

local function OnPanelHacked()
    canHack = false
    TriggerEvent('mission:local:removeblip1')
    Relay("command", { cmd = "removeblip1" }, false)

    CreateKeysBlip()
    Relay("event", { name = "mission:keysBlipOn", args = {} }, false)
    Debug('panneau piraté : coupure de courant')

    if _G.npcHandle and DoesEntityExist(_G.npcHandle) then EntrerVoiture(_G.npcHandle) end

    TriggerEvent('mission:local:guide', 'power')
    ShowSubtitle(L('wait_blackout'), 8500)
    Relay("subtitle", { text = L('wait_blackout'), duration = 8500 }, false)
    Wait(6000)
    TriggerEvent('mission:client:openShowroomDoors')
    Relay("command", { cmd = "open1" }, false)
    TriggerEvent('__chHyperSound:play', 0, 'unlock', false, hackPanelPos, 30.0)
    Relay("hypersound", { sound = "unlock", coords = hackPanelPos, distance = 30.0 }, false)
    PlaySoundFrontend(-1, "Challenge_Unlock", "HUD_AWARDS", true)
    Wait(3000)
    TriggerEvent('__chHyperSound:play', 0, 'shutdown', false, hackPanelPos, 50.0)
    Relay("hypersound", { sound = "shutdown", coords = hackPanelPos, distance = 50.0 }, false)
    PlaySoundFrontend(-1, "Power_Down", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    Blackout(true)
    Relay("command", { cmd = "blc" }, false)
    TriggerEvent('mission:local:lasers', false)
    Relay("command", { cmd = "laseroff" }, false)
    Wait(900)
    MissionNotify(L('force_car'), 10000)
    StartMissionTimer()
    Relay("event", { name = "StartMissionTimer", args = {} }, false)
end

Citizen.CreateThread(function()
    local terminalCoords = Config.Positions.Terminal
    local busy = false
    while true do
        local wait = 1000

        if canHack and not busy then
            local dist = #(GetEntityCoords(PlayerPedId()) - terminalCoords)
            if dist <= 10.0 then
                wait = 0
                DrawMarker(24, hackPanelPos.x, hackPanelPos.y, hackPanelPos.z, 0.2, 0.5, 0, 0, 0, 0, 0.4, 0.4, 0.4, 175, 75, 75, 200, 0, 0, 2, 0, 0, 0, 0)

                if dist <= 2.0 then
                    ShowPrompt("hack_terminal", hackPanelPos, L('prompt_hack'), "fas fa-laptop-code")
                    if IsControlJustReleased(0, 38) then
                        HidePrompt("hack_terminal")
                        busy = true -- Empêche la réapparition le temps du callback / mini-jeu
                        CheckItem('flipper', function(hasItem)
                            CreateThread(function()
                                if not hasItem then
                                    MissionNotify(L('need_flipper'), 5000)
                                elseif RunVoltlab(40) then
                                    if canHack then OnPanelHacked() end
                                else
                                    MissionNotify(L('hack_failed'), 5000)
                                end
                                busy = false
                            end)
                        end, 'flipper')
                    end
                else
                    HidePrompt("hack_terminal")
                end
            elseif dist > 60.0 then
                wait = 2000
            end
        else
            HidePrompt("hack_terminal")
        end
        Wait(wait)
    end
end)

AddEventHandler("mission:keysBlipOn", function()
    canHack = false
    CreateKeysBlip()
end)

------------------------------------------------------------
-- Clés & Porte Blanche (Interaction)
------------------------------------------------------------
local keysTaken = false
local doorOpened = false
local keysPos = Config.Positions.Keys
local doorPos = Config.Positions.GarageDoor

local function DeleteKeysProp()
    local keysEntity = GetClosestObjectOfType(keysPos.x, keysPos.y, keysPos.z, 2.0, GetHashKey('prop_cuff_keys_01'), false, false, false)
    if DoesEntityExist(keysEntity) then
        SetEntityAsMissionEntity(keysEntity, true, true)
        DeleteObject(keysEntity)
        DeleteEntity(keysEntity)
    end
end

AddEventHandler("mission:setKeysTaken", function()
    keysTaken = true
    RemoveKeysBlip()
    DeleteKeysProp() -- suppression locale pour les autres clients
end)

AddEventHandler("mission:setDoorOpened", function()
    doorOpened = true
    TriggerEvent('openwhitegaragedoor')
end)

local function OpenWhiteDoor(ped)
    -- (Remplace l'emote 'e mechanic4', inexistante)
    if LoadAnimDict("mini@repair") then
        TaskPlayAnim(ped, "mini@repair", "fixing_a_ped", 8.0, -8.0, 1500, 49, 0, false, false, false)
    end
    Wait(1500)
    ClearPedTasks(ped)
    TriggerEvent('openwhitegaragedoor')
    doorOpened = true
    HidePrompt("door")
    Relay("event", { name = "mission:setDoorOpened", args = {} }, false)
    TriggerEvent('mission:local:guide', 'door')
    Debug('porte du garage ouverte')
end

CreateThread(function()
    while true do
        local wait = 1000

        if keysAvailable and (not keysTaken or not doorOpened) then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if not keysTaken then
                local d = #(coords - keysPos)
                if d < 30.0 then
                    -- Flèche au-dessus des clés, seulement à proximité
                    wait = 0
                    DrawMarker(20, keysPos.x, keysPos.y, keysPos.z + 0.6, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, 89, 213, 156, 150, true, true, 2, nil, nil, false)
                end
                if d < 1.8 then
                    ShowPrompt("keys", keysPos + vector3(0,0,0.5), L('prompt_pickup'), "fas fa-key")
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
                    ShowPrompt("door", doorPos + vector3(0,0,1.0), L('prompt_open'), "fas fa-door-open")
                    if IsControlJustPressed(0, 38) then
                        OpenWhiteDoor(ped)
                    end
                else
                    HidePrompt("door")
                end
            else
                HidePrompt("door")
            end
        else
            HidePrompt("keys")
            HidePrompt("door")
        end
        Wait(wait)
    end
end)

function TakeMappedKeys(ped)
    if keysTaken then return end
    keysTaken = true
    RemoveKeysBlip()
    MissionNotify(L('keys_taken'), 7000)

    -- Animation de ramassage
    if LoadAnimDict("pickup_object") then
        TaskPlayAnim(ped, "pickup_object", "putdown_low", 8.0, -8.0, 700, 49)
    end
    Wait(700)

    DeleteKeysProp()

    Wait(300)
    ClearPedTasks(ped)

    -- Synchronisation coop
    Relay("event", { name = "mission:setKeysTaken", args = {} }, false)
    TriggerEvent('mission:local:guide', 'keys')
    Debug('clés récupérées')
end

------------------------------------------------------------
-- Fin de mission : remise à zéro
------------------------------------------------------------
AddEventHandler('mission:local:reset', function()
    canHack = false
    keysAvailable = false
    keysTaken = false
    doorOpened = false
    thorntonLeaving = false
    veh2 = nil
    RemoveKeysBlip()
    HidePrompt("hack_terminal")
    HidePrompt("keys")
    HidePrompt("door")
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemoveKeysBlip()
    if svetlanaPed and DoesEntityExist(svetlanaPed) then DeleteEntity(svetlanaPed) end
end)
