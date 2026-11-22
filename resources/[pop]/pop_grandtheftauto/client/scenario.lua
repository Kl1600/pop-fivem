local npcHandle = nil
local npcBlip = nil
local missionTerminee = false
local challengeStarted = false
local challengeDone = false

local pedModel = GetHashKey('ig_thornton')
local startPos = Config.Positions.ThorntonStart
local targetPos = Config.Positions.ThorntonTarget
local targetHeading = Config.Positions.ThorntonTargetHeading

-- ============================================================
-- SYNCHRO (COOP)
-- ============================================================







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

local function EnsureThorntonBlip()
    if missionTerminee then return end
    if not npcHandle or not DoesEntityExist(npcHandle) then return end
    if npcBlip and DoesBlipExist(npcBlip) then return end

    npcBlip = AddBlipForEntity(npcHandle)
    SetBlipSprite(npcBlip, 128)
    SetBlipColour(npcBlip, 40)
    SetBlipScale(npcBlip, 0.4)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L('blip_thornton'))
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
    if not LoadAnimDict(animDict) then return end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 2, 0, false, false, false)
end

-- Attend que le PNJ soit arrivé, avec un délai max (sinon on le place directement)
local function WaitArrival(ped, pos, radius, timeoutMs)
    local limit = GetGameTimer() + timeoutMs
    while DoesEntityExist(ped) and #(GetEntityCoords(ped) - pos) >= radius do
        if GetGameTimer() > limit then return false end
        Wait(500)
    end
    return true
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

AddEventHandler('startheist', function(ownerServerId, heistId)
    challengeStarted, challengeDone, missionTerminee = false, false, false
    if IsCoopActive() and not IsOwner() then
        return
    end

    if DoesEntityExist(npcHandle) then
        _G.npcHandle = npcHandle
        EnsureThorntonBlip()
        return
    end

    local model = LoadFirstModel({ pedModel, 'csb_thornton', 'a_m_m_business_01' })
    if not model then return end

    npcHandle = CreatePed(4, model, startPos.x, startPos.y, startPos.z - 1.0, startPos.w, true, true)
    SetModelAsNoLongerNeeded(model)

    SetPedPropIndex(npcHandle, 0, 0, 0, true)
    local npcNetId = NetworkGetNetworkIdFromEntity(npcHandle)

    SetNetworkIdCanMigrate(npcNetId, false)
    SetNetworkIdExistsOnAllMachines(npcNetId, true)

    SetEntityAsMissionEntity(npcHandle, true, true)

    local moveClipset = "move_f@depressed@a"
    RequestAnimSet(moveClipset)
    local limit = GetGameTimer() + 3000
    while not HasAnimSetLoaded(moveClipset) and GetGameTimer() < limit do Wait(10) end
    if HasAnimSetLoaded(moveClipset) then SetPedMovementClipset(npcHandle, moveClipset, 1.0) end

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
                MS_ShowSubtitle(L('thornton_1'), 5000)
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

                -- (Test vocal « mensonge » retiré à la demande du client : Thornton accepte directement.)
                Wait(1500)
                local successChallenge = true

                if successChallenge then
                    challengeDone = true
                    RenderScriptCams(false, true, 1000, true, true)
                    DestroyCam(cam, false)

                    -- --- PARCOURS NORMAL (Après victoire) --- --

                    -- 1. Il marche vers la voiture
                    TaskGoStraightToCoord(npcHandle, targetPos.x, targetPos.y, targetPos.z, 1.0, -1, targetHeading, 0.5)

                    MS_PlayHyper(currentNetId, '2t', 15.0)
                    MS_ShowSubtitle(L('thornton_2'), 4000)
                    ThorntonParle(4000)

                    MS_PlayHyper(currentNetId, '3t', 15.0)
                    MS_ShowSubtitle(L('thornton_3a'), 2500)
                    ThorntonParle(2500)
                    MS_ShowSubtitle(L('thornton_3b'), 2500)
                    ThorntonParle(2500)

                    -- Attendre qu'il arrive à la voiture (20 s max)
                    WaitArrival(npcHandle, targetPos, 1.2, 20000)

                    ClearPedTasks(npcHandle)
                    SetEntityCoords(npcHandle, targetPos.x, targetPos.y, targetPos.z - 1.0, false, false, false, true)
                    SetEntityHeading(npcHandle, targetHeading)

                    playArrestAnim(npcHandle)
                    Wait(500)

                    Wait(1000)
                    TriggerEvent('mission:local:opencapot')
                    Relay("command", { cmd = "opencapot" }, false)

                    MS_PlayHyper(currentNetId, '4t', 15.0)
                    MS_ShowSubtitle(L('thornton_4'), 4000)
                    ThorntonParle(4000)

                    ClearPedTasks(npcHandle)
                    Wait(1000)

                    -- 2. Il retourne à son point de départ pour s'en aller
                    TaskGoStraightToCoord(npcHandle, startPos.x, startPos.y, startPos.z, 1.0, -1, startPos.w, 0.5)

                    MS_PlayHyper(currentNetId, '5t', 15.0)
                    MS_ShowSubtitle(L('thornton_5'), 3000)
                    ThorntonParle(3000)

                    MS_PlayHyper(currentNetId, '6t', 15.0)
                    MS_ShowSubtitle(L('thornton_6'), 4000)
                    ThorntonParle(4000)

                    MS_ShowSubtitle(L('wait_thornton'), 6000)
                    Wait(6000)

                    -- Il rentre à sa voiture (30 s max), puis s'en va
                    WaitArrival(npcHandle, vector3(startPos.x, startPos.y, startPos.z), 1.5, 30000)
                    missionTerminee = true
                    if DoesEntityExist(npcHandle) then
                        EntrerVoiture(npcHandle)
                        if npcBlip and DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
                        npcBlip = nil
                        local leaving = npcHandle
                        Citizen.SetTimeout(20000, function()
                            if DoesEntityExist(leaving) and not IsPedInAnyVehicle(leaving, false) then DeleteEntity(leaving) end
                        end)
                    end



                    MS_ShowSubtitle(L('hack_locks'), 10000)
                    TriggerEvent('mission:setupBlips')
                    Relay("event", { name = 'mission:setupBlips', args = {} }, false)

                else
                    challengeStarted = false -- Re-try allowed
                    RenderScriptCams(false, true, 1000, true, true)
                    DestroyCam(cam, false)
                    MissionNotify(L('persuasion_failed'), 5000)
                end
            end
        end

        ::continue::
        Wait(sleep)
    end
end)

-- ============================================================
-- FIN DE MISSION : remise à zéro (le serveur supprime les entités)
-- ============================================================
AddEventHandler('mission:local:reset', function()
    challengeStarted, challengeDone, missionTerminee = false, false, false
    if npcBlip and DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
    npcBlip = nil
    npcHandle = nil
    _G.npcHandle = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if npcBlip and DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
    if npcHandle and DoesEntityExist(npcHandle) and NetworkHasControlOfEntity(npcHandle) then DeleteEntity(npcHandle) end
end)
