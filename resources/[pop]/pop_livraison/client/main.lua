-- pop_livraison : client. Dépôt (PNJ), tournée, blips, port du colis, HUD.
-- Le client ne décide de rien : il demande au serveur (start, deliver, finish, cancel).

local TARGET_DISTANCE    = 2.0
local PED_DISTANCE       = 40.0
local DOOR_ZONE_DISTANCE = 60.0
local BOX_PROP           = 'hei_prop_heist_box'
local CARRY_DICT, CARRY_CLIP = 'anim@heists@box_carry@', 'idle'

local RES = GetCurrentResourceName()

local run = nil         -- { destinations, index, total, endsAt, netId, withVehicle }
local pending = false
local carrying = false
local boxProp = nil
local depotBlip, destBlip = nil, nil
local depotPed, depotTarget = nil, nil
local doorTarget, doorIndex = nil, nil
local vanTarget, vanEntity = nil, nil

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash) and hash or nil
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(50) end
    return HasAnimDictLoaded(dict)
end

local function makeBlip(coords, sprite, color, scale, label, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function currentDest()
    return run and run.destinations[run.index] or nil
end

local function distToDest(pos)
    local d = currentDest()
    if not d then return math.huge end
    return #(pos - vector3(d.x, d.y, d.z))
end

local function timeLeft()
    if not run then return 0 end
    return math.max(0, math.floor((run.endsAt - GetGameTimer()) / 1000 + 0.5))
end

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------

local function computeStep(pos)
    if run.index > run.total then return 'return' end
    local near = distToDest(pos) <= DOOR_ZONE_DISTANCE
    if carrying or (not run.withVehicle and near) then return 'deliver' end
    if run.withVehicle and near then return 'take' end
    return 'drive'
end

local function updateHud(pos)
    if not run then
        SendNUIMessage({ action = 'pop_livraison:hud', show = false })
        return
    end
    SendNUIMessage({
        action = 'pop_livraison:hud', show = true,
        index = math.min(run.index, run.total), total = run.total,
        timeLeft = timeLeft(), step = computeStep(pos or GetEntityCoords(PlayerPedId())),
    })
end

------------------------------------------------------------------------
-- Colis porté
------------------------------------------------------------------------

local function dropBox()
    carrying = false
    if boxProp and DoesEntityExist(boxProp) then
        DetachEntity(boxProp, true, true)
        DeleteEntity(boxProp)
    end
    boxProp = nil
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, CARRY_DICT, CARRY_CLIP, 3) then StopAnimTask(ped, CARRY_DICT, CARRY_CLIP, 1.0) end
    RemoveAnimDict(CARRY_DICT)
end

