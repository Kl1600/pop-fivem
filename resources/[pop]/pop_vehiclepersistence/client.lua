-- client.lua
-- (Config partagé via config.lua : ne pas l'écraser ici.)

local hasVehicleSaved = false
local isAutoSaveEnabled = true
local isInVehicle = false
local hasRequestedVehicles = false
local pendingSpawnPlates = {}  -- plaques en cours de spawn (entre CreateVehicle et SetVehicleProperties)

-- Custom GetVehicleProperties to ensure all mods are saved
local function GetVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then
        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
        local extras = {}


        for extraId=0, 20 do
            if DoesExtraExist(vehicle, extraId) then
                local state = IsVehicleExtraTurnedOn(vehicle, extraId) == 1
                extras[tostring(extraId)] = state
            end
        end
        
        local modLivery = GetVehicleMod(vehicle, 48)
        local livery = GetVehicleLivery(vehicle)

        -- Damage state : portières cassées / vitres brisées (on ne stocke que les éléments endommagés)
        local doorsBroken = {}
        for doorIdx = 0, 5 do
            if IsVehicleDoorDamaged(vehicle, doorIdx) then
                doorsBroken[tostring(doorIdx)] = true
            end
        end

        local windowsBroken = {}
        for winIdx = 0, 7 do
            if not IsVehicleWindowIntact(vehicle, winIdx) then
                windowsBroken[tostring(winIdx)] = true
            end
        end

        return {
            model             = GetEntityModel(vehicle),
            plate             = GetVehicleNumberPlateText(vehicle),
            plateIndex        = GetVehicleNumberPlateTextIndex(vehicle),

            bodyHealth        = GetVehicleBodyHealth(vehicle),
            engineHealth      = GetVehicleEngineHealth(vehicle),
            tankHealth        = GetVehiclePetrolTankHealth(vehicle),

            fuelLevel         = GetVehicleFuelLevel(vehicle),
            dirtLevel         = GetVehicleDirtLevel(vehicle),
            color1            = colorPrimary,
            color2            = colorSecondary,

            pearlescentColor  = pearlescentColor,
            wheelColor        = wheelColor,

            wheels            = GetVehicleWheelType(vehicle),
            windowTint        = GetVehicleWindowTint(vehicle),
            xenonColor        = GetVehicleXenonLightsColor(vehicle),

            neonEnabled       = {
                IsVehicleNeonLightEnabled(vehicle, 0),
                IsVehicleNeonLightEnabled(vehicle, 1),
                IsVehicleNeonLightEnabled(vehicle, 2),
                IsVehicleNeonLightEnabled(vehicle, 3)
            },

            neonColor         = table.pack(GetVehicleNeonLightsColour(vehicle)),
            extras            = extras,
            tyreSmokeColor    = table.pack(GetVehicleTyreSmokeColor(vehicle)),

            modSpoilers       = GetVehicleMod(vehicle, 0),
            modFrontBumper    = GetVehicleMod(vehicle, 1),
            modRearBumper     = GetVehicleMod(vehicle, 2),
            modSideSkirt      = GetVehicleMod(vehicle, 3),
            modExhaust        = GetVehicleMod(vehicle, 4),
            modFrame          = GetVehicleMod(vehicle, 5),
            modGrille         = GetVehicleMod(vehicle, 6),
            modHood           = GetVehicleMod(vehicle, 7),
            modFender         = GetVehicleMod(vehicle, 8),
            modRightFender    = GetVehicleMod(vehicle, 9),
            modRoof           = GetVehicleMod(vehicle, 10),

            modEngine         = GetVehicleMod(vehicle, 11),
            modBrakes         = GetVehicleMod(vehicle, 12),
            modTransmission   = GetVehicleMod(vehicle, 13),
            modHorns          = GetVehicleMod(vehicle, 14),
            modSuspension     = GetVehicleMod(vehicle, 15),
            modArmor          = GetVehicleMod(vehicle, 16),

            modTurbo          = IsToggleModOn(vehicle, 18),
            modSmokeEnabled   = IsToggleModOn(vehicle, 20),
            modXenon          = IsToggleModOn(vehicle, 22),

            modFrontWheels    = GetVehicleMod(vehicle, 23),
            modCustomFrontWheels = GetVehicleModVariation(vehicle, 23),
            modBackWheels     = GetVehicleMod(vehicle, 24),
            modCustomBackWheels = GetVehicleModVariation(vehicle, 24),

            modPlateHolder    = GetVehicleMod(vehicle, 25),
            modVanityPlate    = GetVehicleMod(vehicle, 26),
            modTrimA          = GetVehicleMod(vehicle, 27),
            modOrnaments      = GetVehicleMod(vehicle, 28),
            modDashboard      = GetVehicleMod(vehicle, 29),
            modDial           = GetVehicleMod(vehicle, 30),
            modDoorSpeaker    = GetVehicleMod(vehicle, 31),
            modSeats          = GetVehicleMod(vehicle, 32),
            modSteeringWheel  = GetVehicleMod(vehicle, 33),
            modShifterLeavers = GetVehicleMod(vehicle, 34),
            modAPlate         = GetVehicleMod(vehicle, 35),
            modSpeakers       = GetVehicleMod(vehicle, 36),
            modTrunk          = GetVehicleMod(vehicle, 37),
            modHydrolic       = GetVehicleMod(vehicle, 38),
            modEngineBlock    = GetVehicleMod(vehicle, 39),
            modAirFilter      = GetVehicleMod(vehicle, 40),
            modStruts         = GetVehicleMod(vehicle, 41),
            modArchCover      = GetVehicleMod(vehicle, 42),
            modAerials        = GetVehicleMod(vehicle, 43),
            modTrimB          = GetVehicleMod(vehicle, 44),
            modTank           = GetVehicleMod(vehicle, 45),
            modWindows        = GetVehicleMod(vehicle, 46),
            modLivery         = modLivery,
            livery            = livery,
            doorsBroken       = doorsBroken,
            windowsBroken     = windowsBroken,
        }
    else
        return nil
    end
end

-- Custom SetVehicleProperties to ensure all mods are applied
local function SetVehicleProperties(vehicle, props)
    if DoesEntityExist(vehicle) then
        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

        SetVehicleModKit(vehicle, 0)

        if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
        if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
        if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
        if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
        if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
        if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
        if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
        if props.color1 then SetVehicleColours(vehicle, props.color1, colorSecondary) end
        if props.color2 then SetVehicleColours(vehicle, props.color1 or colorPrimary, props.color2) end
        if props.pearlescentColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, wheelColor) end
        if props.wheelColor then SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor) end
        if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
        if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

        if props.neonEnabled then
            SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
            SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
            SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
            SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
        end

        if props.extras then
            for extraId,enabled in pairs(props.extras) do
                if enabled then
                    SetVehicleExtra(vehicle, tonumber(extraId), 0)
                else
                    SetVehicleExtra(vehicle, tonumber(extraId), 1)
                end
            end
        end

        if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
        if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end
        if props.modSmokeEnabled then ToggleVehicleMod(vehicle, 20, true) end
        if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end
        if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
        if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
        if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
        if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
        if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
        if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
        if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
        if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
        if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
        if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
        if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
        if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
        if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
        if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
        if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
        if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
        if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
        if props.modTurbo then ToggleVehicleMod(vehicle, 18, props.modTurbo) end
        if props.modXenon then ToggleVehicleMod(vehicle, 22, props.modXenon) end
        if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomFrontWheels or false) end
        if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomBackWheels or false) end
        if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
        if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
        if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
        if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
        if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
        if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
        if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
        if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
        if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
        if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end
        if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
        if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
        if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
        if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
        if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
        if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
        if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
        if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
        if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
        if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
        if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
        if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end

        if props.modLivery and props.modLivery ~= -1 then
            SetVehicleMod(vehicle, 48, props.modLivery, false)
        end

        if props.livery then
            SetVehicleLivery(vehicle, props.livery)
        end

        -- Restauration des dégâts : portières cassées / vitres brisées
        if props.doorsBroken then
            for doorIdx, broken in pairs(props.doorsBroken) do
                if broken then
                    -- 2e arg true = détacher la porte (chute au sol) au lieu de juste l'endommager
                    SetVehicleDoorBroken(vehicle, tonumber(doorIdx), true)
                end
            end
        end

        if props.windowsBroken then
            for winIdx, broken in pairs(props.windowsBroken) do
                if broken then
                    SmashVehicleWindow(vehicle, tonumber(winIdx))
                end
            end
        end
    end
