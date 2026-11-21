Police = Police or {}
Police.cuffed, Police.escorts, Police.escortedBy, Police.busy = {}, {}, {}, {}

local duty, lastAction, lastPanic = {}, {}, {}
local dutyLocks = {}
local previousInventoryBusy = {}
local guards = {}
local stopped = false

local function qb()
    return Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox'
end

local function setState(src, key, value)
    local player = GetPlayerName(src) and Player(src)
    if player and player.state[key] ~= value then player.state:set(key, value, true) end
end

function Police.IsOfficer(src)
    if not GetPlayerName(src) or not Bridge.GetPlayer(src) then return false end
    if Bridge.Framework == 'standalone' then return IsPlayerAceAllowed(src, 'pop.police') end
    return Bridge.HasJob(src, Config.Jobs)
end

function Police.IsOnDuty(src)
    if not Police.IsOfficer(src) then return false end
    if qb() then return (Bridge.GetJob(src) or {}).onDuty == true end
    return duty[src] == true
end

function Police.RefreshDuty(src)
    local active = Police.IsOnDuty(src)
    if not active then
        if not Police.IsOfficer(src) then duty[src] = nil end
        Police.SetEscort(src, nil)
    end
    setState(src, Police.STATE_DUTY, active and true or nil)
    return active
end

function Police.CheckOfficer(src)
    if not Police.IsOfficer(src) then
        Police.RefreshDuty(src)
        return false, 'wrong_job'
    end
    if not Police.RefreshDuty(src) then return false, 'not_on_duty' end
    if Bridge.IsDead(src) or Police.cuffed[src] then return false, 'cannot_now' end
    return true
end

function Police.CheckTarget(src, target, skipDistance)
    if math.type(target) ~= 'integer' or target <= 0 or target == src or not GetPlayerName(target)
        or not Bridge.GetPlayer(target) or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target) then
        return false, 'invalid_target'
    end
    local ped = GetPlayerPed(target)
    if ped == 0 then return false, 'invalid_target' end
    local coords = Bridge.GetCoords(target)
    if not skipDistance and (not coords or not Bridge.IsNear(src, coords, Police.ACTION_DISTANCE)) then
        return false, 'too_far'
    end
    return true, nil, ped
end

function Police.OnFoot(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) == 0
end

function Police.Lock(src)
    if Police.busy[src] then return end
    local token = {}
    Police.busy[src] = token
    return token
end

function Police.Unlock(src, token)
    if Police.busy[src] == token then Police.busy[src] = nil end
end

