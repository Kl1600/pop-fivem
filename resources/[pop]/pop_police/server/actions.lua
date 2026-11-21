Police = Police or {}
local cuffing, seating = {}, {}

local function register(action, options, run)
    Callback.Register('pop_police:' .. action, function(src, target, arg)
        local release = action == 'escort' and arg == false and Police.escorts[src] == target
        -- An agent who has died or lost duty still needs to release their own escort.
        if release then return Police.SetEscort(src, nil) end
        local ok, reason = Police.CheckOfficer(src)
        if not ok then return false, reason end
        if not Police.OnFoot(src) then return false, 'cannot_now' end
        if not (action == 'cuff' and arg == 'finish') and not Police.Cooldown(src) then return false, 'busy' end
        return Police.WithLock(src, function()
            local valid, failure, ped = Police.CheckTarget(src, target, options.skipDistance)
            if not valid then return false, failure end
            if seating[target] then return false, 'busy' end
            return run(src, target, ped, arg)
        end)
    end)
end

register('cuff', {}, function(src, target, ped, phase)
    if phase == 'finish' then
        local attempt = cuffing[src]
        cuffing[src] = nil
        if not attempt or attempt.target ~= target then return false, 'error' end
        local elapsed = GetGameTimer() - attempt.time
        if elapsed < Config.Durations.cuff - 500 or elapsed > Config.Durations.cuff + 5000 then return false, 'error' end
    elseif phase ~= 'start' then
        return false, 'error'
    end
    if Police.cuffed[target] then return false, 'already_cuffed' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'target_in_vehicle' end
    if Config.Handcuffs and not Bridge.HasItem(src, Config.Handcuffs) then
        return false, 'missing_item', L('item_handcuffs')
    end
    if phase == 'start' then
        cuffing[src] = { target = target, time = GetGameTimer() }
        TriggerClientEvent('pop_police:client:beingCuffed', target)
        return true
    end
    if not Police.SetCuffed(target, true, src) then return false, 'invalid_target' end
    Bridge.Notify(src, L('cuffed_done'), 'success')
    Bridge.Notify(target, L('you_are_cuffed'), 'error')
    return true
end)

register('uncuff', {}, function(src, target)
    if not Police.cuffed[target] then return false, 'not_cuffed' end
    if not Police.SetCuffed(target, false, src) then return false, 'invalid_target' end
    Bridge.Notify(src, L('uncuffed_done'), 'success')
    Bridge.Notify(target, L('you_are_uncuffed'), 'success')
    return true
end)

register('escort', {}, function(src, target, ped, state)
    if state ~= true then return false, 'error' end
    if not Police.cuffed[target] then return false, 'not_cuffed' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'target_in_vehicle' end
    if Police.escortedBy[target] then return false, 'already_escorted' end
    if Police.escorts[src] then return false, 'busy' end
    return Police.SetEscort(src, target)
end)

register('putInVehicle', {}, function(src, target, ped, netId)
    if not Police.cuffed[target] then return false, 'not_cuffed' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'target_in_vehicle' end
    if math.type(netId) ~= 'integer' or netId < 1 or netId > 65535 then return false, 'no_vehicle' end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2
        or GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src) then return false, 'no_vehicle' end
    local position = GetEntityCoords(vehicle)
    if not Bridge.IsNear(src, position, Police.VEHICLE_SERVER_DISTANCE)
        or not Bridge.IsNear(target, position, Police.VEHICLE_SERVER_DISTANCE) then return false, 'too_far' end
    Police.ReleaseTarget(target)
    local token = {}
    seating[target] = token
    -- Passenger seats are chosen by the target's client, where the seat natives are available.
    local called, seated = pcall(Callback.Await, 'pop_police:enterVehicle', target, netId)
    local confirmed = false
    if called and seated == true then
        -- The warp must replicate back to the server. The client response alone cannot confirm it.
        for _ = 1, 10 do
            if seating[target] ~= token or not Police.cuffed[target] or not DoesEntityExist(vehicle) then break end
            local valid = Police.CheckTarget(src, target, true)
            if not valid or GetPlayerPed(target) ~= ped then break end
            if GetVehiclePedIsIn(ped, false) == vehicle then
                confirmed = true
                break
            end
            Wait(100)
        end
    end
    if seating[target] == token then seating[target] = nil end
    if not called then return false, 'error' end
    if not confirmed then return false, 'vehicle_full' end
    return true
end)

register('takeOutVehicle', { skipDistance = true }, function(src, target, ped)
    if not Police.cuffed[target] then return false, 'not_cuffed' end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, 'target_not_in_vehicle' end
    if not Bridge.IsNear(src, GetEntityCoords(vehicle), Police.VEHICLE_SERVER_DISTANCE) then return false, 'too_far' end
    TriggerClientEvent('pop_police:client:leaveVehicle', target)
    return true
end)

local function openInventory(src, target)
    if Bridge.Inventory == 'pop_inventory' then return exports.pop_inventory:forceOpenInventory(src, 'player', target) end
    if Bridge.Inventory == 'ox_inventory' then return exports.ox_inventory:forceOpenInventory(src, 'player', target) end
    if Bridge.Inventory == 'qb-inventory' then
        -- OpenInventoryById is available on qb-inventory v2 and does not return a success value.
        return exports['qb-inventory']:OpenInventoryById(src, target) ~= false
    end
    return false
end

register('search', {}, function(src, target)
    if not Police.cuffed[target] and not Bridge.IsDead(target) then return false, 'cannot_search' end
    local called, opened = pcall(openInventory, src, target)
    if not called or not opened then
        local items, summary = Bridge.GetItems(target), {}
        for i = 1, math.min(#items, 10) do
            summary[i] = ('%sx %s'):format(items[i].count, items[i].name)
        end
        if #items > 10 then summary[11] = '…' end
        local message = #summary > 0 and L('search_summary', table.concat(summary, ', ')) or L('search_empty')
        Bridge.Notify(src, message, 'info', 10000)
    end
    Bridge.Notify(target, L('being_searched'), 'warning')
    return true
end)

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    cuffing[src], seating[src] = nil, nil
    for officer, attempt in pairs(cuffing) do
        if attempt.target == src then cuffing[officer] = nil end
    end
end
Bridge.OnPlayerUnloaded(cleanup)
Bridge.OnPlayerDropped(cleanup)
