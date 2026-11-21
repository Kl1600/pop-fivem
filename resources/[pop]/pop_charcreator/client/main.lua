local SkinData = {}
local isCreatorOpen = false

local POSE_DICT = "anim@mp_corona_idles@female_b@idle_a"
local POSE_NAME = "idle_a"

local function ApplyCreatorPose(ped)
    RequestAnimDict(POSE_DICT)
    while not HasAnimDictLoaded(POSE_DICT) do Wait(0) end
    TaskPlayAnim(ped, POSE_DICT, POSE_NAME, 8.0, 8.0, -1, 1, 0, false, false, false)
    SetEntityAnimCurrentTime(ped, POSE_DICT, POSE_NAME, 0.0)
    SetEntityAnimSpeed(ped, POSE_DICT, POSE_NAME, 0.0)
    RemoveAnimDict(POSE_DICT)
end

exports('ApplyCreatorPose', function()
    ApplyCreatorPose(PlayerPedId())
end)

local function OpenCreator()
    local model = GetHashKey('mp_m_freemode_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    -- Ensure interior is loaded at the destination
    local coords = vector3(-578.3015, 44.7212, 92.2444)
    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior ~= 0 then
        LoadInterior(interior)
        while not IsInteriorReady(interior) do Wait(0) end
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    -- IMPORTANT: Wait for the ped to be created/switched and collision to load
    Wait(1000)
    
    local defaultSkin = {
        sex = 0,
        tshirt_1 = 15, tshirt_2 = 0,
        torso_1 = 15, torso_2 = 0,
        arms = 15, arms_2 = 0,
        pants_1 = 61, pants_2 = 0,
        shoes_1 = 34, shoes_2 = 0,
        glasses_1 = 0, glasses_2 = 0,
        helmet_1 = -1, helmet_2 = 0,
        mask_1 = 0, mask_2 = 0,
        bproof_1 = 0, bproof_2 = 0,
        chain_1 = 0, chain_2 = 0,
        decals_1 = 0, decals_2 = 0,
        bags_1 = 0, bags_2 = 0
    }
    TriggerEvent('skinchanger:loadSkin', defaultSkin)
    Wait(500)

    local playerPed = PlayerPedId()
    
    -- Teleport and ensure they are on the correct floor Z
    local destCoords = vector3(-578.3015, 44.7212, 92.2444)

    RequestCollisionAtCoord(destCoords.x, destCoords.y, destCoords.z)
    SetEntityCoordsNoOffset(playerPed, destCoords.x, destCoords.y, destCoords.z, false, false, false)
    SetEntityHeading(playerPed, 245.8544)
    
    -- Freeze instantly BEFORE the next tick so gravity doesn't pull them down
    FreezeEntityPosition(playerPed, true)
    
    ClearPedBloodDamage(playerPed)
    ClearPedWetness(playerPed)
    SetEntityAlpha(playerPed, 255, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, true)

    isCreatorOpen = true
    -- Flag partagé pour que le HUD (pop_hud) cesse de forcer la minimap visible
    -- toutes les 200 ms (sinon elle clignote dans le créateur).
    LocalPlayer.state:set('charcreatorOpen', true, false)
    SetNuiFocus(true, true)

    
    SendNUIMessage({
        action = 'openCreator',
        mode80s = Config and Config.Mode80s or false,
        birthDate = Config and Config.BirthDate or nil,
        enableHeight = Config and (Config.EnableHeight ~= false) or false,
    })
    DisplayRadar(false)

    -- Entrer dans l'instance
    TriggerServerEvent('vanguard_charcreator:server:enterInstance')

    -- Frozen idle pose during creation
    ApplyCreatorPose(playerPed)
    
    CreateCamera()
    -- Give a bit more time for the camera to settle
    Citizen.SetTimeout(500, function()
        FocusOn('gender')
    end)
    
    -- Loop for rotation/zoom via keys
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            -- SetUseHiDof() est déjà appelé chaque frame par le thread de camera.lua
            -- Hide minimap (one-shot DisplayRadar(false) gets overridden by HUD scripts)
            DisplayRadar(false)
            local ped = PlayerPedId()
            
            -- Rotation (Q/E)
            if IsControlPressed(0, 44) then -- Q
                local heading = GetEntityHeading(ped)
                SetEntityHeading(ped, heading + 2.0)
            elseif IsControlPressed(0, 38) then -- E
                local heading = GetEntityHeading(ped)
                SetEntityHeading(ped, heading - 2.0)
            end
            
            -- Zoom (W/S)
            if IsControlPressed(0, 32) then -- W
                camRadius = camRadius - 0.05
                if camRadius < 0.4 then camRadius = 0.4 end
                UpdateCamera()
            elseif IsControlPressed(0, 31) then -- S
                camRadius = camRadius + 0.05
                if camRadius > 4.0 then camRadius = 4.0 end
                UpdateCamera()
            end
            
            -- Keep player updated if they quit NUI via console or crash
            if not IsNuiFocused() then break end
        end
    end)
