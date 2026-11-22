-- Réglages d'apparence envoyés par la NUI (skinchanger), passage vêtements / tatouages.

local SkinData = {} -- luacheck: ignore 241 (suivi d'origine, gardé tel quel)

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

RegisterNUICallback('updateAppearance', function(data, cb)
    local val = tonumber(data.value)
    if val == nil then val = data.value end

    SkinData[data.id] = val

    if data.id == 'height' then
        local h = val or 2
        local heightVal

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
        CharCreator.ApplyCreatorPose(PlayerPedId())
    end)

    cb('ok')
end)

RegisterNUICallback('updateModel', function(data, cb)
    -- Seuls les modèles freemode sont acceptés (le serveur refuse les autres à la sauvegarde)
    if data.model ~= 'mp_m_freemode_01' and data.model ~= 'mp_f_freemode_01' then
        return cb('error')
    end
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

RegisterNUICallback('randomize', function(data, cb)
    -- Implement randomization logic here if needed
    cb('ok')
end)
