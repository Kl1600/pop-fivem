-- Interactions importées de tab_interactions (hors menottes/escorte/fouille déjà gérées).

-- TOUS JOUEURS — copie de l'ID serveur via Alt+clic
exports.ox_target:addGlobalPlayer({
    {
        name = 'copy_player_id',
        icon = 'fas fa-id-badge',
        label = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            return L('target_player_id', tostring(targetId))
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            SetClipboard(tostring(targetId))
            Bridge.Notify({ message = L('player_id_copied'), type = 'success' })
        end
    }
})

-- TOUS JOUEURS — copie de l'animation en cours via Alt+clic
exports.ox_target:addGlobalPlayer({
    {
        name = 'copy_player_emote',
        icon = 'fas fa-person-running',
        label = L('target_copy_emote'),
        canInteract = function(entity)
            local s = Entity(entity).state
            return s and s.currentEmote ~= nil and s.currentEmote ~= ''
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            exports['pop_emotes']:CopyEmoteFromPlayer(targetId)
        end
    }
})

-- POLICE (joueur)
exports.ox_target:addGlobalPlayer({
    {
        name = 'police_put_in_veh',
        icon = 'fas fa-car-side',
        label = L('target_put_in_vehicle'),
        groups = 'police',
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            local veh = GetClosestVehicle(GetEntityCoords(data.entity), 5.0, 0, 71)
            if veh ~= 0 then
                TriggerServerEvent('pop_inventory:server:putInVehicle', targetId, NetworkGetNetworkIdFromEntity(veh))
            else
                Bridge.Notify({ message = L('no_vehicle_near_suspect'), type = 'error' })
            end
        end
    },
    {
        name = 'police_out_veh',
        icon = 'fas fa-door-open',
        label = L('target_out_vehicle'),
        groups = 'police',
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TriggerServerEvent('pop_inventory:server:outVehicle', targetId)
        end
    },
    {
        name = 'police_bill',
        icon = 'fas fa-file-invoice-dollar',
        label = L('target_bill_tpe'),
        groups = 'police',
        canInteract = function(entity)
            return exports.pop_inventory:getItemCount('tpe') > 0
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            local input = lib.inputDialog(L('tpe_title'), {
                { type = 'number', label = L('tpe_amount_label'), description = L('tpe_amount_desc_short'), required = true, min = 1 }
            })
            if not input or not input[1] then return end
            TriggerServerEvent('pop_inventory:server:sendTpeRequest', targetId, input[1])
        end
    }
})