end

RegisterNUICallback('switchCategory', function(data, cb)
    FocusOn(data.category)
    
    local components = {
        hair = { 'hair_1', 'hair_color_1', 'hair_color_2', 'eyebrows_1', 'eyebrows_2' },
        beard = { 'beard_1', 'beard_2', 'beard_3', 'eyebrows_3' },
        arms = { 'arms', 'arms_2' }
    }
    
    local list = components[data.category]
    if list then
        for _, id in ipairs(list) do
            TriggerEvent('skinchanger:getData', function(all, max)
                local m = max[id]
                if m then
                    SendNUIMessage({ action = 'updateMax', id = id, max = m })
                end
            end)
        end
    end
    cb('ok')
end)

RegisterNUICallback('requestTextures', function(data, cb)
    -- Deprecated with grid removal
    cb({ count = 1 })
end)

RegisterNUICallback('openClothes', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCreator' })

    cb('ok')

    Citizen.CreateThread(function()
        Citizen.Wait(100)
        TriggerEvent('clothes:openFromCreator')
    end)
end)

RegisterNUICallback('openTattoos', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCreator' })

    cb('ok')

    Citizen.CreateThread(function()
        Citizen.Wait(100)
        TriggerEvent('tattoos:openFromCreator')
    end)
end)

RegisterNetEvent('vanguard_charcreator:reopen')
AddEventHandler('vanguard_charcreator:reopen', function()
    if isCreatorOpen then
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openCreator',
            mode80s = Config and Config.Mode80s or false,
            birthDate = Config and Config.BirthDate or nil,
            enableHeight = Config and (Config.EnableHeight ~= false) or false,
        })
        
        -- Restore Camera
        if Cam and DoesCamExist(Cam) then
            SetCamActive(Cam, true)
            RenderScriptCams(true, false, 0, true, true)
            UpdateCamera()
        end
    end
end)

RegisterNUICallback('updateAppearance', function(data, cb)
    local val = tonumber(data.value)
    if val == nil then val = data.value end

    SkinData[data.id] = val
    
    if data.id == 'height' then
        local h = val or 2
        local heightVal = 100

        if h == 1 then
            heightVal = 90
        elseif h == 3 then
            heightVal = 110
        else
            heightVal = 100
        end

        SkinData['height'] = heightVal
        TriggerEvent('skinchanger:change', 'height', heightVal)
        cb('ok')
        return
    end

    TriggerEvent('skinchanger:change', data.id, val)

    if data.texture then
        local texVal = tonumber(data.texture)
        if texVal == nil then texVal = data.texture end

        local texKey = data.id:gsub('_1', '_2')
        SkinData[texKey] = texVal
        TriggerEvent('skinchanger:change', texKey, texVal)
    end
    cb('ok')
end)

