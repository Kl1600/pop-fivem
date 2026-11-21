-- pop_vehiclepersistence — client : suivi du véhicule conduit, envoi au serveur, apparition des véhicules.
-- (Config partagé via config.lua : ne pas l'écraser ici.)

local PC = PersistClient
local GetFuel, GetNetId = PC.GetFuel, PC.GetNetId
local GetVehicleProperties, SetVehicleProperties = PC.GetVehicleProperties, PC.SetVehicleProperties

local isAutoSaveEnabled = true
local isInVehicle = false
local hasRequestedVehicles = false
local pendingSpawnPlates = {}  -- plaques en cours de spawn (entre CreateVehicle et SetVehicleProperties)

-- Sauvegarde immédiate du véhicule conduit (non utilisée par le script, gardée pour compatibilité)
function PC.SaveVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if DoesEntityExist(vehicle) then
        local pos = GetEntityCoords(vehicle)
        local heading = GetEntityHeading(vehicle)

        -- Use enhanced property getter
        local vehicleData = GetVehicleProperties(vehicle)

        -- Add persistence specific data
        vehicleData.x = pos.x
        vehicleData.y = pos.y
        vehicleData.z = pos.z
        vehicleData.heading = heading
        vehicleData.fuel = GetFuel(vehicle)
        vehicleData.netId = GetNetId(vehicle)

        -- Save tyre states
        local tyres = {}
        for i = 0, 7 do
            if IsVehicleTyreBurst(vehicle, i, false) then
                tyres[i] = true
            end
        end
        vehicleData.tyres = tyres

        TriggerServerEvent("saveVehicleToDatabase", vehicleData)
    end
end

function updateServer()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if DoesEntityExist(vehicle) then
        local pos = GetEntityCoords(vehicle)
        local heading = GetEntityHeading(vehicle)

        -- Use enhanced property getter
        local vehicleData = GetVehicleProperties(vehicle)

        -- Add persistence specific data
        vehicleData.x = pos.x
        vehicleData.y = pos.y
        vehicleData.z = pos.z
        vehicleData.heading = heading
        vehicleData.fuel = GetFuel(vehicle)
        vehicleData.netId = GetNetId(vehicle)

        -- Save tyre states
        local tyres = {}
        for i = 0, 7 do
            if IsVehicleTyreBurst(vehicle, i, false) then
                tyres[i] = true
            end
        end
        vehicleData.tyres = tyres

        return vehicleData
    else
        return nil
    end
end


-- Notifie le serveur qu'un vrai véhicule vient d'être spawné :
-- le placeholder UtilityNet peut être supprimé (au cas où requestSavedVehicle ne l'aurait pas fait).
local function notifyVehicleSpawned(plate)
    TriggerServerEvent("pop_vehiclepersistence:vehicleSpawned", plate)
end

-- Function to respawn the player in the saved vehicle
function RespawnPlayerInVehicle(vehicleData, shouldWarp)
    if vehicleData then
        -- Check if vehicle already exists to prevent duplicates
        local vehicles = GetGamePool('CVehicle')
        local foundVehicle = nil
        -- Remove ALL whitespace to match server storage format
        local targetPlate = string.upper(string.gsub(vehicleData.plate, "%s+", ""))

        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehPlate = GetVehicleNumberPlateText(veh)
                if vehPlate then
                    -- Remove ALL whitespace for comparison
                    local cleanVehPlate = string.upper(string.gsub(vehPlate, "%s+", ""))
                    if cleanVehPlate == targetPlate then
                        foundVehicle = veh
                        break
                    end
                end
            end
        end

        if foundVehicle then
            -- Déjà présent localement (resend de sécurité du serveur) → rien à faire
            return
        end

        -- Vérifie si un spawn est déjà en cours pour cette plaque (race condition guard)
        if pendingSpawnPlates[targetPlate] then return end
        pendingSpawnPlates[targetPlate] = true

        local vehicleHash = vehicleData.model

        -- Modèle invalide : on abandonne au lieu de boucler indéfiniment.
        if not IsModelInCdimage(vehicleHash) then
            pendingSpawnPlates[targetPlate] = nil
            return
        end
        RequestModel(vehicleHash)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(vehicleHash) do
            if GetGameTimer() > timeout then
                pendingSpawnPlates[targetPlate] = nil
                return
            end
            Wait(100)
        end

        -- Create vehicle and force precise coordinates
        local vehicle = CreateVehicle(vehicleHash, vehicleData.x, vehicleData.y, vehicleData.z, vehicleData.heading, true, false)

        -- Give the game engine a moment to initialize the entity and its components
        Wait(150)

        -- Apply all visual and performance properties
        SetVehicleProperties(vehicle, vehicleData)
        pendingSpawnPlates[targetPlate] = nil

        -- Set coordinates slightly above ground to ensure SetVehicleOnGroundProperly works
        SetEntityCoords(vehicle, vehicleData.x, vehicleData.y, vehicleData.z + 0.05, false, false, false, true)
        SetEntityHeading(vehicle, vehicleData.heading)
        SetVehicleOnGroundProperly(vehicle)

        SetVehicleHandbrake(vehicle, false) -- Enforce release

        -- Unlocked by default so they are openable for the test/user
        SetVehicleDoorsLocked(vehicle, 1)

        -- Restore Body/Health (Properties already does some, but ensuring override)
        if vehicleData.health then SetEntityHealth(vehicle, vehicleData.health) end
        if vehicleData.bodyHealth then SetVehicleBodyHealth(vehicle, vehicleData.bodyHealth + 0.0) end



        -- Restore Tyres
        if vehicleData.tyres then
            for tyreIndex, isBurst in pairs(vehicleData.tyres) do
                if isBurst then
                    -- Change 3rd param to false to avoid "onRim" which makes wheels disappear on many cars
                    SetVehicleTyreBurst(vehicle, tonumber(tyreIndex), false, 1000.0)
                end
            end
        end

        SetModelAsNoLongerNeeded(vehicleHash)
        if vehicleData.fuel then
            DecorSetFloat(vehicle, "fFuel", vehicleData.fuel + 0.0)
            SetVehicleFuelLevel(vehicle, vehicleData.fuel + 0.0)
        end
        notifyVehicleSpawned(vehicleData.plate)

        -- User requested NOT to spawn inside the vehicle.
        -- if shouldWarp then
        --    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        -- end
    end
end

-- Function to display notifications


local function RequestSavedVehicles()
    if not hasRequestedVehicles then
        hasRequestedVehicles = true
        TriggerServerEvent("requestSavedVehicle")
    end
end

-- Référence du dernier véhicule occupé (sert à capturer la position finale à la sortie)
local lastVehicleEntity = nil

-- Construit les données véhicule à partir d'une entité (utilisable même après la sortie)
local function buildVehicleDataFromEntity(veh)
    if not veh or not DoesEntityExist(veh) then return nil end
    local props = GetVehicleProperties(veh)
    if not props or not props.plate then return nil end
    local pos = GetEntityCoords(veh)
    props.x       = pos.x
    props.y       = pos.y
    props.z       = pos.z
    props.heading = GetEntityHeading(veh)
    props.fuel    = GetFuel(veh)
    props.netId   = GetNetId(veh)
    local tyres = {}
    for i = 0, 7 do
        if IsVehicleTyreBurst(veh, i, false) then tyres[i] = true end
    end
    props.tyres = tyres
    return props
end

-- Main loop : detect entry/exit (tracks vehicle entity for accurate exit-time save)
CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(playerPed, false)

        if inVehicle then
            if not isInVehicle then -- Just entered
                isInVehicle = true
                lastVehicleEntity = GetVehiclePedIsIn(playerPed, false)
                local vehicleData = updateServer()
                TriggerServerEvent("CurrentVehicle", vehicleData)
            else
                -- Refresh entity reference (au cas où le joueur change de véhicule sans transition out)
                lastVehicleEntity = GetVehiclePedIsIn(playerPed, false)
            end
        else
            if isInVehicle then -- Just left
                -- Capture la position FINALE depuis le véhicule (parking réel, pas dernière sync)
                local finalData = buildVehicleDataFromEntity(lastVehicleEntity)
                if finalData then
                    TriggerServerEvent("CurrentVehicle", finalData)
                end
                TriggerServerEvent("CurrentVehicle", nil)
                isInVehicle = false
                lastVehicleEntity = nil
            end
        end

        Wait(1000)
    end
end)

-- Adaptive sync loop : 10s en mouvement → 30s → 60s si inactif
CreateThread(function()
    local interval    = 10000
    local lastSentPos = nil
    local idleCount   = 0
    local MOVE_THRESHOLD_SQ = 1.0  -- 1m

    while true do
        Wait(interval)
        if isInVehicle and isAutoSaveEnabled then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            if DoesEntityExist(veh) then
                local pos = GetEntityCoords(veh)
                local moved = true
                if lastSentPos then
                    local dx = pos.x - lastSentPos.x
                    local dy = pos.y - lastSentPos.y
                    local dz = pos.z - lastSentPos.z
                    moved = (dx*dx + dy*dy + dz*dz) > MOVE_THRESHOLD_SQ
                end

                local vehicleData = updateServer()
                if vehicleData then
                    TriggerServerEvent("CurrentVehicle", vehicleData)
                end
                lastSentPos = pos

                if moved then
                    idleCount = 0
                    interval  = 10000
                else
                    idleCount = idleCount + 1
                    if idleCount >= 6 then
                        interval = 60000
                    elseif idleCount >= 3 then
                        interval = 30000
                    end
                end
            end
        else
            lastSentPos = nil
            idleCount   = 0
            interval    = 10000
        end
    end
end)

-- All saving is now automatic based on entering/exiting vehicles with keys.

AddEventHandler("playerSpawned", function()
    Wait(2000)
    RequestSavedVehicles()
end)

-- Also request on resource (re)start if already spawned.
CreateThread(function()
    Wait(1000)
    if NetworkIsPlayerActive(PlayerId()) then
        RequestSavedVehicles()
    end
end)

-- Reset guard when this resource restarts so vehicles are re-requested correctly.
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        hasRequestedVehicles = false
    end
end)