-- EMS (joueur)
exports.ox_target:addGlobalPlayer({
    {
        name = 'ems_revive',
        icon = 'fas fa-heart-pulse',
        label = L('target_revive_aed'),
        groups = 'ambulance',
        canInteract = function(entity)
            return exports.pop_inventory:getItemCount('aed') > 0 and (IsPedDeadOrDying(entity, 1) or IsEntityDead(entity))
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TaskStartScenarioInPlace(PlayerPedId(), 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
            if lib.progressBar({ duration = 8000, label = L('progress_reviving'), useWhileDead = false, canCancel = true, disable = { move = true, car = true } }) then
                ClearPedTasks(PlayerPedId())
                TriggerServerEvent('pop_inventory:server:useAED', targetId)
            else
                ClearPedTasks(PlayerPedId())
            end
        end
    },
    {
        name = 'ems_heal',
        icon = 'fas fa-kit-medical',
        label = L('target_heal_kit'),
        groups = 'ambulance',
        canInteract = function(entity)
            return exports.pop_inventory:getItemCount('kitsoins') > 0
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TaskStartScenarioInPlace(PlayerPedId(), 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
            if lib.progressBar({ duration = 5000, label = L('progress_healing'), useWhileDead = false, canCancel = true, disable = { move = true, car = true } }) then
                ClearPedTasks(PlayerPedId())
                TriggerServerEvent('pop_inventory:server:healPlayer', targetId)
            else
                ClearPedTasks(PlayerPedId())
            end
        end
    }
})

-- CHAISES / BANCS (objets)
local chairModels = {
    GetHashKey('prop_chair_01a'), GetHashKey('prop_chair_02'), GetHashKey('prop_chair_03a'), GetHashKey('prop_chair_04a'),
    GetHashKey('prop_chair_05'), GetHashKey('prop_chair_06'), GetHashKey('prop_chair_07'), GetHashKey('prop_chair_07a'),
    GetHashKey('prop_chair_08a'), GetHashKey('prop_chair_09'), GetHashKey('prop_off_chair_01a'), GetHashKey('prop_off_chair_02'),
    GetHashKey('prop_off_chair_03a'), GetHashKey('prop_off_chair_04'), GetHashKey('prop_bar_stool_01'),
    GetHashKey('prop_bench_01a'), GetHashKey('prop_bench_02'), GetHashKey('prop_bench_03'),
    GetHashKey('prop_seat_01'), GetHashKey('prop_seat_gar_01'),
    -99500382,   -- banc arrêt de bus
    1437508529,  -- banc arrêt de bus (panneau)
}

local sittingEntity      = nil
local sittingLockedUntil = 0

local function standUp()
    ClearPedTasks(PlayerPedId())
    sittingEntity = nil
end

local function sitOnChair(entity)
    local ped     = PlayerPedId()
    local coords  = GetEntityCoords(entity)
    local heading = (GetEntityHeading(entity) + 180.0) % 360.0
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    sittingEntity      = entity
    sittingLockedUntil = GetGameTimer() + 1500
    TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_BENCH', coords.x, coords.y, groundZ or coords.z, heading, 0, true, true)
end

CreateThread(function()
    while true do
        if sittingEntity then
            Wait(0)
            if GetGameTimer() < sittingLockedUntil then goto continue end
            if IsControlJustPressed(0, 32) or IsControlJustPressed(0, 33)
            or IsControlJustPressed(0, 34) or IsControlJustPressed(0, 35)
            or IsControlJustPressed(0, 22) then
                standUp()
            end
            ::continue::
        else
            Wait(500)
        end
    end
end)

exports.ox_target:addModel(chairModels, {
    {
        name        = 'sit_chair',
        icon        = 'fas fa-chair',
        label       = L('target_sit'),
        canInteract = function() return sittingEntity == nil end,
        onSelect    = function(data) sitOnChair(data.entity) end,
    },
    {
        name        = 'stand_up_chair',
        icon        = 'fas fa-person-walking',
        label       = L('target_stand_up'),
        canInteract = function() return sittingEntity ~= nil end,
        onSelect    = function() standUp() end,
    },
})

-- BENNYS (véhicule)
exports.ox_target:addGlobalVehicle({
    {
        name = 'bennys_repair',
        icon = 'fas fa-wrench',
        label = L('target_repair_vehicle'),
        groups = 'bennys',
        canInteract = function(entity)
            return exports.pop_inventory:getItemCount('repakit') > 0
        end,
        onSelect = function(data)
            TriggerEvent('pop_inventory:client:repairVehicle', data.entity)
        end
    },
    {
        name = 'bennys_menu',
        icon = 'fas fa-car-rear',
        label = L('target_customize'),
        groups = 'bennys',
        onSelect = function()
            exports.pop_bennys:open()
        end
    }
})

-- MECHANIC (véhicule)
exports.ox_target:addGlobalVehicle({
    {
        name = 'mechanic_analyze',
        icon = 'fas fa-magnifying-glass',
        label = L('target_analyze_damage'),
        groups = 'mechanic',
        canInteract = function(entity)
            -- Pas d'option d'analyse si une checklist est déjà ouverte (sinon re-cliquer
            -- la régénérerait et remettrait à zéro les tâches déjà faites).
            local ok, active = pcall(function() return exports.ox_target:isMechanicChecklistActive() end)
            if ok and active then return false end
            return true
        end,
        onSelect = function(data)
            TriggerEvent('pop_hud:client:showDamageChecklist', true, data.entity)
        end
    }
})


-- Actions client
RegisterNetEvent('pop_inventory:client:repairVehicle', function(veh)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)
    if lib.progressBar({ duration = 10000, label = L('progress_repairing'), useWhileDead = false, canCancel = true, disable = { move = true, car = true } }) then
        ClearPedTasks(ped)
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        TriggerServerEvent('pop_inventory:server:consumeItem', 'repakit')
        Bridge.Notify({ message = L('vehicle_fully_repaired'), type = 'success' })
    else
        ClearPedTasks(ped)
    end
end)

RegisterNetEvent('pop_inventory:client:putInVehicle', function(vehNetId)
    local ped = PlayerPedId()
    local veh = NetToVeh(vehNetId)
    if DoesEntityExist(veh) then
        local maxSeats = GetVehicleMaxNumberOfPassengers(veh)
        for i = maxSeats - 1, 0, -1 do
            if IsVehicleSeatFree(veh, i) then
                TaskWarpPedIntoVehicle(ped, veh, i)
                break
            end
        end
    end
end)

RegisterNetEvent('pop_inventory:client:outVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
end)

RegisterNetEvent('pop_inventory:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    Bridge.Notify({ message = L('wounds_healed'), type = 'success' })
end)

-- MAINS LEVÉES (X) — importé de foltone_core. Statebag 'handsup' (réseau) pour que
-- le ox_target "Fouiller" sache que la cible a les mains levées, depuis n'importe quel client.
local handsupDict = 'missminuteman_1ig_2'
local handsup = false

local function setHandsUp(state)
    local ped = PlayerPedId()
    handsup = state and true or false
    LocalPlayer.state:set('handsup', handsup, true)
    if handsup then
        if not HasAnimDictLoaded(handsupDict) then
            RequestAnimDict(handsupDict)
            local t = GetGameTimer() + 2000
            while not HasAnimDictLoaded(handsupDict) and GetGameTimer() < t do Wait(0) end
        end
        TaskPlayAnim(ped, handsupDict, 'handsup_enter', 8.0, 8.0, -1, 50, 0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end

RegisterCommand('+levermain', function() setHandsUp(not handsup) end, false)
RegisterCommand('-levermain', function() end, false)
RegisterKeyMapping('+levermain', L('key_hands_up'), 'keyboard', 'X')

-- Sécurité : on relâche le statebag si la ressource s'arrête.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and handsup then
        LocalPlayer.state:set('handsup', false, true)
    end
end)