end

-- Function to save the vehicle
-- Function to save the vehicle
function SaveVehicle()
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
        -- Prefer Decor fuel if available as it is often used for persistence
        vehicleData.fuel = DecorGetFloat(vehicle, "fFuel")
        
        -- Save tyre states
        local tyres = {}
        for i = 0, 7 do
            if IsVehicleTyreBurst(vehicle, i, false) then
                tyres[i] = true
            end
        end
        vehicleData.tyres = tyres

        TriggerServerEvent("saveVehicleToDatabase", vehicleData)
    else
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
        vehicleData.fuel = DecorGetFloat(vehicle, "fFuel")
        
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
        if vehicleData.fuel then DecorSetFloat(vehicle, "fFuel", vehicleData.fuel + 0.0) end
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
    props.fuel    = DecorGetFloat(veh, "fFuel")
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

-- ─── /showvehicles : markers 3D + HUD natif temps réel ──────────────────────

local showAllVehiclesActive = false
local allVehiclesCache      = {}

-- Stats reçues du serveur (rafraîchies toutes les 2s tant que le HUD est actif)
local liveStats = {
    total         = 0,
    driven        = 0,
    spawnedServer = 0,
    placeholders  = 0,
    owned         = 0,
    onlinePlayers = 0,
    cullRadius    = 250.0,
    promoteRadius = 30.0,
    autoSave      = 1,
    maxPersistenceDays = 0,
}

