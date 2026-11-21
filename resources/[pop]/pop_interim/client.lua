-- pop_interim/client.lua
-- Marqueur + touche E à l'emplacement du blip Intérim, ouvre un menu NUI
-- (style pop_emotes) : 3 cases images en bas. Cliquer une case déplace la
-- caméra et le ped sur la vue du poste ; un bouton confirme et applique le job ESX.

local menuOpen = false
local previewCam = nil
local camPool = {}   -- cams gardées vivantes le temps des interpolations
local initialCoords = nil
local initialHeading = 0.0
local currentDofConfig = nil
local isTransitioning = false
local pendingPreviewId = nil -- dernier aperçu demandé pendant une transition (rejoué à la fin)

-- Index id -> entrée de config (pour retrouver la caméra côté client).
local JOB_BY_ID = {}
for _, entry in ipairs(Config.Jobs) do
    JOB_BY_ID[entry.id] = entry
end

-- Payload allégé envoyé à la NUI (pas de vector4 dans le JSON, pas de nom de job).
local function jobsForNui()
    local out = {}
    for _, entry in ipairs(Config.Jobs) do
        out[#out + 1] = {
            id          = entry.id,
            label       = entry.label,
            image       = entry.image,
            description = entry.description,
        }
    end
    return out
end

local previewEntities = {}

local function clearPreviewEntities()
    for _, entity in ipairs(previewEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    previewEntities = {}
end

-- =============================================================
-- CAMÉRA DE PRÉVISUALISATION
-- =============================================================
local function clearCam()
    clearPreviewEntities()
    currentDofConfig = nil
    if previewCam or #camPool > 0 then
        RenderScriptCams(false, true, Config.CameraBlend, true, true)
    end
    for _, c in ipairs(camPool) do
        if c and DoesCamExist(c) then
            DestroyCam(c, false)
        end
    end
    camPool = {}
    previewCam = nil
    ClearFocus()
end

local function moveCamTo(view)
    local newCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    
    local pos, rot, fov
    if type(view) == 'vector4' then
        pos = vector3(view.x, view.y, view.z)
        rot = vector3(Config.CameraPitch, 0.0, view.w)
        fov = Config.CameraFov
    else
        pos = view.pos
        rot = view.rot or vector3(Config.CameraPitch, 0.0, 0.0)
        fov = view.fov or Config.CameraFov
    end

    SetCamCoord(newCam, pos.x, pos.y, pos.z)
    SetCamRot(newCam, rot.x, rot.y, rot.z, 2)
    SetCamFov(newCam, fov)
    
    -- Configurer le flou d'arrière-plan pour la boucle par tick
    if type(view) == 'table' and view.dof then
        currentDofConfig = {
            cam = newCam,
            focusDist = view.focusDist or 5.3,
            nearDof = view.nearDof,
            farDof = view.farDof,
            dofStrength = view.dofStrength
        }
    else
        currentDofConfig = nil
    end

    camPool[#camPool + 1] = newCam

    -- Force le streaming sur la zone visée (souvent loin de l'agence).
    SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)

    -- On garde l'ancienne cam vivante (source de l'interpolation) ; tout est
    -- détruit d'un coup dans clearCam() à la fermeture.
    if previewCam then
        SetCamActiveWithInterp(newCam, previewCam, Config.CameraBlend, 1, 1)
    else
        SetCamActive(newCam, true)
    end
    RenderScriptCams(true, true, Config.CameraBlend, true, true)
    previewCam = newCam
end

-- =============================================================
-- NUI
-- =============================================================
local function openMenu()
    if menuOpen then return end
    menuOpen = true

    local ped = PlayerPedId()
    initialCoords = GetEntityCoords(ped)
    initialHeading = GetEntityHeading(ped)

    FreezeEntityPosition(ped, true)
    SetNuiFocus(true, true)
    TriggerEvent('hud:toggleui', false) -- Hide custom HUD
    SendNUIMessage({
        type = 'open',
        jobs = jobsForNui(),
    })
end

-- Attend la fin d'un fondu au noir (3 s max pour ne jamais bloquer l'état).
local function waitFadedOut()
    local t = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
