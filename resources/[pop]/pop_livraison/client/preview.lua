-- Preview livraison : création et suppression de la scène (véhicules et peds de Config).

Livraison = {}

local spawnedEntities = {}

-- Chargements avec délai max : pas de boucle infinie si un modèle / une anim manque
local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + Config.LoadTimeout
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function loadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + Config.LoadTimeout
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function spawnVehicle(data)
    local model = GetHashKey(data.model)
    if not loadModel(model) then
        if Config.Debug then print(('[pop_livraison] modèle introuvable : %s'):format(data.model)) end
        return
    end

    local c = data.coords
    local veh = CreateVehicle(model, c.x, c.y, c.z, c.w, false, false)
    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    if data.colours then SetVehicleColours(veh, data.colours[1], data.colours[2]) end
    if data.extraColours then SetVehicleExtraColours(veh, data.extraColours[1], data.extraColours[2]) end
    if data.interior then SetVehicleInteriorColour(veh, data.interior) end
    if data.dashboard then SetVehicleDashboardColour(veh, data.dashboard) end
    if data.livery then
        SetVehicleModKit(veh, 0)
        SetVehicleMod(veh, 48, data.livery, false)
        SetVehicleLivery(veh, data.livery)
    end
    if data.door then SetVehicleDoorOpen(veh, data.door, false, false) end
    SetModelAsNoLongerNeeded(model)
    table.insert(spawnedEntities, veh)
end

local function attachProp(ped, propName, boneIndex, p)
    if not loadModel(GetHashKey(propName)) then return end
    local propObj = CreateObject(GetHashKey(propName), 0, 0, 0, false, false, false)
    AttachEntityToEntity(propObj, ped, GetPedBoneIndex(ped, boneIndex), p[1], p[2], p[3], p[4], p[5], p[6], true, true, false, true, 1, true)
    table.insert(spawnedEntities, propObj)
end

local function spawnPed(data)
    local pedModel = GetHashKey(data.model)
    if not loadModel(pedModel) then return end

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
        if loadAnimDict(data.animDict) then
            TaskPlayAnim(ped, data.animDict, data.animName, 8.0, 8.0, -1, 49, 0, false, false, false)
            RemoveAnimDict(data.animDict)
        end
    end

    if data.prop then attachProp(ped, data.prop, data.boneIndex, data.propPlacement) end
    if data.extraProp then attachProp(ped, data.extraProp, data.extraBoneIndex, data.extraPropPlacement) end

    table.insert(spawnedEntities, ped)
end

function Livraison.IsSpawned()
    return #spawnedEntities > 0
end

function Livraison.SpawnPreview()
    for _, data in ipairs(Config.Vehicles) do spawnVehicle(data) end
    for _, data in ipairs(Config.Peds) do spawnPed(data) end
    if Config.Debug then print(('[pop_livraison] preview créée : %d entités'):format(#spawnedEntities)) end
end

function Livraison.DeletePreview()
    for _, entity in ipairs(spawnedEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    spawnedEntities = {}
end
