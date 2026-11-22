-- client.lua

-- (Anciennes commandes de test retirées : /nightv et la touche N sautaient l'étape
--  Thornton et gênaient le push-to-talk ; /jouer et /andale étaient des tests.)

-- ============================================================
-- SYNCHRO BRAQUAGE (COOP)
-- ============================================================


local function ShowSubtitleFallback(text, duration)
    BeginTextCommandPrint("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(duration or 5000, 1)
end

-- Étape 1 : Svetlana a donné la mission -> direction le showroom
local pendingId = nil
RegisterNetEvent('mission:client:pending')
AddEventHandler('mission:client:pending', function(heistId, isOwner)
    if pendingId == heistId then return end
    pendingId = heistId

    SetNewWaypoint(Config.ShowroomPos.x, Config.ShowroomPos.y)
    MissionNotify(L('go_showroom'), 8000)

    if not isOwner then return end
    CreateThread(function()
        while pendingId == heistId and not EnsureMissionSync().active do
            if #(GetEntityCoords(PlayerPedId()) - Config.ShowroomPos) <= 100.0 then
                TriggerServerEvent('mission:server:startHeist')
                return
            end
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('mission:client:heistStart')
AddEventHandler('mission:client:heistStart', function(ownerServerId, heistId)
    local MS = EnsureMissionSync()
    if MS.active and MS.id == heistId then return end
    MS.active = true
    MS.id = heistId
    MS.owner = ownerServerId
    MS.isOwner = (GetPlayerServerId(PlayerId()) == ownerServerId)
    MS.entities = {}
    MS.flags = {}

    TriggerEvent('startheist', ownerServerId, heistId)
end)

-- Fin de mission (serveur) : chaque fichier remet son état à zéro sur 'mission:local:reset'
RegisterNetEvent('mission:client:reset')
AddEventHandler('mission:client:reset', function(reason)
    local MS = EnsureMissionSync()
    MS.active = false
    MS.id = nil
    MS.owner = nil
    MS.isOwner = false
    MS.entities = {}
    MS.flags = {}
    pendingId = nil

    TriggerEvent('mission:local:reset', reason)

    if reason == 'done' then
        MissionNotify(L('heist_done'), 8000)
    elseif reason == 'timeout' then
        MissionNotify(L('heist_timeout'), 8000)
    elseif reason == 'owner_left' then
        MissionNotify(L('heist_owner_left'), 8000)
    end
end)

RegisterNetEvent('mission:client:entity')
AddEventHandler('mission:client:entity', function(key, payload, heistId)
    local MS = EnsureMissionSync()
    if MS.active and MS.id and heistId and MS.id ~= heistId then return end

    MS.entities[key] = payload
    -- L'entité peut ne pas encore exister chez nous : on attend qu'elle arrive (15 s max)
    local netId = type(payload) == 'table' and payload.netId or payload
    CreateThread(function()
        local limit = GetGameTimer() + 15000
        while type(netId) == 'number' and not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < limit do Wait(250) end
        if MS.entities[key] == payload then
            TriggerEvent('mission:entity:' .. tostring(key), payload)
        end
    end)
end)

-- Commandes relayées -> évènements locaux (plus de commandes tapables par tout le monde)
local RelayCommandEvents = {
    opencapot   = { 'mission:local:opencapot' },
    removeblip1 = { 'mission:local:removeblip1' },
    open1       = { 'mission:client:openShowroomDoors' },
    blc         = { 'mission:local:blackout', true },
    laseroff    = { 'mission:local:lasers', false },
}

local RelayEvents = {
    ['mission:forceThorntonExit'] = true,
    ['mission:keysBlipOn'] = true,
    ['mission:setKeysTaken'] = true,
    ['mission:setDoorOpened'] = true,
    ['mission:client:lockShowroomDoors'] = true,
    ['mission:client:openShowroomDoors'] = true,
    ['mission:setupBlips'] = true,
    ['StartMissionTimer'] = true,
    ['mission:client:syncTruckDoor'] = true,
}

RegisterNetEvent('mission:client:relay')
AddEventHandler('mission:client:relay', function(action, data, senderServerId, includeSender, heistId)
    local MS = EnsureMissionSync()
    if not MS.active then return end
    if MS.id and heistId and MS.id ~= heistId then return end
    if type(data) ~= 'table' then return end

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

    -- HyperSound (pour que les autres joueurs entendent)
    if action == "hypersound" then
        if data.sound then
            if data.netId then
                TriggerEvent('__chHyperSound:playOnEntity', data.netId, nil, data.sound, false, data.distance or 15.0)
            elseif data.coords then
                TriggerEvent('__chHyperSound:play', 0, data.sound, false, data.coords, data.distance or 15.0)
            end
        end
        return
    end

    -- Sons InteractSound
    if action == "interactsound_one" then
        if data.sound then
            TriggerEvent('InteractSound_CL:PlayOnOne', data.sound, data.volume or 0.6)
        end
        return
    end

    if action == "command" then
        local ev = RelayCommandEvents[data.cmd]
        if ev then TriggerEvent(ev[1], ev[2]) end
        return
    end

    if action == "event" then
        if data.name and RelayEvents[data.name] then
            TriggerEvent(data.name, table.unpack(data.args or {}))
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

-- Signal d'arrêt (Serveur -> Client)
RegisterNetEvent('mission:client:stopPoliceTracking')
AddEventHandler('mission:client:stopPoliceTracking', function()
    local hadBlips = next(policeBlips) ~= nil
    for _, blip in pairs(policeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    policeBlips = {}

    if hadBlips then
        MissionNotify(L('signal_lost'), 7000)
    end
end)

-- Réception des positions (Serveur -> Client)
RegisterNetEvent('mission:client:startPoliceTracking')
AddEventHandler('mission:client:startPoliceTracking', function(trackingData)

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
            AddTextComponentString(L('blip_gps'))
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
    TriggerEvent('mission:client:removeShowroomBlip')
    showroomAlertBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(showroomAlertBlip, 161)
    SetBlipScale(showroomAlertBlip, 1.2)
    SetBlipColour(showroomAlertBlip, 1)
    PulseBlip(showroomAlertBlip)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L('blip_alert'))
    EndTextCommandSetBlipName(showroomAlertBlip)

    showroomAlertRadius = AddBlipForRadius(coords.x, coords.y, coords.z, 50.0)
    SetBlipColour(showroomAlertRadius, 1)
    SetBlipAlpha(showroomAlertRadius, 128)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in pairs(policeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    TriggerEvent('mission:client:removeShowroomBlip')
end)
