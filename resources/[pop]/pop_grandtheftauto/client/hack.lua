-- Piratage d'une voiture : verrou serveur, placement du module (caméra), mini-jeu, fin validée par le serveur.

-- =========================
-- CONFIG
-- =========================
local PLATE_PATTERN = "BEN"
local PROP_MODEL = "hei_prop_heist_card_hack_02"
local ROTATION_SPEED = 5.0
local WIN_RADIUS = 0.12

-- SUIVI DES ÉTATS
local HackedVehicles = {}
local CompletedMissions = {}

-- =========================
-- SYNCHRO COOP (LOCKS / ÉTATS)
-- =========================




-- Utilisation de ShowPrompt et HidePrompt globaux (depuis utils.lua)

local PendingHackLocks = {}
local RemoteHackLockedBy = {} -- plate -> serverId

RegisterNetEvent('mission:client:hackLockResult')
AddEventHandler('mission:client:hackLockResult', function(plate, ok, reason)
    PendingHackLocks[plate] = { ok = ok == true, reason = reason }
end)

RegisterNetEvent('mission:client:hackState')
AddEventHandler('mission:client:hackState', function(plate, completed, lockedBy)
    if not plate or plate == '' then return end

    if completed == true then
        CompletedMissions[plate] = true
        HackedVehicles[plate] = nil
        RemoteHackLockedBy[plate] = nil
    else
        RemoteHackLockedBy[plate] = lockedBy
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('mission:server:requestHackState')
end)

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

local function RequestHackLock(plate)
    if not plate or plate == '' then return false, 'invalid' end
    if CompletedMissions[plate] then return false, 'completed' end

    PendingHackLocks[plate] = nil
    TriggerServerEvent('mission:server:tryLockHack', plate)

    local timeout = GetGameTimer() + 4000
    while GetGameTimer() < timeout do
        Wait(0)
        local r = PendingHackLocks[plate]
        if r then
            PendingHackLocks[plate] = nil
            return r.ok, r.reason
        end
    end

    return false, 'timeout'
end

local function ReleaseHackLock(plate)
    if not plate or plate == '' then return end
    TriggerServerEvent('mission:server:releaseHackLock', plate)
end

local function clamp(v, min, max) return math.max(min, math.min(max, v)) end

-- =========================
-- CONFIG CAMÉRAS
-- =========================
local VehicleCamConfig = {
    schlagen = { camOffset = vector3(0.3, 2.1, 1.3), pointOffset = vector3(0.0, -0.2, 0.25), invertX = true },
    schweizer2 = { camOffset = vector3(0.0, 3.2, 1.5), pointOffset = vector3(0.0, 0.0, 0.0), invertX = true },
    krieger = { camOffset = vector3(0.0, 0.0, 1.5), pointOffset = vector3(0.0, 0.0, 0.0), invertX = true },
    sm722 = { camOffset = vector3(0.0, 0.0, 1.5), pointOffset = vector3(0.0, 0.0, 0.0), invertX = false }
}

-- Les voitures viennent de shared/config.lua (Cars), avec leur modèle de repli
deliveryStarted = false
local PendingFinalize = {}
RegisterNetEvent('mission:client:finalizeResult')
AddEventHandler('mission:client:finalizeResult', function(plate, ok, reason)
    PendingFinalize[plate] = { ok = ok == true, reason = reason }
end)

-- =========================
-- UTILS
-- =========================
local function AggressiveEngineStart(vehicle)
    if DoesEntityExist(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleBurnout(vehicle, true)
        SetVehicleEngineOn(vehicle, true, false, true)

        local endTimer = GetGameTimer() + 1500
        CreateThread(function()
            local ped = PlayerPedId()
            while GetGameTimer() < endTimer do
                Wait(0)
                TaskVehicleTempAction(ped, vehicle, 23, 100)
                SetVehicleCurrentRpm(vehicle, 1.0)
            end
            SetVehicleBurnout(vehicle, false)
        end)
    end
end

-- =========================
-- SCALEFORM CONTROLS
-- =========================
local buttonsScaleform = nil

local function DrawHackControls()
    if not buttonsScaleform then
        buttonsScaleform = RequestScaleformMovie("instructional_buttons")
        while not HasScaleformMovieLoaded(buttonsScaleform) do Wait(0) end

        PushScaleformMovieFunction(buttonsScaleform, "CLEAR_ALL")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(0)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 322, true))
        PushScaleformMovieMethodParameterString(L('hack_cancel'))
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(1)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 38, true))
        PushScaleformMovieMethodParameterString(L('hack_validate'))
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(2)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 241, true))
        PushScaleformMovieMethodParameterString(L('hack_scroll'))
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(3)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 25, true))
        PushScaleformMovieMethodParameterString(L('hack_move'))
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
        PopScaleformMovieFunctionVoid()
    end
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
end

