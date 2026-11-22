-- Menottes (anim, prop, statebag) et escorte.

-- =====================================================
-- MENOTTES (anim + prop collé aux poignets + statebag)
-- =====================================================
local isHandcuffed = false
local isEscorted = false -- forward decl. (utilisé par le watchdog menottes pour ne pas écraser l'anim d'escorte)
local cuffProp = nil
local cuffDict = 'mp_arresting'
local cuffAnim = 'idle'
local cuffPropName = 'p_cs_cuffs_02_s' -- prop streamé par SmartCuffs (British Speedcuffs)

local function loadCuffDict()
    if HasAnimDictLoaded(cuffDict) then return true end
    RequestAnimDict(cuffDict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(cuffDict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(cuffDict)
end

local function playCuffAnim(ped)
    if loadCuffDict() then
        TaskPlayAnim(ped, cuffDict, cuffAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end

local function removeCuffProp()
    if cuffProp and DoesEntityExist(cuffProp) then
        DeleteEntity(cuffProp)
    end
    cuffProp = nil
end

-- Offsets exacts repris de SmartCuffs (src/Main.cs ProcessModel). Bone 60309.
local CUFF_OFFSETS = {
    rear  = { ox = -0.055, oy = 0.06,  oz = 0.04, rx = 265.0, ry = 155.0, rz = 80.0  },
    front = { ox = -0.058, oy = 0.005, oz = 0.090, rx = 290.0, ry = 95.0,  rz = 120.0 },
}
local currentCuffMode = 'rear'

local function attachCuffProp(ped, mode)
    mode = mode or currentCuffMode or 'rear'
    currentCuffMode = mode
    removeCuffProp()
    local model = GetHashKey(cuffPropName)
    RequestModel(model)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(model) then return end

    local coords = GetEntityCoords(ped)
    cuffProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    -- Setup réseau (visibilité sur tous les clients). ObjToNet warne si l'entité
    -- n'a pas encore d'objet réseau : on attend l'enregistrement avant d'y toucher.
    local netTimeout = GetGameTimer() + 500
    while not NetworkGetEntityIsNetworked(cuffProp) and GetGameTimer() < netTimeout do
        Wait(0)
    end
    if NetworkGetEntityIsNetworked(cuffProp) then
        local netId = ObjToNet(cuffProp)
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, false)
        NetworkSetNetworkIdDynamic(netId, true)
    end
    local o = CUFF_OFFSETS[mode] or CUFF_OFFSETS.rear
    local bone = GetPedBoneIndex(ped, 60309)
    AttachEntityToEntity(
        cuffProp, ped, bone,
        o.ox, o.oy, o.oz,
        o.rx, o.ry, o.rz,
        true, false, false, false, 0, true
    )
    SetModelAsNoLongerNeeded(model)
end

-- Pose un état EXPLICITE (true = menotté / false = libre), idempotent.
local function setHandcuffed(state)
    local ped = PlayerPedId()
    local newState = state and true or false
    local wasHandcuffed = isHandcuffed
    isHandcuffed = newState

    if newState then
        playCuffAnim(ped)
        SetEnableHandcuffs(ped, true)
        SetPedCanPlayGestureAnims(ped, false)
        attachCuffProp(ped)
        -- Son cliquet de menottes (natif GTA, pas de dépendance externe).
        PlaySoundFromEntity(-1, 'Cuffs_On', ped, 'POLICE_HANDCUFFS_SOUNDSET', false, 0)

        -- Un seul thread à la fois (uniquement sur la transition libre -> menotté)
        if not wasHandcuffed then
            CreateThread(function()
                while isHandcuffed do
                    Wait(0)
                    if not isHandcuffed then break end
                    local p = PlayerPedId()
                    -- Déplacement : complètement bloqué (le menotté ne bouge plus).
                    DisableControlAction(0, 30, true)  -- Move LR
                    DisableControlAction(0, 31, true)  -- Move UD
                    DisableControlAction(0, 32, true)  -- Avancer (W)
                    DisableControlAction(0, 33, true)  -- Reculer (S)
                    DisableControlAction(0, 34, true)  -- Gauche (A)
                    DisableControlAction(0, 35, true)  -- Droite (D)
                    DisableControlAction(0, 21, true)  -- Sprint
                    DisableControlAction(0, 36, true)  -- Accroupi
                    DisableControlAction(0, 24, true)  -- Attaque
                    DisableControlAction(0, 257, true) -- Attaque 2
                    DisableControlAction(0, 25, true)  -- Viser
                    DisableControlAction(0, 263, true) -- Melee 1
                    DisableControlAction(0, 264, true) -- Melee 2
                    DisableControlAction(0, 45, true)  -- Recharger
                    DisableControlAction(0, 22, true)  -- Saut
                    DisableControlAction(0, 44, true)  -- Couverture
                    DisableControlAction(0, 37, true)  -- Roue des armes
                    DisableControlAction(0, 23, true)  -- Entrer dans un véhicule
                    DisableControlAction(0, 288, true) -- F1
                    DisableControlAction(0, 289, true) -- F2 (inventaire)
                    DisableControlAction(0, 170, true) -- F3 (anims)
                    DisableControlAction(0, 167, true) -- F6 (job)
                    DisableControlAction(0, 47, true)  -- Detonateur
                    DisableControlAction(0, 140, true) -- Coup leger
                    DisableControlAction(0, 141, true)
                    DisableControlAction(0, 142, true)

                    if not isEscorted and not IsEntityPlayingAnim(p, cuffDict, cuffAnim, 3) then
                        playCuffAnim(p)
                    end
                    if not (cuffProp and DoesEntityExist(cuffProp)) then
                        attachCuffProp(p)
                    end
                end
            end)
        end
    else
        ClearPedSecondaryTask(ped)
        StopAnimTask(ped, cuffDict, cuffAnim, 1.0)
        ClearPedTasks(ped)
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
        removeCuffProp()
    end
end

-- Event recommandé : état explicite envoyé par le serveur
RegisterNetEvent('pop_inventory:client:setHandcuffed', function(state)
    setHandcuffed(state)
end)

-- Compatibilité : ancien event de bascule
RegisterNetEvent('pop_inventory:client:toggleHandcuffs', function()
    setHandcuffed(not isHandcuffed)
end)

-- =====================================================
-- ESCORTE (inspirée de corry-escort)
-- =====================================================
-- isEscorted déclaré en haut du fichier (forward decl.)
local isEscorting = false
local escortedDict = 'anim@move_m@prisoner_cuffed' -- côté escorté
local escortedWalk = 'walk'
local escorterDict = 'amb@world_human_drinking@coffee@female@base' -- côté escorteur
local escorterAnim = 'base'

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

-- ─── Côté ESCORTÉ : on est attaché et on suit l'escorteur ──────────────────
local function detachFromEscort()
    if not isEscorted then return end
    isEscorted = false
    local ped = PlayerPedId()
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
    end
    StopAnimTask(ped, escortedDict, escortedWalk, -4.0)
    -- Si toujours menotté : repasse en mode rearcuff (prop + anim mp_arresting).
    if isHandcuffed then
        attachCuffProp(ped, 'rear')
        playCuffAnim(ped)
    else
        ClearPedTasks(ped)
    end
end

local function attachToEscort(escorterServerId)
    local escorterPlyId = GetPlayerFromServerId(escorterServerId)
    if escorterPlyId == -1 then return end
    local escorterPed = GetPlayerPed(escorterPlyId)
    if not DoesEntityExist(escorterPed) then return end

    local ped = PlayerPedId()
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
    end
    -- Offsets repris de corry-escort : bone 11816, (0.38, 0.4, 0.0).
    AttachEntityToEntity(
        ped, escorterPed, 11816,
        0.38, 0.4, 0.0,
        0.0, 0.0, 0.0,
        false, false, false, true, 2, true
    )
    isEscorted = true
    -- Frontcuff pendant l'escorte (mains devant).
    attachCuffProp(ped, 'front')

    -- Boucle : joue 'walk' QUAND l'escorteur marche, sinon stop -> idle visuel propre.
    CreateThread(function()
        while isEscorted do
            local escorterId = GetPlayerFromServerId(escorterServerId)
            local ePed = escorterId > 0 and GetPlayerPed(escorterId) or 0
            if not ePed or ePed == 0 or not DoesEntityExist(ePed) then break end
            local p = PlayerPedId()
            if IsPedWalking(ePed) then
                if not IsEntityPlayingAnim(p, escortedDict, escortedWalk, 3) then
                    if loadDict(escortedDict) then
                        TaskPlayAnim(p, escortedDict, escortedWalk, 8.0, 8.0, -1, 1, 0, false, false, false)
                    end
                end
            else
                if IsEntityPlayingAnim(p, escortedDict, escortedWalk, 3) then
                    StopAnimTask(p, escortedDict, escortedWalk, -4.0)
                end
            end
            Wait(0)
        end
    end)
end

AddStateBagChangeHandler('escortedBy', nil, function(bagName, _, value)
    local plyId = GetPlayerFromStateBagName(bagName)
    if plyId == 0 then return end
    if plyId ~= PlayerId() then return end

    if value then
        attachToEscort(tonumber(value))
    else
        detachFromEscort()
    end
end)

-- ─── Côté ESCORTEUR : on tient la cible, anim café + watchdog prevent ──────
local function stopEscorting()
    if not isEscorting then return end
    isEscorting = false
    local ped = PlayerPedId()
    StopAnimTask(ped, escorterDict, escorterAnim, -4.0)
    TriggerServerEvent('pop_inventory:server:stopEscort')
end

AddStateBagChangeHandler('escorting', nil, function(bagName, _, value)
    local plyId = GetPlayerFromStateBagName(bagName)
    if plyId == 0 then return end
    if plyId ~= PlayerId() then return end

    if value then
        isEscorting = true
        local ped = PlayerPedId()
        if loadDict(escorterDict) then
            TaskPlayAnim(ped, escorterDict, escorterAnim, 8.0, 8.0, -1, 50, 0, false, false, false)
        end
        CreateThread(function()
            while isEscorting do
                Wait(0)
                local p = PlayerPedId()
                if not IsEntityPlayingAnim(p, escorterDict, escorterAnim, 3) then
                    if loadDict(escorterDict) then
                        TaskPlayAnim(p, escorterDict, escorterAnim, 8.0, 8.0, -1, 50, 0, false, false, false)
                    end
                end
                -- Prompt de relâche (G = control 47). Ne retire PAS les menottes.
                if ESX and ESX.ShowHelpNotification then
                    ESX.ShowHelpNotification(L('escort_release_help'))
                else
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(L('escort_release_help'))
                    EndTextCommandDisplayHelp(0, false, true, -1)
                end
                if IsControlJustReleased(0, 47) then
                    stopEscorting()
                    break
                end
                -- Conditions d'arrêt (corry-escort : ragdoll/sprint/véhicule).
                if IsPedRagdoll(p) or IsPedSprinting(p) or IsPedInAnyVehicle(p, false) then
                    stopEscorting()
                    break
                end
            end
        end)
    else
        isEscorting = false
        local ped = PlayerPedId()
        StopAnimTask(ped, escorterDict, escorterAnim, -4.0)
    end
end)

-- Sécurité : on retire le prop si la ressource s'arrête
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        removeCuffProp()
        detachFromEscort()
    end
end)