end

local function closeMenu(confirmed)
    if not menuOpen then return end
    menuOpen = false
    isTransitioning = false
    pendingPreviewId = nil

    SetNuiFocus(false, false)
    TriggerEvent('hud:toggleui', true) -- Restore custom HUD
    SendNUIMessage({ type = 'close' })

    local ped = PlayerPedId()

    if previewCam then
        CreateThread(function()
            DoScreenFadeOut(500)
            waitFadedOut()

            ClearPedTasks(ped)
            clearCam()

            if not confirmed and initialCoords then
                SetEntityCoords(ped, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, true)
                SetEntityHeading(ped, initialHeading)
            end

            initialCoords = nil
            FreezeEntityPosition(ped, false)

            Wait(200)
            DoScreenFadeIn(500)
        end)
    else
        ClearPedTasks(ped)
        clearCam()
        initialCoords = nil
        FreezeEntityPosition(ped, false)
    end

    -- Empêche le MÊME appui sur Échap (qui ferme le menu) d'ouvrir le menu pause.
    CreateThread(function()
        local ticks = 15
        while ticks > 0 do
            ticks = ticks - 1
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        end
    end)
end

RegisterNUICallback('close', function(_, cb)
    -- Ignoré pendant la préparation de l'aperçu (Échap pourra être réappuyé).
    if isTransitioning then cb('ok') return end
    closeMenu(false)
    cb('ok')
end)

