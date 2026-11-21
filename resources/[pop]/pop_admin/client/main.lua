local ESX = exports['es_extended']:getSharedObject()

-- État partagé entre les fichiers client de la ressource.
Admin = {
    open      = false,
    view      = Config.DefaultView or 'quick',
    minimized = false,
    isAdmin   = false,
    spec      = { active = false, target = nil, spectating = nil },
    noclip    = false,
    godmode   = false,
    invisible = false,
    shownames = false,
}

local function send(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end
AdminSend = send

local cursorThreadRunning = false
local inputFocused = false

-- Bloque uniquement la caméra/tir pour libérer la souris (curseur NUI),
-- tout en laissant les déplacements (WASD, course, saut) actifs.
local DISABLED_WHILE_FOCUSED = {
    1, 2,            -- regard gauche/droite & haut/bas (souris)
    24, 25, 257,     -- attaque / visée / attaque 2
    140, 141, 142, 263, 264, -- mêlée
    106,             -- override souris véhicule
    245,             -- chat (T)
    37,              -- molette d'armes
}

function AdminRefreshFocus()
    local focused = Admin.open and not Admin.minimized and not Admin.spec.active
    SetNuiFocus(focused, focused)
    if focused and inputFocused then
        SetNuiFocusKeepInput(false)
    else
        SetNuiFocusKeepInput(focused)  -- garde les contrôles jeu actifs (déplacement) malgré le curseur
    end
    if focused and not cursorThreadRunning then
        cursorThreadRunning = true
        CreateThread(function()
            while Admin.open and not Admin.minimized and not Admin.spec.active do
                if inputFocused then
                    DisableAllControlActions(0)
                else
                    for i = 1, #DISABLED_WHILE_FOCUSED do
                        DisableControlAction(0, DISABLED_WHILE_FOCUSED[i], true)
                    end
                end
                Wait(0)
            end
            cursorThreadRunning = false
        end)
    end
end

function AdminNotify(msg, kind)
    local payload = { title = 'Admin', message = tostring(msg or ''), duration = 3500 }
    if kind == 'success' then
        payload.icon = 'fas fa-check'; payload.badge = 'OK'; payload.badgeColor = '#4ad07a'
    elseif kind == 'error' then
        payload.icon = 'fas fa-triangle-exclamation'; payload.badge = 'ERREUR'; payload.badgeColor = '#ef5b6a'
    else
        payload.icon = 'fas fa-circle-info'
    end
    if GetResourceState('pop_notify') == 'started' then
        pcall(function() exports['pop_notify']:ShowNotify(payload) end)
    else
        ESX.ShowNotification(tostring(msg or ''))
    end
end

RegisterNetEvent('pop_admin:notify', function(msg, kind)
    AdminNotify(msg, kind)
end)

-- =====================================================================
--  ACCÈS
-- =====================================================================
RegisterNetEvent('pop_admin:setAccess', function(allowed)
    Admin.isAdmin = allowed == true
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    Wait(1500)
    TriggerServerEvent('pop_admin:requestAccess')
    TriggerServerEvent('pop_admin:requestTimeWeather')
end)

-- =====================================================================
--  OUVERTURE / FERMETURE
-- =====================================================================
local function openMenu()
    if not Admin.isAdmin then
        AdminNotify("Accès refusé", 'error')
        return
    end
    Admin.open = true
    Admin.minimized = false
    send('config', {
        keys = { open = Config.OpenKey, reveal = Config.RevealKey, spec = Config.SpecKey },
        weathers = Config.Weathers,
        pedModels = Config.PedModels,
        quickVehicles = Config.QuickVehicles,
    })
    send('open', { view = Admin.view })
    send('selfState', {
        noclip = Admin.noclip, godmode = Admin.godmode,
        invisible = Admin.invisible, spec = Admin.spec.active,
        shownames = Admin.shownames,
    })
    AdminRefreshFocus()
    TriggerServerEvent('pop_admin:requestPlayers')
    TriggerServerEvent('pop_admin:requestJobs')
    TriggerServerEvent('pop_admin:requestTimeWeather')
end

function AdminClose()
    Admin.open = false
    Admin.minimized = false
    inputFocused = false
    send('close')
    AdminRefreshFocus()
end

local function toggleMenu()
    if Admin.spec.active then
        AdminStopSpec()
        return
    end
    if Admin.open and not Admin.minimized then
        AdminClose()
    else
        openMenu()
    end
end

RegisterCommand('tab_admin_open', toggleMenu, false)
RegisterKeyMapping('tab_admin_open', 'Admin : ouvrir / fermer le menu', 'keyboard', Config.OpenKey or 'F6')

RegisterCommand('tab_admin_reveal', function()
    if Admin.open and Admin.minimized then
        Admin.minimized = false
        send('restore')
        AdminRefreshFocus()
    end
end, false)
RegisterKeyMapping('tab_admin_reveal', 'Admin : révéler la fenêtre minimisée', 'keyboard', Config.RevealKey or 'G')

RegisterCommand('tab_admin_noclip', function()
    if not Admin.isAdmin then return end
    AdminToggleNoclip()
    if Admin.open and not Admin.minimized then
        send('selfState', {
            noclip = Admin.noclip, godmode = Admin.godmode,
            invisible = Admin.invisible, spec = Admin.spec.active,
            shownames = Admin.shownames,
        })
    end
end, false)
RegisterKeyMapping('tab_admin_noclip', 'Admin : noclip', 'keyboard', Config.NoclipKey or 'F7')

-- =====================================================================
--  CALLBACKS NUI GÉNÉRAUX
-- =====================================================================
RegisterNUICallback('close', function(_, cb)
    AdminClose(); cb({})
end)

RegisterNUICallback('inputFocus', function(data, cb)
    inputFocused = data.focus == true
    AdminRefreshFocus()
    cb({})
end)

RegisterNUICallback('switchView', function(data, cb)
    Admin.view = data.view or 'quick'
    cb({})
end)

RegisterNUICallback('minimize', function(_, cb)
    Admin.minimized = true
    AdminRefreshFocus()
    cb({})
end)

RegisterNUICallback('requestPlayers', function(_, cb)
    TriggerServerEvent('pop_admin:requestPlayers'); cb({})
end)

RegisterNUICallback('requestVehicles', function(_, cb)
    TriggerServerEvent('pop_admin:requestVehicles'); cb({})
end)

RegisterNUICallback('requestJobs', function(_, cb)
    TriggerServerEvent('pop_admin:requestJobs'); cb({})
end)

-- =====================================================================
--  LOGS DE DÉCONNEXION
-- =====================================================================
RegisterNUICallback('requestLogs', function(_, cb)
    TriggerServerEvent('pop_admin:logs:request'); cb({})
end)

RegisterNUICallback('clearLogs', function(_, cb)
    TriggerServerEvent('pop_admin:logs:clear'); cb({})
end)

RegisterNUICallback('logGoto', function(data, cb)
    if data and data.x then
        SetEntityCoords(PlayerPedId(), data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false, true)
        AdminNotify('Téléporté au point de déconnexion', 'success')
    end
    cb({})
end)

RegisterNetEvent('pop_admin:logs:receive', function(list)
    AdminSend('logs', { list = list or {} })
end)

-- =====================================================================
--  SOINS / RÉANIMATION (déclenchés serveur sur la cible)
-- =====================================================================
RegisterNetEvent('pop_admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('pop_admin:revive', function()
    local ped = PlayerPedId()
    if GetResourceState('esx_ambulancejob') == 'started' then
        TriggerEvent('esx_ambulancejob:revive')
    end
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

-- =====================================================================
--  ACTIONS PERSONNELLES (menu rapide)
-- =====================================================================
RegisterNUICallback('quickAction', function(data, cb)
    local id = data.id
    if id == 'noclip' then
        AdminToggleNoclip()
    elseif id == 'godmode' then
        Admin.godmode = not Admin.godmode
        SetEntityInvincible(PlayerPedId(), Admin.godmode)
        SetPlayerInvincible(PlayerId(), Admin.godmode)
        AdminNotify(Admin.godmode and 'Godmode activé' or 'Godmode désactivé', 'success')
    elseif id == 'invisible' then
        Admin.invisible = not Admin.invisible
        SetEntityVisible(PlayerPedId(), not Admin.invisible, false)
        AdminNotify(Admin.invisible and 'Invisible' or 'Visible', 'success')
    elseif id == 'heal' then
        TriggerEvent('pop_admin:heal')
        AdminNotify('Soigné', 'success')
    elseif id == 'revive' then
        TriggerEvent('pop_admin:revive')
        AdminNotify('Réanimé', 'success')
    elseif id == 'fix' then
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            SetVehicleFixed(veh); SetVehicleDeformationFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0); SetVehiclePetrolTankHealth(veh, 1000.0)
            AdminNotify('Véhicule réparé', 'success')
        else
            AdminNotify('Pas dans un véhicule', 'error')
        end
    elseif id == 'tpm' then
        AdminTeleportToWaypoint()
    elseif id == 'cleararea' then
        local c = GetEntityCoords(PlayerPedId())
        ClearAreaOfVehicles(c.x, c.y, c.z, 50.0, false, false, false, false, false)
        AdminNotify('Zone nettoyée', 'success')
    elseif id == 'copycoords' then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local str = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
        print('[pop_admin] ' .. str)
        send('copyText', { text = str, label = 'Coordonnées copiées' })
    elseif id == 'spec' then
        AdminToggleSpec()
    elseif id == 'shownames' then
        AdminToggleNames()
    elseif id == 'spawnveh' then
        AdminSpawnVehicle(data.model)
    elseif id == 'dv' then
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then DeleteEntity(veh); AdminNotify('Véhicule supprimé', 'success') end
    end
    send('selfState', {
        noclip = Admin.noclip, godmode = Admin.godmode,
        invisible = Admin.invisible, spec = Admin.spec.active,
        shownames = Admin.shownames,
    })
    cb({ noclip = Admin.noclip, godmode = Admin.godmode, invisible = Admin.invisible, shownames = Admin.shownames })
end)

-- =====================================================================
--  TELEPORTS / VEHICULES PERSO
-- =====================================================================
function AdminTeleportToWaypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        AdminNotify('Aucun point GPS', 'error'); return
    end
    local coords = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    local found, z = false, 0.0
    for height = 950, 0, -25 do
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, height + 0.0, false, false, false)
        Wait(60)
        found, z = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, false)
        if found then
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, z + 1.0, false, false, false)
            break
        end
    end
    AdminNotify('Téléporté au point GPS', 'success')