local function GetVehicleByPlatePattern(pattern)
    if #(GetEntityCoords(PlayerPedId()) - Config.ShowroomPos) > 80.0 then return nil end
    local vehicles = GetGamePool("CVehicle")
    local pCoords = GetEntityCoords(PlayerPedId())
    local closest, dist = nil, 20.0
    for _, veh in ipairs(vehicles) do
        local plate = GetVehicleNumberPlateText(veh)
        if plate and trim(plate):find(pattern) then
            local d = #(pCoords - GetEntityCoords(veh))
            if d < dist then closest, dist = veh, d end
        end
    end
    return closest
end

local function GetVehicleModelName(veh)
    local model = GetEntityModel(veh)
    for _, v in ipairs(Cars) do
        if joaat(v.model) == model or (v.fallback and joaat(v.fallback) == model) then return v.model end
    end
    return nil
end

-- =========================
-- GESTION HACK
-- =========================
local ActiveHacks = {}

local function CreateHackInstance(veh, modelName)
    local startOffset = (modelName == "schweizer2") and vector3(0.35, 0.35, 0.0) or vector3(0.25, 0.25, 0.0)
    local inst = {
        ped = PlayerPedId(), veh = veh, cam = nil, prop = nil, placeholder = nil,
        rotX = 0.0, rotZ = 0.0, offset = startOffset, success = false, modelName = modelName, lockPlate = nil
    }
    ActiveHacks[inst.ped] = inst
    return inst
end

local function StopHack(inst)
    RenderScriptCams(false, true, 800, true, true)
    if DoesCamExist(inst.cam) then DestroyCam(inst.cam, false) end
    if DoesEntityExist(inst.prop) then DeleteEntity(inst.prop) end
    if DoesEntityExist(inst.placeholder) then DeleteEntity(inst.placeholder) end

    if DoesEntityExist(inst.veh) and not inst.success then
        SetVehicleDoorShut(inst.veh, 4, false)
    end

    FreezeEntityPosition(inst.ped, false)
    SetNuiFocus(false, false)

    if buttonsScaleform then
        SetScaleformMovieAsNoLongerNeeded(buttonsScaleform)
        buttonsScaleform = nil
    end

    ActiveHacks[inst.ped] = nil

    if inst.lockPlate and not inst.success then
        ReleaseHackLock(inst.lockPlate)
    end
end

local function FinalizeHack(veh)
    local plate = trim(GetVehicleNumberPlateText(veh))

    -- Le serveur valide et consomme le module pirate (pcb) seulement maintenant
    PendingFinalize[plate] = nil
    TriggerServerEvent('mission:server:finalizeHack', plate, NetworkGetNetworkIdFromEntity(veh))
    local limit = GetGameTimer() + 5000
    while not PendingFinalize[plate] and GetGameTimer() < limit do Wait(50) end
    local res = PendingFinalize[plate]
    PendingFinalize[plate] = nil
    if not res or not res.ok then
        local reason = res and res.reason
        if reason == 'nopcb' then
            MissionNotify(L('need_pcb'), 5000)
        elseif reason == 'completed' then
            MissionNotify(L('already_hacked'), 7000)
        else
            MissionNotify(L('hack_failed'), 5000)
        end
        return
    end

    NetworkRequestControlOfEntity(veh)
    SetVehicleDoorOpen(veh, 4, false, true)

    HackedVehicles[plate] = nil
    CompletedMissions[plate] = true
    deliveryStarted = true
    AggressiveEngineStart(veh)

    -- Alertes police (positions et véhicules suivis déterminés par le serveur)
    TriggerServerEvent('mission:server:alertPoliceLocation')
    TriggerServerEvent('mission:server:alertPolice')

    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    TriggerEvent('ondeliveryblip')
    TriggerEvent('spawncamion')

    for i = 0, 5 do SetVehicleDoorOpen(veh, i, false, true) end
    Wait(1000)
    for i = 0, 5 do SetVehicleDoorShut(veh, i, false) end

        MissionNotify(L('security_off'), 7000)