-- Construit la scène d'aperçu d'un poste (téléportation, caméra, décor).
local function buildPreviewScene(entry)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    waitFadedOut()
    
    -- Nettoyage des anciennes entités de prévisualisation
    clearPreviewEntities()
    
    -- 1. Téléportation physique du ped (pour charger les collisions/textures et le positionner)
    local tpPos, tpHeading
    if entry.pedPos then
        tpPos = vector3(entry.pedPos.x, entry.pedPos.y, entry.pedPos.z)
        tpHeading = entry.pedPos.w
    else
        if type(entry.camera) == 'vector4' then
            tpPos = vector3(entry.camera.x, entry.camera.y, entry.camera.z)
            tpHeading = entry.camera.w
        else
            tpPos = entry.camera.pos
            tpHeading = entry.camera.rot.z
        end
    end
    
    SetEntityCoords(ped, tpPos.x, tpPos.y, tpPos.z - 0.95, false, false, false, true)
    SetEntityHeading(ped, tpHeading)
    ClearPedTasks(ped)

    -- Jouer l'animation sur le propre ped du joueur si spécifiée
    if entry.pedAnimDict and entry.pedAnimName then
        RequestAnimDict(entry.pedAnimDict)
        local animTimeout = 0
        while not HasAnimDictLoaded(entry.pedAnimDict) and animTimeout < 2000 do
            Wait(10)
            animTimeout = animTimeout + 10
        end
        if HasAnimDictLoaded(entry.pedAnimDict) then
            TaskPlayAnim(ped, entry.pedAnimDict, entry.pedAnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end
    
    -- 2. Activation de la caméra de prévisualisation
    moveCamTo(entry.camera)

    -- 3. Spawn des peds ambiants pour le décor de prévisualisation
    if entry.previewPeds then
        for _, pedData in ipairs(entry.previewPeds) do
            local hash = GetHashKey(pedData.model)
            RequestModel(hash)
            local timeout = 0
            while not HasModelLoaded(hash) and timeout < 2000 do
                Wait(10)
                timeout = timeout + 10
            end
            if HasModelLoaded(hash) then
                local cp = pedData.coords
                local aped = CreatePed(4, hash, cp.x, cp.y, cp.z - 0.98, cp.w, false, true)
                SetEntityAsMissionEntity(aped, true, true)
                SetBlockingOfNonTemporaryEvents(aped, true)
                FreezeEntityPosition(aped, true)
                SetEntityInvincible(aped, true)

                if pedData.weapon then
                    local wepHash = GetHashKey(pedData.weapon)
                    GiveWeaponToPed(aped, wepHash, 1, false, true)
                    SetCurrentPedWeapon(aped, wepHash, true)
                end

                if pedData.animDict and pedData.animName then
                    RequestAnimDict(pedData.animDict)
                    local animTimeout = 0
                    while not HasAnimDictLoaded(pedData.animDict) and animTimeout < 2000 do
                        Wait(10)
                        animTimeout = animTimeout + 10
                    end
                    if HasAnimDictLoaded(pedData.animDict) then
                        TaskPlayAnim(aped, pedData.animDict, pedData.animName, 8.0, -8.0, -1, pedData.animFlag or 1, 0, false, false, false)
                    end
                end

                if pedData.prop then
                    local propModel = GetHashKey(pedData.prop)
                    RequestModel(propModel)
                    local pTimeout = 0
                    while not HasModelLoaded(propModel) and pTimeout < 2000 do
                        Wait(10)
                        pTimeout = pTimeout + 10
                    end
                    if HasModelLoaded(propModel) then
                        local propObj = CreateObject(propModel, 0.0, 0.0, 0.0, false, false, false)
                        AttachEntityToEntity(propObj, aped, GetPedBoneIndex(aped, pedData.boneIndex), pedData.propPlacement[1], pedData.propPlacement[2], pedData.propPlacement[3], pedData.propPlacement[4], pedData.propPlacement[5], pedData.propPlacement[6], true, true, false, true, 1, true)
                        table.insert(previewEntities, propObj)
                    end
                    SetModelAsNoLongerNeeded(propModel)
                end

                if pedData.extraProp then
                    local extraModel = GetHashKey(pedData.extraProp)
                    RequestModel(extraModel)
                    local epTimeout = 0
                    while not HasModelLoaded(extraModel) and epTimeout < 2000 do
                        Wait(10)
                        epTimeout = epTimeout + 10
                    end
                    if HasModelLoaded(extraModel) then
                        local extraObj = CreateObject(extraModel, 0.0, 0.0, 0.0, false, false, false)
                        AttachEntityToEntity(extraObj, aped, GetPedBoneIndex(aped, pedData.extraBoneIndex), pedData.extraPropPlacement[1], pedData.extraPropPlacement[2], pedData.extraPropPlacement[3], pedData.extraPropPlacement[4], pedData.extraPropPlacement[5], pedData.extraPropPlacement[6], true, true, false, true, 1, true)
                        table.insert(previewEntities, extraObj)
                    end
                    SetModelAsNoLongerNeeded(extraModel)
                end

                table.insert(previewEntities, aped)
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end

    -- 4. Spawn des véhicules ambiants pour le décor de prévisualisation (hélico, etc.)
    if entry.previewVehicles then
        for _, vehData in ipairs(entry.previewVehicles) do
            local hash = GetHashKey(vehData.model)
            RequestModel(hash)
            local timeout = 0
            while not HasModelLoaded(hash) and timeout < 2000 do
                Wait(10)
                timeout = timeout + 10
            end
            if HasModelLoaded(hash) then
                local cv = vehData.coords
                local veh = CreateVehicle(hash, cv.x, cv.y, cv.z, cv.w, false, true)
                SetEntityAsMissionEntity(veh, true, true)
                SetVehicleOnGroundProperly(veh)
                FreezeEntityPosition(veh, true)
                SetEntityInvincible(veh, true)

                if vehData.colours then
                    SetVehicleColours(veh, vehData.colours[1], vehData.colours[2])
                end
                if vehData.extraColours then
                    SetVehicleExtraColours(veh, vehData.extraColours[1], vehData.extraColours[2])
                end
                if vehData.interiorColour then
                    SetVehicleInteriorColour(veh, vehData.interiorColour)
                end
                if vehData.dashboardColour then
                    SetVehicleDashboardColour(veh, vehData.dashboardColour)
                end
                if vehData.modKit then
                    SetVehicleModKit(veh, vehData.modKit)
                end
                if vehData.livery then
                    SetVehicleMod(veh, 48, vehData.livery, false)
                    SetVehicleLivery(veh, vehData.livery)
                end
                if vehData.doorOpen then
                    SetVehicleDoorOpen(veh, vehData.doorOpen, false, false)
                elseif vehData.doorsOpen then
                    for _, doorIdx in ipairs(vehData.doorsOpen) do
                        SetVehicleDoorOpen(veh, doorIdx, false, false)
                    end
                end

                table.insert(previewEntities, veh)
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    
    Wait(1000)
end

local runPreview

local function finishTransition()
    isTransitioning = false
    if menuOpen and pendingPreviewId then
        -- Un autre poste a été cliqué entre-temps : on l'enchaîne (écran encore noir).
        local id = pendingPreviewId
        pendingPreviewId = nil
        runPreview(id)
        return
    end
    pendingPreviewId = nil
    if not menuOpen then
        -- Menu fermé pendant la préparation (arrêt forcé) : on ne laisse rien traîner.
        clearPreviewEntities()
    end
    SendNUIMessage({ type = 'sceneReady' })
    DoScreenFadeIn(500)
end

runPreview = function(id)
    local entry = id and JOB_BY_ID[id]
    if not entry then
        SendNUIMessage({ type = 'sceneReady' })
        DoScreenFadeIn(500)
        return
    end
    isTransitioning = true
    if entry.camera then
        CreateThread(function()
            local ok, err = pcall(buildPreviewScene, entry)
            if not ok then
                print(('[pop_interim] Erreur aperçu "%s" : %s'):format(tostring(id), tostring(err)))
            end
            finishTransition()
        end)
    else
        -- Poste sans coordonnées : on revient à l'agence d'intérim
        clearCam()
        if initialCoords then
            CreateThread(function()
                local ok, err = pcall(function()
                    local ped = PlayerPedId()
                    DoScreenFadeOut(500)
                    waitFadedOut()

                    SetEntityCoords(ped, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, true)
                    SetEntityHeading(ped, initialHeading)

                    Wait(500)
                end)
                if not ok then
                    print(('[pop_interim] Erreur retour agence : %s'):format(tostring(err)))
                end
                finishTransition()
            end)
        else
            finishTransition()
        end
    end
end

-- Clic sur une case : déplace la caméra ET le ped sur la vue du poste (si définie).
RegisterNUICallback('previewJob', function(data, cb)
    local id = data and data.id
    if isTransitioning then
        -- Transition en cours : on mémorise la demande, rejouée à la fin.
        pendingPreviewId = id
        cb('ok')
        return
    end
    runPreview(id)
    cb('ok')
end)

-- Confirmation : applique le job (validé serveur), confirme la position et ferme.
RegisterNUICallback('selectJob', function(data, cb)
    -- Ignoré pendant la préparation de l'aperçu (le joueur pourra revalider).
    if isTransitioning then cb('ok') return end

    local entry = data and data.id and JOB_BY_ID[data.id]
    if entry then
        TriggerServerEvent('pop_interim:setJob', data.id)
        
        -- Si pas de coordonnées, on le ramène à l'agence
        if not entry.camera and initialCoords then
            local ped = PlayerPedId()
            SetEntityCoords(ped, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, true)
            SetEntityHeading(ped, initialHeading)
        end
        
        closeMenu(true) -- Confirmé ! (on ne TP pas en arrière)
    else
        closeMenu(false)
    end
    cb('ok')
end)

-- =============================================================
-- MARQUEUR + INTERACTION
-- =============================================================
CreateThread(function()
    local m = Config.Marker
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local dist = #(coords - Config.Location)

        if dist < Config.DrawDistance then
            sleep = 0
            DrawMarker(
                m.type,
                Config.Location.x, Config.Location.y, Config.Location.z - 0.95,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                m.sizeX, m.sizeY, m.sizeZ,
                m.r, m.g, m.b, m.a,
                false, true, 2, false, nil, nil, false
            )

            if dist < Config.InteractDist and not menuOpen then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour consulter l'~b~agence d'intérim~s~")
                if IsControlJustReleased(0, Config.OpenKey) then
                    openMenu()
                end
            end
        end

        Wait(sleep)
    end
end)

-- Bloque les contrôles gênants pendant que le menu est ouvert (cf. pop_emotes).
CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 200, true) -- pause
            DisableControlAction(0, 199, true) -- pause
            DisableControlAction(0, 322, true) -- ESC
            
            -- Masquer le radar et l'HUD du jeu
            DisplayRadar(false)
            HideHudAndRadarThisFrame()
            
            -- Appliquer le flou d'arrière-plan à chaque frame si actif
            if currentDofConfig and DoesCamExist(currentDofConfig.cam) then
                SetUseHiDof()
                SetCamUseShallowDofMode(currentDofConfig.cam, true)
                local fdist = currentDofConfig.focusDist
                local nearDof = currentDofConfig.nearDof or 1.5
                local farDof = currentDofConfig.farDof or 3.0
                local strength = currentDofConfig.dofStrength or 1.5
                SetCamNearDof(currentDofConfig.cam, math.max(0.1, fdist - nearDof))
                SetCamFarDof(currentDofConfig.cam, fdist + farDof)
                SetCamDofStrength(currentDofConfig.cam, strength)
            end
            
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Ferme proprement et supprime le ped si la resource s'arrête en plein écran ouvert.
local devSpawnedEntities = {}