RegisterNUICallback('updateGender', function(data, cb)
    local isMale = (data.gender == 'male')
    local model = isMale and GetHashKey('mp_m_freemode_01') or GetHashKey('mp_f_freemode_01')
    
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end
    
    SetPlayerModel(PlayerId(), model)
    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)
    
    -- Re-apply coordinates and freezing just in case changing model dropped us
    local destCoords = vector3(-578.3015, 44.7212, 92.2444)
    SetEntityCoordsNoOffset(newPed, destCoords.x, destCoords.y, destCoords.z, false, false, false)
    SetEntityHeading(newPed, 245.8544)
    FreezeEntityPosition(newPed, true)
    SetEntityVisible(newPed, true, false)
    SetEntityInvincible(newPed, true)
    
    local sexNum = isMale and 0 or 1
    
    local defaultSkin = {
        sex = sexNum,
        tshirt_1 = 15, tshirt_2 = 0,
        torso_1 = 15, torso_2 = 0,
        arms = 15, arms_2 = 0,
        pants_1 = isMale and 61 or 17, pants_2 = 0,
        shoes_1 = isMale and 34 or 35, shoes_2 = 0,
        glasses_1 = 0, glasses_2 = 0,
        helmet_1 = -1, helmet_2 = 0,
        mask_1 = 0, mask_2 = 0,
        bproof_1 = 0, bproof_2 = 0,
        chain_1 = 0, chain_2 = 0,
        decals_1 = 0, decals_2 = 0,
        bags_1 = 0, bags_2 = 0
    }
    
    TriggerEvent('skinchanger:loadSkin', defaultSkin)
    
    for k, v in pairs(defaultSkin) do
        SkinData[k] = v
    end

    -- Re-apply frozen animation AFTER skin load, with a small delay to avoid being cleared
    Citizen.SetTimeout(200, function()
        ApplyCreatorPose(PlayerPedId())
    end)

    cb('ok')
end)

RegisterNUICallback('updateModel', function(data, cb)
    local model = GetHashKey(data.model)
    
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        return cb('error')
    end

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    SetPlayerModel(PlayerId(), model)
    local newPed = PlayerPedId()
    SetPedDefaultComponentVariation(newPed)

    local destCoords = vector3(-578.3015, 44.7212, 92.2444)
    SetEntityCoordsNoOffset(newPed, destCoords.x, destCoords.y, destCoords.z, false, false, false)
    SetEntityHeading(newPed, 245.8544)
    FreezeEntityPosition(newPed, true)
    SetEntityVisible(newPed, true, false)
    SetEntityInvincible(newPed, true)

    -- Clear skin data when switching to PED
    SkinData = { model = data.model }
    
    cb('ok')
end)