local function playCarry(ped)
    if loadDict(CARRY_DICT) then
        TaskPlayAnim(ped, CARRY_DICT, CARRY_CLIP, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end
end

local function startCarry()
    local ped = PlayerPedId()
    local hash = loadModel(BOX_PROP)
    if not hash then return end
    local pos = GetEntityCoords(ped)
    boxProp = CreateObject(hash, pos.x, pos.y, pos.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(boxProp, false, false)
    AttachEntityToEntity(boxProp, ped, GetPedBoneIndex(ped, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0,
        true, true, false, true, 1, true)
    playCarry(ped)
    carrying = true

    -- Wait(0) seulement pendant le port : sprint, saut, entrer dans un véhicule, tir désactivés.
    CreateThread(function()
        local check = 0
        while carrying do
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            local busy = Bridge.IsBusy()
            if not busy and IsControlJustPressed(0, Config.Keys.Cancel.control) then
                dropBox()
                break
            end
            check = check + 1
            if check >= 30 then -- environ 2 fois par seconde
                check = 0
                local p = PlayerPedId()
                if IsPedDeadOrDying(p, true) or IsPedInAnyVehicle(p, false) then
                    dropBox()
                    break
                end
                if not busy and not IsEntityPlayingAnim(p, CARRY_DICT, CARRY_CLIP, 3) and not IsPedRagdoll(p) then
                    playCarry(p)
                end
            end
            Wait(0)
        end
    end)
end

------------------------------------------------------------------------
-- Cibles de la tournée (porte, camionnette)
------------------------------------------------------------------------

local function removeDoor()
    if doorTarget then Bridge.Target.Remove(doorTarget) end
    doorTarget, doorIndex = nil, nil
end

local function removeVan()
    if vanTarget then Bridge.Target.Remove(vanTarget) end
    vanTarget, vanEntity = nil, nil
end

local function setDestBlip()
    removeBlip(destBlip)
    destBlip = nil
    if not run then return end
    local coords = currentDest()
    if not coords then
        if not run.withVehicle then return end
        coords = Config.Depot.coords -- retour de la camionnette
    end
    destBlip = makeBlip(coords, 478, 5, 0.9, L('blip_destination'), false)
    SetBlipRoute(destBlip, true)
    SetBlipRouteColour(destBlip, 5)
end

local function cleanupRun()
    run = nil
    dropBox()
    removeDoor()
    removeVan()
    removeBlip(destBlip)
    destBlip = nil
    SendNUIMessage({ action = 'pop_livraison:hud', show = false })
end

local deliver -- déclaré plus bas

local function addDoor(index)
    local d = run.destinations[index]
    doorIndex = index
    doorTarget = Bridge.Target.AddBoxZone('pop_livraison_door', vector3(d.x, d.y, d.z), vec3(1.5, 1.5, 2.5), d.w, {
        {
            label = L('target_deliver'),
            icon = 'fa-solid fa-box',
            distance = TARGET_DISTANCE,
            canInteract = function()
                return run ~= nil and run.index == index and (not run.withVehicle or carrying)
            end,
            onSelect = function() deliver() end,
        },
    })
end

local function takeParcel()
    if carrying or not run or Bridge.IsBusy() then return end
    local ok = Bridge.Progress(L('taking'), Config.Durations.take, {
        canCancel = true, disableMovement = true,
        anim = { dict = CARRY_DICT, clip = CARRY_CLIP, flag = 49 },
    })
    if ok and run and not carrying then startCarry() end
end

local function addVan(veh)
    vanEntity = veh
    vanTarget = Bridge.Target.AddLocalEntity(veh, {
        {
            label = L('target_take'),
            icon = 'fa-solid fa-box-open',
            distance = TARGET_DISTANCE,
            canInteract = function(entity)
                if carrying or not run or run.index > run.total then return false end
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then return false end
                local pos = GetEntityCoords(ped)
                if distToDest(pos) > DOOR_ZONE_DISTANCE then return false end
                -- À l'arrière de la camionnette.
                local target = entity or vanEntity
                return target ~= nil and DoesEntityExist(target)
                    and GetOffsetFromEntityGivenWorldCoords(target, pos.x, pos.y, pos.z).y < 0.0
            end,
            onSelect = takeParcel,
        },
    })
end

-- Boucle de tournée : 1000 ms (HUD, zone de porte, cible de la camionnette).
local function runLoop()
    local current = run
    CreateThread(function()
        while run and run == current do
            local pos = GetEntityCoords(PlayerPedId())

            -- Zone de porte : créée à <= 60 m, retirée au-delà ou au changement d'adresse.
            local near = run.index <= run.total and distToDest(pos) <= DOOR_ZONE_DISTANCE
            if doorTarget and (not near or doorIndex ~= run.index) then removeDoor() end
            if near and not doorTarget then addDoor(run.index) end

            -- Cible de la camionnette : le handle local peut changer (sortie / retour dans la zone de streaming).
            if run.netId then
                local veh = NetworkDoesNetworkIdExist(run.netId) and NetToVeh(run.netId) or 0
                if veh == 0 or not DoesEntityExist(veh) then
                    if vanTarget then removeVan() end
                elseif veh ~= vanEntity then
                    removeVan()
                    addVan(veh)
                end
            end

            updateHud(pos)
            Wait(1000)
        end
    end)
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

-- Appelle le serveur ; échec → notification et nettoyage si la tournée n'existe plus.
local function request(name, ...)
    if pending then return end
    pending = true
    local ok, reason, arg, value = Callback.Await(name, ...)
    pending = false
    if not ok then
        Bridge.Notify(L(reason or 'error', arg), 'error')
        if reason == 'no_run' or reason == 'vehicle_missing' or reason == 'run_expired' then cleanupRun() end
        return false
    end
    return true, value
end

local function start(withVehicle)
    if run then return end
    local ok, data = request('pop_livraison:start', withVehicle)
    if not ok or type(data) ~= 'table' then return end

    run = {
        destinations = data.destinations or {},
        index = data.index or 1,
        total = data.total or 0,
        endsAt = GetGameTimer() + (tonumber(data.timeLeft) or 0) * 1000,
        netId = data.netId,
        withVehicle = data.netId ~= nil,
    }
    setDestBlip()
    runLoop()
    updateHud()

    if run.netId then
        local timeout = GetGameTimer() + 5000
        while not NetworkDoesNetworkIdExist(run.netId) and GetGameTimer() < timeout do Wait(50) end
        if not run or not NetworkDoesNetworkIdExist(run.netId) then return end
        local veh = NetToVeh(run.netId)
        if veh ~= 0 then
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            if GetResourceState('qb-vehiclekeys') == 'started' then
                -- NOTE: event historique de qb-vehiclekeys (QBCore).
                TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))
            end
        end
    end
end

deliver = function()
    if not run or Bridge.IsBusy() or pending then return end
    if run.withVehicle and not carrying then return end
    local ok = Bridge.Progress(L('delivering'), Config.Durations.deliver, {
        canCancel = true, disableMovement = true,
        anim = { dict = 'pickup_object', clip = 'putdown_low', flag = 0 },
    })
    if not ok or not run then return end

    local success, index = request('pop_livraison:deliver')
    if not success or not run then return end

    dropBox()
    removeDoor()
    run.index = math.tointeger(index) or (run.index + 1)
    if run.index > run.total and not run.withVehicle then
        cleanupRun() -- mode à pied : tournée terminée côté serveur
        return
    end
    setDestBlip()
    updateHud()
end

local function finish()
    if request('pop_livraison:finish') then cleanupRun() end
end

local function cancel()
    if request('pop_livraison:cancel') then cleanupRun() end
end

------------------------------------------------------------------------
-- Dépôt : blip, PNJ par distance, options
------------------------------------------------------------------------

local function depotOptions()
    local options = {}
    if Config.Vehicle then
        options[#options + 1] = {
            label = L('target_start_vehicle', Config.Vehicle.deposit),
            icon = 'fa-solid fa-truck',
            distance = TARGET_DISTANCE,
            canInteract = function() return run == nil end,
            onSelect = function() start(true) end,
        }
    end
    options[#options + 1] = {
        label = L('target_start_foot'),
        icon = 'fa-solid fa-box',
        distance = TARGET_DISTANCE,
        canInteract = function() return run == nil end,
        onSelect = function() start(false) end,
    }
    options[#options + 1] = {
        label = L('target_finish'),
        icon = 'fa-solid fa-flag-checkered',
        distance = TARGET_DISTANCE,
        canInteract = function() return run ~= nil and run.withVehicle and run.index > run.total end,
        onSelect = finish,
    }
    options[#options + 1] = {
        label = L('target_cancel'),
        icon = 'fa-solid fa-xmark',
        distance = TARGET_DISTANCE,
        canInteract = function() return run ~= nil end,
        onSelect = cancel,
    }
    return options
end

local function deletePed()
    if depotTarget then Bridge.Target.Remove(depotTarget) end
    depotTarget = nil
    if depotPed and DoesEntityExist(depotPed) then DeleteEntity(depotPed) end
    depotPed = nil
end

local function spawnPed()
    local c = Config.Depot.coords
    local hash = loadModel(Config.Depot.ped)
    if not hash then return end
    depotPed = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(depotPed, true)
    FreezeEntityPosition(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    TaskStartScenarioInPlace(depotPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    depotTarget = Bridge.Target.AddLocalEntity(depotPed, depotOptions())
end

local function setupDepot()
    local c = Config.Depot.coords
    if Config.Depot.blip and not depotBlip then
        depotBlip = makeBlip(c, Config.Blip.sprite, Config.Blip.color, Config.Blip.scale, L('blip_name'), true)
    end

    if not Config.Depot.ped then
        depotTarget = Bridge.Target.AddBoxZone('pop_livraison_depot', vector3(c.x, c.y, c.z), vec3(1.5, 1.5, 2.0),
            c.w, depotOptions())
        return
    end

    -- PNJ par distance : 1000 ms près du dépôt, 2500 ms au loin.
    local center = vector3(c.x, c.y, c.z)
    CreateThread(function()
        while true do
            local near = #(GetEntityCoords(PlayerPedId()) - center) <= PED_DISTANCE
            if near and not depotPed then
                spawnPed()
            elseif not near and depotPed then
                deletePed()
            end
            Wait(near and 1000 or 2500)
        end
    end)
end

CreateThread(setupDepot)

------------------------------------------------------------------------
-- Events, exports, arrêt
------------------------------------------------------------------------

-- Le serveur a clos la tournée (temps écoulé, camionnette détruite, changement de personnage).
RegisterNetEvent('pop_livraison:client:runEnded', function(reason)
    cleanupRun()
    if type(reason) == 'string' then Bridge.Notify(L(reason), 'error') end
end)

exports('IsOnRun', function()
    return run ~= nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    cleanupRun()
    deletePed()
    removeBlip(depotBlip)
    depotBlip = nil
end)
