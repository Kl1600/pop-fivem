-- Menu NUI du crew (/crew), cache d'état et recrutement via ox_target.

local CrewState = { inCrew = false, isOwner = false }
local menuOpen  = false

-- ─────────────────────────────────────────────
-- Récupération de l'état (cache pour ox_target + menu)
-- ─────────────────────────────────────────────

local function refreshState(cb)
    Callback.Trigger('pop_crew:getState', function(state)
        CrewState = state or { inCrew = false, isOwner = false }
        if cb then cb(CrewState) end
    end)
end

-- Push serveur après chaque mutation
RegisterNetEvent('pop_crew:state', function(state)
    CrewState = state or { inCrew = false, isOwner = false }
    if menuOpen then
        SendNUIMessage({ type = 'state', state = CrewState })
    end
end)

-- ─────────────────────────────────────────────
-- Ouverture / fermeture du menu
-- ─────────────────────────────────────────────

local function openMenu()
    if menuOpen then return end
    refreshState(function(state)
        menuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'open', state = state })
    end)
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterCommand(Config.Command, function()
    -- Une ancienne version liait /crew à F7 (touche du noclip admin) et FiveM garde
    -- ce raccourci sur le PC des joueurs : on ignore l'appel s'il vient de F7.
    if IsControlPressed(0, Config.IgnoredControl) or IsDisabledControlPressed(0, Config.IgnoredControl) then return end
    if menuOpen then closeMenu() else openMenu() end
end, false)

-- ─────────────────────────────────────────────
-- Callbacks NUI
-- ─────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({})
end)

RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('pop_crew:create', data.tag, data.label)
    cb({})
end)

RegisterNUICallback('accept', function(_, cb)
    TriggerServerEvent('pop_crew:accept')
    cb({})
end)

RegisterNUICallback('decline', function(_, cb)
    TriggerServerEvent('pop_crew:decline')
    cb({})
end)

RegisterNUICallback('leave', function(_, cb)
    TriggerServerEvent('pop_crew:leave')
    cb({})
end)

RegisterNUICallback('disband', function(_, cb)
    TriggerServerEvent('pop_crew:disband')
    cb({})
end)

RegisterNUICallback('setColor', function(data, cb)
    TriggerServerEvent('pop_crew:setColor', data.color)
    cb({})
end)

-- ─────────────────────────────────────────────
-- Recrutement via ox_target (chef de crew uniquement)
-- ox_target direct : addGlobalPlayer n'existe pas dans le bridge.
-- ─────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= 'ox_target' and resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') ~= 'started' then return end
    -- Retirée avant d'être remise : évite le doublon « Replacing existing target option »
    pcall(function() exports.ox_target:removeGlobalPlayer('pop_crew_recruit') end)
    exports.ox_target:addGlobalPlayer({
        {
            name = 'pop_crew_recruit',
            icon = 'fas fa-user-plus',
            label = L('target_recruit'),
            distance = Config.RecruitTargetDistance,
            canInteract = function(entity)
                return CrewState.inCrew == true and CrewState.isOwner == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                if targetId and targetId > 0 then
                    TriggerServerEvent('pop_crew:invite', targetId)
                else
                    Bridge.Notify({
                        title = L('crew_title'), message = L('player_unknown'), type = 'error', duration = Config.ClientNotifyDuration,
                    })
                end
            end
        }
    })
end)

-- ─────────────────────────────────────────────
-- État initial : tout de suite si le personnage est déjà chargé, puis à chaque chargement
-- ─────────────────────────────────────────────

Bridge.OnPlayerLoaded(function()
    refreshState()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or GetResourceState('ox_target') ~= 'started' then return end
    pcall(function() exports.ox_target:removeGlobalPlayer('pop_crew_recruit') end)
end)
