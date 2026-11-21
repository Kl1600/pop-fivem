Config = Config or {}

local cam = nil
local inMenu = false
local activePrompt = nil
local camHeading = 0.0
local camRadius = 2.5
local camHeight = 0.2
local currentShopType = 'clothing'
local currentShop = nil
local pedRestoreCoords = nil
local pedRestoreHeading = nil
local originalSkin = {}
local currentTattoos = {}
local openedFromCreator = false
local purchaseCompleted = false


local function hasFixedCam()
    return currentShop and currentShop.cam and currentShop.cam.coords
end

-- Lit la tenue réellement portée sur le ped (composants + props) sous forme
-- de table compatible skinchanger. Sert à figer dans skinchanger les habits
-- choisis dans le menu du créateur (sinon ils sont écrasés au prochain
-- skinchanger:change, ex. réglage du visage).
local function ReadWornClothes(ped)
    return {
        mask_1   = GetPedDrawableVariation(ped, 1),  mask_2   = GetPedTextureVariation(ped, 1),
        arms     = GetPedDrawableVariation(ped, 3),  arms_2   = GetPedTextureVariation(ped, 3),
        pants_1  = GetPedDrawableVariation(ped, 4),  pants_2  = GetPedTextureVariation(ped, 4),
        bags_1   = GetPedDrawableVariation(ped, 5),  bags_2   = GetPedTextureVariation(ped, 5),
        shoes_1  = GetPedDrawableVariation(ped, 6),  shoes_2  = GetPedTextureVariation(ped, 6),
        chain_1  = GetPedDrawableVariation(ped, 7),  chain_2  = GetPedTextureVariation(ped, 7),
        tshirt_1 = GetPedDrawableVariation(ped, 8),  tshirt_2 = GetPedTextureVariation(ped, 8),
        bproof_1 = GetPedDrawableVariation(ped, 9),  bproof_2 = GetPedTextureVariation(ped, 9),
        decals_1 = GetPedDrawableVariation(ped, 10), decals_2 = GetPedTextureVariation(ped, 10),
        torso_1  = GetPedDrawableVariation(ped, 11), torso_2  = GetPedTextureVariation(ped, 11),
        helmet_1  = GetPedPropIndex(ped, 0), helmet_2  = GetPedPropTextureIndex(ped, 0),
        glasses_1 = GetPedPropIndex(ped, 1), glasses_2 = GetPedPropTextureIndex(ped, 1),
        ears_1    = GetPedPropIndex(ped, 2), ears_2    = GetPedPropTextureIndex(ped, 2),
    }
end

-- Tattoo List (Expanded)
local TattooList = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }

RegisterNetEvent('clothes:setTattooList')
AddEventHandler('clothes:setTattooList', function(rawJson)
    local rawTattoos = json.decode(rawJson)
    if rawTattoos then
        local mapping = {
            ZONE_HEAD = "Head",
            ZONE_TORSO = "Torso",
            ZONE_LEFT_ARM = "LeftArm",
            ZONE_RIGHT_ARM = "RightArm",
            ZONE_LEFT_LEG = "LeftLeg",
            ZONE_RIGHT_LEG = "RightLeg"
        }
        TattooList = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }
        for zoneId, tattoos in pairs(rawTattoos) do
            local mappedZone = mapping[zoneId]
            if mappedZone then
                for _, t in ipairs(tattoos) do
                    table.insert(TattooList[mappedZone], t)
                end
            end
        end
    else
        print("[pop_clothes] Error: Failed to decode tattoo list from server!")
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('clothes:requestTattooList')
end)

local function BuildTattooList()
    local pedModel = GetEntityModel(PlayerPedId())
    local isFemale = pedModel == GetHashKey("mp_f_freemode_01")
    
    local ret = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }
    for zone, tattoos in pairs(TattooList) do
        for i, t in ipairs(tattoos) do
            local hashToUse = isFemale and t.hashFemale or t.hashMale
            if hashToUse and hashToUse ~= "" then
                table.insert(ret[zone], {
                    collection = t.collection,
                    hash = hashToUse,
                    label = t.label or ("Tattoo #" .. i)
                })
            end
        end
    end
    return ret
end

