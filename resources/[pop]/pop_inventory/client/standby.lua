local display = false
local openedVehicle = nil -- Handle du véhicule dont le coffre/capot est ouvert
local openedHood = false -- true si c'est le capot (moteur) au lieu du coffre arrière
local openedDoor = nil -- porte réellement ouverte (4 = capot avant, 5 = capot/coffre arrière)

local function getSafeItemsConfig()
    if not Config or not Config.Items then return {} end
    local safeItems = {}
    for k, v in pairs(Config.Items) do
        safeItems[k] = {}
        for propKey, propValue in pairs(v) do
            if type(propValue) ~= 'function' then
                safeItems[k][propKey] = propValue
            end
        end
    end
    return safeItems
end

-- Le coffre est desormais une iframe (#standby-frame) dans la NUI de pop_inventory.
-- Les SendNUIMessage du coffre arrivent au top frame (app.js) qui les relaie a
-- l'iframe. On enveloppe donc chaque message du coffre.
local function standbySend(msg)
    SendNUIMessage({ _standby = true, msg = msg })
end

function SetDisplay(bool, containerType, data)
    display = bool
    SetNuiFocus(bool, bool)
    if bool then
        TriggerScreenblurFadeIn(500)
        DisplayHud(false)
        TriggerEvent('hud:toggleui', false)
    else
        TriggerScreenblurFadeOut(500)
        DisplayHud(true)
        TriggerEvent('hud:toggleui', true)
    end
    if GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:setMechanicChecklistHidden(bool) end)
    end
    standbySend({
        action = bool and "open" or "close",
        containerType = containerType,
        data = data
    })
    if bool then
        if Config and Config.Items then
            standbySend({
                action = "config",
                items = getSafeItemsConfig(),
                containerOrder = Config.InventorySettings and Config.InventorySettings.ContainerOrder
            })
        end
        local pCoords = GetEntityCoords(PlayerPedId())

        if containerType == 'vehicle' and data then
            TriggerServerEvent('pop_inventory:server:openVehicle', data.plate, data.class, data.model)
        elseif containerType == 'vehicleEngine' and data then
            TriggerServerEvent('pop_inventory:server:openVehicleEngine', data.plate)
        elseif containerType == 'remoteContainer' and data then
            TriggerServerEvent('pop_inventory:server:openRemoteContainerStandby', data.coords)
        elseif containerType == 'staticChest' and data then
            TriggerServerEvent('pop_inventory:server:openStaticChest', data.id, data.label, data.slots, data.maxWeight)
        elseif containerType == 'myLocker' and data then
            -- Mon casier : ouvre DIRECTEMENT le contenu de mon casier (matricule),
            -- sans liste ni code (le serveur pose standby = sous-conteneur du casier).
            TriggerServerEvent('pop_inventory:server:openMyLocker', data.id)
        elseif containerType == 'lockerRoom' and data then
            -- Parcourir : la grille de tous les casiers (clic droit "Ouvrir" sur le
            -- casier d'un collègue demande le code via pop_management).
            TriggerServerEvent('pop_inventory:server:openLockerRoom', data.id)
        elseif containerType == 'searchPlayer' and data then
            TriggerServerEvent('pop_inventory:server:openSearchStandby', data.targetId)
        else
            TriggerServerEvent('pop_inventory:server:openStandbyContainer', {x=pCoords.x, y=pCoords.y, z=pCoords.z})
        end
    else
        TriggerServerEvent('pop_inventory:server:closeStandbyContainer')
        -- Fermer le coffre/capot physiquement si un véhicule était ouvert
        if openedVehicle and DoesEntityExist(openedVehicle) then
            SetVehicleDoorShut(openedVehicle, openedDoor or (openedHood and 4 or 5), false)
            openedVehicle = nil
            openedHood = false
            openedDoor = nil
        end
        if _G.chestPromptId then
            exports['pop_v3dui']:Remove(_G.chestPromptId)
            _G.chestPromptId = nil
        end
        if _G.lockerMyPromptId then
            exports['pop_v3dui']:Remove(_G.lockerMyPromptId)
            _G.lockerMyPromptId = nil
        end
        if _G.lockerBrowsePromptId then
            exports['pop_v3dui']:Remove(_G.lockerBrowsePromptId)
            _G.lockerBrowsePromptId = nil
        end
    end
end

-- Permet à une autre ressource (ex: pop_bank) d'ouvrir un coffre statique précis sans
-- dupliquer la logique de SetDisplay (focus NUI, blur, panneau coffre via le canal
-- _standby, et le TriggerServerEvent openStaticChest fait par SetDisplay lui-même).
exports('OpenStaticChestUI', function(chestId, label, slots, maxWeight)
    SetDisplay(true, 'staticChest', { id = chestId, label = label, slots = slots, maxWeight = maxWeight })
end)

RegisterNUICallback("standbyClose", function(data, cb)
    SetDisplay(false)
    TriggerServerEvent('pop_inventory:server:stopSearchingPlayer')
    if cb then cb('ok') end
end)

-- Send Config items to NUI once regular loading is done or on first open
Citizen.CreateThread(function()
    while not Config or not Config.Items do
        Citizen.Wait(100)
    end
    -- Send config to NUI
    standbySend({
        action = "config",
        items = getSafeItemsConfig(),
        containerOrder = Config.InventorySettings and Config.InventorySettings.ContainerOrder
    })
end)

-- Request loop for pop_inventory state
Citizen.CreateThread(function()
    while true do
        if display then
            local pCoords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('pop_inventory:server:requestState', {x=pCoords.x, y=pCoords.y, z=pCoords.z})
            Citizen.Wait(1000)
        else
            Citizen.Wait(500)
        end
    end
end)

RegisterNetEvent('pop_inventory:client:state', function(state)
    if display then
        standbySend({
            action = "state",
            state = state
        })
    end
end)

RegisterNUICallback("standbyAction", function(data, cb)
    if data then
        local pCoords = GetEntityCoords(PlayerPedId())
        data.coords = {x=pCoords.x, y=pCoords.y, z=pCoords.z}
        TriggerServerEvent('pop_inventory:server:standbyAction', data)
    end
    if cb then cb('ok') end
end)

RegisterCommand('coffre', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)

    if DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then
            plate = plate:gsub("^%s*(.-)%s*$", "%1") -- trim
            -- Open trunk physically
            SetVehicleDoorOpen(vehicle, 5, false, false)
            openedVehicle = vehicle
            openedHood = false

            local class = GetVehicleClass(vehicle)
            local model = GetEntityModel(vehicle)

            SetDisplay(true, 'vehicle', {
                plate = plate,
                class = class,
                model = model
            })
        end
    else -- luacheck: ignore 542
        -- Optional: Notify no vehicle found
    end
end)

