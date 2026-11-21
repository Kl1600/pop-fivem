local noclip, invisible = false, false
local spectate, collisionEntity, hiddenPed
local running, stopping = false, false
local controls = { 32, 33, 34, 35, 44, 38, 21, 19, 24, 25, 140, 141, 142 }

local function hud()
    SendNUIMessage({ action = 'pop_admin:modes', noclip = noclip, invisible = invisible, spectating = spectate ~= nil })
    SendNUIMessage({
        action = 'pop_admin:hud', noclip = noclip, invisible = invisible,
        spectate = spectate and { id = spectate.id, name = spectate.name }, stopKey = 'BACKSPACE',
    })
end

local function restoreEntity()
    if collisionEntity and DoesEntityExist(collisionEntity) then
        SetEntityCollision(collisionEntity, true, true)
        FreezeEntityPosition(collisionEntity, false)
        SetEntityInvincible(collisionEntity, false)
    end
    collisionEntity = nil
end

local function restorePed()
    if hiddenPed and DoesEntityExist(hiddenPed) then
        SetEntityVisible(hiddenPed, true, false)
        ResetEntityAlpha(hiddenPed)
    end
    hiddenPed = nil
end

local function stopObservation()
    if not spectate then return end
    local saved = spectate
    spectate = nil
    NetworkSetInSpectatorMode(false, 0)
    restoreEntity()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(saved.coords.x, saved.coords.y, saved.coords.z)
    SetEntityCoordsNoOffset(ped, saved.coords.x, saved.coords.y, saved.coords.z, false, false, false)
    SetEntityHeading(ped, saved.heading)
end

local function requestStop()
    if stopping then return end
    stopping = true
    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_admin:action', 'spectate')
        stopping = false
        if not ok and reason ~= 'not_spectating' then Bridge.Notify(L(reason or 'error', arg), 'error') end
        if reason == 'not_spectating' then stopObservation(); hud() end
    end)
end

local function pressed(control)
    return IsDisabledControlPressed(0, control) and 1 or 0
end

local function fly(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and veh or ped
    if collisionEntity ~= entity then
        restoreEntity()
        collisionEntity = entity
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
        SetEntityInvincible(entity, true)
    end
    for _, control in ipairs(controls) do DisableControlAction(0, control, true) end
    local rot = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local forward = vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local right = vec3(math.cos(yaw), math.sin(yaw), 0)
    local move = forward * (pressed(32) - pressed(33)) + right * (pressed(35) - pressed(34))
        + vec3(0, 0, pressed(38) - pressed(44))
    if #move > 0 then
        local speed = math.min(GetFrameTime(), 0.05) * 60 * (pressed(21) == 1 and 4 or (pressed(19) == 1 and 0.25 or 1))
        local pos = GetEntityCoords(entity) + move * (speed / #move)
        SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(entity, rot.z)
    end
end

local function prepareObserver(ped)
    if collisionEntity == ped then return end
    restoreEntity()
    collisionEntity = ped
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
end

local function observe(ped)
    if IsControlJustPressed(0, 177) then requestStop() end
    local now = GetGameTimer()
    if now < spectate.nextCheck then return end
    spectate.nextCheck = now + 250
    prepareObserver(ped)
    local player = GetPlayerFromServerId(spectate.id)
    local target = player ~= -1 and GetPlayerPed(player) or 0
    if target ~= 0 then
        if target ~= spectate.entity then
            NetworkSetInSpectatorMode(true, target)
            spectate.entity = target
        end
        local pos = GetEntityCoords(target)
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z - 15, false, false, false)
        spectate.deadline = now + 5000
    elseif now >= spectate.deadline then
        spectate.deadline = now + 10000
        requestStop()
    end
end

local function startLoop()
    if running then return end
    running = true
    CreateThread(function()
        while noclip or invisible or spectate do
            local ped = PlayerPedId()
            if hiddenPed ~= ped then
                restorePed()
                hiddenPed = ped
                SetEntityVisible(ped, false, false)
            end
            if spectate then
                SetEntityLocallyInvisible(ped)
                observe(ped)
            else
                SetEntityLocallyVisible(ped)
                SetEntityAlpha(ped, 102, false)
                if noclip then fly(ped) end
            end
            Wait(0)
        end
        running = false
        restorePed()
        restoreEntity()
    end)
end

RegisterNetEvent('pop_admin:client:setMode', function(mode, enabled)
    if source ~= 65535 then return end
    if mode == 'noclip' then
        noclip = enabled == true
        if not noclip and not spectate then restoreEntity() end
    elseif mode == 'invisible' then
        invisible = enabled == true
    else
        return
    end
    hud()
    if noclip or invisible or spectate then startLoop() end
end)

RegisterNetEvent('pop_admin:client:spectate', function(target, coords, name)
    if source ~= 65535 then return end
    if not target then
        stopObservation()
    else
        local ped = PlayerPedId()
        local saved = spectate or { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped) }
        spectate = { id = target, name = name, coords = saved.coords, heading = saved.heading,
            nextCheck = 0, deadline = GetGameTimer() + 5000 }
        prepareObserver(ped)
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z - 15, false, false, false)
        startLoop()
    end
    hud()
end)

exports('IsNoclip', function() return noclip end)
exports('IsInvisible', function() return invisible end)
exports('IsSpectating', function() return spectate ~= nil end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopObservation()
    noclip, invisible = false, false
    restorePed()
    restoreEntity()
    hud()
end)