local categoryOffsets = {
    -- Clothes
    Hats            = { z = 0.75, d = 0.9,  fov = 28.0 },
    Masks           = { z = 0.75, d = 0.7,  fov = 28.0 },
    Ears            = { z = 0.75, d = 0.6,  fov = 28.0 },
    Glasses         = { z = 0.75, d = 0.6,  fov = 28.0 },
    Tops            = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Undershirts     = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Torsos          = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Legs            = { z = 0.1,  d = 1.5,  fov = 40.0 },
    Shoes           = { z = -0.6, d = 1.0,  fov = 40.0 },
    Bags            = { z = 0.5,  d = 1.8,  fov = 38.0 },
    Accessories     = { z = 0.6,  d = 1.2,  fov = 35.0 },
    Decals          = { z = 0.5,  d = 1.3,  fov = 35.0 },
    Watches         = { z = 0.6,  d = 1.2,  fov = 35.0 },
    Bracelets       = { z = 0.5,  d = 1.5,  fov = 35.0 },
    ['Body Armors'] = { z = 0.6,  d = 1.2,  fov = 35.0 },
    -- Barber
    Hair            = { z = 0.7,  d = 0.7,  fov = 35.0 },
    Beard           = { z = 0.6,  d = 0.6,  fov = 30.0 },
    Eyebrows        = { z = 0.75, d = 0.5,  fov = 25.0 },
    ChestHair       = { z = 0.4,  d = 1.0,  fov = 40.0 },
    Makeup          = { z = 0.75, d = 0.5,  fov = 25.0 },
    Lipstick        = { z = 0.65, d = 0.5,  fov = 25.0 },
    Blush           = { z = 0.75, d = 0.5,  fov = 25.0 },
    -- Tattoos
    Head            = { z = 0.75, d = 0.7,  fov = 30.0 },
    Torso           = { z = 0.4,  d = 1.2,  fov = 40.0 },
    LeftArm         = { z = 0.4,  d = 1.2,  fov = 40.0 },
    RightArm        = { z = 0.4,  d = 1.2,  fov = 40.0 },
    LeftLeg         = { z = -0.4, d = 1.2,  fov = 40.0 },
    RightLeg        = { z = -0.4, d = 1.2,  fov = 40.0 },
}

local function updateCamera()
    if not cam then return end

    if hasFixedCam() then
        local c = currentShop.cam.coords
        local la = currentShop.cam.lookAt or (currentShop.pedCoords or currentShop.coords)
        SetCamCoord(cam, c.x, c.y, c.z)
        PointCamAtCoord(cam, la.x, la.y, la.z)
    else
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local rad = math.rad(camHeading)
        local x = coords.x + (math.sin(rad) * camRadius)
        local y = coords.y + (math.cos(rad) * camRadius)
        local z = coords.z + camHeight
        SetCamCoord(cam, x, y, z)
        PointCamAtCoord(cam, coords.x, coords.y, coords.z + camHeight)
    end

    -- Activer le flou d'arrière-plan (Depth of Field) de façon plus agressive (comme dans le charcreator)
    SetCamUseShallowDofMode(cam, true)
    SetCamDofFnumberOfLens(cam, 0.0) -- Force un flou maximal optique absolu (f/0.0)
    SetCamDofFocalLengthMultiplier(cam, 10.0) -- Multiplie l'effet optique du flou
    SetCamNearDof(cam, 0.1)
    SetCamFarDof(cam, camRadius + 0.5) -- Le flou commence pile après le personnage
    SetCamDofStrength(cam, 1.0)
end

local function focusOnCategory(category)
    if not cam or not DoesCamExist(cam) then return end
    if hasFixedCam() then return end -- camera locked by shop config
    local offset = categoryOffsets[category] or { z = 0.2, d = 2.5, fov = 45.0 }
    camRadius = offset.d
    camHeight = offset.z
    SetCamFov(cam, offset.fov)
    updateCamera()

    -- Automatically rotate player ped based on category focus in tattoo shops
    if currentShopType == 'tattoo' then
        local ped = PlayerPedId()
        if category == 'Head' then
            SetEntityHeading(ped, camHeading - 180.0) -- front
        elseif category == 'Torso' then
            SetEntityHeading(ped, camHeading - 180.0) -- front default (chest)
        elseif category == 'LeftArm' then
            SetEntityHeading(ped, camHeading - 90.0)  -- left arm facing camera
        elseif category == 'RightArm' then
            SetEntityHeading(ped, camHeading - 270.0) -- right arm facing camera
        elseif category == 'LeftLeg' then
            SetEntityHeading(ped, camHeading - 90.0)  -- left leg facing camera
        elseif category == 'RightLeg' then
            SetEntityHeading(ped, camHeading - 270.0) -- right leg facing camera
        end
    end
