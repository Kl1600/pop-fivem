local enabled = Config.Enabled == true
local previous
local lastTalking, lastRadio
local pmaActive = GetResourceState('pma-voice') == 'started'
local legacyRadio = false

local function talking()
    local player = PlayerId()
    local active = NetworkIsPlayerTalking(player)
    if active == true or active == 1 then return true end
    local mumble = pmaActive and type(MumbleIsPlayerTalking) == 'function' and MumbleIsPlayerTalking(player)
    return mumble == true or mumble == 1
end

local function setVisible(state)
    if type(state) ~= 'boolean' then return false end
    enabled = state
    lastTalking = nil
    return true
end

exports('IsTalking', talking)
exports('SetVisible', setVisible)
RegisterCommand(Config.Command, function() setVisible(not enabled) end, false)

AddEventHandler('pma-voice:radioActive', function(active)
    legacyRadio = pmaActive and active == true
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'pma-voice' then pmaActive = true end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'pma-voice' then pmaActive, legacyRadio = false, false end
end)

RegisterNUICallback('pop_voiceui_ready', function(_, cb)
    previous = nil
    cb(true)
end)

local function sample()
    local data = { action = 'pop_voiceui:update', show = false, radio = false }
    if not enabled or not NetworkIsSessionStarted() or IsPauseMenuActive() or LocalPlayer.state.charcreatorOpen then
        lastTalking = nil
        return data, 1000
    end
    local now = GetGameTimer()
    if talking() then
        lastTalking = now
        local state = LocalPlayer.state.radioActive
        lastRadio = state == true or (state == nil and legacyRadio)
    end
    if not lastTalking or now - lastTalking > math.max(0, Config.HangTime) then return data, 125 end
    data.show = true
    data.radio = lastRadio
    if Config.ShowRange and not data.radio then
        local proximity = LocalPlayer.state.proximity
        local distance = type(proximity) == 'table' and proximity.distance
        if type(distance) == 'number' and distance > 0 and distance <= 10000 then
            data.range = L('voice_range', math.floor(distance + 0.5))
        end
    end
    return data, 75
end

CreateThread(function()
    while true do
        local data, interval = sample()
        if not previous or data.show ~= previous.show or data.radio ~= previous.radio or data.range ~= previous.range then
            previous = data
            SendNUIMessage(data)
        end
        Wait(interval)
    end
end)