-- Ouverture du CAPOT (moteur) : conteneur distant façon coffre. Ouvre la porte du
-- capot moteur (4 = avant, 5 = arrière pour les moteurs arrière) puis affiche la
-- grille moteur (moteur 3x3 + batterie).
local function openHood(vehicle, plate, door)
    if not DoesEntityExist(vehicle) or not plate then return end
    plate = plate:gsub("^%s*(.-)%s*$", "%1") -- trim
    door = door or 4
    SetVehicleDoorOpen(vehicle, door, false, false)
    openedVehicle = vehicle
    openedHood = true
    openedDoor = door
    SetDisplay(true, 'vehicleEngine', { plate = plate })
end

RegisterCommand('capot', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    if DoesEntityExist(vehicle) then
        openHood(vehicle, GetVehicleNumberPlateText(vehicle))
    end
end)

-- Déclenché par l'option ox_target "Ouvrir le capot" (cf. remote_container.lua).
RegisterNetEvent('pop_inventory:client:openHood', function(vehicle, plate, door)
    openHood(vehicle, plate, door)
end)

RegisterNUICallback("saveState", function(data, cb)
    TriggerServerEvent('pop_inventory:server:saveState', data.state)
    if cb then cb('ok') end
end)

-- Ouverture depuis pop_inventory (ox_target sur un carton)
AddEventHandler('standby_ui:client:openBox', function(coords)
    SetDisplay(true, 'remoteContainer', { coords = coords })
end)