end

local function GetAppearanceCounts()
    local ped = PlayerPedId()
    local counts = { clothing = {}, props = {}, overlays = {} }
    for i = 0, 11 do counts.clothing[tostring(i)] = GetNumberOfPedDrawableVariations(ped, i) end
    for i = 0, 7 do counts.props[tostring(i)] = GetNumberOfPedPropDrawableVariations(ped, i) end
    local overlays = {1, 2, 4, 5, 8, 10}
    for _, id in ipairs(overlays) do counts.overlays[tostring(id)] = GetNumHeadOverlayValues(id) end
    return counts
end

-- Choix du barbier en attente d'achat : reportés dans skinchanger à l'achat
-- (les natives seules ne mettent pas à jour le skin sauvegardé : coupe perdue).
local barberPending = {}

-- composant d'overlay -> clés skinchanger (index, opacité, couleur)
local OVERLAY_KEYS = {
    [1] = { 'beard_1', 'beard_2', 'beard_3' },
    [2] = { 'eyebrows_1', 'eyebrows_2', 'eyebrows_3' },
    [4] = { 'makeup_1', 'makeup_2', 'makeup_3' },
    [5] = { 'blush_1', 'blush_2', 'blush_3' },
    [8] = { 'lipstick_1', 'lipstick_2', 'lipstick_3' },
    [10] = { 'chest_1', 'chest_2', 'chest_3' },
}

local function commitBarberToSkin()
    for _, sel in pairs(barberPending) do
        if sel.kind == 'clothing' and sel.component == 2 then
            TriggerEvent('skinchanger:change', 'hair_1', sel.index == -1 and 0 or sel.index)
            TriggerEvent('skinchanger:change', 'hair_2', sel.texture)
            TriggerEvent('skinchanger:change', 'hair_color_1', sel.texture)
            TriggerEvent('skinchanger:change', 'hair_color_2', sel.texture)
        elseif sel.kind == 'overlay' and OVERLAY_KEYS[sel.component] then
            local k = OVERLAY_KEYS[sel.component]
            if sel.index == -1 then
                TriggerEvent('skinchanger:change', k[1], 0)
                TriggerEvent('skinchanger:change', k[2], 0)
            else
                TriggerEvent('skinchanger:change', k[1], sel.index)
                TriggerEvent('skinchanger:change', k[2], 10)
                TriggerEvent('skinchanger:change', k[3], sel.texture)
            end
        end
    end
    barberPending = {}
    -- skinchanger réapplique tout le skin (« nu ») : on remet la tenue de l'inventaire.
    if GetResourceState('pop_inventory') == 'started' then
        pcall(function() exports.pop_inventory:RefreshEquipment() end)
    end
end