-- Stats locales calculées chaque frame
local localStats = { inCull = 0, near50 = 0, renderedReal = 0, lastCompute = 0, renderedPlates = {} }

local function DrawHudText(text, x, y, scale, r, g, b, a, align)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    if align == 'right' then
        SetTextJustification(2)
        SetTextWrap(0.0, x)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(0.0, y)
    else
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

RegisterNetEvent("pop_vehiclepersistence:receiveAllVehicles")
AddEventHandler("pop_vehiclepersistence:receiveAllVehicles", function(list)
    allVehiclesCache = list or {}
end)

RegisterNetEvent("pop_vehiclepersistence:receiveStats")
AddEventHandler("pop_vehiclepersistence:receiveStats", function(stats)
    if not stats then return end
    for k, v in pairs(stats) do liveStats[k] = v end
end)

RegisterCommand("showvehicles", function()
    showAllVehiclesActive = not showAllVehiclesActive
    if showAllVehiclesActive then
        TriggerServerEvent("pop_vehiclepersistence:requestAllVehicles")
        TriggerServerEvent("pop_vehiclepersistence:requestStats")
        print(("[Persistence] HUD ON (%d véhicules)"):format(#allVehiclesCache))
    else
        allVehiclesCache = {}
        print("[Persistence] HUD OFF")
    end
end, false)

-- Refresh périodique (un seul thread) : stats toutes les 2 s, liste toutes les 5 s, tant que l'affichage est actif
CreateThread(function()
    local lastList = 0
    while true do
        Wait(2000)
        if showAllVehiclesActive then
            TriggerServerEvent("pop_vehiclepersistence:requestStats")
            local now = GetGameTimer()
            if now - lastList >= 5000 then
                lastList = now
                TriggerServerEvent("pop_vehiclepersistence:requestAllVehicles")
            end
        end
    end
end)

-- Calcule les stats locales (compte des véhicules réels rendus côté client)
local function ComputeLocalStats()
    local pCoords = GetEntityCoords(PlayerPedId())
    local cullSq  = (liveStats.cullRadius or 250.0) * (liveStats.cullRadius or 250.0)
    local inCull, near50 = 0, 0
    local plateSet = {}

    for _, v in ipairs(allVehiclesCache) do
        local dx, dy, dz = v.x - pCoords.x, v.y - pCoords.y, v.z - pCoords.z
        local d = dx*dx + dy*dy + dz*dz
        if d < cullSq then inCull = inCull + 1 end
        if d < 2500.0 then near50 = near50 + 1 end
        plateSet[string.upper(string.gsub(v.plate or '', '%s+', ''))] = true
    end

    local rendered = 0
    local renderedPlates = {}
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local vp = GetVehicleNumberPlateText(veh)
            local clean = vp and string.upper(string.gsub(vp, '%s+', ''))
            if clean and plateSet[clean] then
                rendered = rendered + 1
                renderedPlates[clean] = true
            end
        end
    end

    localStats.inCull         = inCull
    localStats.near50         = near50
    localStats.renderedReal   = rendered
    localStats.renderedPlates = renderedPlates
end

-- HUD natif RP / sobre — bandeau en haut à gauche
local function DrawPersistenceHUD()
    local x, y = 0.013, 0.025
    local w    = 0.205
    local rowH = 0.022
    local rows = 10

    local headerH = 0.030
    local effH    = 0.082   -- section "chargement a la demande" (separateur + titre + barre + legende)
    local h       = headerH + (rows * rowH) + 0.010 + effH

    -- Fond sombre semi-transparent
    DrawRect(x + w*0.5, y + h*0.5, w, h, 8, 10, 14, 220)
    -- Bandeau d'en-tête (un ton plus clair)
    DrawRect(x + w*0.5, y + headerH*0.5, w, headerH, 16, 22, 30, 240)
    -- Accent vertical à gauche
    DrawRect(x + 0.0025, y + h*0.5, 0.005, h, 255, 46, 136, 255)
    -- Séparateur sous le titre
    DrawRect(x + w*0.5, y + headerH, w, 0.0015, 255, 46, 136, 200)
    -- Pulse "live" : petit point qui clignote dans le header
    local pulse = (math.floor(GetGameTimer() / 600) % 2) == 0
    if pulse then
        DrawRect(x + w - 0.012, y + headerH*0.5, 0.006, 0.010, 80, 220, 130, 255)
    end

    -- Titre
    DrawHudText("PERSISTENCE  /  TRACKER", x + 0.010, y + 0.007, 0.30, 230, 245, 235, 255)

    local rowY = y + headerH + 0.005
    local function row(label, value, vr, vg, vb)
        DrawHudText(label, x + 0.010, rowY, 0.28, 170, 178, 184, 255)
        DrawHudText(tostring(value), x + w - 0.010, rowY, 0.30, vr, vg, vb, 255, 'right')
        rowY = rowY + rowH
    end

    -- Données
    local total      = liveStats.total or 0
    local inCull     = localStats.inCull
    local rendered   = localStats.renderedReal
    local serverSpawn= liveStats.spawnedServer or 0
    local driven     = liveStats.driven or 0
    local near       = localStats.near50
    local owned      = liveStats.owned or 0
    local players    = liveStats.onlinePlayers or 0

    -- Couleur dynamique : vert si proche limite serveur, jaune si moyen
    local cullColor = {120, 200, 255}
    if inCull >= 50 then cullColor = {255, 180, 90} end
    if inCull >= 120 then cullColor = {255, 110, 110} end

    row("Total persistes",              total,                         255, 255, 255)
    row(("Rayon spawn (%dm)"):format(math.floor(liveStats.cullRadius or 250)),
                                        inCull .. " / " .. total,      cullColor[1], cullColor[2], cullColor[3])
    row("Spawnes (serveur)",            serverSpawn,                   255, 210, 120)
    row("Rendus chez toi",              rendered,                      130, 220, 255)
    row("En conduite",                  driven,                        120, 230, 150)
    row("A <=50m de toi",               near,                          255, 150, 150)
    row("A toi (proprietaire)",         owned,                         200, 180, 255)
    row("Joueurs connectes",            players,                       200, 200, 210)
    row("Auto-save",                    (liveStats.autoSave == 1) and "ON" or "OFF",
                                        (liveStats.autoSave == 1) and 120 or 255,
                                        (liveStats.autoSave == 1) and 230 or 110,
                                        (liveStats.autoSave == 1) and 150 or 110)

    local expDays = liveStats.maxPersistenceDays or 0
    row("Expiration inactive",          (expDays > 0) and (expDays .. " j") or "OFF",
                                        (expDays > 0) and 255 or 120,
                                        (expDays > 0) and 200 or 230,
                                        (expDays > 0) and 120 or 150)

    -- ─── Section "CHARGEMENT A LA DEMANDE" : valorise le culling spatial ───────
    -- Le serveur ne matérialise QUE les véhicules proches d'un joueur. Le reste
    -- vit en base/mémoire sans entité : 0 charge CPU/réseau/synchro.
    local loaded = serverSpawn
    if loaded > total then loaded = total end
    local atRest = total - loaded
    if atRest < 0 then atRest = 0 end
    local loadRatio = (total > 0) and (loaded / total) or 0.0
    local savedPct  = math.floor((1.0 - loadRatio) * 100 + 0.5)

    -- Séparateur
    rowY = rowY + 0.006
    DrawRect(x + w*0.5, rowY, w - 0.014, 0.0015, 255, 46, 136, 160)
    rowY = rowY + 0.010

    -- Titre + badge d'économie (vert = positif) à droite
    DrawHudText("CHARGEMENT A LA DEMANDE", x + 0.010, rowY, 0.27, 170, 178, 184, 255)
    DrawHudText(("-%d%% charge"):format(savedPct), x + w - 0.010, rowY, 0.30, 120, 230, 150, 255, 'right')
    rowY = rowY + 0.024

    -- Barre bicolore : actifs (bleu) + au repos (vert) = total
    local barX, barW, barH = x + 0.010, w - 0.020, 0.011
    DrawRect(barX + barW*0.5, rowY + barH*0.5, barW, barH, 28, 34, 42, 230)
    local activeW = barW * loadRatio
    if activeW > 0.0005 then
        DrawRect(barX + activeW*0.5, rowY + barH*0.5, activeW, barH, 90, 150, 220, 235)
    end
    local restW = barW - activeW
    if restW > 0.0005 then
        DrawRect(barX + activeW + restW*0.5, rowY + barH*0.5, restW, barH, 80, 200, 130, 235)
    end
    rowY = rowY + barH + 0.011

    -- Légende sous la barre (couleurs alignées sur la barre)
    DrawHudText(("Actifs %d / %d"):format(loaded, total), barX, rowY, 0.27, 130, 200, 255, 255)
    DrawHudText(("Au repos %d"):format(atRest),           x + w - 0.010, rowY, 0.27, 120, 230, 150, 255, 'right')
end

-- ─── 3D UI persistence : raconte le "chargement à la demande" dans le monde ──
-- Code couleur d'état :
--   AU REPOS (bleu)     = persisté en base, AUCUNE entité → 0 ressource
--   EN CHARGE (jaune)   = dans TON rayon → va être matérialisé (clignote)
--   ACTIF (vert)        = entité réelle rendue chez toi
--   ACTIF RESEAU (cyan) = matérialisé pour un autre joueur (pas encore streamé chez toi)
local function StateForVehicle(plate, distSq, cullSq, serverActive)
    if localStats.renderedPlates[plate] then
        return "ACTIF", 80, 230, 140, false
    elseif serverActive then
        return "ACTIF RESEAU", 90, 210, 235, false
    elseif distSq < cullSq then
        return "EN CHARGE", 255, 200, 90, true
    else
        return "AU REPOS", 120, 165, 235, false
    end
end

local function DrawTagLine(sx, sy, str, scale, r, g, b, a)
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(str)
    DrawText(sx, sy)
end

-- Panneau flottant (plaque + état + distance) avec fond, mis à l'échelle par distance
local function DrawVehTag3D(wx, wy, wz, plate, dist, label, r, g, b, blink, expiresIn)
    local onScreen, sx, sy = World3dToScreen2d(wx, wy, wz)
    if not onScreen then return end

    local s = 1.0 - (dist / 90.0)
    if s < 0.45 then s = 0.45 elseif s > 1.0 then s = 1.0 end

    local pw, ph = 0.066 * s, 0.054 * s
    local cy = sy + ph * 0.5

    -- Fond + liseré d'état (haut) + accent gauche
    DrawRect(sx, cy, pw, ph, 8, 10, 14, 205)
    DrawRect(sx, cy - ph*0.5 + 0.004*s, pw, 0.008*s, r, g, b, 240)
    DrawRect(sx - pw*0.5 + 0.003*s, cy, 0.005*s, ph, r, g, b, 200)

    DrawTagLine(sx, sy + 0.006*s, plate, 0.44*s, 255, 255, 255, 255)

    local show = (not blink) or ((math.floor(GetGameTimer() / 250) % 2) == 0)
    if show then
        DrawTagLine(sx, sy + 0.024*s, label, 0.34*s, r, g, b, 255)
    end

    local foot = ("%.0f m"):format(dist)
    local dr, dg, db = 190, 205, 220
    if expiresIn then
        foot = foot .. ("  -  exp %dj"):format(expiresIn)
        if expiresIn <= 3 then dr, dg, db = 255, 120, 120 end   -- bientôt supprimé
    end
    DrawTagLine(sx, sy + 0.040*s, foot, 0.28*s, dr, dg, db, 235)
end

-- Gros placeholder volumétrique (cube translucide) à l'emplacement du véhicule.
-- Aligné sur les axes du monde (la liste serveur n'envoie pas le heading), ce qui
-- suffit à matérialiser "un véhicule persisté est ici" sans charger aucun modèle.
local function DrawPlaceholderBox(cx, cy, cz, r, g, b)
    local hl, hw = 2.4, 1.2            -- demi-dimensions (~4.8 x 2.4 m)
    local zBot   = cz - 1.0
    local zTop   = cz + 1.5
    local a      = math.floor(85 + math.sin(GetGameTimer() / 350.0) * 25)  -- "respire"
    DrawBox(cx - hl, cy - hw, zBot, cx + hl, cy + hw, zTop, r, g, b, a)
end

-- Render loop : HUD + 3D UI
CreateThread(function()
    while true do
        if showAllVehiclesActive then
            -- Recalcule les stats locales 5x/s (assez réactif sans cramer le CPU)
            local now = GetGameTimer()
            if now - localStats.lastCompute > 200 then
                ComputeLocalStats()
                localStats.lastCompute = now
            end

            DrawPersistenceHUD()

            -- 3D UI très visible : gros placeholder (cube) + halo + chevron + panneau
            if #allVehiclesCache > 0 then
                local pCoords = GetEntityCoords(PlayerPedId())
                local cullSq  = (liveStats.cullRadius or 250.0) * (liveStats.cullRadius or 250.0)
                for _, v in ipairs(allVehiclesCache) do
                    local dx, dy, dz = v.x - pCoords.x, v.y - pCoords.y, v.z - pCoords.z
                    local distSq = dx*dx + dy*dy + dz*dz
                    if distSq < 40000.0 then   -- 200 m
                        local plate        = string.upper(string.gsub(v.plate or '', '%s+', ''))
                        local renderedHere = localStats.renderedPlates[plate]
                        local label, r, g, b, blink = StateForVehicle(plate, distSq, cullSq, v.active)

                        -- Gros placeholder cube : UNIQUEMENT si aucune entité réelle n'est
                        -- rendue ici. Quand on s'approche et que le véhicule passe ACTIF,
                        -- le cube laisse place au vrai modèle => démonstration directe du
                        -- chargement à la demande.
                        if not renderedHere then
                            DrawPlaceholderBox(v.x, v.y, v.z, r, g, b)
                        end

                        -- Halo cylindre au sol
                        DrawMarker(1, v.x, v.y, v.z - 1.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            2.0, 2.0, 1.0,
                            r, g, b, 130,
                            false, false, 2, false, nil, nil, false)

                        -- Chevron animé au-dessus du cube
                        DrawMarker(2, v.x, v.y, v.z + 2.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.9, 0.9, 0.7,
                            r, g, b, 225,
                            true, false, 2, false, nil, nil, false)

                        -- Panneau plaque + état + distance à <120 m
                        if distSq < 14400.0 then
                            DrawVehTag3D(v.x, v.y, v.z + 2.3, v.plate,
                                math.sqrt(distSq), label, r, g, b, blink, v.expiresIn)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)





