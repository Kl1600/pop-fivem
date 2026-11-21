-- Ouverture du magasin (vêtements / barbier / tatoueur), prompt d'entrée, ouverture depuis le créateur.

local activePrompt = nil

local function GetAppearanceCounts()
    local ped = PlayerPedId()
    local counts = { clothing = {}, props = {}, overlays = {} }
    for i = 0, 11 do counts.clothing[tostring(i)] = GetNumberOfPedDrawableVariations(ped, i) end
    for i = 0, 7 do counts.props[tostring(i)] = GetNumberOfPedPropDrawableVariations(ped, i) end
    local overlays = {1, 2, 4, 5, 8, 10}
    for _, id in ipairs(overlays) do counts.overlays[tostring(id)] = GetNumHeadOverlayValues(id) end
    return counts
end

local function OpenShopMenu(shop)
    if not Clothes.inMenu then
        Clothes.purchaseCompleted = false
        Clothes.barberPending = {}
        local ped = PlayerPedId()
        Clothes.currentShop = shop

        Clothes.currentShopType = shop.type
        SetNuiFocus(true, true)

        -- Save Original Skin
        TriggerEvent('skinchanger:getSkin', function(skin)
            Clothes.originalSkin = skin
            if Clothes.currentShopType == 'tattoo' then
                local isFemale = GetEntityModel(ped) == GetHashKey("mp_f_freemode_01")
                local undressed
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
            Clothes.pedRestoreCoords = GetEntityCoords(ped)
            Clothes.pedRestoreHeading = GetEntityHeading(ped)
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
            shopType = Clothes.currentShopType,
            categories = Config.Categories[Clothes.currentShopType],
            counts = counts,
            tattoos = Clothes.currentShopType == 'tattoo' and Clothes.BuildTattooList() or {},
            prices = Config.Prices,
            currentGender = gender,
            isCreator = Clothes.openedFromCreator,
            mode80s = Config.Mode80s,
        })
        Clothes.inMenu = true
        Clothes.camHeading = GetEntityHeading(ped) + 180.0

        if Clothes.currentShopType == 'clothing' then
            Clothes.camRadius, Clothes.camHeight = 2.5, 0.2
        else
            Clothes.camRadius, Clothes.camHeight = 0.8, 0.7
        end

        Clothes.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        Clothes.UpdateCamera()
        SetCamFov(Clothes.cam, (shop.cam and shop.cam.fov) or 45.0)
        SetCamActive(Clothes.cam, true)
        RenderScriptCams(true, false, 0, true, true)

        -- Activer le flou d'arrière-plan avec un thread HiDof dédié (comme dans le charcreator)
        CreateThread(function()
            while Clothes.inMenu and Clothes.cam and DoesCamExist(Clothes.cam) do
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
-- pop_v3dui direct : prompt 3D d'origine (style conservé, hors bridge).
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if not Clothes.inMenu then
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
                        content = { key = "E", label = L('prompt_open', string.upper(closestShop.name)), icon = "fas fa-shopping-cart" }
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

RegisterNetEvent('clothes:openFromCreator')
AddEventHandler('clothes:openFromCreator', function()
    Clothes.openedFromCreator = true
    local fakeShop = {
        name = "Créateur",
        type = "clothing"
    }
    OpenShopMenu(fakeShop)
end)

RegisterNetEvent('tattoos:openFromCreator')
AddEventHandler('tattoos:openFromCreator', function()
    Clothes.openedFromCreator = true
    TriggerServerEvent('pop_clothes:server:setCreatorMode', true)
    local fakeShop = {
        name = "Créateur",
        type = "tattoo"
    }
    OpenShopMenu(fakeShop)
end)