-- Ouverture depuis pop_inventory (ox_target sur un armytanker)
AddEventHandler('standby_ui:client:openArmyTanker', function(chestData)
    SetDisplay(true, 'staticChest', chestData)
end)

-- Ouverture du coffre arrière de l'ambulance (ox_target)
AddEventHandler('pop_inventory:client:openAmbulanceTrunk', function(vehicle, plate)
    if not DoesEntityExist(vehicle) then return end
    openedVehicle = vehicle
    openedHood = false
    local class = GetVehicleClass(vehicle)
    local model = GetEntityModel(vehicle)
    SetDisplay(true, 'vehicle', {
        plate = plate,
        class = class,
        model = model
    })
end)


-- Ouverture de la fouille d'un joueur
RegisterNetEvent('pop_inventory:client:openSearch', function(targetId)
    -- Fouille en mode standby : inventaire de la cible affiché comme conteneur distant
    -- (panneau de gauche), ton inventaire à droite.
    SetDisplay(true, 'searchPlayer', { targetId = targetId })
end)

-- Zones interactives pour les conteneurs configurables (Config.StaticChests)
local function hasJobForChest(chest)
    if not chest.jobs and not chest.job then
        return true
    end

    local allowedJobs = chest.jobs or chest.job
    if type(allowedJobs) == 'string' then
        allowedJobs = { allowedJobs }
    end

    local job = Bridge.GetJob()
    local playerJob = job and job.name

    if playerJob then
        for _, jobName in ipairs(allowedJobs) do
            if playerJob == jobName then
                return true
            end
        end
    end
    return false
end