local function OpenShopMenu(shop)
    if not inMenu then
        purchaseCompleted = false
        barberPending = {}
        local ped = PlayerPedId()
        currentShop = shop

        currentShopType = shop.type
        SetNuiFocus(true, true)

        -- Save Original Skin
        TriggerEvent('skinchanger:getSkin', function(skin)
            originalSkin = skin
            if currentShopType == 'tattoo' then
                local isFemale = GetEntityModel(ped) == GetHashKey("mp_f_freemode_01")
                local undressed = {}
                if isFemale then
                    undressed = {
                        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
                        ['torso_1'] = 15, ['torso_2'] = 0,
                        ['arms'] = 15, ['arms_2'] = 0,
                        ['pants_1'] = 15, ['pants_2'] = 0,
                        ['shoes_1'] = 35, ['shoes_2'] = 0,
                        ['bproof_1'] = 0, ['bproof_2'] = 0,
                        ['chain_1'] = 0, ['chain_2'] = 0,
                        ['bags_1'] = 0, ['bags_2'] = 0,
                        ['helmet_1'] = -1, ['helmet_2'] = 0,
                        ['glasses_1'] = -1, ['glasses_2'] = 0
                    }
                else
                    undressed = {
                        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
                        ['torso_1'] = 15, ['torso_2'] = 0,
                        ['arms'] = 15, ['arms_2'] = 0,
                        ['pants_1'] = 61, ['pants_2'] = 0,
                        ['shoes_1'] = 34, ['shoes_2'] = 0,
                        ['bproof_1'] = 0, ['bproof_2'] = 0,
                        ['chain_1'] = 0, ['chain_2'] = 0,
                        ['bags_1'] = 0, ['bags_2'] = 0,
                        ['helmet_1'] = -1, ['helmet_2'] = 0,
                        ['glasses_1'] = -1, ['glasses_2'] = 0
                    }
                end
                TriggerEvent('skinchanger:loadClothes', skin, undressed)
            end
        end)

        -- Lock ped position / heading if the shop has a predefined cam frame
        if shop.pedCoords then
            pedRestoreCoords = GetEntityCoords(ped)
            pedRestoreHeading = GetEntityHeading(ped)
            RequestCollisionAtCoord(shop.pedCoords.x, shop.pedCoords.y, shop.pedCoords.z)
            SetEntityCoordsNoOffset(ped, shop.pedCoords.x, shop.pedCoords.y, shop.pedCoords.z, false, false, false)
            FreezeEntityPosition(ped, true)
        end
        if shop.pedHeading then
            SetEntityHeading(ped, shop.pedHeading)
        end

        local counts = GetAppearanceCounts()
        local gender = GetEntityModel(ped) == GetHashKey("mp_f_freemode_01") and 'female' or 'male'

        SendNUIMessage({
            action = 'open',
            shopType = currentShopType,
            categories = Config.Categories[currentShopType],
            counts = counts,
            tattoos = currentShopType == 'tattoo' and BuildTattooList() or {},
            prices = Config.Prices,
            currentGender = gender,
            isCreator = openedFromCreator,
            mode80s = Config.Mode80s,
        })
        inMenu = true
        camHeading = GetEntityHeading(ped) + 180.0

        if currentShopType == 'clothing' then
            camRadius, camHeight = 2.5, 0.2
        else
            camRadius, camHeight = 0.8, 0.7
        end

        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        updateCamera()
        SetCamFov(cam, (shop.cam and shop.cam.fov) or 45.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)

        -- Activer le flou d'arrière-plan avec un thread HiDof dédié (comme dans le charcreator)
        CreateThread(function()
            while inMenu and cam and DoesCamExist(cam) do
                SetUseHiDof()
                Wait(0)
            end
        end)

        if activePrompt then exports['pop_v3dui']:Remove(activePrompt); activePrompt = nil end
    end
end

-- NOTE: les blips des shops (vêtements / barbier / tatoueur) sont
-- entièrement définis dans pop_management/config.lua (Config.Blips).
-- Aucun blip n'est créé ici.
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if not inMenu then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local closestDist, closestShop = 5.0, nil
            for _, shop in ipairs(Config.Shops) do
                local dist = #(pCoords - shop.coords)
                if dist < closestDist then closestDist, closestShop = dist, shop end
            end

            if closestShop and closestDist < 2.5 then
                sleep = 0
                if not activePrompt then
                    activePrompt = exports['pop_v3dui']:Create({
                        coords = closestShop.coords + vector3(0, 0, 1.0),
                        type = "prompt",
                        content = { key = "E", label = "OUVRIR "..string.upper(closestShop.name), icon = "fas fa-shopping-cart" }
                    })
                end
                if IsControlJustPressed(0, 38) then OpenShopMenu(closestShop) end
            else
                if activePrompt then exports['pop_v3dui']:Remove(activePrompt); activePrompt = nil end
            end
        end
        Citizen.Wait(sleep)
    end
end)

local previewBackup = nil

local function captureBackup(ped, kind, component)
    if previewBackup then return end
    if kind == 'clothing' then
        previewBackup = {
            kind = 'clothing',
            component = component,
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
        }
    elseif kind == 'prop' then
        previewBackup = {
            kind = 'prop',
            component = component,
            drawable = GetPedPropIndex(ped, component),
            texture = GetPedPropTextureIndex(ped, component),
        }
    elseif kind == 'overlay' then
        local _, idx, _, primary, secondary = GetPedHeadOverlayData(ped, component)
        previewBackup = {
            kind = 'overlay',
            component = component,
            index = idx or 0,
            primary = primary or 0,
            secondary = secondary or 0,
        }
    elseif kind == 'tattoo' then
        previewBackup = {
            kind = 'tattoo'
        }
    end
end