end

function AdminSpawnVehicle(model)
    model = tostring(model or 'adder')
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        AdminNotify('Modèle invalide : ' .. model, 'error'); return
    end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() - t > 5000 then AdminNotify('Chargement échoué', 'error'); return end
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleNumberPlateText(veh, 'ADMIN')
    SetModelAsNoLongerNeeded(hash)
    AdminNotify('Véhicule : ' .. model, 'success')
end

RegisterNUICallback('persona', function(data, cb)
    -- Personnages admin : aller à une position sauvegardée / incarner un modèle.
    if data.do_ == 'save' then
        local c = GetEntityCoords(PlayerPedId())
        cb({ x = c.x, y = c.y, z = c.z, h = GetEntityHeading(PlayerPedId()) })
        return
    elseif data.do_ == 'goto' and data.x then
        SetEntityCoords(PlayerPedId(), data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false, true)
        if data.h then SetEntityHeading(PlayerPedId(), data.h + 0.0) end
        AdminNotify('Téléporté : ' .. tostring(data.label or ''), 'success')
    elseif data.do_ == 'model' and data.model then
        local hash = GetHashKey(data.model)
        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(0) end
        if HasModelLoaded(hash) then
            SetPlayerModel(PlayerId(), hash)
            SetModelAsNoLongerNeeded(hash)
            AdminNotify('Incarné : ' .. tostring(data.label or data.model), 'success')
        else
            AdminNotify('Modèle introuvable', 'error')
        end
    end
    cb({})
end)

-- =====================================================================
--  MAPZONES (réutilise l'éditeur de la ressource MapZones)
-- =====================================================================
RegisterNUICallback('openMapZones', function(_, cb)
    AdminClose()
    if GetResourceState('MapZones') == 'started' then
        ExecuteCommand('mapzones')
    else
        AdminNotify('Ressource MapZones absente', 'error')
    end
    cb({})
end)

-- =====================================================================
--  DOORBUILDER (réutilise l'éditeur de la ressource pop_doorlock)
-- =====================================================================
RegisterNUICallback('openDoorbuilder', function(_, cb)
    AdminClose()
    if GetResourceState('pop_doorlock') == 'started' then
        -- le serveur revérifie les droits admin avant d'ouvrir
        TriggerServerEvent('pop_doorlock:builder:request')
    else
        AdminNotify('Ressource pop_doorlock absente', 'error')
    end
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if Admin.noclip then AdminToggleNoclip() end
    if Admin.spec.spectating then NetworkSetInSpectatorMode(false, PlayerPedId()) end
end)