-- Event to respawn the player in the saved vehicle
RegisterNetEvent("respawnPlayerInVehicle")
AddEventHandler("respawnPlayerInVehicle", function(vehicleData, shouldWarp)
    RespawnPlayerInVehicle(vehicleData, shouldWarp)
end)

-- Server tells us a previously-spawned real vehicle should be demoted back to placeholder.
-- We delete the local entity if no one is inside it.
-- Re-envoie CurrentVehicle après qu'une clé vient d'être donnée
RegisterNetEvent("pop_vehiclepersistence:forceResync")
AddEventHandler("pop_vehiclepersistence:forceResync", function()
    if isInVehicle then
        local vehicleData = updateServer()
        if vehicleData then
            TriggerServerEvent("CurrentVehicle", vehicleData)
        end
    end
end)

RegisterNetEvent("pop_vehiclepersistence:despawnVehicle")
AddEventHandler("pop_vehiclepersistence:despawnVehicle", function(plate)
    local cleanPlate = string.upper(string.gsub(plate or '', "%s+", ""))
    local vehicles   = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate and string.upper(string.gsub(vehPlate, "%s+", "")) == cleanPlate then
                local hasOccupant = false
                for seat = -1, 7 do
                    if not IsVehicleSeatFree(veh, seat) then hasOccupant = true; break end
                end
                if not hasOccupant then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                else
                    TriggerServerEvent("pop_vehiclepersistence:despawnFailed", plate)
                end
                return
            end
        end
    end
end)
