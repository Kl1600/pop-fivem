-- Callbacks NUI : aperçu, achat, fermeture, caméra.

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
        for _, tat in ipairs(Clothes.currentTattoos) do
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
        if Clothes.currentShopType == 'barber' and component and index then
            Clothes.barberPending[kind .. ':' .. component] = { kind = kind, component = component, index = index, texture = texture }
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
        for _, tat in ipairs(Clothes.currentTattoos) do
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
                SetEntityHeading(ped, Clothes.camHeading) -- Show back
            else
                SetEntityHeading(ped, Clothes.camHeading - 180.0) -- Show chest
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
    TriggerEvent('skinchanger:loadSkin', Clothes.originalSkin)
    cb('ok')
end)

RegisterNUICallback('switchCategory', function(data, cb)
    Clothes.FocusOnCategory(data.category)
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('clothes:buy_all', data)
    cb('ok')
end)

RegisterNetEvent('clothes:purchaseSuccess')
AddEventHandler('clothes:purchaseSuccess', function(shopType)
    Clothes.purchaseCompleted = true
    if shopType == 'barber' then
        Clothes.CommitBarberToSkin()
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerServerEvent('esx_skin:save', skin)
            Clothes.originalSkin = skin
        end)
    elseif shopType == 'tattoo' then
        -- currentTattoos already contains the preview applied, keep them on ped
        -- Refresh applied tattoos from server (canonical state)
        TriggerServerEvent('clothes:requestTattoos')
    end
    SendNUIMessage({
        action = 'close'
    })
end)

-- NOTE: bridge/client.lua enregistre aussi un callback 'close' (SetNuiFocus(false, false)) :
-- les deux s'exécutent, celui-ci garde toute la logique de fermeture d'origine.
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    Clothes.inMenu = false
    previewBackup = nil

    local ped = PlayerPedId()

    -- Menu vêtements ouvert depuis le créateur : on FIGE la tenue choisie dans
    -- skinchanger pour qu'elle survive aux prochains skinchanger:change (réglages
    -- visage/cheveux). Pas de RefreshEquipment ici : il forcerait la tenue
    -- pré-configurée (Config.Nude), qui ne doit s'appliquer que sur un perso nu.
    local clothingCreator = Clothes.openedFromCreator and Clothes.currentShopType == 'clothing'

    if clothingCreator then
        local worn = Clothes.ReadWornClothes(ped)
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerEvent('skinchanger:loadClothes', skin, worn)
        end)
    elseif not Clothes.purchaseCompleted then
        TriggerEvent('skinchanger:loadSkin', Clothes.originalSkin)
    end

    if Clothes.pedRestoreCoords then
        local c = Clothes.pedRestoreCoords
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
        if Clothes.pedRestoreHeading then SetEntityHeading(ped, Clothes.pedRestoreHeading) end
        Clothes.pedRestoreCoords = nil
        Clothes.pedRestoreHeading = nil
    end
    Clothes.currentShop = nil

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

    if Clothes.cam then
        RenderScriptCams(false, false, 0, true, true); DestroyCam(Clothes.cam, false); Clothes.cam = nil
    end

    if Clothes.openedFromCreator then
        Clothes.openedFromCreator = false
        TriggerServerEvent('pop_clothes:server:setCreatorMode', false)
        TriggerEvent('pop_charcreator:reopen')
    end
    Clothes.purchaseCompleted = false
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
    if data.deltaY and not Clothes.HasFixedCam() then
        Clothes.camHeight = Clothes.camHeight + (data.deltaY * 0.005)
        Clothes.camHeight = math.max(-0.8, math.min(1.2, Clothes.camHeight))
        Clothes.UpdateCamera()
    end
    cb('ok')
end)

RegisterNUICallback('zoom', function(data, cb)
    if Clothes.HasFixedCam() then cb('ok') return end
    Clothes.camRadius = Clothes.camRadius + (data.delta > 0 and 0.1 or -0.1)
    Clothes.camRadius = math.max(0.4, math.min(4.0, Clothes.camRadius))
    Clothes.UpdateCamera()
    cb('ok')
end)