end

local function StartCableHack(veh)
    NetworkRequestControlOfEntity(veh)
    local timeout = 0
    while not NetworkHasControlOfEntity(veh) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end

    local modelName = GetVehicleModelName(veh)
    local inst = CreateHackInstance(veh, modelName)
    inst.lockPlate = trim(GetVehicleNumberPlateText(veh))
    local cfg = VehicleCamConfig[modelName]

    SetVehicleDoorOpen(veh, 4, false, true)
    if IsCoopActive() then
        Relay("command", { cmd = "opencapot" }, false)
    end

    FreezeEntityPosition(inst.ped, true)

    local bone = GetEntityBoneIndexByName(veh, "engine")
    if bone == -1 then bone = GetEntityBoneIndexByName(veh, "bonnet") end

    local model = LoadModel(PROP_MODEL)
    if not model then
        FreezeEntityPosition(inst.ped, false)
        ActiveHacks[inst.ped] = nil
        ReleaseHackLock(inst.lockPlate)
        return
    end

    local attachZ = (modelName == "schweizer2") and 0.22 or 0.1

    inst.placeholder = CreateObject(model, 0, 0, 0, false, false, false)
    SetEntityCollision(inst.placeholder, false, false)
    AttachEntityToEntity(inst.placeholder, veh, bone, 0.0, 0.0, attachZ, 0.0, 90.0, 0.0, false, false, false, false, 2, true)
    SetEntityAlpha(inst.placeholder, 100, false)
    SetEntityDrawOutline(inst.placeholder, true)
    SetEntityDrawOutlineColor(0, 255, 0, 255)

    inst.prop = CreateObject(model, 0, 0, 0, false, false, false)
    SetEntityCollision(inst.prop, false, false)
    SetEntityDrawOutline(inst.prop, true)

    inst.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local camOffset = cfg and cfg.camOffset or vector3(0.0, 0.0, 1.5)
    local camPos = GetOffsetFromEntityInWorldCoords(veh, camOffset.x, camOffset.y, camOffset.z)
    SetCamCoord(inst.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(inst.cam, inst.placeholder, 0.0, 0.0, 0.0, true)

    SetCamActive(inst.cam, true)
    RenderScriptCams(true, true, 800, true, true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
end

local function StartCableHackCoop(veh)
    local plate = trim(GetVehicleNumberPlateText(veh))
    if CompletedMissions[plate] then
            MissionNotify(L('already_hacked'), 7000)
        return
    end

    local ok, reason = RequestHackLock(plate)
    if not ok then
        if reason == 'completed' then
            MissionNotify(L('already_hacked'), 7000)
        elseif reason == 'locked' then
            MissionNotify(L('being_hacked'), 7000)
        elseif reason == 'nomission' then
            MissionNotify(L('no_heist'), 7000)
        else
            MissionNotify(L('hack_failed_retry'), 5000)
        end
        return
    end
    StartCableHack(veh)
end

local startBusy = false
CreateThread(function()
    while true do
        local wait = 500
        local ped = PlayerPedId()

        if not IsCoopActive() and next(ActiveHacks) == nil then
            wait = 1500
            HidePrompt("start_module")
        elseif next(ActiveHacks) ~= nil then
            for _, inst in pairs(ActiveHacks) do
                wait = 0
                DisableAllControlActions(0)
                if IsDisabledControlJustPressed(0, 322) then StopHack(inst) break end

                DrawHackControls()

                if not inst.success then
                    local my = GetDisabledControlNormal(0, 2)
                    local scrollMove = 0.0
                    if IsDisabledControlJustPressed(0, 241) then scrollMove = 0.08
                    elseif IsDisabledControlJustPressed(0, 242) then scrollMove = -0.08 end

                    if IsDisabledControlPressed(0, 24) then
                        inst.rotZ = inst.rotZ - GetDisabledControlNormal(0, 1) * ROTATION_SPEED
                        inst.rotX = clamp(inst.rotX + my * ROTATION_SPEED, -45.0, 45.0)
                    end

                    if IsDisabledControlPressed(0, 25) then
                        inst.offset = inst.offset + vector3(my * 0.02, 0.0, 0.0)
                    end

                    if scrollMove ~= 0.0 then
                        inst.offset = inst.offset + vector3(0.0, scrollMove, 0.0)
                    end

                    inst.offset = vector3(clamp(inst.offset.x, -0.6, 0.6), clamp(inst.offset.y, -0.6, 0.6), 0.0)

                    local finalPos = GetOffsetFromEntityInWorldCoords(inst.placeholder, inst.offset.x, inst.offset.y, inst.offset.z)
                    SetEntityCoordsNoOffset(inst.prop, finalPos.x, finalPos.y, finalPos.z, true, true, true)
                    SetEntityRotation(inst.prop, inst.rotX, 90.0, inst.rotZ + GetEntityHeading(inst.veh), 2, true)

                    if #(GetEntityCoords(inst.prop) - GetEntityCoords(inst.placeholder)) < WIN_RADIUS then
                        inst.success = true
                        local plate = trim(GetVehicleNumberPlateText(inst.veh))
                        HackedVehicles[plate] = true
                        PlaySoundFrontend(-1, "Challenge_Unlock", "HUD_AWARDS", true)
                        HidePrompt("fix_module_"..tostring(inst.ped))
                    end
                else
                    ShowPrompt("fix_module_"..tostring(inst.ped), GetEntityCoords(inst.prop) + vector3(0,0,0.2), L('prompt_fix'), "fas fa-microchip")
                    if IsDisabledControlJustReleased(0, 38) then
                        local v = inst.veh
                        StopHack(inst)
                        HidePrompt("fix_module_"..tostring(inst.ped))
                        CreateThread(function()
                            Wait(100)
                            if RunVoltlab(30) then
                                FinalizeHack(v)
                            else
                                MissionNotify(L('hack_failed_restart'), 5000)
                            end
                        end)
                        break
                    end
                end
            end
        else
            local veh = GetVehicleByPlatePattern(PLATE_PATTERN)
            if veh then
                local plate = trim(GetVehicleNumberPlateText(veh))
                if HackedVehicles[plate] and not CompletedMissions[plate] then
                    local vCoords = GetEntityCoords(veh)
                    local dist = #(GetEntityCoords(ped) - vCoords)
                    if dist < 4.0 then
                        wait = 0
                        ShowPrompt("start_module", vCoords + vector3(0,0,1.0), L('prompt_start'), "fas fa-power-off")
                        if IsControlJustReleased(0, 38) and not startBusy then
                            HidePrompt("start_module")
                            startBusy = true
                            CreateThread(function()
                                if RunVoltlab(30) then
                                    FinalizeHack(veh)
                                else
                                    MissionNotify(L('hack_failed'), 5000)
                                end
                                startBusy = false
                            end)
                        end
                    else
                        HidePrompt("start_module")
                    end
                else
                    HidePrompt("start_module")
                end
            else
                HidePrompt("start_module")
            end
        end
        Wait(wait)
    end
end)

-- =========================
-- FIN DE MISSION : remise à zéro
-- =========================
AddEventHandler('mission:local:reset', function()
    for _, inst in pairs(ActiveHacks) do StopHack(inst) end
    deliveryStarted = false
    -- vidées sur place : pcb.lua garde une référence vers ces tables
    for k in pairs(HackedVehicles) do HackedVehicles[k] = nil end
    for k in pairs(CompletedMissions) do CompletedMissions[k] = nil end
    for k in pairs(RemoteHackLockedBy) do RemoteHackLockedBy[k] = nil end
    for k in pairs(PendingHackLocks) do PendingHackLocks[k] = nil end
    HidePrompt("start_module")
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, inst in pairs(ActiveHacks) do StopHack(inst) end
end)

-- Partagé avec pcb.lua (commande, glisser-déposer, livraison coop)
PCB = {
    PATTERN = PLATE_PATTERN,
    Active = ActiveHacks,
    Hacked = HackedVehicles,
    Completed = CompletedMissions,
    trim = trim,
    FindVehicle = GetVehicleByPlatePattern,
    StartCoop = StartCableHackCoop,
}
