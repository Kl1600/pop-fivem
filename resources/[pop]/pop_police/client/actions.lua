Police = Police or {}
local escortLoop, acting = false, false
local cuffAnim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 }
local searchAnim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search', flag = 49 }

function Police.Request(action, ...)
    local ok, reason, arg = Callback.Await('pop_police:' .. action, ...)
    if not ok then Bridge.Notify(L(reason or 'error', arg), 'error') end
    return ok, reason, arg
end

function Police.GetTarget()
    local center = GetEntityCoords(PlayerPedId())
    local nearest, target, targetPed = math.huge
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) then
                local maxDistance = Police.TARGET_DISTANCE + (IsPedInAnyVehicle(ped, false) and 1.5 or 0)
                local distance = #(center - GetEntityCoords(ped))
                if distance <= maxDistance and distance < nearest then
                    nearest, target, targetPed = distance, GetPlayerServerId(player), ped
                end
            end
        end
    end
    return target, targetPed
end

function Police.GetVehicle()
    local center = GetEntityCoords(PlayerPedId())
    local nearest, current = Police.VEHICLE_DISTANCE
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local distance = #(center - GetEntityCoords(vehicle))
        if distance <= nearest and NetworkGetEntityIsNetworked(vehicle) then nearest, current = distance, vehicle end
    end
    if current then return current, VehToNet(current) end
end

local function watchEscort()
    if escortLoop then return end
    escortLoop = true
    CreateThread(function()
        while Police.escorting do
            Wait(500)
            local target = Police.escorting
            if not target then break end
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or GetPlayerFromServerId(target) == -1
                or Player(target).state[Police.STATE_ESCORT] ~= GetPlayerServerId(PlayerId()) then
                Police.escorting = nil
                Callback.Await('pop_police:escort', target, false)
            end
        end
        escortLoop = false
    end)
end

local actions = {}
actions.panic = function() Police.Request('panic') end
actions.duty_off = function() Police.Request('setDuty', false) end
actions.stop_escort = function()
    if Police.escorting then
        local target = Police.escorting
        Police.escorting = nil
        Police.Request('escort', target, false)
    end
end
actions.cuff = function(target, ped)
    if not Police.Request('cuff', target, 'start') then return end
    TaskTurnPedToFaceEntity(PlayerPedId(), ped, 500)
    if Bridge.Progress(L('cuffing'), Config.Durations.cuff, { anim = cuffAnim }) then Police.Request('cuff', target, 'finish') end
end
actions.uncuff = function(target)
    if Bridge.Progress(L('uncuffing'), Config.Durations.uncuff, { anim = cuffAnim }) then Police.Request('uncuff', target) end
end
actions.search = function(target)
    if Bridge.Progress(L('searching'), Config.Durations.search, { anim = searchAnim }) then Police.Request('search', target) end
end
actions.escort = function(target)
    if Police.Request('escort', target, true) then
        Police.escorting = target
        watchEscort()
    end
end
actions.take_out_vehicle = function(target) Police.Request('takeOutVehicle', target) end
actions.put_in_vehicle = function(target)
    local _, netId = Police.GetVehicle()
    if not netId then
        Bridge.Notify(L('no_vehicle'), 'error')
        return
    end
    local ok = Police.Request('putInVehicle', target, netId)
    if ok and Police.escorting == target then Police.escorting = nil end
end

function Police.RunAction(id, target)
    if not actions[id] then return end
    if acting or Bridge.IsBusy() then
        Bridge.Notify(L('busy'), 'error')
        return
    end
    local ped
    if id ~= 'panic' and id ~= 'duty_off' and id ~= 'stop_escort' then
        local player = target and GetPlayerFromServerId(target)
        ped = player and player ~= -1 and GetPlayerPed(player)
        if not ped or not DoesEntityExist(ped)
            or #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > Police.TARGET_DISTANCE + 1.5 then
            Bridge.Notify(L('too_far'), 'error')
            return
        end
    end
    acting = true
    local ok, failure = pcall(actions[id], target, ped)
    acting = false
    if not ok then
        print(('[pop_police] Client action failed: %s'):format(tostring(failure)))
        Bridge.Notify(L('error'), 'error')
    end
end