RegisterNUICallback('finish', function(data, cb)
    isCreatorOpen = false
    LocalPlayer.state:set('charcreatorOpen', false, false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCreator' })
    DestroyCamera()
    DisplayRadar(true)
    
    TriggerEvent('skinchanger:getSkin', function(skin)
        local isMale = (skin.sex == 0)

        -- On capture TOUTE la tenue/accessoires RÉELLEMENT choisis par le joueur
        -- AVANT de remettre le skin nu. Renvoyé au serveur pour équiper exactement
        -- ces pièces (vêtements + props : casquette, lunettes, masque…) au lieu
        -- d'une tenue prédéfinie en dur.
        local chosenClothes = {
            -- composants
            torso_1  = skin['torso_1'],  torso_2  = skin['torso_2'],
            tshirt_1 = skin['tshirt_1'], tshirt_2 = skin['tshirt_2'],
            arms     = skin['arms'],     arms_2   = skin['arms_2'],
            pants_1  = skin['pants_1'],  pants_2  = skin['pants_2'],
            shoes_1  = skin['shoes_1'],  shoes_2  = skin['shoes_2'],
            mask_1   = skin['mask_1'],   mask_2   = skin['mask_2'],
            bproof_1 = skin['bproof_1'], bproof_2 = skin['bproof_2'],
            chain_1  = skin['chain_1'],  chain_2  = skin['chain_2'],
            bags_1   = skin['bags_1'],   bags_2   = skin['bags_2'],
            decals_1 = skin['decals_1'], decals_2 = skin['decals_2'],
            -- props (accessoires)
            helmet_1  = skin['helmet_1'],  helmet_2  = skin['helmet_2'],
            glasses_1 = skin['glasses_1'], glasses_2 = skin['glasses_2'],
            ears_1    = skin['ears_1'],    ears_2    = skin['ears_2'],
        }

        -- Vider le skin (mettre les vêtements par défaut nus)
        skin['tshirt_1'] = 15
        skin['tshirt_2'] = 0
        skin['torso_1'] = 15
        skin['torso_2'] = 0
        skin['arms'] = 15
        skin['arms_2'] = 0
        skin['pants_1'] = isMale and 61 or 17
        skin['pants_2'] = 0
        skin['shoes_1'] = isMale and 34 or 35
        skin['shoes_2'] = 0
        skin['glasses_1'] = 0
        skin['glasses_2'] = 0
        skin['helmet_1'] = -1
        skin['helmet_2'] = 0
        skin['mask_1'] = 0
        skin['mask_2'] = 0
        skin['bproof_1'] = 0
        skin['bproof_2'] = 0
        skin['chain_1'] = 0
        skin['chain_2'] = 0
        skin['decals_1'] = 0
        skin['decals_2'] = 0
        skin['bags_1'] = 0
        skin['bags_2'] = 0
        
        -- Copie immédiate du skin AVANT tout respawn/sortie d'instance : le table
        -- 'skin' est une référence partagée vers SkinChanger.character qui peut être
        -- remis à zéro pendant le délai → on fige les valeurs et on envoie tout de suite.
        local skinCopy = {}
        for k, v in pairs(skin) do skinCopy[k] = v end

        TriggerServerEvent('vanguard_charcreator:save', skinCopy, data.firstname, data.lastname, data.dateofbirth, data.spawn, chosenClothes)

        TriggerEvent('skinchanger:loadSkin', skin)
    end)
    
    local playerPed = PlayerPedId()

    -- Lieu d'apparition choisi par le joueur dans l'UI (data.spawn = 'usa'|'mexico').
    -- Les coordonnées viennent de config.lua (Config.SpawnPoints). Fallback sur le
    -- spawn par défaut si la clé reçue est absente/invalide.
    local spawnKey = data and data.spawn
    local spawnPoint = (Config and Config.SpawnPoints and Config.SpawnPoints[spawnKey])
                       or (Config and Config.SpawnPoints and Config.SpawnPoints[Config.DefaultSpawn])
    -- Sécurité ultime si config.lua absent/cassé : ancien spawn USA en dur.
    if not spawnPoint then
        spawnPoint = { coords = vector3(-536.7485, -217.9594, 37.6498), heading = 206.7365 }
    end

    local spawnX, spawnY, spawnZ = spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z

    -- Teleport and freeze until the map collision is verified
    RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
    SetEntityCoordsNoOffset(playerPed, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityHeading(playerPed, spawnPoint.heading or 0.0)
    FreezeEntityPosition(playerPed, true)

    Citizen.CreateThread(function()
        local timeout = GetGameTimer() + 4000
        while not HasCollisionLoadedAroundEntity(playerPed) and GetGameTimer() < timeout do
            RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
            Wait(0)
        end
        
        -- Safely drop them onto the ground if slightly high, then unfreeze
        FreezeEntityPosition(playerPed, false)
        SetEntityInvincible(playerPed, false)
    end)
    
    -- Cancel animation when leaving the creator
    ClearPedTasks(playerPed)
    
    -- Sortir de l'instance
    TriggerServerEvent('vanguard_charcreator:server:exitInstance')
    
    cb('ok')
end)

RegisterNUICallback('randomize', function(data, cb)
    -- Implement randomization logic here if needed
    cb('ok')
end)

RegisterNetEvent('vanguard_charcreator:client:finishSuccess', function()
    -- Nothing to do here visually, animation moved to the creator phase
end)

-- Event to trigger from join/spawn system
RegisterNetEvent('vanguard_charcreator:open')
AddEventHandler('vanguard_charcreator:open', function()
    OpenCreator()
end)

-- Auto-open for NEW players ONLY — but defer until the player has clicked
-- "Rejoindre le plateau de jeu" on the loading-screen Join NUI, so the two
-- UIs don't overlap.
local pendingCreatorOpen = false

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer, isNew)
    if isNew then
        pendingCreatorOpen = true
    end
end)

AddEventHandler('vfw:loading:playerClickedJoin', function()
    if pendingCreatorOpen then
        pendingCreatorOpen = false
        OpenCreator()
    end
end)