function Police.Cooldown(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < Police.ACTION_COOLDOWN then return false end
    lastAction[src] = now
    return true
end

function Police.WithLock(src, fn, ...)
    local token = Police.Lock(src)
    if not token then return false, 'busy' end
    local ok, result, reason, data = pcall(fn, src, ...)
    Police.Unlock(src, token)
    if not ok then
        print(('[pop_police] Action failed: %s'):format(tostring(result)))
        return false, 'error'
    end
    return result, reason, data
end

function Police.SetEscort(officer, target)
    local previous = Police.escorts[officer]
    if target and (previous or Police.escortedBy[target]) then return false end
    if previous then
        Police.escortedBy[previous] = nil
        setState(previous, Police.STATE_ESCORT, nil)
    end
    Police.escorts[officer] = target
    if target then
        Police.escortedBy[target] = officer
        setState(target, Police.STATE_ESCORT, officer)
    end
    return true
end

function Police.ReleaseTarget(target)
    local officer = Police.escortedBy[target]
    if officer then Police.SetEscort(officer, nil) end
end

function Police.SetCuffed(target, state, officer)
    if math.type(target) ~= 'integer' or type(state) ~= 'boolean' or not GetPlayerName(target) then return false end
    if (Police.cuffed[target] == true) == state then return true end
    Police.cuffed[target] = state or nil
    local original = previousInventoryBusy[target]
    if state then
        previousInventoryBusy[target] = Player(target).state.invBusy == true
        Police.SetEscort(target, nil)
    else
        Police.ReleaseTarget(target)
        previousInventoryBusy[target] = nil
    end
    setState(target, Police.STATE_CUFFED, state or nil)
    setState(target, 'invBusy', state or original == true)
    if qb() then
        local player = Bridge.GetPlayer(target)
        if player then pcall(player.Functions.SetMetaData, 'ishandcuffed', state) end
    end
    TriggerEvent('pop_police:cuffChanged', target, state, officer)
    return true
end

local reference = {
    [Police.STATE_CUFFED] = function(src) return Police.cuffed[src] end,
    [Police.STATE_ESCORT] = function(src) return Police.escortedBy[src] end,
    [Police.STATE_DUTY] = function(src) return Police.IsOnDuty(src) and true or nil end,
    invBusy = function(src) return Police.cuffed[src] and true or nil end,
}
for key, state in pairs(reference) do
    guards[#guards + 1] = AddStateBagChangeHandler(key, nil, function(bagName, _, value)
        local src = GetPlayerFromStateBagName(bagName)
        if src == 0 or stopped or (key == 'invBusy' and not Police.cuffed[src]) then return end
        -- Player statebags are writable by their owners. Privileged decisions use the server tables.
        if (value or nil) ~= state(src) then
            SetTimeout(0, function()
                if not stopped and (key ~= 'invBusy' or Police.cuffed[src]) then setState(src, key, state(src)) end
            end)
        end
    end)
end

function Police.GetOfficers()
    local result = {}
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Police.IsOnDuty(src) then result[#result + 1] = src end
    end
    return result
end

Callback.Register('pop_police:getState', function(src)
    return { officer = Police.IsOfficer(src), onDuty = Police.RefreshDuty(src), grade = (Bridge.GetJob(src) or {}).grade or 0 }
end)

local function setDuty(src, state, index)
    if type(state) ~= 'boolean' then return false, 'error' end
    if not Police.IsOfficer(src) then return false, 'wrong_job' end
    if state then
        if Bridge.IsDead(src) or Police.cuffed[src] then return false, 'cannot_now' end
        local station = math.type(index) == 'integer' and Config.Stations[index]
        if not station then return false, 'error' end
        if not Bridge.IsNear(src, station.duty, Police.STATION_DISTANCE + 1) then return false, 'too_far' end
    end
    if dutyLocks[src] then return false, 'busy' end
    if Police.IsOnDuty(src) == state then return true end

    local token = {}
    dutyLocks[src] = token
    local ok = pcall(function()
        if qb() then
            Bridge.GetPlayer(src).Functions.SetJobDuty(state)
            TriggerClientEvent('QBCore:Client:SetDuty', src, state)
        else
            duty[src] = state or nil
        end
    end)
    if dutyLocks[src] ~= token then return false, 'error' end
    dutyLocks[src] = nil
    if not ok or Police.RefreshDuty(src) ~= state then return false, 'error' end
    TriggerEvent('pop_police:dutyChanged', src, state)
    Bridge.Notify(src, L(state and 'duty_on' or 'duty_off'), 'success')
    return true
end
Callback.Register('pop_police:setDuty', setDuty)

function Police.CleanText(value, max)
    if type(value) ~= 'string' or #value > max * 4 then return end
    local result = value:gsub('%c', ''):match('^%s*(.-)%s*$')
    local length = utf8.len(result)
    if length and length <= max then return result, length end
end

function Police.Truncate(value, max)
    local length = utf8.len(value)
    if not length then return '' end
    return length > max and value:sub(1, utf8.offset(value, max + 1) - 1) or value
end

local function broadcast(action, coords, name, value)
    local data = { coords = { x = coords.x, y = coords.y, z = coords.z }, [name] = value }
    for _, officer in ipairs(Police.GetOfficers()) do TriggerClientEvent(action, officer, data) end
end

Callback.Register('pop_police:panic', function(src)
    local ok, reason = Police.CheckOfficer(src)
    if not ok then return false, reason end
    local now = os.time()
    local remaining = Config.Panic.cooldown - (now - (lastPanic[src] or 0))
    if remaining > 0 then return false, 'cooldown', remaining end
    local coords = Bridge.GetCoords(src)
    if not coords then return false, 'error' end
    lastPanic[src] = now
    broadcast('pop_police:client:panic', coords, 'name', Bridge.GetName(src) or '#' .. src)
    TriggerEvent('pop_police:panic', src, coords)
    Bridge.Notify(src, L('panic_sent'), 'success')
    return true
end)

local function finite(n)
    return type(n) == 'number' and n > -math.huge and n < math.huge
end

exports('IsCuffed', function(src) return Police.cuffed[src] == true end)
exports('SetCuffed', function(src, state) return Police.SetCuffed(src, state) end)
exports('IsOnDuty', Police.IsOnDuty)
exports('GetOfficers', Police.GetOfficers)
exports('Alert', function(coords, message)
    if (type(coords) ~= 'vector3' and type(coords) ~= 'table') or not finite(coords.x) or not finite(coords.y)
        or not finite(coords.z) or type(message) ~= 'string' then return false end
    message = Police.Truncate(message:gsub('%c', ''), 150)
    if message == '' then return false end
    broadcast('pop_police:client:alert', coords, 'text', message)
    return true
end)

Bridge.OnPlayerLoaded(function(src)
    duty[src] = nil
    Police.RefreshDuty(src)
end)

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    Police.SetEscort(src, nil)
    Police.ReleaseTarget(src)
    Police.cuffed[src], duty[src], Police.busy[src], lastAction[src], lastPanic[src] = nil, nil, nil, nil, nil
    dutyLocks[src], previousInventoryBusy[src] = nil, nil
end
Bridge.OnPlayerUnloaded(function(src)
    Police.SetCuffed(src, false)
    setState(src, Police.STATE_DUTY, nil)
    cleanup(src)
end)
Bridge.OnPlayerDropped(cleanup)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    for _, guard in ipairs(guards) do RemoveStateBagChangeHandler(guard) end
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        Police.SetCuffed(src, false)
        Police.SetEscort(src, nil)
        setState(src, Police.STATE_DUTY, nil)
    end
end)
