local npcHandle = nil
local npcMoving = false
local npcBlip = nil
local missionTerminee = false
local challengeStarted = false
local challengeDone = false

local pedModel = GetHashKey('ig_thornton')
local startPos = vector4(-72.6626, 84.9975, 71.4851, 57.4806)
local targetPos = vector3(-57.3825, 76.5334, 71.6155)
local targetHeading = 255.9274

-- ============================================================
-- SYNCHRO (COOP)
-- ============================================================




local function EnsureMissionSync()
    _G.MissionSync = _G.MissionSync or { active = false, id = nil, owner = nil, isOwner = false, entities = {}, flags = {} }
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

local function Relay(action, data, includeSender)
    local MS = EnsureMissionSync()
    if MS.active and MS.isOwner then
        TriggerServerEvent('mission:server:relay', action, data, includeSender == true)
    end
end

local function MS_ShowSubtitle(text, duration)
    ShowSubtitle(text, duration)
    Relay("subtitle", { text = text, duration = duration or 5000 }, false)
end

local function MS_PlayHyper(netId, soundName, distance)
    TriggerEvent('__chHyperSound:playOnEntity', netId, nil, soundName, false, distance or 15.0)
    Relay("hypersound", { netId = netId, sound = soundName, looped = false, distance = distance or 15.0 }, false)
end

local function MS_PlayInteractSound(soundName, volume)
    TriggerEvent('InteractSound_CL:PlayOnOne', soundName, volume or 0.6)
    Relay("interactsound_one", { sound = soundName, volume = volume or 0.6 }, false)
end

local function EnsureThorntonBlip()
    if not npcHandle or not DoesEntityExist(npcHandle) then return end
    if npcBlip and DoesBlipExist(npcBlip) then return end

    npcBlip = AddBlipForEntity(npcHandle)
    SetBlipSprite(npcBlip, 128)
    SetBlipColour(npcBlip, 40)
    SetBlipScale(npcBlip, 0.4)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Thornton Duggan")
    EndTextCommandSetBlipName(npcBlip)
end

-- ============================================================
-- TES FONCTIONS (INCHANGÉES)
-- ============================================================

local function ThorntonParle(duree)
    if not npcHandle or not DoesEntityExist(npcHandle) then return end
    SetFacialIdleAnimOverride(npcHandle, "mood_talking_1", 0)
    Wait(duree)
    ClearFacialIdleAnimOverride(npcHandle)
end

local function playArrestAnim(ped)
    local animDict = "missheistfbisetup1"
    local animName = "hassle_intro_loop_f"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 2, 0, false, false, false)
end

function ShowSubtitle(text, duration)
    BeginTextCommandPrint("STRING")
    local maxLength = 99
    if #text > maxLength then
        for i = 1, #text, maxLength do
            AddTextComponentSubstringPlayerName(string.sub(text, i, i + maxLength - 1))
        end
    else
        AddTextComponentSubstringPlayerName(text)
    end
    EndTextCommandPrint(duration or 5000, 1)
end

-- ============================================================
-- RÉCEPTION DU NETID THORNTON (COOP)
-- ============================================================

AddEventHandler('mission:entity:thornton', function(netId)
    if npcHandle and DoesEntityExist(npcHandle) then
        _G.npcHandle = npcHandle
        EnsureThorntonBlip()
        return
    end

    local ped = NetToPed(netId)
    if ped and DoesEntityExist(ped) then
        npcHandle = ped
        _G.npcHandle = npcHandle
        EnsureThorntonBlip()
    end
end)

-- ============================================================
-- ÉVÉNEMENT DE SPAWN (DÉCLENCHÉ PAR STARTHEIST)
-- ============================================================

RegisterNetEvent('startheist')
AddEventHandler('startheist', function(ownerServerId, heistId)
    if IsCoopActive() and not IsOwner() then
        return
    end

    if DoesEntityExist(npcHandle) then
        _G.npcHandle = npcHandle
        EnsureThorntonBlip()
        return
    end

    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end

    npcHandle = CreatePed(4, pedModel, startPos.x, startPos.y, startPos.z - 1.0, startPos.w, true, true)

    SetPedPropIndex(npcHandle, 0, 0, 0, true)
    local npcNetId = NetworkGetNetworkIdFromEntity(npcHandle)

    SetNetworkIdCanMigrate(npcNetId, false)
    SetNetworkIdExistsOnAllMachines(npcNetId, true)

    SetEntityAsMissionEntity(npcHandle, true, true)

    local moveClipset = "move_f@depressed@a"
    RequestAnimSet(moveClipset)
    while not HasAnimSetLoaded(moveClipset) do Wait(1) end
    SetPedMovementClipset(npcHandle, moveClipset, 1.0)

    SetEntityInvincible(npcHandle, true)
    SetBlockingOfNonTemporaryEvents(npcHandle, true)

    _G.npcHandle = npcHandle
    EnsureThorntonBlip()

    if IsCoopActive() then
        TriggerServerEvent('mission:server:registerEntity', 'thornton', npcNetId)
    end
end)

-- ============================================================
-- BOUCLE PRINCIPALE (LOGIQUE IDENTIQUE CÔTÉ OWNER)
-- ============================================================

