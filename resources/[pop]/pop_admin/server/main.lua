local perms = {}
for word in ('goto bring spectate freeze heal revive warn kick ban unban noclip invisible vehicle world announce'):gmatch('%w+') do
    perms[word] = true
end

local function hasPermission(src, perm)
    if math.type(src) ~= 'integer' or not perms[perm] or not Bridge.IsAdmin(src) then return false end
    if IsPlayerAceAllowed(src, 'pop.admin') then return IsPlayerAceAllowed(src, 'pop.admin.' .. perm) end
    return Config.FrameworkAdmins == true
end

local worldKey = 'pop_admin:world'
local sessions, frozen = {}, {}
local vehicleTypes = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true }
local actionRules = {
    ['goto'] = { target = true }, bring = { target = true }, spectate = { optional = true },
    freeze = { target = true, immune = true }, heal = { target = true, self = true },
    revive = { target = true, self = true }, warn = { target = true, immune = true },
    kick = { target = true, immune = true }, ban = { target = true, immune = true },
    unban = {}, noclip = {}, invisible = {}, vehicle_spawn = { perm = 'vehicle' },
    vehicle_fix = { perm = 'vehicle' }, vehicle_delete = { perm = 'vehicle' }, world = {}, announce = {},
}

local function nameOf(src)
    return Bridge.GetName(src) or GetPlayerName(src) or ''
end

local function sqlName(value)
    if not utf8.len(value) then return 'System' end
    local offset = utf8.offset(value, 65)
    return offset and value:sub(1, offset - 1) or value
end

local function emit(event, src, ...)
    TriggerClientEvent('pop_admin:client:' .. event, src, ...)
end

local function allowedValue(list, value)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end

local function cleanText(text)
    if type(text) ~= 'string' or #text > 800 then return end
    text = text:gsub('%c', ' '):match('^%s*(.-)%s*$')
    local chars = utf8.len(text)
    if chars and chars >= 3 and chars <= 200 then return text end
end

local function validHours(hours)
    return math.type(hours) == 'integer' and hours >= 0 and hours <= (4294967295 - os.time()) // 3600
end

local function setWorld(info)
    GlobalState[worldKey] = {
        weather = info.weather, hour = info.hour, minute = info.minute, frozen = info.frozen, t = os.time(),
    }
end

