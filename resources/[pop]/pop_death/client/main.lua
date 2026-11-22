-- pop_death : client. Détecte la mort, affiche l'écran « Inconscient », gère l'appel aux secours
-- et la réapparition à l'hôpital à la fin du délai.

local state = {
    dead = false,
    endTime = 0,        -- GetGameTimer() de la fin du délai
    called = false,
    respawning = false,
    restoreSeconds = nil, -- temps restant donné par le serveur après une reconnexion
}

local function isPedDead(ped)
    return IsEntityDead(ped) or IsPedFatallyInjured(ped)
end

local function texts()
    return {
        title     = L('title'),
        respawnIn = L('respawn_in'),
        callKey   = L('call_key'),
        callSent  = L('call_sent'),
        key       = Config.CallKey,
    }
end

local function hideScreen()
    SendNUIMessage({ action = 'hide' })
end

local function respawnAt(coords, label)
    state.respawning = true
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(50) end

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, true, false)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w)
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    TriggerEvent('esx_status:set', 'hunger', Config.RespawnStatus)
    TriggerEvent('esx_status:set', 'thirst', Config.RespawnStatus)

    state.dead, state.called, state.respawning = false, false, false
    hideScreen()
    Wait(500)
    DoScreenFadeIn(800)
    Bridge.Notify({ title = label, message = L('notify_respawn', label), icon = 'fas fa-hospital', duration = 6000 })
end

local function requestRespawn()
    if state.respawning then return end
    state.respawning = true
    Callback.Trigger('pop_death:respawn', function(coords, label)
        state.respawning = false
        if not state.dead then return end
        if coords then
            respawnAt(coords, label)
        else
            state.endTime = GetGameTimer() + 3000 -- horloge en avance sur le serveur : on réessaie
        end
    end)
end

local function onDeath()
    local seconds = state.restoreSeconds or Config.RespawnTime
    state.restoreSeconds = nil
    state.dead, state.called = true, false
    state.endTime = GetGameTimer() + seconds * 1000
    TriggerServerEvent('pop_death:server:died')
    SendNUIMessage({ action = 'show', texts = texts(), seconds = seconds })

    CreateThread(function()
        while state.dead do
            local left = math.max(0, math.ceil((state.endTime - GetGameTimer()) / 1000))
            SendNUIMessage({ action = 'tick', seconds = left })
            if left <= 0 then requestRespawn() end
            Wait(500)
        end
    end)
end

-- Réanimé sur place (défibrillateur, admin...) avant la fin du délai.
local function onRevived()
    state.dead, state.called = false, false
    hideScreen()
    TriggerServerEvent('pop_death:server:revived')
end

CreateThread(function()
    while true do
        Wait(500)
        local dead = isPedDead(PlayerPedId())
        if dead and not state.dead then
            onDeath()
        elseif not dead and state.dead and not state.respawning then
            onRevived()
        end
    end
end)

-- Appel aux secours (touche réglable par le joueur).
RegisterCommand('pop_death_call', function()
    if not state.dead or state.called then return end
    state.called = true
    TriggerServerEvent('pop_death:server:callEms')
end, false)
RegisterKeyMapping('pop_death_call', L('keymap_call'), 'keyboard', Config.CallKey)

RegisterNetEvent('pop_death:client:callSent', function()
    SendNUIMessage({ action = 'called' })
    Bridge.Notify({ message = L('notify_called'), icon = 'fas fa-truck-medical', duration = 5000 })
    -- Nouvel appel possible après le délai
    SetTimeout(Config.CallCooldown * 1000, function() state.called = false; SendNUIMessage({ action = 'callReady' }) end)
end)

-- Reconnexion pendant le délai : on remet le joueur au sol avec le temps restant.
RegisterNetEvent('pop_death:client:restore', function(seconds)
    if state.dead then return end
    state.restoreSeconds = tonumber(seconds) or Config.RespawnTime
    CreateThread(function()
        Wait(2000) -- laisser le personnage apparaître
        SetEntityHealth(PlayerPedId(), 0)
    end)
end)

exports('isDead', function() return state.dead end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then hideScreen() end
end)