Citizen.CreateThread(function()
    while true do
        local sleep = 500

        if DoesEntityExist(npcHandle) then
            EnsureThorntonBlip()

            if IsCoopActive() and not IsOwner() then
                Wait(sleep)
                goto continue
            end

            local playerCoords = GetEntityCoords(PlayerPedId())
            local npcCoords = GetEntityCoords(npcHandle)
            local distToStart = #(playerCoords - vector3(startPos.x, startPos.y, startPos.z))
            local currentNetId = NetworkGetNetworkIdFromEntity(npcHandle)

            if not challengeStarted and not challengeDone and not missionTerminee and distToStart < 4.0 then
                challengeStarted = true
                sleep = 0

                -- --- DIALOGUE INITIAL --- --
                MS_PlayHyper(currentNetId, '1t', 15.0)
                MS_ShowSubtitle("M.Duggan : Qu'est-ce que vous faites là, je ne vous attendais pas avant au moins 20min !", 5000)
                ThorntonParle(5000)

                -- --- CAMERA ZOOM --- --
                local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                local npcHeading = GetEntityHeading(npcHandle)
                local rad = math.rad(npcHeading)
                local cx = npcCoords.x + math.sin(rad) * 1.5
                local cy = npcCoords.y - math.cos(rad) * 1.5
                
                SetCamCoord(cam, cx, cy, npcCoords.z + 0.6)
                PointCamAtEntity(cam, npcHandle, 0.0, 0.0, 0.6, true)
                SetCamFov(cam, 35.0)
                SetCamActive(cam, true)
                RenderScriptCams(true, true, 1000, true, true)

                -- --- VOICE CHALLENGE --- --
                exports['pma_voice_challenge']:StartChallenge()

                local finishedChallenge = false
                local successChallenge = false
                local challengeListener = AddEventHandler('pma_voice_challenge:finished', function(res)
                    successChallenge = res
                    finishedChallenge = true
                end)

                while not finishedChallenge do Wait(100) end
                RemoveEventHandler(challengeListener)

                if successChallenge then
                    challengeDone = true
                    RenderScriptCams(false, true, 1000, true, true)
                    DestroyCam(cam, false)

                    -- --- PARCOURS NORMAL (Après victoire) --- --
                    
                    -- 1. Il marche vers la voiture
                    TaskGoStraightToCoord(npcHandle, targetPos.x, targetPos.y, targetPos.z, 1.0, -1, targetHeading, 0.5)
                    
                    MS_PlayHyper(currentNetId, '2t', 15.0)
                    MS_ShowSubtitle("M.Duggan : Bon et bien puisque vous êtes déjà là...", 4000)
                    ThorntonParle(4000)

                    MS_PlayHyper(currentNetId, '3t', 15.0)
                    MS_ShowSubtitle("M.Duggan : Elle a des voyants moteurs, c'est surement rien", 2500)
                    ThorntonParle(2500)
                    MS_ShowSubtitle("mais on merde pas avec une voiture à ce prix là.", 2500)
                    ThorntonParle(2500)

                    -- Attendre qu'il arrive à la voiture
                    local arrivedAtTarget = false
                    while not arrivedAtTarget do
                        Wait(500)
                        if #(GetEntityCoords(npcHandle) - targetPos) < 1.2 then arrivedAtTarget = true end
                    end
                    
                    ClearPedTasks(npcHandle)
                    SetEntityCoords(npcHandle, targetPos.x, targetPos.y, targetPos.z - 1.0, false, false, false, true)
                    SetEntityHeading(npcHandle, targetHeading)
                    
                    playArrestAnim(npcHandle)
                    Wait(500)

                    Wait(1000)
                    ExecuteCommand('opencapot')
                    Relay("command", { cmd = "opencapot" }, false)

                    MS_PlayHyper(currentNetId, '4t', 15.0)
                    MS_ShowSubtitle("M.Duggan : C'est de l'ingénierie allemande, on rigole pas avec ça !", 4000)
                    ThorntonParle(4000)

                    ClearPedTasks(npcHandle)
                    Wait(1000)

                    -- 2. Il retourne à son point de départ pour s'en aller
                    TaskGoStraightToCoord(npcHandle, startPos.x, startPos.y, startPos.z, 1.0, -1, startPos.w, 0.5)

                    MS_PlayHyper(currentNetId, '5t', 15.0)
                    MS_ShowSubtitle("M.Duggan : Bon je vous laisse travailler !", 3000)
                    ThorntonParle(3000)

                    MS_PlayHyper(currentNetId, '6t', 15.0)
                    MS_ShowSubtitle("M.Duggan : On se revoit quand c'est fait !", 4000)
                    ThorntonParle(4000)

                    MS_ShowSubtitle("Attendez que ~HUD_COLOUR_MENU_GREY_LIGHT~M. Duggan~w~ s'en aille.", 6000)
                    Wait(6000)

                    local isReturning = true
                    while isReturning do
                        Wait(500)
                        if DoesEntityExist(npcHandle) then
                            local currentCoords = GetEntityCoords(npcHandle)
                            local distToHome = #(currentCoords - vector3(startPos.x, startPos.y, startPos.z))

                            if distToHome < 1.5 then
                                EntrerVoiture(npcHandle)
                                if DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
                                missionTerminee = true
                                isReturning = false

                                Citizen.SetTimeout(20000, function()
                                    if DoesEntityExist(npcHandle) then DeleteEntity(npcHandle) end
                                end)
                            end
                        else
                            isReturning = false
                        end
                    end



                    MS_ShowSubtitle("Piratez les ~r~verrous électriques.", 10000)
                    TriggerEvent('mission:setupBlips')
                    Relay("event", { name = 'mission:setupBlips', args = {} }, false)

                else
                    challengeStarted = false -- Re-try allowed
                    RenderScriptCams(false, true, 1000, true, true)
                    DestroyCam(cam, false)
                    ShowNotification("Vous avez <span style='color:#E74C3C; font-weight:bold;'>échoué le test de persuasion</span>.", 5000)
                end
            end
        end

        ::continue::
        Wait(sleep)
    end
end)