Citizen.CreateThread(function()
    while not (Config and Config.StaticChests) do
        Citizen.Wait(200)
    end

    while true do
        local interval = 1000
        local playerPed = PlayerPedId()
        local pCoords = GetEntityCoords(playerPed)

        local chestInRange = nil

        for _, chest in ipairs(Config.StaticChests) do
            if hasJobForChest(chest) then
                local cCoords = chest.coords
                local dist = #(pCoords - cCoords)
                local radius = chest.radius or 2.0

                if dist < 30.0 then
                    if interval > 250 then interval = 250 end

                    local notifType = (Config.UI and Config.UI.HelpNotificationType) or 'pop_inventory'
                    -- Marqueur 3D (Seulement si le type n'est pas pop_v3dui)
                    local m = chest.marker
                    if m and m.enabled and notifType ~= 'pop_v3dui' then
                        interval = 0
                        local col = m.color or { r = 50, g = 200, b = 255, a = 180 }
                        DrawMarker(
                            m.type or 1,
                            cCoords.x, cCoords.y, cCoords.z - 1.0,
                            0, 0, 0,
                            0, 0, 0,
                            0.5, 0.5, 0.5,
                            col.r, col.g, col.b, col.a,
                            false, true, 2, false, nil, nil, false
                        )
                    end

                    if dist < radius then
                        chestInRange = chest
                        interval = 0
                    end
                end
            end
        end

        if chestInRange then
            local notifType = (Config.UI and Config.UI.HelpNotificationType) or 'pop_inventory'
            local msg = L('chest_help', chestInRange.label or L('chest_default'))

            if notifType == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
                if not _G.chestPromptId then
                    _G.chestPromptId = exports['pop_v3dui']:Create({
                        coords = chestInRange.coords,
                        type = "prompt",
                        content = {
                            label = L('prompt_open', chestInRange.label or L('chest_default')),
                            icon = "fas fa-box-open",
                            key = "E"
                        },
                    })
                end
                if IsControlJustReleased(0, 38) then -- Touche E
                    SetDisplay(true, 'staticChest', chestInRange)
                end
            elseif notifType == 'esx' and ESX and ESX.ShowHelpNotification then
                ESX.ShowHelpNotification(msg) -- ESX direct
                if IsControlJustReleased(0, 38) then -- Touche E
                    SetDisplay(true, 'staticChest', chestInRange)
                end
            else
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentString(msg)
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then -- Touche E
                    SetDisplay(true, 'staticChest', chestInRange)
                end
            end
        else
            if _G.chestPromptId then
                exports['pop_v3dui']:Remove(_G.chestPromptId)
                _G.chestPromptId = nil
            end
        end

        Citizen.Wait(interval)
    end
end)

-- Salles de casiers (Config.LockerRooms) : points FIXES, donc prompt v3DUI + touche
-- (pas d'ox_target). Deux actions sur le même point :
--   [E] Mon casier      -> ouvre directement le contenu de mon casier (matricule),
--                          sans liste ni code (sous-conteneur ouvert d'office).
--   [G] Parcourir       -> la grille de tous les casiers ; ouvrir celui d'un collègue
--                          demande le code (géré dans sv_actions.lua via pop_management).
Citizen.CreateThread(function()
    while not (Config and Config.LockerRooms) do
        Citizen.Wait(200)
    end

    while true do
        local interval = 1000
        local pCoords = GetEntityCoords(PlayerPedId())
        local lockerInRange = nil

        if not display then
            for _, lockerRoom in ipairs(Config.LockerRooms) do
                if hasJobForChest(lockerRoom) then
                    local dist = #(pCoords - lockerRoom.coords)
                    if dist < 30.0 then
                        if interval > 250 then interval = 250 end
                        if dist < (lockerRoom.radius or 1.5) then
                            lockerInRange = lockerRoom
                            interval = 0
                        end
                    end
                end
            end
        end

        if lockerInRange then
            local notifType = (Config.UI and Config.UI.HelpNotificationType) or 'pop_inventory'

            if notifType == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
                if not _G.lockerMyPromptId then
                    _G.lockerMyPromptId = exports['pop_v3dui']:Create({
                        coords = lockerInRange.coords,
                        type = "prompt",
                        content = { label = L('locker_mine'), icon = "fas fa-lock", key = "E" },
                    })
                end
                if not _G.lockerBrowsePromptId then
                    _G.lockerBrowsePromptId = exports['pop_v3dui']:Create({
                        coords = lockerInRange.coords,
                        offset = vector3(0.0, 0.0, -0.25),
                        type = "prompt",
                        content = { label = L('locker_browse'), icon = "fas fa-boxes-stacked", key = "G" },
                    })
                end
            else
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentString(L('locker_help'))
                EndTextCommandDisplayHelp(0, false, true, -1)
            end

            if IsControlJustReleased(0, 38) then -- E : mon casier (direct)
                SetDisplay(true, 'myLocker', lockerInRange)
            elseif IsControlJustReleased(0, 47) then -- G : parcourir
                SetDisplay(true, 'lockerRoom', lockerInRange)
            end
        else
            if _G.lockerMyPromptId then
                exports['pop_v3dui']:Remove(_G.lockerMyPromptId)
                _G.lockerMyPromptId = nil
            end
            if _G.lockerBrowsePromptId then
                exports['pop_v3dui']:Remove(_G.lockerBrowsePromptId)
                _G.lockerBrowsePromptId = nil
            end
        end

        Citizen.Wait(interval)
    end
end)

-- Masquer HUD, radar et désactiver les contrôles de caméra/combat quand l'UI est ouverte
Citizen.CreateThread(function()
    while true do
        if display then
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            HideHudAndRadarThisFrame()
            DisplayRadar(false)
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