local function clearDevEntities()
    for _, entity in ipairs(devSpawnedEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    devSpawnedEntities = {}
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clearDevEntities()
        if menuOpen then
            SetNuiFocus(false, false)
            clearCam()
            if initialCoords then
                local ped = PlayerPedId()
                SetEntityCoords(ped, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false, true)
                SetEntityHeading(ped, initialHeading)
            end
            FreezeEntityPosition(PlayerPedId(), false)
        end
    end
end)

-- Chargement avec délai max (2 s) : jamais de boucle infinie sur un modèle invalide.
local function devLoadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash)
end

local function devLoadAnimDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- Command to test/spawn all preview entities in-game without opening the menu
-- Usage: /devpreview [all | pesticides | youtool | transport_urgence | clean]
-- Restreinte (ACE) : add_ace group.admin command.devpreview allow
RegisterCommand("devpreview", function(source, args)
    local target = args[1]
    
    if target == "clean" then
        clearDevEntities()
        TriggerEvent("chat:addMessage", { args = { "^2Dev Preview^7: Toutes les entités ont été supprimées." } })
        return
    end

    local jobsToSpawn = {}
    if not target or target == "all" then
        jobsToSpawn = Config.Jobs
    else
        for _, entry in ipairs(Config.Jobs) do
            if entry.id == target then
                table.insert(jobsToSpawn, entry)
                break
            end
        end
    end

    if #jobsToSpawn == 0 then
        TriggerEvent("chat:addMessage", { args = { "^1Dev Preview^7: Aucun job valide trouvé avec l'id: " .. tostring(target) } })
        return
    end

    clearDevEntities()

    for _, entry in ipairs(jobsToSpawn) do
        -- Spawning preview peds
        if entry.previewPeds then
            for _, pedData in ipairs(entry.previewPeds) do
                local hash = GetHashKey(pedData.model)
                if devLoadModel(hash) then
                    local cp = pedData.coords
                    local aped = CreatePed(4, hash, cp.x, cp.y, cp.z - 0.98, cp.w, false, true)
                    SetEntityAsMissionEntity(aped, true, true)
                    SetBlockingOfNonTemporaryEvents(aped, true)
                    FreezeEntityPosition(aped, true)
                    SetEntityInvincible(aped, true)

                    if pedData.weapon then
                        local wepHash = GetHashKey(pedData.weapon)
                        GiveWeaponToPed(aped, wepHash, 1, false, true)
                        SetCurrentPedWeapon(aped, wepHash, true)
                    end

                    if pedData.animDict and pedData.animName then
                        if devLoadAnimDict(pedData.animDict) then
                            TaskPlayAnim(aped, pedData.animDict, pedData.animName, 8.0, -8.0, -1, pedData.animFlag or 1, 0, false, false, false)
                        end
                    end

                    if pedData.prop then
                        local propModel = GetHashKey(pedData.prop)
                        if devLoadModel(propModel) then
                            local propObj = CreateObject(propModel, 0.0, 0.0, 0.0, false, false, false)
                            AttachEntityToEntity(propObj, aped, GetPedBoneIndex(aped, pedData.boneIndex), pedData.propPlacement[1], pedData.propPlacement[2], pedData.propPlacement[3], pedData.propPlacement[4], pedData.propPlacement[5], pedData.propPlacement[6], true, true, false, true, 1, true)
                            table.insert(devSpawnedEntities, propObj)
                        end
                        SetModelAsNoLongerNeeded(propModel)
                    end

                    if pedData.extraProp then
                        local extraModel = GetHashKey(pedData.extraProp)
                        if devLoadModel(extraModel) then
                            local extraObj = CreateObject(extraModel, 0.0, 0.0, 0.0, false, false, false)
                            AttachEntityToEntity(extraObj, aped, GetPedBoneIndex(aped, pedData.extraBoneIndex), pedData.extraPropPlacement[1], pedData.extraPropPlacement[2], pedData.extraPropPlacement[3], pedData.extraPropPlacement[4], pedData.extraPropPlacement[5], pedData.extraPropPlacement[6], true, true, false, true, 1, true)
                            table.insert(devSpawnedEntities, extraObj)
                        end
                        SetModelAsNoLongerNeeded(extraModel)
                    end

                    table.insert(devSpawnedEntities, aped)
                end
                SetModelAsNoLongerNeeded(hash)
            end
        end

        -- Spawning preview vehicles
        if entry.previewVehicles then
            for _, vehData in ipairs(entry.previewVehicles) do
                local hash = GetHashKey(vehData.model)
                if devLoadModel(hash) then
                    local cv = vehData.coords
                    local veh = CreateVehicle(hash, cv.x, cv.y, cv.z, cv.w, false, true)
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleOnGroundProperly(veh)
                    FreezeEntityPosition(veh, true)
                    SetEntityInvincible(veh, true)

                    if vehData.colours then
                        SetVehicleColours(veh, vehData.colours[1], vehData.colours[2])
                    end
                    if vehData.extraColours then
                        SetVehicleExtraColours(veh, vehData.extraColours[1], vehData.extraColours[2])
                    end
                    if vehData.interiorColour then
                        SetVehicleInteriorColour(veh, vehData.interiorColour)
                    end
                    if vehData.dashboardColour then
                        SetVehicleDashboardColour(veh, vehData.dashboardColour)
                    end
                    if vehData.modKit then
                        SetVehicleModKit(veh, vehData.modKit)
                    end
                    if vehData.livery then
                        SetVehicleMod(veh, 48, vehData.livery, false)
                        SetVehicleLivery(veh, vehData.livery)
                    end
                    if vehData.doorOpen then
                        SetVehicleDoorOpen(veh, vehData.doorOpen, false, false)
                    elseif vehData.doorsOpen then
                        for _, doorIdx in ipairs(vehData.doorsOpen) do
                            SetVehicleDoorOpen(veh, doorIdx, false, false)
                        end
                    end

                    table.insert(devSpawnedEntities, veh)
                end
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
    TriggerEvent("chat:addMessage", { args = { "^2Dev Preview^7: Entités générées pour " .. tostring(target or "tous les jobs") .. "." } })
end, true)
