-- pop_ems : soins sur un joueur. Target joueur (en service), menu NUI, enchaînement
-- begin -> progression -> finish (le serveur contrôle la durée et le résultat),
-- réception des soins côté patient (treated / revived) et carte de diagnostic.

local ACTIONS = { diagnose = true, bandage = true, kit = true, revive = true, load = true }
local ORDER = { 'diagnose', 'bandage', 'kit', 'revive', 'load' }

local ANIMS = {
    diagnose = { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_a', flag = 1 },
    bandage  = { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_a', flag = 1 },
    kit      = { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_a', flag = 1 },
    revive   = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
    load     = { dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49 },
}

-- Objet exigé par action (pour le texte missing_item).
local ACTION_ITEM = { bandage = 'bandage', kit = 'kit', revive = 'defib' }

local playerTarget = nil
local menuOpen = false
local current = nil -- { id = serverId, entity = ped }

local function hideMenu()
    if not menuOpen then return end
    menuOpen = false
    SendNUIMessage({ action = 'menu', data = { show = false } })
end

local function runAction(action, targetId, entity)
    if Ems.busy or Bridge.IsBusy() then return Bridge.Notify(L('busy'), 'error') end

    local vehicleNetId = nil
    if action == 'load' then
        local veh = Ems.NearestAmbulance(GetEntityCoords(PlayerPedId()), Config.Distances.vehicle)
        if not veh then return Bridge.Notify(L('no_vehicle'), 'error') end
        vehicleNetId = NetworkGetNetworkIdFromEntity(veh)
    end

    local ok, duration = Ems.Request('pop_ems:begin', targetId, action, vehicleNetId)
    if not ok then
        local item = ACTION_ITEM[action] and Config.Items[ACTION_ITEM[action]]
        return Ems.NotifyError(duration, item)
    end

    if DoesEntityExist(entity) then
        TaskTurnPedToFaceEntity(PlayerPedId(), entity, 500)
        Wait(500)
    end

    if not Bridge.Progress(L('progress_' .. action), duration, { anim = ANIMS[action] }) then return end

    local done, result = Ems.Request('pop_ems:finish', targetId, action)
    if not done then
        local item = ACTION_ITEM[action] and Config.Items[ACTION_ITEM[action]]
        return Ems.NotifyError(result, item)
    end

    if action == 'diagnose' then
        if type(result) == 'table' then SendNUIMessage({ action = 'diagnosis', data = result }) end
        Bridge.Notify(L('done_diagnose'), 'success')
    elseif action == 'load' then
        Bridge.Notify(L('patient_loaded'), 'success')
    else
        Bridge.Notify(L('done_' .. action), 'success')
    end
end

local function openMenu(entity)
    if not Ems.onDuty or not entity or not DoesEntityExist(entity) then return end
    if Ems.busy or Bridge.IsBusy() then return end
    local player = NetworkGetPlayerIndexFromPed(entity)
    if player == -1 then return end
    local targetId = GetPlayerServerId(player)
    if targetId == GetPlayerServerId(PlayerId()) then return Bridge.Notify(L('patient_self'), 'error') end

    -- Affichage seulement : le serveur revérifie tout.
    local unconscious = IsPedDeadOrDying(entity, true)
    local ambulance = unconscious
        and Ems.NearestAmbulance(GetEntityCoords(PlayerPedId()), Config.Distances.vehicle) ~= nil
    local enabled = {
        diagnose = true,
        bandage = true,
        kit = not unconscious,
        revive = unconscious,
        load = unconscious and ambulance,
    }
    local list = {}
    for i, id in ipairs(ORDER) do list[i] = { id = id, enabled = enabled[id] == true } end

    current = { id = targetId, entity = entity }
    menuOpen = true
    SendNUIMessage({ action = 'menu', data = { show = true, actions = list } })
    SetNuiFocus(true, true)
end

RegisterNUICallback('menuAction', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    hideMenu()
    local action = type(data) == 'table' and data.id or nil
    local target = current
    current = nil
    if type(action) ~= 'string' or not ACTIONS[action] or not target then return end
    CreateThread(function() runAction(action, target.id, target.entity) end)
end)

Bridge.OnUiClose(function()
    hideMenu()
    current = nil
end)

------------------------------------------------------------------------
-- Target joueur : seulement en service (hors service, aucun scan)
------------------------------------------------------------------------

Ems.OnDuty(function(state)
    if state then
        if playerTarget then return end
        playerTarget = Bridge.Target.AddModel(Config.PlayerModels, {
            {
                label = L('target_care'), icon = 'fas fa-kit-medical', distance = Config.Distances.interact,
                canInteract = function(e) return e ~= nil and IsPedAPlayer(e) and e ~= PlayerPedId() end,
                onSelect = openMenu,
            },
        })
    else
        if playerTarget then Bridge.Target.Remove(playerTarget) end
        playerTarget = nil
        if menuOpen then SetNuiFocus(false, false) end
        hideMenu()
        current = nil
    end
end)

------------------------------------------------------------------------
-- Côté patient
------------------------------------------------------------------------

RegisterNetEvent('pop_ems:client:treated', function(kind)
    local ped = PlayerPedId()
    if kind == 'bandage' then
        Ems.ClearBleeding()
        if not IsEntityDead(ped) then
            SetEntityHealth(ped, math.min(GetEntityHealth(ped) + Config.BandageHealth, GetEntityMaxHealth(ped)))
        end
        Bridge.Notify(L('treated_bandage_you'), 'success')
    elseif kind == 'kit' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        Ems.ClearInjuries()
        Bridge.Notify(L('treated_kit_you'), 'success')
    end
end)

RegisterNetEvent('pop_ems:client:revived', function(health)
    if Ems.DetachSelf then Ems.DetachSelf(false) end
    local ped = PlayerPedId()
    local coords, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, math.min(tonumber(health) or Config.ReviveHealth, GetEntityMaxHealth(ped)))
    ClearPedBloodDamage(ped)
    Ems.ClearInjuries()
    Bridge.Notify(L('revived_you'), 'success')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
end)