local function worldNow()
    local info = GlobalState[worldKey] or Config.DefaultWorld
    local elapsed = info.t and math.max(0, os.time() - info.t) or 0
    local minutes = (info.hour * 60 + info.minute + (info.frozen and 0 or elapsed // 2)) % 1440
    return { weather = info.weather, hour = minutes // 60, minute = minutes % 60, frozen = info.frozen }
end

local function session(src)
    if not sessions[src] then sessions[src] = {} end
    return sessions[src]
end

local function stopSpectating(src, state)
    local spectating = state.spectating
    if not spectating then return false end
    state.spectating = nil
    SetPlayerRoutingBucket(src, spectating.bucket)
    emit('spectate', src, false)
    return true
end

local function deleteSpawn(state)
    if state.vehicle and DoesEntityExist(state.vehicle) and Entity(state.vehicle).state['pop_admin:spawn'] == state.spawnToken then
        DeleteEntity(state.vehicle)
    end
    state.vehicle = nil
end

local function teleport(src, target)
    local pos = Bridge.GetCoords(target)
    if not pos then return false end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(target))
    emit('teleport', src, { x = pos.x + 1, y = pos.y, z = pos.z })
    return true
end

local function currentTarget(src, license)
    return license and GetPlayerName(src) and Bans.Identifiers(src) == license
end

local function execute(src, action, target, data, state)
    local targetName = target and nameOf(target)
    if action == 'goto' or action == 'bring' then
        local moved = action == 'goto' and src or target
        if sessions[moved] then stopSpectating(moved, sessions[moved]) end
        if not teleport(moved, action == 'goto' and target or src) then return false, 'player_not_found' end
    elseif action == 'spectate' then
        if not target then
            if not stopSpectating(src, state) then return false, 'not_spectating' end
            return true, 'done_spectate_stop'
        end
        local coords = Bridge.GetCoords(target)
        if not coords then return false, 'player_not_found' end
        if state.noclip then
            state.noclip = false
            emit('setMode', src, 'noclip', false)
        end
        local bucket = state.spectating and state.spectating.bucket or GetPlayerRoutingBucket(src)
        state.spectating = { target = target, bucket = bucket }
        SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(target))
        emit('spectate', src, target, { x = coords.x, y = coords.y, z = coords.z }, targetName)
    elseif action == 'freeze' then
        local enabled = not frozen[target]
        frozen[target] = enabled or nil
        emit('freeze', target, enabled)
        Bridge.Notify(target, L(enabled and 'you_frozen' or 'you_unfrozen'), 'warning')
        return true, enabled and 'done_freeze' or 'done_unfreeze', enabled, targetName
    elseif action == 'heal' or action == 'revive' then
        if GetResourceState('qbx_medical') == 'started' and (action == 'heal' or Config.ReviveEvent == '') then
            if action == 'heal' then exports.qbx_medical:Heal(target) else exports.qbx_medical:Revive(target) end
        else
            emit(action, target)
        end
        Bridge.Notify(target, L(action == 'heal' and 'you_healed' or 'you_revived'), 'success')
    elseif action == 'warn' or action == 'ban' or action == 'kick' then
        local reason = cleanText(data.reason)
        if not reason then return false, 'invalid_reason' end
        local admin, adminLicense = sqlName(nameOf(src)), Bans.Identifiers(src)
        local license = Bans.Identifiers(target)
        if action == 'ban' then
            if not validHours(data.duration) or not allowedValue(Config.BanDurations, data.duration) then
                return false, 'invalid_duration'
            end
            local ban = Bans.Add(target, reason, data.duration, admin, adminLicense)
            if not ban then return false, 'error' end
            AdminLog(src, action, target, ('#%d | %dh | %s'):format(ban.id, data.duration, reason))
            if currentTarget(target, license) then DropPlayer(target, Bans.Message(ban)) end
            return true, 'done_ban', ban.id, targetName
        elseif action == 'warn' then
            if not Bans.Warn(target, reason, admin, adminLicense) then return false, 'error' end
            if currentTarget(target, license) then emit('warn', target, reason) end
        else
            AdminLog(src, action, target, reason)
            DropPlayer(target, L('kick_message', reason))
        end
    elseif action == 'unban' then
        if math.type(data.banId) ~= 'integer' or data.banId < 1 or not Bans.Remove(data.banId) then
            return false, 'ban_not_found'
        end
        return true, 'done_unban', nil, data.banId
    elseif action == 'noclip' or action == 'invisible' then
        if action == 'noclip' and state.spectating then return false, 'busy' end
        local enabled = not state[action]
        state[action] = enabled
        emit('setMode', src, action, enabled)
        return true, 'done_' .. action .. (enabled and '_on' or '_off'), enabled
    elseif action == 'vehicle_spawn' then
        local model = data.model
        if type(model) ~= 'string' or #model > 32 or not model:match('^[%w_]+$') or not vehicleTypes[data.vtype] then
            return false, 'invalid_model'
        end
        local ped, coords = GetPlayerPed(src), Bridge.GetCoords(src)
        if ped == 0 or not coords then return false, 'player_not_found' end
        local veh = CreateVehicleServerSetter(joaat(model), data.vtype, coords.x, coords.y, coords.z, GetEntityHeading(ped))
        if veh == 0 then return false, 'invalid_model' end
        local timeout = GetGameTimer() + 2000
        while not DoesEntityExist(veh) and GetGameTimer() < timeout do Wait(50) end
        if not DoesEntityExist(veh) then
            SetTimeout(2000, function()
                if DoesEntityExist(veh) and GetEntityType(veh) == 2
                    and GetEntityModel(veh) == joaat(model) and NetworkGetEntityOwner(veh) <= 0 then
                    DeleteEntity(veh)
                end
            end)
            return false, 'invalid_model'
        end
        if sessions[src] ~= state or not hasPermission(src, 'vehicle') then
            DeleteEntity(veh)
            return false, 'no_permission'
        end
        deleteSpawn(state)
        local token = ('%s:%s'):format(src, GetGameTimer())
        Entity(veh).state:set('pop_admin:spawn', token, false)
        state.vehicle, state.spawnToken = veh, token
        SetEntityRoutingBucket(veh, GetPlayerRoutingBucket(src))
        SetPedIntoVehicle(GetPlayerPed(src), veh, -1)
    elseif action == 'vehicle_fix' or action == 'vehicle_delete' then
        local id = data.netId
        local veh = math.type(id) == 'integer' and id > 0 and id <= 65535 and NetworkGetEntityFromNetworkId(id)
        if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
            return false, 'vehicle_not_found'
        end
        if GetEntityRoutingBucket(veh) ~= GetPlayerRoutingBucket(src) or not Bridge.IsNear(src, GetEntityCoords(veh), 10.0) then
            return false, 'too_far'
        end
        if action == 'vehicle_delete' then
            DeleteEntity(veh)
        else
            local owner = NetworkGetEntityOwner(veh)
            if owner <= 0 then return false, 'vehicle_not_found' end
            emit('fixVehicle', owner, id)
        end
    elseif action == 'world' then
        if not Config.WorldSync then return false, 'world_disabled' end
        if not allowedValue(Config.Weathers, data.weather) or math.type(data.hour) ~= 'integer' or data.hour < 0
            or data.hour > 23 or math.type(data.minute) ~= 'integer' or data.minute < 0 or data.minute > 59
            or type(data.frozen) ~= 'boolean' then return false, 'invalid_weather' end
        setWorld(data)
    elseif action == 'announce' then
        local message = cleanText(data.message)
        if not message then return false, 'invalid_message' end
        local now = GetGameTimer()
        if state.lastAnnounce and now - state.lastAnnounce < 10000 then
            return false, 'cooldown', math.ceil((10000 + state.lastAnnounce - now) / 1000)
        end
        state.lastAnnounce = now
        emit('announce', -1, message)
    end
    return true, 'done_' .. action, nil, targetName
end

Callback.Register('pop_admin:open', function(src)
    if not Bridge.IsAdmin(src) then AdminDenied(src, 'open'); return false end
    local rights, state = {}, session(src)
    for perm in pairs(perms) do rights[perm] = hasPermission(src, perm) end
    return { self = src, perms = rights, weathers = Config.Weathers, banDurations = Config.BanDurations,
        worldSync = Config.WorldSync, world = worldNow(),
        modes = { noclip = state.noclip == true, invisible = state.invisible == true, spectating = state.spectating ~= nil } }
end)

Callback.Register('pop_admin:getPlayers', function(src)
    if not Bridge.IsAdmin(src) then return false end
    local rows = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        rows[#rows + 1] = { id = id, name = nameOf(id), fivem = GetPlayerName(id), ping = GetPlayerPing(id),
            frozen = frozen[id] == true, warns = Bans.WarnCount(Bans.Identifiers(id)), admin = Bridge.IsAdmin(id) }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end)

Callback.Register('pop_admin:getBans', function(src)
    return hasPermission(src, 'unban') and Bans.List() or false
end)

Callback.Register('pop_admin:action', function(src, action, target, data)
    local rule = type(action) == 'string' and actionRules[action]
    if not rule then return false, 'error' end
    local state = sessions[src]
    local stopping = action == 'spectate' and target == nil and state and state.spectating
    if not stopping and not hasPermission(src, rule.perm or action) then
        AdminDenied(src, action)
        return false, 'no_permission'
    end
    state = session(src)
    local now = GetGameTimer()
    if not stopping and state.lastAction and now - state.lastAction < 1000 then return false, 'cooldown', 1 end
    state.lastAction = now
    if state.busy then return false, 'busy' end
    if rule.target or (rule.optional and target ~= nil) then
        if math.type(target) ~= 'integer' or target < 1 or target > 65535 then return false, 'invalid_target' end
        if not GetPlayerName(target) or GetPlayerPed(target) == 0 then return false, 'player_not_found' end
        if target == src and not rule.self then return false, 'self_target' end
        if rule.immune and Bridge.IsAdmin(target) then return false, 'target_immune' end
    else
        target = nil
    end
    state.busy = true
    local ran, ok, key, arg, label = pcall(execute, src, action, target, type(data) == 'table' and data or {}, state)
    state.busy = nil
    if not ran then
        print(('[pop_admin] %s failed: %s'):format(action, ok))
        return false, 'error'
    end
    if not ok then return false, key, arg end
    if sessions[src] == state then Bridge.Notify(src, L(key, label), 'success') end
    if action ~= 'kick' and action ~= 'ban' and key ~= 'done_spectate_stop' then AdminLog(src, action, target, label) end
    return true, nil, arg
end)

exports('HasPermission', hasPermission)
exports('IsBanned', function(src)
    if math.type(src) ~= 'integer' or not GetPlayerName(src) then return end
    local _, ids = Bans.Identifiers(src)
    local ban = Bans.Find(ids)
    return ban and Bans.ToRow(ban)
end)

exports('BanPlayer', function(src, reason, hours, by)
    if math.type(src) ~= 'integer' or not GetPlayerName(src) then return false, 'player_not_found' end
    if not validHours(hours) then return false, 'invalid_duration' end
    reason = cleanText(reason)
    if not reason then return false, 'invalid_reason' end
    local license = Bans.Identifiers(src)
    local actor = sqlName(type(by) == 'string' and by or 'System')
    local ban = Bans.Add(src, reason, hours, actor)
    if not ban then return false, 'error' end
    AdminLog(0, 'ban', src, ('%s | #%d | %s'):format(actor, ban.id, reason))
    if currentTarget(src, license) then DropPlayer(src, Bans.Message(ban)) end
    return true, ban.id
end)

local function cleanup(src, online)
    local state = sessions[src]
    if state then
        if online then
            stopSpectating(src, state)
            if state.noclip then emit('setMode', src, 'noclip', false) end
            if state.invisible then emit('setMode', src, 'invisible', false) end
        end
        deleteSpawn(state)
        sessions[src] = nil
    end
    if online and frozen[src] then emit('freeze', src, false) end
    frozen[src] = nil
    for admin, other in pairs(sessions) do
        if other.spectating and other.spectating.target == src then
            stopSpectating(admin, other)
            Bridge.Notify(admin, L('done_spectate_stop'), 'info')
        end
    end
end

Bridge.OnPlayerDropped(function(src) cleanup(src, false) end)
Bridge.OnPlayerUnloaded(function(src) cleanup(src, true) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, state in pairs(sessions) do
        if state.spectating then SetPlayerRoutingBucket(src, state.spectating.bucket) end
        deleteSpawn(state)
    end
end)

MySQL.ready(function()
    Bans.Load()
    Bans.Ready = true
end)
if GetConvar('onesync', 'off') == 'off' then print('[pop_admin] OneSync is required') end
if Config.WorldSync then
    if not GlobalState[worldKey] then setWorld(Config.DefaultWorld) end
    for _, resource in ipairs({ 'qb-weathersync', 'cd_easytime', 'vSync', 'Renewed-Weathersync', 'av_weather' }) do
        if GetResourceState(resource) == 'started' then
            print(('[pop_admin] Disable WorldSync while %s is running to avoid conflicting weather'):format(resource))
        end
    end
end
