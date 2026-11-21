local ESX = exports['es_extended']:getSharedObject()

local CrewState = { inCrew = false, isOwner = false }
local menuOpen  = false

-- ─────────────────────────────────────────────
-- Récupération de l'état (cache pour ox_target + menu)
-- ─────────────────────────────────────────────

local function refreshState(cb)
    ESX.TriggerServerCallback('pop_crew:getState', function(state)
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

RegisterCommand('crew', function()
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
-- ─────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= 'ox_target' and resourceName ~= GetCurrentResourceName() then return end
    exports.ox_target:addGlobalPlayer({
        {
            name = 'vg_crew_recruit',
            icon = 'fas fa-user-plus',
            label = 'Recruter dans le crew',
            distance = 2.5,
            canInteract = function(entity)
                return CrewState.inCrew == true and CrewState.isOwner == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                if targetId and targetId > 0 then
                    TriggerServerEvent('pop_crew:invite', targetId)
                else
                    exports['pop_notify']:ShowNotify({
                        title = 'Crew', message = 'Impossible d\'identifier ce joueur.', type = 'error', duration = 4000,
                    })
                end
            end
        }
    })
end)

-- ─────────────────────────────────────────────
-- État initial
-- ─────────────────────────────────────────────

RegisterNetEvent('esx:playerLoaded', function()
    refreshState()
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded or not ESX.IsPlayerLoaded() do Wait(500) end
    refreshState()
end)
