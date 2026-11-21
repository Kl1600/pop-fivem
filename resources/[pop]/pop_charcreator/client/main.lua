local panel, previewPed, camera
local opening = false
local loadingRevision, autoPending
local generation = 0

local function applyFace(ped, profile)
    SetPedHeadBlendData(ped, profile.mother, profile.father, 0, profile.mother, profile.father, 0,
        profile.blend / 100, profile.skin / 100, 0.0, false)
    SetPedFaceFeature(ped, 0, profile.nose / 100)
    SetPedFaceFeature(ped, 13, profile.jaw / 100)
    SetPedFaceFeature(ped, 15, profile.chin / 100)
    SetPedEyeColor(ped, profile.eyes)
    if profile.hair < GetNumberOfPedDrawableVariations(ped, 2) then SetPedComponentVariation(ped, 2, profile.hair, 0, 0) end
    SetPedHairColor(ped, profile.hairColor, profile.hairColor)
end

local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return end
    RequestModel(hash)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
    if HasModelLoaded(hash) then return hash end
    SetModelAsNoLongerNeeded(hash)
end

local function preview(state, profile)
    local wanted = joaat(profile.model)
    if not previewPed or GetEntityModel(previewPed) ~= wanted then
        local hash = requestModel(profile.model)
        if not hash then return false end
        if panel ~= state then SetModelAsNoLongerNeeded(hash) return false end
        local player = PlayerPedId()
        local position = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.8, 0.0)
        local heading = GetEntityHeading(player) + 180.0
        if previewPed then
            position, heading = GetEntityCoords(previewPed), GetEntityHeading(previewPed)
        end
        local ped = CreatePed(4, hash, position.x, position.y, position.z, heading, false, false)
        SetModelAsNoLongerNeeded(hash)
        if ped == 0 then return false end
        if previewPed then DeleteEntity(previewPed) end
        previewPed = ped
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDefaultComponentVariation(ped)
        if not camera then
            local front = GetOffsetFromEntityInWorldCoords(ped, 0.65, 1.45, 0.76)
            camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(camera, front.x, front.y, front.z)
            PointCamAtCoord(camera, position.x, position.y, position.z + 0.65)
            SetCamFov(camera, 36.0)
            RenderScriptCams(true, false, 0, true, true)
        end
    end
    applyFace(previewPed, profile)
    return true
end

local function close(cancel)
    local state = panel
    panel = nil
    if not state then return end
    if state.focused then
        SetNuiFocus(false, false)
        LocalPlayer.state:set('charcreatorOpen', false, false)
    end
    SendNUIMessage({ action = 'pop_charcreator:panel', show = false })
    if camera then RenderScriptCams(false, false, 0, true, true) DestroyCam(camera, false) camera = nil end
    if previewPed then DeleteEntity(previewPed) previewPed = nil end
    if cancel and not state.saving then Callback.Trigger('pop_charcreator:cancel', function() end, state.token) end
end

local function applyProfile(profile, spawn, revision)
    local clean = CharacterProfile.Appearance(profile)
    if not clean or revision ~= generation or not Bridge.IsLoaded() then return end
    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= joaat(clean.model) then
        local hash = requestModel(clean.model)
        if not hash then return end
        if generation ~= revision or not Bridge.IsLoaded() then SetModelAsNoLongerNeeded(hash) return end
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end
    applyFace(ped, clean)
    for _, point in ipairs(Config.Spawns) do
        if point.id == spawn then
            local position = point.coords
            SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
            SetEntityHeading(ped, position.w)
            break
        end
    end
    TriggerEvent('pop_charcreator:client:applied')
end

local function open(quiet)
    if panel or opening or IsNuiFocused() or not Bridge.IsLoaded() then return end
    opening = true
    local revision = generation
    local result, reason = Callback.Await('pop_charcreator:begin')
    opening = false
    if revision ~= generation or not Bridge.IsLoaded() then return end
    if not result then
        if not quiet then Bridge.Notify(L(reason or 'error'), 'error') end
        return
    end

    local state = { token = result.token }
    panel = state
    local profile = result.profile or CharacterProfile.Default()
    if not preview(state, profile) then
        close(true)
        Bridge.Notify(L('error'), 'error')
        return
    end

    if panel ~= state or IsNuiFocused() then
        if panel == state then close(true) end
        return
    end

    local limits = {}
    for _, model in ipairs(CharacterProfile.Models) do limits[model] = CharacterProfile.Limits(model) end
    state.focused = true
    LocalPlayer.state:set('charcreatorOpen', true, false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'pop_charcreator:panel', show = true, profile = profile, limits = limits,
        birth = result.birth, spawns = result.spawns, defaultSpawn = Config.DefaultSpawn,
    })
    CreateThread(function()
        local deadline = GetGameTimer() + Config.SessionSeconds * 1000
        while panel == state do
            Wait(500)
            if panel == state and (not Bridge.IsLoaded() or IsEntityDead(PlayerPedId()) or GetGameTimer() >= deadline) then
                close(true)
            end
        end
    end)
end

local function load(first)
    if first then autoPending = Config.AutoCreate end
    local revision = generation
    if loadingRevision == revision or panel or not Bridge.IsLoaded() then return end
    loadingRevision = revision
    for _ = 1, 5 do
        local data, reason = Callback.Await('pop_charcreator:load')
        if revision ~= generation or not Bridge.IsLoaded() then break end
        if data then
            if data.profile then
                applyProfile(data.profile, nil, revision)
            elseif autoPending and data.canCreate then
                autoPending = nil
                open(true)
            end
            break
        end
        if reason and reason ~= 'busy' then break end
        Wait(500)
    end
    if loadingRevision == revision then loadingRevision = nil end
end

Bridge.OnPlayerLoaded(function()
    generation = generation + 1
    close(true)
    load(true)
end)
AddEventHandler('playerSpawned', function() CreateThread(function() load(false) end) end)
RegisterNetEvent('pop_charcreator:client:unloaded', function()
    if source ~= 65535 then return end
    generation = generation + 1
    autoPending = nil
    close(false)
end)

RegisterCommand(Config.Command, function()
    CreateThread(function() open(false) end)
end, false)

RegisterNUICallback('pop_charcreator:preview', function(data, cb)
    local state = panel
    if not state or state.saving or state.previewing then return cb(false) end
    local profile = CharacterProfile.Appearance(data)
    if not profile then return cb(false) end
    state.previewing = true
    local ok = preview(state, profile)
    state.previewing = nil
    cb(ok)
end)

RegisterNUICallback('pop_charcreator:rotate', function(data, cb)
    local direction = type(data) == 'table' and data.direction
    if previewPed and (direction == -1 or direction == 1) then
        SetEntityHeading(previewPed, GetEntityHeading(previewPed) + direction * 30.0)
    end
    cb(true)
end)

RegisterNUICallback('pop_charcreator:save', function(data, cb)
    local state = panel
    if not state or state.saving or type(data) ~= 'table' then return cb(false) end
    state.saving = true
    local revision = generation
    local ok, result, spawn = Callback.Await('pop_charcreator:save', state.token, data.profile, data.spawn)
    state.saving = nil
    if not ok then
        if panel == state then
            Bridge.Notify(L(result or 'error'), 'error')
            if result == 'session_expired' then close(false) end
        end
        return cb(false)
    end
    if panel == state then close(false) end
    applyProfile(result, spawn, revision)
    if revision == generation then Bridge.Notify(L('saved'), 'success') end
    cb(true)
end)

Bridge.OnUiClose(function() close(true) end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then close(false) end
end)