local function applyBackup(ped)
    if not previewBackup then return end
    local b = previewBackup
    if b.kind == 'clothing' then
        SetPedComponentVariation(ped, b.component, b.drawable, b.texture, 0)
    elseif b.kind == 'prop' then
        if b.drawable == -1 then
            ClearPedProp(ped, b.component)
        else
            SetPedPropIndex(ped, b.component, b.drawable, b.texture, true)
        end
    elseif b.kind == 'overlay' then
        SetPedHeadOverlay(ped, b.component, b.index, 1.0)
        local colorType = (b.component == 1 or b.component == 2 or b.component == 10) and 1 or 2
        SetPedHeadOverlayColor(ped, b.component, colorType, b.primary, b.secondary)
    elseif b.kind == 'tattoo' then
        ClearPedDecorations(ped)
        for _, tat in ipairs(currentTattoos) do
            local col = type(tat.collection) == 'string' and GetHashKey(tat.collection) or tat.collection
            local hsh = type(tat.hash) == 'string' and GetHashKey(tat.hash) or tat.hash
            AddPedDecorationFromHashes(ped, col, hsh)
        end
    end
    previewBackup = nil
end

RegisterNUICallback('change', function(data, cb)
    local ped = PlayerPedId()
    local kind, component, index, texture = data.type, tonumber(data.component), tonumber(data.index), tonumber(data.texture) or 0
    local isPreview = data.isPreview == true

    if isPreview then
        captureBackup(ped, kind, component)
    else
        previewBackup = nil
        if currentShopType == 'barber' and component and index then
            barberPending[kind .. ':' .. component] = { kind = kind, component = component, index = index, texture = texture }
        end
    end

    if kind == 'clothing' then
        if index == -1 then
            local emptyVal = 0
            if component == 3 or component == 8 or component == 11 then
                emptyVal = 15
            end
            SetPedComponentVariation(ped, component, emptyVal, 0, 0)
        else
            SetPedComponentVariation(ped, component, index, texture, 0)
            if component == 2 then SetPedHairColor(ped, texture, texture) end
        end
    elseif kind == 'prop' then
        if index == -1 then ClearPedProp(ped, component) else SetPedPropIndex(ped, component, index, texture, true) end
    elseif kind == 'overlay' then
        if index == -1 then
            SetPedHeadOverlay(ped, component, 255, 1.0)
        else
            SetPedHeadOverlay(ped, component, index, 1.0)
            local colorType = (component == 1 or component == 2 or component == 10) and 1 or 2
            SetPedHeadOverlayColor(ped, component, colorType, texture, texture)
        end
    elseif kind == 'tattoo' then
        ClearPedDecorations(ped)
        for _, tat in ipairs(currentTattoos) do
            local col = type(tat.collection) == 'string' and GetHashKey(tat.collection) or tat.collection
            local hsh = type(tat.hash) == 'string' and GetHashKey(tat.hash) or tat.hash
            AddPedDecorationFromHashes(ped, col, hsh)
        end
        local newCol = type(data.collection) == 'string' and GetHashKey(data.collection) or data.collection
        local newHsh = type(data.hash) == 'string' and GetHashKey(data.hash) or data.hash
        AddPedDecorationFromHashes(ped, newCol, newHsh)

        -- If previewing Torso tattoo, check if it's a back tattoo and rotate player ped automatically
        if data.category == 'Torso' and data.label then
            local labelLower = string.lower(data.label)
            if string.find(labelLower, "back") or string.find(labelLower, "dos") or string.find(labelLower, "derriere") then
                SetEntityHeading(ped, camHeading) -- Show back
            else
                SetEntityHeading(ped, camHeading - 180.0) -- Show chest
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('endPreview', function(data, cb)
    applyBackup(PlayerPedId())
    cb('ok')
end)

RegisterNUICallback('revert', function(data, cb)
    TriggerEvent('skinchanger:loadSkin', originalSkin)
    cb('ok')
end)

RegisterNUICallback('switchCategory', function(data, cb)
    focusOnCategory(data.category)
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('clothes:buy_all', data)
    cb('ok')
end)

RegisterNetEvent('clothes:purchaseSuccess')
AddEventHandler('clothes:purchaseSuccess', function(shopType)
    purchaseCompleted = true
    if shopType == 'barber' then
        commitBarberToSkin()
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerServerEvent('esx_skin:save', skin)
            originalSkin = skin
        end)
    elseif shopType == 'tattoo' then
        local ped = PlayerPedId()
        for _, sel in pairs(currentTattoos) do
            -- currentTattoos already contains the preview applied, keep them on ped
        end
        -- Refresh applied tattoos from server (canonical state)
        TriggerServerEvent('clothes:requestTattoos')
    end
    SendNUIMessage({
        action = 'close'
    })
end)

