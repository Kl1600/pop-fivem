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


-- =========================
-- CONFIG
-- =========================
local PLATE_PATTERN = "BEN"
local PROP_MODEL = "hei_prop_heist_card_hack_02"
local ROTATION_SPEED = 5.0
local MOVE_SPEED = 0.02
local WIN_RADIUS = 0.12

-- SUIVI DES ÉTATS
local HackedVehicles = {}    
local CompletedMissions = {} 

-- =========================
-- SYNCHRO COOP (LOCKS / ÉTATS)
-- =========================

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

local function Relay(action, data, includeSender)
    local MS = EnsureMissionSync()
    if MS.active then 
        TriggerServerEvent('mission:server:relay', action, data, includeSender == true)
    end
end

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

local Cars = {
    { plate = "763 BEN", model = 'krieger' },
    { plate = "968 BEN", model = 'sm722' },
    { plate = "119 BEN", model = 'schlagen' },
    { plate = "317 BEN", model = 'schweizer2' }
}

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
        PushScaleformMovieMethodParameterString("Annuler")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(1)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 38, true))
        PushScaleformMovieMethodParameterString("Valider")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(2)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 241, true))
        PushScaleformMovieMethodParameterString("Avant-Arrière (Molette)")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(3)
        PushScaleformMovieMethodParameterString(GetControlInstructionalButton(0, 25, true))
        PushScaleformMovieMethodParameterString("Déplacement (Clic Droit)")
        PopScaleformMovieFunctionVoid()

        PushScaleformMovieFunction(buttonsScaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
        PopScaleformMovieFunctionVoid()
    end
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
end

local function GetVehicleByPlatePattern(pattern)
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
    for _, v in ipairs(Cars) do if joaat(v.model) == model then return v.model end end
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
    local showroomCoords = vector3(-69.0, 64.0, 71.9)
    
    NetworkRequestControlOfEntity(veh)
    SetVehicleDoorOpen(veh, 4, false, true)
    
    HackedVehicles[plate] = nil 
    CompletedMissions[plate] = true 
    TriggerServerEvent('mission:server:setHackCompleted', plate, true) 
    AggressiveEngineStart(veh)
    
    TriggerServerEvent('mission:server:alertPoliceLocation', showroomCoords)

    -- RÉCUPÉRATION SYNCHRONISÉE DES NETIDS
    local vehicleNetIds = {}
    if _G.Cars then 
        for i = 1, #_G.Cars do
            if _G.Cars[i] and _G.Cars[i].spawned then
                table.insert(vehicleNetIds, NetworkGetNetworkIdFromEntity(_G.Cars[i].spawned))
            end
        end
    end
    
    -- APPEL SERVEUR POUR TRACKER 10 SECONDES
    TriggerServerEvent('mission:server:alertPolice', vehicleNetIds)
    
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    TriggerEvent('ondeliveryblip')
    TriggerEvent('spawncamion')
    
    for i = 0, 5 do SetVehicleDoorOpen(veh, i, false, true) end
    Wait(1000)
    for i = 0, 5 do SetVehicleDoorShut(veh, i, false) end
    
    --ESX.ShowNotification("La sécurité a été desactivée, ~y~rendez-vous au point~w~ indiqué sur votre GPS.")

        ShowNotification("Vous avez désactivé la <span style='color:#E74C3C; font-weight:bold;'>sécurité de démarrage</span>, rendez-vous au point <span style='color:#ECA95D; font-weight:bold;'>indiqué sur votre GPS.</span>", 7000)
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

    local model = joaat(PROP_MODEL)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

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
        --ESX.ShowNotification('Ce véhicule ~r~a déjà été piraté.~s~')
            ShowNotification("Le véhicule que vous essayez de pirater <span style='color:#E74C3C; font-weight:bold;'>a déjà été piraté.</span>", 7000)
        return
    end

    local ok, reason = RequestHackLock(plate)
    if not ok then
        if reason == 'completed' then
            --ESX.ShowNotification('Ce véhicule ~r~a déjà été piraté.~s~')
            ShowNotification("Le véhicule que vous essayez de pirater <span style='color:#E74C3C; font-weight:bold;'>a déjà été piraté.</span>", 7000)
        elseif reason == 'locked' then
            --ESX.ShowNotification("Quelqu'un est ~y~déjà en train de pirater ce véhicule.")
            ShowNotification("Le véhicule que vous essayez de pirater <span style='color:#E74C3C; font-weight:bold;'>est déjà en train d'être piraté.</span>", 7000)
        else
            print('error: contact Tabernac Softwares')
        end
        return
    end
    StartCableHack(veh)
end

CreateThread(function()
    while true do
        local wait = 500
        local ped = PlayerPedId()

        if next(ActiveHacks) ~= nil then
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
                    --ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ~HUD_COLOUR_MENU_GREY_LIGHT~fixer le module pirate.")
                    ShowPrompt("fix_module_"..tostring(inst.ped), GetEntityCoords(inst.prop) + vector3(0,0,0.2), "FIXER LE MODULE", "fas fa-microchip")
                    if IsDisabledControlJustReleased(0, 38) then
                        local v = inst.veh
                        StopHack(inst)
                        HidePrompt("fix_module_"..tostring(inst.ped))
                        Wait(100)
                        local success = exports['CircuitBreakerMinigame_lua']:startCircuit(7, 0)
                        if success then
                            FinalizeHack(v)
                        else
                            ShowNotification("Le <span style='color:#E74C3C; font-weight:bold;'>piratage a échoué</span>.", 5000)
                        end
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
                        ShowPrompt("start_module", vCoords + vector3(0,0,1.0), "DÉMARRER", "fas fa-power-off")
                        if IsControlJustReleased(0, 38) then 
                            HidePrompt("start_module")
                            local success = exports['CircuitBreakerMinigame_lua']:startCircuit(7, 0)
                            if success then
                                FinalizeHack(veh) 
                            else
                                ShowNotification("Le <span style='color:#E74C3C; font-weight:bold;'>piratage a échoué</span>.", 5000)
                            end
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

RegisterCommand("voler_auto", function()
    local ped = PlayerPedId()
    if ActiveHacks[ped] then return end
    
    local veh = GetVehicleByPlatePattern(PLATE_PATTERN)
    if not veh then return end
    
    CheckItem('pcb', function(hasItem)
        if hasItem then
            local plate = trim(GetVehicleNumberPlateText(veh))
            
            if CompletedMissions[plate] then
                ShowNotification("Le véhicule que vous essayez de pirater <span style='color:#E74C3C; font-weight:bold;'>a déjà été piraté.</span>", 7000)
                return
            end

            if HackedVehicles[plate] then
                ShowNotification("Un module pirate <span style='color:#E74C3C; font-weight:bold;'>a déjà été installé, enclenchez le</span> pour démarrer la voiture.", 7000)
                return
            end

            if #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 5.0 then
                -- Remove item here, assuming success path (or make it so it's removed only if hack succeeds? No, user said "supprimé une fois utilisé", usually implies on attempt/start)
                TriggerServerEvent('grandtheftauto:removeItem', 'pcb', 1)
                StartCableHackCoop(veh) 
            else
                ShowNotification("Vous n'êtes <span style='color:#E74C3C; font-weight:bold;'>pas assez proche</span> du véhicue que vous essayez de pirater.", 7000)
            end
        else
            ShowNotification("Vous avez besoin d'un <span style='color:#E74C3C; font-weight:bold;'>Module Pirate (PCB)</span>.", 5000)
        end
    end, 'pcb')
end, false)

RegisterNetEvent('grandtheftauto:usePCB')
AddEventHandler('grandtheftauto:usePCB', function()
    ExecuteCommand('voler_auto')
end)

-- =========================
-- COMMANDES DEV
-- =========================
RegisterCommand("voler_auto_dev", function()
    local ped = PlayerPedId()
    if ActiveHacks[ped] then return end
    
    local veh = GetVehicleByPlatePattern(PLATE_PATTERN)
    if not veh then 
        print("Aucun véhicule correspondant au pattern '" .. PLATE_PATTERN .. "' trouvé à proximité.")
        return 
    end
    
    ShowNotification("<span style='color:#3498DB; font-weight:bold;'>MODE DEV</span> : Initialisation du hack sans condition.", 3000)
    
    -- On téléporte le joueur près du capot pour être sûr
    local bonnetPos = GetWorldPositionOfEntityBone(veh, GetEntityBoneIndexByName(veh, "engine"))
    if bonnetPos ~= vector3(0,0,0) then
        SetEntityCoords(ped, bonnetPos.x, bonnetPos.y, bonnetPos.z - 1.0, false, false, false, true)
    end
    
    Wait(500)
    StartCableHack(veh)
end, true)

-- =========================
-- DRAG & DROP INVENTORY INTEGRATION
-- =========================
local registeredDragVehs = {}

CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local vehicles = GetGamePool("CVehicle")
        
        for _, veh in ipairs(vehicles) do
            if not registeredDragVehs[veh] then
                local plate = GetVehicleNumberPlateText(veh)
                if plate and trim(plate):find(PLATE_PATTERN) then
                    exports.pop_inventory:registerDragTarget(veh, 'pcb', function()
                        ExecuteCommand('pop_inventory') -- Force la fermeture de l'inventaire
                        
                        local playerPed = PlayerPedId()
                        if ActiveHacks[playerPed] then return end
                        
                        CheckItem('pcb', function(hasItem)
                            if hasItem then
                                local plateEntity = trim(GetVehicleNumberPlateText(veh))
                                
                                if CompletedMissions[plateEntity] then
                                    ShowNotification("Le véhicule que vous essayez de pirater <span style='color:#E74C3C; font-weight:bold;'>a déjà été piraté.</span>", 7000)
                                    return
                                end

                                if HackedVehicles[plateEntity] then
                                    ShowNotification("Un module pirate <span style='color:#E74C3C; font-weight:bold;'>a déjà été installé, enclenchez le</span> pour démarrer la voiture.", 7000)
                                    return
                                end

                                if #(GetEntityCoords(playerPed) - GetEntityCoords(veh)) < 5.0 then
                                    TriggerServerEvent('grandtheftauto:removeItem', 'pcb', 1)
                                    StartCableHackCoop(veh) 
                                else
                                    ShowNotification("Vous n'êtes <span style='color:#E74C3C; font-weight:bold;'>pas assez proche</span> du véhicue que vous essayez de pirater.", 7000)
                                end
                            else
                                ShowNotification("Vous avez besoin d'un <span style='color:#E74C3C; font-weight:bold;'>Module Pirate (PCB)</span>.", 5000)
                            end
                        end, 'pcb')
                    end)
                    registeredDragVehs[veh] = true
                end
            end
        end
        
        for v, _ in pairs(registeredDragVehs) do
            if not DoesEntityExist(v) then
                exports.pop_inventory:unregisterDragTarget(v)
                registeredDragVehs[v] = nil
            end
        end
    end
end)