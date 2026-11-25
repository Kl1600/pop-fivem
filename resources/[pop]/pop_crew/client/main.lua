-- Menu NUI du crew (/crew), cache d'état et recrutement via ox_target.

local crewState = { inCrew = false, isOwner = false }
local menuOpen  = false

-- État courant, lu aussi par client/recruit.lua
function CrewState() return crewState end

-- ─────────────────────────────────────────────
-- Récupération de l'état (cache pour ox_target + menu)
-- ─────────────────────────────────────────────

local function refreshState(cb)
    Callback.Trigger('pop_crew:getState', function(state)
        crewState = state or { inCrew = false, isOwner = false }
        if cb then cb(crewState) end
    end)
end

-- Push serveur après chaque mutation
RegisterNetEvent('pop_crew:state', function(state)
    crewState = state or { inCrew = false, isOwner = false }
    if menuOpen then
        SendNUIMessage({ type = 'state', state = crewState })
    end
end)

-- ─────────────────────────────────────────────
-- Ouverture / fermeture du menu
-- ─────────────────────────────────────────────

-- Textes de la NUI (langue de Config.Locale, anglais en secours)
local function sendLocale()
    local data = GetLocaleTable()
    data._lang = Config.Locale
    SendNUIMessage({
        action = 'locale', data = data,
        opts = {
            maxTag = Config.MaxTagLen, maxLabel = Config.MaxLabelLen,
            targetMode = Bridge.TargetSystem, keyLabel = Config.Keys.Interact.label,
        },
    })
end

local function openMenu()
    if menuOpen then return end
    refreshState(function(state)
        menuOpen = true
        SetNuiFocus(true, true)
        sendLocale()
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
-- État initial : tout de suite si le personnage est déjà chargé, puis à chaque chargement
-- ─────────────────────────────────────────────

Bridge.OnPlayerLoaded(function()
    refreshState()
end)
