-- pop_weed client : mode placement (aperçu local, validation locale, envoi au serveur).
-- Wait(0) uniquement pendant le placement (30 s max).

local RES = GetCurrentResourceName()

local MAX_TIME = 30000        -- ms avant annulation automatique
local MAX_GROUND_GAP = 1.5    -- écart max (m) entre le sol du joueur et celui de l'aperçu
local ALPHA_VALID, ALPHA_INVALID = 150, 60
local ANIM = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }

local placing = false
local preview = nil

local function deletePreview()
    if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
    preview = nil
end

local function sendPanel(valid, reason)
    SendNUIMessage({
        action = 'pop_weed:placement', show = true, valid = valid, reason = reason,
        confirmKey = Config.Keys.Interact.label, cancelKey = Config.Keys.Cancel.label,
    })
end

local function closePanel()
    SendNUIMessage({ action = 'pop_weed:placement', show = false })
end

-- Renvoie z du sol si l'emplacement est valide, sinon nil + raison (clé de locale).
local function checkSpot(ped, pos, x, y)
    if IsPedInAnyVehicle(ped, false) then return nil, 'in_vehicle' end
    if IsEntityInWater(ped) or IsPedSwimming(ped) then return nil, 'cannot_plant_here' end

    local found, groundZ = GetGroundZFor_3dCoord(x, y, pos.z + 1.0, false)
    if not found then return nil, 'cannot_plant_here' end

    local feetZ = pos.z - GetEntityHeightAboveGround(ped)
    if math.abs(feetZ - groundZ) > MAX_GROUND_GAP then return groundZ, 'cannot_plant_here' end

    local hasWater, waterZ = GetWaterHeight(x, y, groundZ + 1.0)
    if hasWater and waterZ > groundZ then return groundZ, 'cannot_plant_here' end

    local minSpacing = Config.MinSpacing
    for _, p in pairs(WeedPlants) do
        local dx, dy, dz = x - p.x, y - p.y, groundZ - p.z
        if dx * dx + dy * dy + dz * dz < minSpacing * minSpacing then return groundZ, 'too_close_plant' end
    end

    return groundZ, nil
end

local function plantAt(spot)
    if not Bridge.Progress(L('planting'), Config.Durations.plant, { anim = ANIM }) then return end
    local ok, reason, arg = Callback.Await('pop_weed:plant', { x = spot.x, y = spot.y, z = spot.z }, spot.heading)
    if not ok then
        Bridge.Notify(L(type(reason) == 'string' and reason or 'error', arg), 'error')
    elseif WeedPlants[reason] then
        -- Succès : reason = id de la nouvelle plante (plantAdded est déjà arrivé).
        WeedPlants[reason].mine = true
    end
end

local function startPlacement()
    if placing or Bridge.IsBusy() then return end
    placing = true

    local cfg = Config.Stages[1]
    local hash = joaat(cfg.model)
    if not WeedLoadModel(hash) then
        placing = false
        Bridge.Notify(L('error'), 'error')
        return
    end
    if not placing then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    preview = CreateObject(hash, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if preview == 0 then
        preview, placing = nil, false
        Bridge.Notify(L('error'), 'error')
        return
    end
    SetEntityAlpha(preview, ALPHA_VALID, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)

    local offset = cfg.offset or 0.0
    local interact, cancel = Config.Keys.Interact.control, Config.Keys.Cancel.control
    local deadline = GetGameTimer() + MAX_TIME
    local lastValid, lastReason = nil, nil
    local spot = nil

    while placing do
        ped = PlayerPedId()
        if IsEntityDead(ped) or GetGameTimer() > deadline then break end

        local pos = GetEntityCoords(ped)
        local fwd = GetEntityForwardVector(ped)
        local heading = GetEntityHeading(ped)
        local x, y = pos.x + fwd.x * Plant.PLACE_FORWARD, pos.y + fwd.y * Plant.PLACE_FORWARD
        local z, reason = checkSpot(ped, pos, x, y)
        local valid = reason == nil

        SetEntityCoordsNoOffset(preview, x, y, (z or pos.z - 1.0) + offset, false, false, false)
        SetEntityHeading(preview, heading)

        if valid ~= lastValid or reason ~= lastReason then
            SetEntityAlpha(preview, valid and ALPHA_VALID or ALPHA_INVALID, false)
            sendPanel(valid, reason)
            lastValid, lastReason = valid, reason
        end

        DisableControlAction(0, interact, true)
        DisableControlAction(0, cancel, true)
        if IsDisabledControlJustReleased(0, cancel) then break end
        if valid and IsDisabledControlJustReleased(0, interact) then
            spot = { x = x, y = y, z = z, heading = heading }
            break
        end

        Wait(0)
    end

    local stillActive = placing
    placing = false
    deletePreview()
    closePanel()

    if spot and stillActive then plantAt(spot) end
end

RegisterNetEvent('pop_weed:client:startPlacement', function()
    CreateThread(startPlacement)
end)

exports('IsPlacing', function()
    return placing
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    placing = false
    deletePreview()
    closePanel()
end)
