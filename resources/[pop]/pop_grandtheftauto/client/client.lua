-- client.lua

-- COMMANDES DE TEST / VISIONS (CONSERVÉES)
local isNightVisionOn = false
RegisterCommand('nightv', function()
    isNightVisionOn = not isNightVisionOn
    SetNightvision(isNightVisionOn)
    if not isNightVisionOn then
        TriggerEvent('mission:setupBlips')
    end
end, false)

RegisterKeyMapping('nightv', 'Activer/Désactiver Vision Nocturne', 'keyboard', 'N')

RegisterCommand('offnightv', function()
    isNightVisionOn = false
    SetNightvision(false)
    TriggerEvent('mission:setupBlips')
end, false)

RegisterCommand('jouer', function()
    local success = exports['CircuitBreakerMinigame_lua']:startCircuit(7, 0)
    if success then
        print("Succès ! Accès accordé.")
    else
        print("Échec ! Accès refusé.")
    end
end, true)


RegisterCommand('andale', function()
    TriggerEvent('InteractSound_CL:PlayOnOne', 'demo', 1.0)

end, true)

-- ============================================================
-- SYNCHRO BRAQUAGE (COOP)
-- ============================================================

local function EnsureMissionSync()
    _G.MissionSync = _G.MissionSync or {
        active = false,
        id = nil,
        owner = nil,
        isOwner = false,
        entities = {},
        flags = {}
    }
    return _G.MissionSync
end

local function ShowSubtitleFallback(text, duration)
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(duration or 5000, 1)
end

RegisterNetEvent('mission:client:heistStart')
AddEventHandler('mission:client:heistStart', function(ownerServerId, heistId)
    local MS = EnsureMissionSync()
    MS.active = true
    MS.id = heistId
    MS.owner = ownerServerId
    MS.isOwner = (GetPlayerServerId(PlayerId()) == ownerServerId)
    MS.entities = MS.entities or {}
    MS.flags = MS.flags or {}

    TriggerEvent('startheist', ownerServerId, heistId)
end)

RegisterNetEvent('mission:client:entity')
AddEventHandler('mission:client:entity', function(key, payload, heistId)
    local MS = EnsureMissionSync()
    if MS.active and MS.id and heistId and MS.id ~= heistId then return end

    MS.entities[key] = payload
    TriggerEvent('mission:entity:' .. tostring(key), payload)
end)

RegisterNetEvent('mission:client:relay')
AddEventHandler('mission:client:relay', function(action, data, senderServerId, includeSender, heistId)
    local MS = EnsureMissionSync()
    if MS.active and MS.id and heistId and MS.id ~= heistId then return end

    if includeSender == false and senderServerId and GetPlayerServerId(PlayerId()) == senderServerId then
        return
    end

    -- Gestion des sous-titres
    if action == "subtitle" then
        if type(_G.ShowSubtitle) == "function" then
            _G.ShowSubtitle(data.text or "", data.duration or 5000)
        else
            ShowSubtitleFallback(data.text or "", data.duration or 5000)
        end
        return
    end

    -- AJOUT : Gestion de HyperSound (Pour que les autres joueurs entendent)
    if action == "hypersound" then
        if data.sound then
            if data.netId then
                TriggerEvent('__chHyperSound:playOnEntity', data.netId, nil, data.sound, data.looped or false, data.distance or 15.0)
            elseif data.coords then
                TriggerEvent('__chHyperSound:play', 0, data.sound, data.looped or false, data.coords, data.distance or 15.0)
            elseif data.location then
                 TriggerEvent('__chHyperSound:play', 0, data.sound, data.looped or false, data.location, data.distance or 15.0)
            end
        end
        return
    end

    -- Gestion des sons InteractSound
    if action == "interactsound_one" then
        if data and data.sound then
            TriggerEvent('InteractSound_CL:PlayOnOne', data.sound, data.volume or 0.6)
        end
        return
    end

    -- Gestion des commandes et événements
    if action == "command" then
        -- Seules les commandes de la mission peuvent être relayées entre coéquipiers.
        local allowed = { opencapot = true, removeblip1 = true, open1 = true, blc = true, laseroff = true }
        if data and allowed[data.cmd] then ExecuteCommand(data.cmd) end
        return
    end

    if action == "event" then
        if data and data.name then
            local args = data.args or {}
            TriggerEvent(data.name, table.unpack(args))
        end
        return
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('mission:server:syncMissionToPlayer')
end)

-- ============================================================
-- POLICE TRACKING / BLIPS (SYSTÈME ROBUSTE PAR COORDONNÉES)
-- ============================================================

local policeBlips = {}
local isTrackingActive = false

-- Signal d'arrêt (Serveur -> Client)
RegisterNetEvent('mission:client:stopPoliceTracking')
AddEventHandler('mission:client:stopPoliceTracking', function()
    isTrackingActive = false
    for netId, blip in pairs(policeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    policeBlips = {}
    --ESX.ShowNotification("Le signal GPS ~b~des véhicules volés~w~ a été perdu.")

    ShowNotification("Le signal des sportives volées <br> <span style='color:#E74C3C; font-weight:bold;'>a été perdu.</span>", 7000)
end)

-- Réception des positions (Serveur -> Client)
RegisterNetEvent('mission:client:startPoliceTracking')
AddEventHandler('mission:client:startPoliceTracking', function(trackingData)
    isTrackingActive = true
    
    for _, data in ipairs(trackingData) do
        local netId = data.netId
        local coords = data.coords

        if not policeBlips[netId] then
            -- Création du blip sur les coordonnées (Visible à n'importe quelle distance)
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 523) -- Icône voiture
            SetBlipColour(blip, 1)   -- Rouge
            SetBlipScale(blip, 1.2)
            PulseBlip(blip)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("GPS : Véhicule Volé")
            EndTextCommandSetBlipName(blip)
            policeBlips[netId] = blip
        else
            -- Mise à jour de la position reçue du serveur
            SetBlipCoords(policeBlips[netId], coords.x, coords.y, coords.z)
        end
    end
end)

-- ============================================================
-- ALERTES SHOWROOM
-- ============================================================

local showroomAlertBlip = nil
local showroomAlertRadius = nil

RegisterNetEvent('mission:client:removeShowroomBlip')
AddEventHandler('mission:client:removeShowroomBlip', function()
    if showroomAlertBlip and DoesBlipExist(showroomAlertBlip) then RemoveBlip(showroomAlertBlip) end
    if showroomAlertRadius and DoesBlipExist(showroomAlertRadius) then RemoveBlip(showroomAlertRadius) end
    showroomAlertBlip = nil
    showroomAlertRadius = nil
end)

RegisterNetEvent('mission:client:policeShowroomBlip')
AddEventHandler('mission:client:policeShowroomBlip', function(coords)
    showroomAlertBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(showroomAlertBlip, 161)
    SetBlipScale(showroomAlertBlip, 1.2)
    SetBlipColour(showroomAlertBlip, 1)
    PulseBlip(showroomAlertBlip)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("ALERTE : Braquage Showroom")
    EndTextCommandSetBlipName(showroomAlertBlip)

    showroomAlertRadius = AddBlipForRadius(coords.x, coords.y, coords.z, 50.0)
    SetBlipColour(showroomAlertRadius, 1)
    SetBlipAlpha(showroomAlertRadius, 128)
end)