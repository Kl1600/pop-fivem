-- Piratage d'une voiture, en étapes courtes :
--   1. Brancher le module : [E] près du capot, capot ouvert, 3 s d'animation (barre annulable).
--   2. Pirater : fenêtre NUI « stop au bon moment » (3 manches, [E] valider, [Échap] abandonner).
--   3. Réussite : le serveur valide (distance, plaque, mission, pcb) puis déverrouille la voiture.
--      3 erreurs : alarme, module non consommé, nouvel essai après Config.Hack.retryDelay secondes.

-- =========================
-- CONFIG
-- =========================
local PLATE_PATTERN = "BEN"
local PLUG_DISTANCE = 2.2 -- distance au capot pour brancher le module

-- SUIVI DES ÉTATS
local CompletedMissions = {}
local HackedVehicles = {} -- conservé pour pcb.lua (plus utilisé : le piratage se fait d'une traite)
local retryAt = 0         -- GetGameTimer() avant lequel on ne peut pas réessayer (après l'alarme)
local busy = false        -- un piratage (ou le branchement) est en cours

-- =========================
-- SYNCHRO COOP (LOCKS / ÉTATS)
-- =========================
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
    Debug(('verrou %s rendu'):format(plate))
end

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

-- Position du capot (os « bonnet », sinon l'avant de la voiture)
local function BonnetCoords(veh)
    local bone = GetEntityBoneIndexByName(veh, "bonnet")
    if bone ~= -1 then return GetWorldPositionOfEntityBone(veh, bone) end
    local _, max = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y, 0.2)
end

-- =========================
-- MINI-JEU NUI « STOP AU BON MOMENT » (aussi utilisé par le panneau électrique)
-- =========================
local hackResult = nil
RegisterNUICallback('hackResult', function(data, cb)
    hackResult = data and data.result or 'abort'
    cb('ok')
end)

-- Renvoie 'success', 'fail' (trop d'erreurs) ou 'abort' (Échap / Retour arrière / mort)
function RunHackGame(title)
    local h = Config.Hack
    hackResult = nil
    SendNUIMessage({
        action = 'hack:open', title = title,
        rounds = h.rounds, zoneStart = h.zoneStart, zoneShrink = h.zoneShrink,
        speedStart = h.speedStart, speedStep = h.speedStep, maxFails = h.maxFails,
    })
    Debug('mini-jeu ouvert')

    -- Pas de focus NUI : le jeu lit [E] et [Échap] ; le joueur ne bouge pas pendant le mini-jeu
    local limit = GetGameTimer() + 90000
    while hackResult == nil do
        DisableAllControlActions(0)
        DisableControlAction(0, 199, true)
        DisableControlAction(0, 200, true)
        EnableControlAction(0, 1, true) -- caméra libre
        EnableControlAction(0, 2, true)
        if IsDisabledControlJustPressed(0, 38) then
            SendNUIMessage({ action = 'hack:stop' })
        elseif IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) or IsDisabledControlJustPressed(0, 177)
            or IsEntityDead(PlayerPedId()) or GetGameTimer() > limit then
            SendNUIMessage({ action = 'hack:close' })
            hackResult = 'abort'
        end
        Wait(0)
    end
    Debug(('mini-jeu terminé : %s'):format(hackResult))
    return hackResult
end

-- =========================
-- FIN DU PIRATAGE (validée par le serveur)
-- =========================
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
        local reason = res and res.reason or 'timeout'
        Debug(('fin du piratage refusée par le serveur (%s) : %s'):format(plate, reason))
        ReleaseHackLock(plate)
        if reason == 'nopcb' then
            MissionNotify(L('need_pcb'), 5000)
        elseif reason == 'completed' then
            MissionNotify(L('already_hacked'), 7000)
        else
            MissionNotify(L('hack_failed'), 5000)
        end
        return false
    end

    Debug(('piratage réussi (%s) : voiture déverrouillée par le serveur'):format(plate))
    NetworkRequestControlOfEntity(veh)
    local ctrlLimit = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < ctrlLimit do Wait(10) end

    CompletedMissions[plate] = true
    deliveryStarted = true
    SetVehicleDoorShut(veh, 4, false)
    AggressiveEngineStart(veh)

    -- Alertes police (positions et véhicules suivis déterminés par le serveur)
    TriggerServerEvent('mission:server:alertPoliceLocation')
    TriggerServerEvent('mission:server:alertPolice')

    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    TriggerEvent('ondeliveryblip')
    TriggerEvent('spawncamion')

    MissionNotify(L('security_off'), 7000)
    return true
end

-- =========================
-- DÉROULÉ COMPLET SUR UNE VOITURE
-- =========================
local function HackVehicle(veh)
    if busy then return end
    local plate = trim(GetVehicleNumberPlateText(veh))

    if CompletedMissions[plate] then
        MissionNotify(L('already_hacked'), 7000)
        return
    end
    if GetGameTimer() < retryAt then
        MissionNotify(L('hack_retry_wait', math.ceil((retryAt - GetGameTimer()) / 1000)), 5000)
        return
    end

    busy = true
    local ok, reason = RequestHackLock(plate)
    Debug(('verrou %s : %s (%s)'):format(plate, ok and 'obtenu' or 'refusé', tostring(reason)))
    if not ok then
        if reason == 'completed' then
            MissionNotify(L('already_hacked'), 7000)
        elseif reason == 'locked' then
            MissionNotify(L('being_hacked'), 7000)
        elseif reason == 'nomission' then
            MissionNotify(L('no_heist'), 7000)
        elseif reason == 'cooldown' then
            MissionNotify(L('hack_retry_wait', Config.Hack.retryDelay), 5000)
        else
            MissionNotify(L('hack_failed_retry'), 5000)
        end
        busy = false
        return
    end

    -- 1. Brancher le module : capot ouvert, mécano penché sur le moteur
    local ped = PlayerPedId()
    NetworkRequestControlOfEntity(veh)
    local ctrlLimit = GetGameTimer() + 500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < ctrlLimit do Wait(10) end
    SetVehicleDoorOpen(veh, 4, false, false)
    Relay("command", { cmd = "opencapot" }, false)
    TaskTurnPedToFaceCoord(ped, GetEntityCoords(veh), 800)
    Wait(800)

    local plugged = Bridge.Progress(L('hack_plug'), Config.Hack.plugTime, {
        anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },
        canCancel = true,
    })
    ClearPedTasks(ped)
    if not plugged then
        Debug(('branchement annulé (%s)'):format(plate))
        SetVehicleDoorShut(veh, 4, false)
        ReleaseHackLock(plate)
        busy = false
        return
    end
    Debug(('module branché (%s)'):format(plate))

    -- 2. Pirater
    local result = RunHackGame(L('hack_ui_title'))

    if result == 'success' then
        -- 3. Le serveur valide tout (distance, plaque, mission, module)
        FinalizeHack(veh)
    elseif result == 'fail' then
        -- Trop d'erreurs : alarme, module non consommé, nouvel essai plus tard
        retryAt = GetGameTimer() + Config.Hack.retryDelay * 1000
        TriggerServerEvent('mission:server:hackFailed', plate)
        ReleaseHackLock(plate)
        SetVehicleDoorShut(veh, 4, false)
        TriggerEvent('grandtheftauto:alarme')
        MissionNotify(L('hack_alarm', Config.Hack.retryDelay), 7000)
    else
        ReleaseHackLock(plate)
        SetVehicleDoorShut(veh, 4, false)
        MissionNotify(L('hack_aborted'), 5000)
    end
    busy = false
end

local function StartHackFlow(veh)
    CreateThread(function() HackVehicle(veh) end)
end

-- =========================
-- INVITE « BRANCHER LE MODULE » PRÈS DU CAPOT
-- =========================
CreateThread(function()
    while true do
        local wait = 1000
        if IsCoopActive() and not busy then
            local veh = GetVehicleByPlatePattern(PLATE_PATTERN)
            local shown = false
            if veh then
                local plate = trim(GetVehicleNumberPlateText(veh))
                if not CompletedMissions[plate] then
                    wait = 300
                    local bonnet = BonnetCoords(veh)
                    if #(GetEntityCoords(PlayerPedId()) - bonnet) < PLUG_DISTANCE and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        wait = 0
                        shown = true
                        ShowPrompt("plug_module", bonnet + vector3(0, 0, 0.4), L('prompt_plug'), "fas fa-microchip")
                        if IsControlJustReleased(0, 38) then
                            HidePrompt("plug_module")
                            CheckItem('pcb', function(hasItem)
                                if hasItem then
                                    StartHackFlow(veh)
                                else
                                    MissionNotify(L('need_pcb'), 5000)
                                end
                            end)
                        end
                    end
                end
            end
            if not shown then HidePrompt("plug_module") end
        else
            HidePrompt("plug_module")
        end
        Wait(wait)
    end
end)

-- =========================
-- FIN DE MISSION : remise à zéro
-- =========================
AddEventHandler('mission:local:reset', function()
    if hackResult == nil then SendNUIMessage({ action = 'hack:close' }) end
    hackResult = 'abort'
    busy = false
    retryAt = 0
    deliveryStarted = false
    -- vidées sur place : pcb.lua garde une référence vers ces tables
    for k in pairs(HackedVehicles) do HackedVehicles[k] = nil end
    for k in pairs(CompletedMissions) do CompletedMissions[k] = nil end
    for k in pairs(RemoteHackLockedBy) do RemoteHackLockedBy[k] = nil end
    for k in pairs(PendingHackLocks) do PendingHackLocks[k] = nil end
    HidePrompt("plug_module")
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    HidePrompt("plug_module")
end)

-- Partagé avec pcb.lua (commande, glisser-déposer, livraison coop)
PCB = {
    PATTERN = PLATE_PATTERN,
    Active = {},          -- (ancien placement 3D) : toujours vide, gardé pour pcb.lua
    Hacked = HackedVehicles,
    Completed = CompletedMissions,
    trim = trim,
    FindVehicle = GetVehicleByPlatePattern,
    StartCoop = StartHackFlow,
    IsBusy = function() return busy end,
}
