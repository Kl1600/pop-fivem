-- pop_territories : état local, détection de zone, HUD, /territory, alertes rivales.
-- Lecture seule : toute l'influence est calculée par le serveur.

local RES = GetCurrentResourceName()
local DETECT_INTERVAL = 1000

local state = nil        -- format SPEC §4
local currentZone = nil  -- zone normalisée (Zones) où se trouve le joueur
local hudVisible = false
local hudToken = 0
local detecting = false

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------

local function hideHud()
    hudToken = hudToken + 1
    if not hudVisible then return end
    hudVisible = false
    SendNUIMessage({ action = 'territory:hud', show = false })
end

local function showHud(zone)
    if not zone then return end
    local info = state and state.zones and state.zones[zone.id] or nil
    local owner = info and type(info.owner) == 'table' and info.owner or nil
    local crew = state and type(state.crew) == 'table' and state.crew or nil
    local capture = math.floor(tonumber(state and state.capture) or Config.Influence.Capture)

    -- Champs absents (nil) = null pour le JS (owner, color, influence).
    local data = {
        action = 'territory:hud',
        show = true,
        zone = L(zone.label),
        mine = owner ~= nil and crew ~= nil and owner.key == crew.key,
        capture = capture,
    }

    if owner then
        data.owner = tostring(owner.label)
        if type(owner.color) == 'string' then data.color = owner.color end
    end

    if state and state.enabled and crew then
        -- Arrondi inférieur : le HUD n'affiche jamais 60 % tant que le seuil n'est pas réellement atteint.
        local value = math.floor(tonumber(info and info.influence) or 0)
        data.influence = math.max(0, math.min(100, value))
    end

    SendNUIMessage(data)
    hudVisible = true

    hudToken = hudToken + 1
    local duration = tonumber(Config.HudDuration) or 0
    if duration > 0 then
        local token = hudToken
        SetTimeout(math.floor(duration * 1000), function()
            if token == hudToken then hideHud() end
        end)
    end
end

-- Réaffiche le HUD si le joueur est dans la zone concernée (nil = n'importe quelle zone).
local function refreshHud(zoneId)
    if currentZone and (zoneId == nil or currentZone.id == zoneId) then showHud(currentZone) end
end

------------------------------------------------------------------------
-- Détection de zone (un seul thread, 1000 ms)
------------------------------------------------------------------------

local function startDetection()
    if detecting then return end
    detecting = true
    CreateThread(function()
        while detecting do
            local ped = PlayerPedId()
            local zone = Zones.At(GetEntityCoords(ped))
            if zone ~= currentZone then
                currentZone = zone
                if zone then showHud(zone) else hideHud() end
            end
            Wait(DETECT_INTERVAL)
        end
    end)
end

------------------------------------------------------------------------
-- État
------------------------------------------------------------------------

local function zoneEntry(zoneId)
    if not state then return nil end
    if type(state.zones) ~= 'table' then state.zones = {} end
    local entry = state.zones[zoneId]
    if not entry then
        entry = { influence = 0 }
        state.zones[zoneId] = entry
    end
    return entry
end

Bridge.OnPlayerLoaded(function()
    local s = Callback.Await('pop_territories:getState')
    if type(s) ~= 'table' then
        Wait(5000)
        s = Callback.Await('pop_territories:getState')
    end
    if type(s) == 'table' then state = s end
    Blips.Refresh(state)
    startDetection()
    refreshHud()
end)

RegisterNetEvent('pop_territories:client:state', function(s)
    if type(s) ~= 'table' then return end
    state = s
    Blips.Refresh(state)
    refreshHud()
end)

RegisterNetEvent('pop_territories:client:owner', function(zoneId, owner)
    if not Zones.Get(zoneId) then return end
    if type(owner) ~= 'table' then owner = nil end
    local entry = zoneEntry(zoneId)
    if entry then entry.owner = owner end
    Blips.SetOwner(zoneId, owner)
    refreshHud(zoneId)
end)

RegisterNetEvent('pop_territories:client:influence', function(zoneId, value)
    if not Zones.Get(zoneId) then return end
    value = tonumber(value)
    if not value then return end
    local entry = zoneEntry(zoneId)
    if not entry then return end
    local old = tonumber(entry.influence) or 0
    entry.influence = value
    if not currentZone or currentZone.id ~= zoneId then return end
    -- Pas de réapparition à chaque point gagné : seulement si le HUD est déjà visible
    -- ou si le seuil de prise est franchi (dans un sens ou dans l'autre).
    local capture = tonumber(state and state.capture) or Config.Influence.Capture
    if hudVisible or ((old >= capture) ~= (value >= capture)) then showHud(currentZone) end
end)

RegisterNetEvent('pop_territories:client:alert', function(zoneId, coords)
    local zone = Zones.Get(zoneId)
    if not zone then return end
    Bridge.Notify(L('notify_rival', L(zone.label)), 'warning')
    if coords and tonumber(coords.x) and tonumber(coords.y) then Blips.Alert(coords) end
end)

------------------------------------------------------------------------
-- Commande, export
------------------------------------------------------------------------

RegisterCommand(Config.Commands.Info, function()
    local zone = Zones.At(GetEntityCoords(PlayerPedId()))
    currentZone = zone
    if zone then
        showHud(zone)
    else
        hideHud()
        Bridge.Notify(L('notify_no_zone'), 'info')
    end
end, false)

if GetResourceState('chat') == 'started' then
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Info, L('cmd_territory'))
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Admin, L('cmd_admin'))
end

exports('GetCurrentZone', function()
    return currentZone and currentZone.id or nil
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    detecting = false
    hudToken = hudToken + 1
    SendNUIMessage({ action = 'territory:hud', show = false })
    if GetResourceState('chat') == 'started' then
        TriggerEvent('chat:removeSuggestion', '/' .. Config.Commands.Info)
        TriggerEvent('chat:removeSuggestion', '/' .. Config.Commands.Admin)
    end
end)
