local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function GetClosestPlayerObj()
    if ESX then
        return ESX.Game.GetClosestPlayer()
    elseif QBCore then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance ~= -1 then
            return player, distance
        end
        return -1, -1
    end
    return -1, -1
end


-- TPE Interaction (use)
RegisterNetEvent('pop_inventory:client:useTPE', function()
    local input = lib.inputDialog('Terminal de Paiement', {
        {type = 'number', label = 'Montant à facturer', description = 'Entrez le montant de la facture ($)', required = true, min = 1}
    })
    
    if not input or not input[1] then return end
    
    local amount = input[1]
    
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        TriggerServerEvent('pop_inventory:server:sendTpeRequest', targetServerId, amount)
        TriggerEvent('notification:client:send', {
            title = 'TPE',
            message = 'Demande de paiement de ' .. amount .. '$ envoyée.',
            type = 'info',
            duration = 5000
        })
    else
        TriggerEvent('notification:client:send', {
            title = 'TPE',
            message = 'Aucun joueur à proximité.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- TPE Interaction (receive)
RegisterNetEvent('pop_inventory:client:receiveTpeRequest', function(requesterId, amount)
    local alert = lib.alertDialog({
        header = 'Demande de paiement',
        content = ('Un terminal de paiement demande %s$. Accepter ?'):format(amount),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('pop_inventory:server:acceptTpeRequest', requesterId, amount)
    else
        TriggerServerEvent('pop_inventory:server:declineTpeRequest', requesterId)
    end
end)

-- Menottes Interaction (utilisation de l'item sur le joueur le plus proche)
RegisterNetEvent('pop_inventory:client:useMenottes', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        -- On menotte/démenotte selon l'état RÉEL de la cible (statebag réseau)
        local alreadyCuffed = Player(targetServerId).state.handcuffed == true
        TriggerServerEvent('pop_inventory:server:menottesPlayer', targetServerId, not alreadyCuffed)
    else
        TriggerEvent('notification:client:send', {
            title = 'Menottes',
            message = 'Aucun joueur à proximité.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- Utilisation du Défibrillateur (AED)
RegisterNetEvent('pop_inventory:client:useAED', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    
    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetPed = GetPlayerPed(nearestPlayer)
        if IsPedDeadOrDying(targetPed, 1) or IsEntityDead(targetPed) then
            local targetServerId = GetPlayerServerId(nearestPlayer)
            
            -- Animation
            TaskStartScenarioInPlace(PlayerPedId(), 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
            Wait(5000)
            ClearPedTasks(PlayerPedId())

            TriggerServerEvent('pop_inventory:server:useAED', targetServerId)
        else
            TriggerEvent('notification:client:send', {
                title = 'AED',
                message = 'Cette personne n\'est pas inconsciente.',
                type = 'error',
                duration = 5000
            })
        end
    else
        TriggerEvent('notification:client:send', {
            title = 'AED',
            message = 'Aucun joueur à proximité.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- Utilisation d'un Kit de Soins
RegisterNetEvent('pop_inventory:client:useKitSoins', function()
    local ped = PlayerPedId()
    
    if GetEntityHealth(ped) >= GetEntityMaxHealth(ped) then
        exports['pop_notify']:ShowNotify({ message = 'Vous êtes déjà en pleine forme.', type = 'error' })
        -- On ne devrait pas consommer l'item si pas utilisé (géré par le retour false dans config si possible, 
        -- mais ici on va juste annuler l'action)
        return
    end

    TaskStartScenarioInPlace(ped, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
    
    local success = lib.progressBar({
        duration = 5000,
        label = 'Utilisation du kit de soins...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true }
    })

    ClearPedTasks(ped)
    
    if success then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        exports['pop_notify']:ShowNotify({ message = 'Vous vous êtes soigné.', type = 'success' })
    else
        -- Le kit est consommé par Config.Items (usable=true + return true), 
        -- pour éviter les exploits de cancel on laisse la consommation.
    end
end)

-- Régénère un peu de santé (items gastronomiques type plateau d'huîtres)
RegisterNetEvent('pop_inventory:client:addHealth', function(amount)
    local ped = PlayerPedId()
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local maxHealth = GetEntityMaxHealth(ped)
    local newHealth = math.min(GetEntityHealth(ped) + amount, maxHealth)
    SetEntityHealth(ped, newHealth)
end)

-- Utilisation d'un Kit de Réparation (via inventaire)
RegisterNetEvent('pop_inventory:client:useRepakit', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        -- Essayer le véhicule le plus proche devant
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if veh ~= 0 then
        -- On déclenche la réparation globale (partagée avec le target)
        TriggerEvent('pop_interacts:client:repairVehicle', veh)
    else
        exports['pop_notify']:ShowNotify({ message = 'Aucun véhicule à proximité.', type = 'error' })
    end
end)

RegisterNetEvent('pop_inventory:client:revivePlayer', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(playerPed)
end)

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
                    ESX.ShowHelpNotification('Appuyez sur ~INPUT_DETONATE~ pour ~r~lâcher~s~ la personne')
                else
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Appuyez sur ~INPUT_DETONATE~ pour ~r~lâcher~s~ la personne')
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

-- Ciseaux Interaction
RegisterNetEvent('pop_inventory:client:useCiseaux', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 2.5 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        local ped = PlayerPedId()
        
        -- Animation
        RequestAnimDict("misshairdresser")
        while not HasAnimDictLoaded("misshairdresser") do Wait(0) end
        
        TaskPlayAnim(ped, "misshairdresser", "keep_hair_cut_player", 8.0, -8.0, -1, 49, 0, false, false, false)
        
        -- Petit son de ciseaux (on utilise un son court existant)
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 2.0, 'scissors', 0.5) 
        -- Fallback si InteractSound non présent : chHyperSound
        TriggerEvent('chHyperSound:play', 'scissors_cut', '1t', false, GetEntityCoords(ped), 5.0)

        local success = lib.progressBar({
            duration = 4000,
            label = 'Coupe des cheveux...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true }
        })
        
        ClearPedTasks(ped)
        
        if success then
            TriggerServerEvent('pop_inventory:server:cutHair', targetServerId)
        end
    else
        TriggerEvent('notification:client:send', {
            title = 'Ciseaux',
            message = 'Aucun joueur à proximité.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- Force Bald (target)
RegisterNetEvent('pop_inventory:client:forceBald', function()
    TriggerEvent('skinchanger:getSkin', function(skin)
        skin['hair_1'] = 0
        skin['hair_2'] = 0
        TriggerEvent('skinchanger:loadSkin', skin)

        -- Enregistrer si permanent
        TriggerEvent('skinchanger:getSkin', function(newSkin)
            TriggerServerEvent('esx_skin:save', newSkin)
        end)
    end)
end)

-- Interaction Clés de voiture
RegisterNetEvent('pop_inventory:client:toggleVehicleLock', function(plate)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = ESX.Game.GetClosestVehicle(coords)
    
    if DoesEntityExist(vehicle) then
        local vehiclePlate = GetVehicleNumberPlateText(vehicle)
        -- Si une plaque est spécifiée sur la clé, on vérifie qu'elle correspond
        if not plate or string.gsub(vehiclePlate, "%s+", "") == string.gsub(plate, "%s+", "") then
            local lockStatus = GetVehicleDoorLockStatus(vehicle)
            
            -- Animation
            RequestAnimDict("anim@mp_player_intmenu@key_fob@")
            while not HasAnimDictLoaded("anim@mp_player_intmenu@key_fob@") do Wait(0) end
            TaskPlayAnim(ped, "anim@mp_player_intmenu@key_fob@", "fob_click", 8.0, 8.0, -1, 48, 1, false, false, false)
            
            if lockStatus == 1 then -- Unlocked
                SetVehicleDoorsLocked(vehicle, 2)
                PlayVehicleDoorCloseSound(vehicle, 1)
                exports['pop_notify']:ShowNotify({ message = 'Véhicule verrouillé ('..vehiclePlate..')', type = 'info' })
            else
                SetVehicleDoorsLocked(vehicle, 1)
                PlayVehicleDoorOpenSound(vehicle, 0)
                exports['pop_notify']:ShowNotify({ message = 'Véhicule déverrouillé ('..vehiclePlate..')', type = 'success' })
            end
            
            -- Clignotants
            SetVehicleLights(vehicle, 2)
            Wait(200)
            SetVehicleLights(vehicle, 0)
            Wait(200)
            SetVehicleLights(vehicle, 2)
            Wait(200)
            SetVehicleLights(vehicle, 0)
        else
            exports['pop_notify']:ShowNotify({ message = 'Ce ne sont pas les bonnes clés.', type = 'error' })
        end
    else
        exports['pop_notify']:ShowNotify({ message = 'Aucun véhicule à proximité.', type = 'error' })
    end
end)

-- =====================================================
-- ROUES (Démontage / Montage avec ls_bolt_minigame)
-- =====================================================
local carryWheelProp = nil
local isCarryingWheel = false
local isMounting = false
local savedBoneCoords = {}

AddStateBagChangeHandler(nil, nil, function(bagName, key, value, _reserved, replicated)
    if not key:find('^wheelOffset_') then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local wheelIndex = tonumber(key:match('_(%d+)$'))
    if wheelIndex and type(value) == 'number' then
        SetVehicleWheelXOffset(entity, wheelIndex, value)
    end
end)

local function removeWheelProp()
    if carryWheelProp and DoesEntityExist(carryWheelProp) then
        DeleteEntity(carryWheelProp)
    end
    carryWheelProp = nil
    if isCarryingWheel then
        ClearPedTasks(PlayerPedId())
        isCarryingWheel = false
    end
end

local function attachWheelProp()
    local ped = PlayerPedId()
    if carryWheelProp and DoesEntityExist(carryWheelProp) then return end
    
    local model = GetHashKey('prop_wheel_tyre')
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end

    local coords = GetEntityCoords(ped)
    carryWheelProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    
    local bone = GetPedBoneIndex(ped, 28422) -- main droite
    RequestAnimDict('anim@heists@box_carry@')
    local t2 = GetGameTimer() + 2000
    while not HasAnimDictLoaded('anim@heists@box_carry@') and GetGameTimer() < t2 do Wait(0) end
    
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
    AttachEntityToEntity(carryWheelProp, ped, bone, 0.0, -0.1, -0.05, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    isCarryingWheel = true
end

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local hasTyre = false
        pcall(function()
            if exports.pop_inventory and exports.pop_inventory.getItemCount then
                hasTyre = exports.pop_inventory:getItemCount('tyre') > 0 or exports.pop_inventory:getItemCount('tyre_burst') > 0
            end
        end)
        
        if hasTyre and not isMounting then
            if not isCarryingWheel then
                attachWheelProp()
            else
                if not IsEntityPlayingAnim(ped, 'anim@heists@box_carry@', 'idle', 3) then
                    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
                end
            end
        else
            if isCarryingWheel then
                removeWheelProp()
            end
        end
    end
end)

RegisterNetEvent('pop_inventory:client:useTyre', function()
    -- Géré automatiquement par la boucle de l'inventaire
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        removeWheelProp()
    end
end)

local function isWheelMounted(vehicle, wheelIndex)
    local state = Entity(vehicle).state['wheelOffset_'..wheelIndex]
    if state and state == 9999.0 then
        return false
    end
    local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
    local boneId = GetEntityBoneIndexByName(vehicle, bones[wheelIndex + 1])
    if boneId == -1 then return false end
    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneId)
    local chassisBone = GetEntityBoneIndexByName(vehicle, 'chassis_dummy')
    local chassisCoords = GetWorldPositionOfEntityBone(vehicle, chassisBone)
    if #(chassisCoords - boneCoords) > 10.0 then
        return false
    end
    return true
end

local function getClosestMissingWheel(vehicle, pCoords)
    local minDistance = 3.0
    local closest = nil
    for i = 0, 3 do
        if not isWheelMounted(vehicle, i) then
            local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
            local boneId = GetEntityBoneIndexByName(vehicle, bones[i + 1])
            if boneId ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneId)
                local dist = #(pCoords - boneCoords)
                if dist < minDistance then
                    minDistance = dist
                    closest = i
                end
            end
        end
    end
    return closest
end

local function getWheelIndexFromBone(entity, bone)
    if type(bone) == 'string' then
        if bone == 'wheel_rf' then return 1
        elseif bone == 'wheel_lr' then return 2
        elseif bone == 'wheel_rr' then return 3
        else return 0 end
    elseif type(bone) == 'number' then
        local bones = {'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr'}
        for i = 0, 3 do
            if GetEntityBoneIndexByName(entity, bones[i + 1]) == bone then
                return i
            end
        end
    end
    -- Fallback si ox_target ne passe pas de bone (on prend la plus proche du joueur)
    local pedCoords = GetEntityCoords(PlayerPedId())
    local minDistance = 3.0
    local closest = nil
    for i = 0, 3 do
        local bones = {'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr'}
        local boneId = GetEntityBoneIndexByName(entity, bones[i + 1])
        if boneId ~= -1 then
            local boneCoords = GetWorldPositionOfEntityBone(entity, boneId)
            local dist = #(pedCoords - boneCoords)
            if dist < minDistance then
                minDistance = dist
                closest = i
            end
        end
    end
    return closest
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'unmount_wheel',
        icon = 'fas fa-wrench',
        label = 'Démonter la roue',
        groups = { 'mechanic', 'bennys' },
        bones = { 'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr' },
        distance = 2.0,
        canInteract = function(entity, distance, coords, name, bone)
            local wheelIndex = getWheelIndexFromBone(entity, bone)
            if not wheelIndex then return false end
            return isWheelMounted(entity, wheelIndex)
        end,
        onSelect = function(data)
            local wheelIndex = getWheelIndexFromBone(data.entity, data.bone)
            if not wheelIndex then return end
            
            local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
            local boneId = GetEntityBoneIndexByName(data.entity, bones[wheelIndex + 1])
            local boneCoords = GetWorldPositionOfEntityBone(data.entity, boneId)
            
            local vehNetId = NetworkGetNetworkIdFromEntity(data.entity)
            if vehNetId ~= 0 then
                savedBoneCoords[vehNetId .. '_' .. wheelIndex] = boneCoords
            end
            
            local success = exports['ls_bolt_minigame']:BoltMinigame(data.entity, wheelIndex, false, true)
            if success then
                local originalOffset = GetVehicleWheelXOffset(data.entity, wheelIndex)
                Entity(data.entity).state:set('wheelOrig_'..wheelIndex, originalOffset, true)
                Entity(data.entity).state:set('wheelCoords_'..wheelIndex, boneCoords, true)
                Entity(data.entity).state:set('wheelOffset_'..wheelIndex, 9999.0, true)
                
                -- Donne TOUJOURS un pneu usé lors du démontage
                TriggerServerEvent('pop_inventory:server:giveWheel', true)
                Wait(500)
                if (exports.pop_inventory:getItemCount('tyre') > 0 or exports.pop_inventory:getItemCount('tyre_burst') > 0) and not isCarryingWheel then
                    attachWheelProp()
                end
            end
        end
    },
    {
        name = 'mount_wheel',
        icon = 'fas fa-wrench',
        label = 'Monter la roue',
        groups = { 'mechanic', 'bennys' },
        bones = { 'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr' },
        canInteract = function(entity, distance, coords, name, bone)
            if exports.pop_inventory:getItemCount('tyre') == 0 then return false end
            local missingIndex = getClosestMissingWheel(entity, coords)
            return missingIndex ~= nil
        end,
        onSelect = function(data)
            local ped = PlayerPedId()
            local missingIndex = getClosestMissingWheel(data.entity, GetEntityCoords(ped))
            if missingIndex then
                local coordsForMinigame = Entity(data.entity).state['wheelCoords_'..missingIndex]
                local vehNetId = NetworkGetNetworkIdFromEntity(data.entity)
                if not coordsForMinigame and vehNetId ~= 0 then
                    coordsForMinigame = savedBoneCoords[vehNetId .. '_' .. missingIndex]
                end
                
                -- Retirer le prop des mains avant de commencer
                if isCarryingWheel then
                    removeWheelProp()
                end
                
                -- Remettre la roue sur la voiture visuellement pour le minijeu
                local origOffset = Entity(data.entity).state['wheelOrig_'..missingIndex]
                if not origOffset then
                    origOffset = (missingIndex % 2 == 0) and -0.8 or 0.8
                end
                Entity(data.entity).state:set('wheelOffset_'..missingIndex, origOffset, true)
                
                -- Lancer le minijeu
                isMounting = true
                local success = exports['ls_bolt_minigame']:BoltMinigame(data.entity, missingIndex, true, true, coordsForMinigame)
                isMounting = false
                
                if success then
                    -- Retirer l'item de l'inventaire
                    TriggerServerEvent('pop_inventory:server:removeWheel')
                    
                    -- Informer la checklist mécano (et réparer la crevaison)
                    TriggerEvent('vg_engine:client:wheelMountedChecklist', data.entity, missingIndex)
                else
                    -- Le joueur a annulé ou échoué, on recache la roue
                    Entity(data.entity).state:set('wheelOffset_'..missingIndex, 9999.0, true)
                    -- On lui remet le prop dans les mains s'il a toujours l'item
                    if exports.pop_inventory:getItemCount('tyre') > 0 then
                        attachWheelProp()
                    end
                end
            end
        end
    }
})

-- =============================================================
-- LOGIQUE DU BRANCARD (EMS STRETCHER)
-- =============================================================
local isPushing = false
local pushedStretcher = nil
local isAttachedToStretcher = false
local stretcherEntity = nil
local wasPlaced = false
local equippedStretcherObj = nil

local function GetClosestAmbulance(coords)
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if GetEntityModel(veh) == GetHashKey("ambulance") then
            local vCoords = GetEntityCoords(veh)
            if #(coords - vCoords) < 5.0 then
                return veh
            end
        end
    end
    return nil
end

local function stopPushingStretcher()
    if not isPushing then return end
    isPushing = false
    if DoesEntityExist(pushedStretcher) then
        local stretcher = pushedStretcher
        DetachEntity(stretcher, true, true)
        CreateThread(function()
            local count = 0
            while DoesEntityExist(stretcher) and count < 10 do
                FreezeEntityPosition(stretcher, false)
                SetEntityCollision(stretcher, true, true)
                PlaceObjectOnGroundProperly(stretcher)
                FreezeEntityPosition(stretcher, true)
                Wait(100)
                count = count + 1
            end
            if DoesEntityExist(stretcher) then
                FreezeEntityPosition(stretcher, true)
                SetEntityCollision(stretcher, true, true)
                SetEntityHasGravity(stretcher, false)
            end
        end)
    end
    pushedStretcher = nil
end

local function pushStretcher(stretcher)
    local ped = PlayerPedId()
    isPushing = true
    pushedStretcher = stretcher
    
    NetworkRequestControlOfEntity(stretcher)
    FreezeEntityPosition(stretcher, false)
    SetEntityCollision(stretcher, true, true)
    AttachEntityToEntity(stretcher, ped, 0, 0.0, 1.3, -1.0, 0.0, 0.0, 90.0, true, true, false, true, 1, true)
    
    CreateThread(function()
        RequestAnimDict("anim@mp_ferris_wheel")
        while not HasAnimDictLoaded("anim@mp_ferris_wheel") do Wait(10) end
        
        while isPushing do
            if not IsEntityPlayingAnim(ped, "anim@mp_ferris_wheel", "idle_a_player_two", 3) then
                TaskPlayAnim(ped, "anim@mp_ferris_wheel", "idle_a_player_two", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(500)
        end
        ClearPedTasks(ped)
    end)
end

-- Spawning stretcher automatically when equipped in inventory
RegisterNetEvent('pop_inventory:client:applyEquipment', function(equipment)
    local hasStretcherEquipped = false
    if equipment and equipment['briefcase'] then
        local item = equipment['briefcase']
        local defId = (type(item) == 'table' and item.defId) or item
        if defId == 'brancard' then
            hasStretcherEquipped = true
        end
    end

    if hasStretcherEquipped then
        if not equippedStretcherObj or not DoesEntityExist(equippedStretcherObj) then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            
            local hash = GetHashKey("strykergurney")
            RequestModel(hash)
            while not HasModelLoaded(hash) do Wait(10) end
            
            equippedStretcherObj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
            SetEntityHeading(equippedStretcherObj, heading)
            
            pushStretcher(equippedStretcherObj)
        end
    else
        if equippedStretcherObj and DoesEntityExist(equippedStretcherObj) then
            stopPushingStretcher()
            DeleteEntity(equippedStretcherObj)
            equippedStretcherObj = nil
            wasPlaced = false
        end
    end
end)

-- Thread to handle keypresses and help UI while pushing to place stretcher
CreateThread(function()
    while true do
        local sleep = 500
        if isPushing and equippedStretcherObj and DoesEntityExist(equippedStretcherObj) then
            sleep = 0
            
            -- Display help text using basic GTA native to ensure it shows regardless of ESX timing
            AddTextEntry('HELP_TXT', "Appuyez sur ~INPUT_DETONATE~ pour poser le brancard")
            BeginTextCommandDisplayHelp('HELP_TXT')
            EndTextCommandDisplayHelp(0, false, true, -1)
            
            if IsControlJustReleased(0, 47) or IsDisabledControlJustReleased(0, 47) then -- 47 is G by default (INPUT_DETONATE)
                wasPlaced = true
                TriggerServerEvent('pop_inventory:server:dropBrancard')
            end
        end
        Wait(sleep)
    end
end)

local function getUpFromStretcher()
    if not isAttachedToStretcher then return end
    isAttachedToStretcher = false
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    ClearPedTasks(ped)
    
    if DoesEntityExist(stretcherEntity) then
        local netId = NetworkGetNetworkIdFromEntity(stretcherEntity)
        TriggerServerEvent('pop_inventory:server:setStretcherPlayer', netId, false)
    end
    stretcherEntity = nil
end

local function layOnStretcher(stretcher)
    local ped = PlayerPedId()
    isAttachedToStretcher = true
    stretcherEntity = stretcher
    
    local netId = NetworkGetNetworkIdFromEntity(stretcher)
    TriggerServerEvent('pop_inventory:server:setStretcherPlayer', netId, true)
    
    AttachEntityToEntity(ped, stretcher, 0, 0.0, 0.0, 1.05, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
    
    RequestAnimDict("anim@gangops@facility@hospital_bed@")
    while not HasAnimDictLoaded("anim@gangops@facility@hospital_bed@") do Wait(10) end
    TaskPlayAnim(ped, "anim@gangops@facility@hospital_bed@", "floor_help_loop_b", 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function GetClosestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestPlayer = -1
    local closestDistance = -1
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped then
            local tCoords = GetEntityCoords(targetPed)
            local dist = #(coords - tCoords)
            if dist < 3.0 and (closestDistance == -1 or dist < closestDistance) then
                closestPlayer = playerId
                closestDistance = dist
            end
        end
    end
    return closestPlayer
end

local function placeWoundedOnStretcher(stretcher)
    local closestPlayer = GetClosestPlayer()
    if closestPlayer ~= -1 then
        local targetServerId = GetPlayerServerId(closestPlayer)
        local netId = NetworkGetNetworkIdFromEntity(stretcher)
        TriggerServerEvent('pop_inventory:server:placePlayerOnStretcher', targetServerId, netId)
    else
        if ESX then
            ESX.ShowNotification("Aucun blessé à proximité.")
        else
            TriggerEvent('notification:client:send', {
                title = 'Brancard',
                message = 'Aucun blessé à proximité.',
                type = 'error',
                duration = 5000
            })
        end
    end
end

local function detachWoundedFromStretcher(stretcher)
    local netId = NetworkGetNetworkIdFromEntity(stretcher)
    TriggerServerEvent('pop_inventory:server:detachPlayerFromStretcher', netId)
end

local function putStretcherInAmbulance(stretcher)
    local coords = GetEntityCoords(stretcher)
    local ambulance = GetClosestAmbulance(coords)
    if ambulance then
        if isPushing and pushedStretcher == stretcher then
            stopPushingStretcher()
            if equippedStretcherObj == stretcher then
                wasPlaced = true
                TriggerServerEvent('pop_inventory:server:removeBrancard')
            end
        end
        NetworkRequestControlOfEntity(stretcher)
        AttachEntityToEntity(stretcher, ambulance, 0, 0.0, -2.1, -0.4, 0.0, 0.0, 0.0, false, false, true, false, 2, true)
    end
end

local function takeStretcherOutAmbulance(stretcher)
    NetworkRequestControlOfEntity(stretcher)
    DetachEntity(stretcher, true, true)
    
    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local pos = GetEntityCoords(ped) + forward * 1.0
    SetEntityCoords(stretcher, pos.x, pos.y, pos.z - 0.5, false, false, false, true)
    
    CreateThread(function()
        local count = 0
        while DoesEntityExist(stretcher) and count < 10 do
            FreezeEntityPosition(stretcher, false)
            SetEntityCollision(stretcher, true, true)
            PlaceObjectOnGroundProperly(stretcher)
            FreezeEntityPosition(stretcher, true)
            Wait(100)
            count = count + 1
        end
        if DoesEntityExist(stretcher) then
            FreezeEntityPosition(stretcher, true)
            SetEntityCollision(stretcher, true, true)
            SetEntityHasGravity(stretcher, false)
        end
    end)
end

local function pickupStretcher(stretcher)
    local coords = GetEntityCoords(stretcher)
    TriggerServerEvent('pop_inventory:server:pickupStretcherProp', coords)
    if DoesEntityExist(stretcher) then
        NetworkRequestControlOfEntity(stretcher)
        DeleteEntity(stretcher)
    end
end

local function startPushingStretcherFromGround(stretcher)
    local coords = GetEntityCoords(stretcher)
    TriggerServerEvent('pop_inventory:server:pushStretcherProp', coords)
    if DoesEntityExist(stretcher) then
        NetworkRequestControlOfEntity(stretcher)
        DeleteEntity(stretcher)
    end
end

-- Item usage event from inventory
RegisterNetEvent('pop_inventory:client:useBrancard', function()
    TriggerServerEvent('pop_inventory:server:useBrancard')
end)

RegisterNetEvent('pop_inventory:client:forcedOnStretcher', function(stretcherNetId)
    local stretcher = NetworkGetEntityFromNetworkId(stretcherNetId)
    if DoesEntityExist(stretcher) then
        layOnStretcher(stretcher)
    end
end)

RegisterNetEvent('pop_inventory:client:forcedOffStretcher', function()
    getUpFromStretcher()
end)

-- ox_target integration
CreateThread(function()
    while not exports or not exports.ox_target do Wait(100) end
    
    local options = {
        {
            name = 'push_stretcher',
            icon = 'fas fa-hand-holding',
            label = 'Pousser le brancard',
            canInteract = function(entity, distance, coords, name, bone)
                return not isPushing and not isAttachedToStretcher and not Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                startPushingStretcherFromGround(data.entity)
            end
        },
        {
            name = 'stop_push_stretcher',
            icon = 'fas fa-hand-holding-slash',
            label = 'Lâcher le brancard',
            canInteract = function(entity, distance, coords, name, bone)
                return isPushing and pushedStretcher == entity
            end,
            onSelect = function(data)
                stopPushingStretcher()
            end
        },
        {
            name = 'lay_on_stretcher',
            icon = 'fas fa-bed',
            label = "S'allonger sur le brancard",
            canInteract = function(entity, distance, coords, name, bone)
                return not isAttachedToStretcher and not Entity(entity).state.hasPlayer and not isPushing and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                layOnStretcher(data.entity)
            end
        },
        {
            name = 'get_up_stretcher',
            icon = 'fas fa-walking',
            label = 'Se relever du brancard',
            canInteract = function(entity, distance, coords, name, bone)
                return isAttachedToStretcher and stretcherEntity == entity
            end,
            onSelect = function(data)
                getUpFromStretcher()
            end
        },
        {
            name = 'place_wounded',
            icon = 'fas fa-user-injured',
            label = 'Placer le blessé sur le brancard',
            canInteract = function(entity, distance, coords, name, bone)
                return not Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                placeWoundedOnStretcher(data.entity)
            end
        },
        {
            name = 'detach_wounded',
            icon = 'fas fa-user-plus',
            label = 'Détacher le blessé',
            canInteract = function(entity, distance, coords, name, bone)
                return Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                detachWoundedFromStretcher(data.entity)
            end
        },
        {
            name = 'put_in_ambulance',
            icon = 'fas fa-ambulance',
            label = "Mettre dans l'ambulance",
            canInteract = function(entity, distance, coords, name, bone)
                local ambulance = GetClosestAmbulance(coords)
                return ambulance ~= nil and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                putStretcherInAmbulance(data.entity)
            end
        },
        {
            name = 'take_out_ambulance',
            icon = 'fas fa-ambulance',
            label = "Sortir de l'ambulance",
            canInteract = function(entity, distance, coords, name, bone)
                return IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                takeStretcherOutAmbulance(data.entity)
            end
        },
        {
            name = 'pickup_stretcher',
            icon = 'fas fa-hands',
            label = 'Ramasser le brancard',
            canInteract = function(entity, distance, coords, name, bone)
                return not Entity(entity).state.hasPlayer and not isPushing and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                pickupStretcher(data.entity)
            end
        }
    }
    exports.ox_target:addModel('strykergurney', options)
end)

-- Safety thread to handle vehicle entries and deaths
CreateThread(function()
    while true do
        local sleep = 500
        if isPushing then
            sleep = 100
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, true) or IsEntityDead(ped) then
                stopPushingStretcher()
            end
        end
        Wait(sleep)
    end
end)

-- Ground drops freezing logic (using utility_lib events)
local groundPropHashes = {}
CreateThread(function()
    while not Config or not Config.GroundProps do Wait(100) end
    for k, modelName in pairs(Config.GroundProps) do
        if k ~= "default" then
            groundPropHashes[GetHashKey(modelName)] = true
        end
    end
    if Config.GroundProps.default then
        groundPropHashes[GetHashKey(Config.GroundProps.default)] = true
    end

    -- Audit : signaler au serveur les modèles que GTA ne connaît pas. Le serveur les
    -- remplace par le `default` (resolveGroundProp) pour ne jamais rendre un item
    -- invisible au sol, et les log pour correction. On dédoublonne par nom de modèle.
    local seen, invalid = {}, {}
    for k, modelName in pairs(Config.GroundProps) do
        if type(modelName) == 'string' and not seen[modelName] then
            seen[modelName] = true
            if not IsModelValid(GetHashKey(modelName)) then
                invalid[#invalid + 1] = modelName
            end
        end
    end
    if #invalid > 0 then
        print(('[pop_inventory] GroundProps invalides détectés (%d) -> fallback default: %s')
            :format(#invalid, table.concat(invalid, ', ')))
        TriggerServerEvent('pop_inventory:server:reportInvalidGroundProps', invalid)
    end
end)

AddEventHandler("Utility:Net:OnRender", function(uNetId, obj, model)
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    if groundPropHashes[modelHash] then
        CreateThread(function()
            -- Sans gravité dès le départ : un prop lourd (coffre-fort) ne doit jamais
            -- être propulsé par le ped pendant la phase de stabilisation au sol.
            SetEntityHasGravity(obj, false)
            local count = 0
            while DoesEntityExist(obj) and count < 10 do
                FreezeEntityPosition(obj, false)
                SetEntityCollision(obj, true, true)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                Wait(100)
                count = count + 1
            end
            if DoesEntityExist(obj) then
                FreezeEntityPosition(obj, true)
                SetEntityCollision(obj, true, true)
                SetEntityHasGravity(obj, false)
            end
        end)
    end
end)


