local spawnedEntities = {}

local function SpawnPreview()
    -- Table of peds/props to spawn
    local pedsToSpawn = {
        -- Ped with box (boite en carton)
        {
            model = "s_m_m_postal_01",
            coords = vector4(1176.8125, -3310.5674, 6.0288 - 1.0, 160.5903),
            animDict = "anim@heists@box_carry@",
            animName = "idle",
            prop = "hei_prop_heist_box",
            boneIndex = 60309,
            propPlacement = {0.025, 0.08, 0.255, -145.0, 290.0, 0.0}
        },
        -- Ped with charriot (trolley 4 / pallet 4)
        {
            model = "s_m_m_postal_01",
            coords = vector4(1180.2562, -3310.1536, 6.0288 - 1.0, 68.8752),
            animDict = "anim@mp_ferris_wheel",
            animName = "idle_a_player_two",
            prop = "prop_flattruck_01c",
            boneIndex = -1,
            propPlacement = {0.0, 1.3, -0.97, 0.0, 0.0, 180.0}
        },
        -- Ped with notepad
        {
            model = "s_m_m_postal_01",
            coords = vector4(1175.5317, -3309.2703, 5.9170 - 1.0, 71.1752),
            animDict = "missheistdockssetup1clipboard@base",
            animName = "base",
            prop = "prop_notepad_01",
            boneIndex = 18905,
            propPlacement = {0.1, 0.02, 0.05, 10.0, 0.0, 0.0},
            extraProp = "prop_pencil_01",
            extraBoneIndex = 58866,
            extraPropPlacement = {0.11, -0.02, 0.001, -120.0, 0.0, 0.0}
        },
        -- SCENE 2: Quickie Pharm Peds
        -- Inspecter 2
        {
            model = "s_m_m_postal_01",
            coords = vector4(358.5620, -608.4681, 28.6855 - 1.0, 223.5900),
            animDict = "anim@amb@carmeet@checkout_engine@",
            animName = "female_c_idle_d"
        },
        -- Attendre
        {
            model = "s_m_m_postal_01",
            coords = vector4(360.2576, -607.1755, 28.6857 - 1.0, 276.8391),
            animDict = "random@shop_tattoo",
            animName = "_idle_a"
        },
        -- Briefcase Ped
        {
            model = "s_m_m_postal_01",
            coords = vector4(359.9845, -605.8492, 28.6747 - 1.0, 266.2759),
            weapon = "WEAPON_BRIEFCASE_03"
        }
    }

    -- 1. Boxville4
    local model1 = GetHashKey("boxville4")
    RequestModel(model1)
    while not HasModelLoaded(model1) do Wait(10) end
    local veh1 = CreateVehicle(model1, 1178.5614, -3307.3799, 5.9486, 89.2651, false, false)
    SetEntityAsMissionEntity(veh1, true, true)
    FreezeEntityPosition(veh1, true)
    table.insert(spawnedEntities, veh1)

    -- 2. Rumpo (open back left door)
    local model2 = GetHashKey("rumpo")
    RequestModel(model2)
    while not HasModelLoaded(model2) do Wait(10) end
    local veh2 = CreateVehicle(model2, 1177.3879, -3314.0940, 6.0510, 203.1342, false, false)
    SetEntityAsMissionEntity(veh2, true, true)
    FreezeEntityPosition(veh2, true)
    SetVehicleDoorOpen(veh2, 2, false, false) -- open back left door
    table.insert(spawnedEntities, veh2)

    -- SCENE 2: Quickie Pharm Vehicles
    local model3 = GetHashKey("sentinel5")
    RequestModel(model3)
    local maxWait = GetGameTimer() + 5000
    while not HasModelLoaded(model3) and GetGameTimer() < maxWait do Wait(10) end

    if HasModelLoaded(model3) then
        -- Vehicle 1: Sentinel5 (trunk open)
        local veh3 = CreateVehicle(model3, 360.4900, -610.6686, 28.2080, 213.5158, false, false)
        SetEntityAsMissionEntity(veh3, true, true)
        FreezeEntityPosition(veh3, true)
        SetVehicleColours(veh3, 54, 11) -- Petrol Green Metallic (54) with Anthracite secondary (11)
        SetVehicleExtraColours(veh3, 0, 54) -- Force Black pearlescent, Wheels match primary color (54)
        SetVehicleInteriorColour(veh3, 11) -- Anthracite Interior
        SetVehicleDashboardColour(veh3, 11) -- Anthracite Trim
        SetVehicleModKit(veh3, 0)
        SetVehicleMod(veh3, 48, 10, false) -- Livery 10 (Quickie Pharm)
        SetVehicleLivery(veh3, 10)
        SetVehicleDoorOpen(veh3, 5, false, false) -- Trunk open
        table.insert(spawnedEntities, veh3)

        -- Vehicle 2: Sentinel5 (right back door open)
        local veh4 = CreateVehicle(model3, 357.9776, -605.2109, 28.1367, 17.8637, false, false)
        SetEntityAsMissionEntity(veh4, true, true)
        FreezeEntityPosition(veh4, true)
        SetVehicleColours(veh4, 111, 11) -- Ice White Classic (111) with Anthracite secondary (11)
        SetVehicleExtraColours(veh4, 111, 111) -- Ice White pearlescent, Wheels match primary color (111)
        SetVehicleInteriorColour(veh4, 11) -- Anthracite Interior
        SetVehicleDashboardColour(veh4, 11) -- Anthracite Trim
        SetVehicleModKit(veh4, 0)
        SetVehicleMod(veh4, 48, 10, false) -- Livery 10 (Quickie Pharm)
        SetVehicleLivery(veh4, 10)
        SetVehicleDoorOpen(veh4, 3, false, false) -- Right back door open
        table.insert(spawnedEntities, veh4)
    end

    -- Removed standalone briefcase object
    -- 3. Spawn Peds
    for _, data in ipairs(pedsToSpawn) do
        local pedModel = GetHashKey(data.model)
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do Wait(10) end

        local ped = CreatePed(4, pedModel, data.coords.x, data.coords.y, data.coords.z, data.coords.w, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)

        if data.weapon then
            local wepHash = GetHashKey(data.weapon)
            GiveWeaponToPed(ped, wepHash, 1, false, true)
            SetCurrentPedWeapon(ped, wepHash, true)
        end

        if data.animDict and data.animName then
            RequestAnimDict(data.animDict)
            while not HasAnimDictLoaded(data.animDict) do Wait(10) end
            TaskPlayAnim(ped, data.animDict, data.animName, 8.0, 8.0, -1, 49, 0, false, false, false)
        end

        if data.prop then
            local propModel = GetHashKey(data.prop)
            RequestModel(propModel)
            while not HasModelLoaded(propModel) do Wait(10) end
            local propObj = CreateObject(propModel, 0, 0, 0, false, false, false)
            AttachEntityToEntity(propObj, ped, GetPedBoneIndex(ped, data.boneIndex), data.propPlacement[1], data.propPlacement[2], data.propPlacement[3], data.propPlacement[4], data.propPlacement[5], data.propPlacement[6], true, true, false, true, 1, true)
            table.insert(spawnedEntities, propObj)
        end

        if data.extraProp then
            local extraModel = GetHashKey(data.extraProp)
            RequestModel(extraModel)
            while not HasModelLoaded(extraModel) do Wait(10) end
            local extraObj = CreateObject(extraModel, 0, 0, 0, false, false, false)
            AttachEntityToEntity(extraObj, ped, GetPedBoneIndex(ped, data.extraBoneIndex), data.extraPropPlacement[1], data.extraPropPlacement[2], data.extraPropPlacement[3], data.extraPropPlacement[4], data.extraPropPlacement[5], data.extraPropPlacement[6], true, true, false, true, 1, true)
            table.insert(spawnedEntities, extraObj)
        end

        table.insert(spawnedEntities, ped)
    end
end

local function DeletePreview()
    for _, entity in ipairs(spawnedEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    spawnedEntities = {}
end

-- Command to toggle the preview
RegisterCommand("previewlivraison", function()
    if #spawnedEntities > 0 then
        DeletePreview()
    else
        SpawnPreview()
    end
end, false)

-- Clean up on resource restart/stop
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeletePreview()
    end
end)