RegisterNetEvent('clothes:applyTattoos')
AddEventHandler('clothes:applyTattoos', function(tattoos)
    local ped = PlayerPedId()
    ClearPedDecorations(ped)
    currentTattoos = {}
    for _, t in ipairs(tattoos or {}) do
        if t.collection and t.hash then
            local col = type(t.collection) == 'string' and GetHashKey(t.collection) or t.collection
            local hsh = type(t.hash) == 'string' and GetHashKey(t.hash) or t.hash
            AddPedDecorationFromHashes(ped, col, hsh)
            currentTattoos[#currentTattoos + 1] = t
        end
    end
end)

AddEventHandler('playerSpawned', function()
    Citizen.SetTimeout(2000, function()
        TriggerServerEvent('clothes:requestTattoos')
    end)
end)

RegisterNetEvent('clothes:openFromCreator')
AddEventHandler('clothes:openFromCreator', function()
    openedFromCreator = true
    local fakeShop = {
        name = "Créateur",
        type = "clothing"
    }
    OpenShopMenu(fakeShop)
end)

RegisterNetEvent('tattoos:openFromCreator')
AddEventHandler('tattoos:openFromCreator', function()
    openedFromCreator = true
    TriggerServerEvent('pop_clothes:server:setCreatorMode', true)
    local fakeShop = {
        name = "Créateur",
        type = "tattoo"
    }
    OpenShopMenu(fakeShop)
end)

AddEventHandler('esx:playerLoaded', function()
    Citizen.SetTimeout(3000, function()
        TriggerServerEvent('clothes:requestTattoos')
    end)
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    inMenu = false
    previewBackup = nil

    local ped = PlayerPedId()

    -- Menu vêtements ouvert depuis le créateur : on FIGE la tenue choisie dans
    -- skinchanger pour qu'elle survive aux prochains skinchanger:change (réglages
    -- visage/cheveux). Pas de RefreshEquipment ici : il forcerait la tenue
    -- pré-configurée (Config.Nude), qui ne doit s'appliquer que sur un perso nu.
    local clothingCreator = openedFromCreator and currentShopType == 'clothing'

    if clothingCreator then
        local worn = ReadWornClothes(ped)
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerEvent('skinchanger:loadClothes', skin, worn)
        end)
    elseif not purchaseCompleted then
        TriggerEvent('skinchanger:loadSkin', originalSkin)
    end

    if pedRestoreCoords then
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, pedRestoreCoords.x, pedRestoreCoords.y, pedRestoreCoords.z, false, false, false)
        if pedRestoreHeading then SetEntityHeading(ped, pedRestoreHeading) end
        pedRestoreCoords = nil
        pedRestoreHeading = nil
    end
    currentShop = nil

    -- Hors mode créateur-vêtements : on restaure tatouages + tenue d'inventaire.
    if not clothingCreator then
        Citizen.SetTimeout(1000, function()
            exports['pop_inventory']:RefreshEquipment()
            TriggerServerEvent('clothes:requestTattoos')
        end)
    else
        Citizen.SetTimeout(1000, function()
            TriggerServerEvent('clothes:requestTattoos')
        end)
    end

    if cam then RenderScriptCams(false, false, 0, true, true); DestroyCam(cam, false); cam = nil end

    if openedFromCreator then
        openedFromCreator = false
        TriggerServerEvent('pop_clothes:server:setCreatorMode', false)
        TriggerEvent('vanguard_charcreator:reopen')
    end
    purchaseCompleted = false
    cb('ok')
end)

RegisterNUICallback('requestTextures', function(data, cb)
    local ped = PlayerPedId()
    local count = data.type == 'clothing' and GetNumberOfPedTextureVariations(ped, tonumber(data.component), tonumber(data.index)) or GetNumberOfPedPropTextureVariations(ped, tonumber(data.component), tonumber(data.index))
    cb({count = count})
end)

RegisterNUICallback('rotate', function(data, cb)
    local ped = PlayerPedId()
    if data.deltaX then SetEntityHeading(ped, GetEntityHeading(ped) + (data.deltaX * 0.5)) end
    if data.deltaY and not hasFixedCam() then
        camHeight = camHeight + (data.deltaY * 0.005)
        camHeight = math.max(-0.8, math.min(1.2, camHeight))
        updateCamera()
    end
    cb('ok')
end)

RegisterNUICallback('zoom', function(data, cb)
    if hasFixedCam() then cb('ok') return end
    camRadius = camRadius + (data.delta > 0 and 0.1 or -0.1)
    camRadius = math.max(0.4, math.min(4.0, camRadius))
    updateCamera()
    cb('ok')
end)
