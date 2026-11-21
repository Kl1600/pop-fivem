local enabled, previous, defaultsRadar = true, nil, nil
local ownedBlips, needs = {}, {}
local radarShown

local function percent(value)
    if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then return end
    return math.floor(math.max(0, math.min(value, 100)) + 0.5)
end

local function setVisible(state)
    if type(state) ~= 'boolean' then return false end
    enabled = state
    return true
end

exports('SetVisible', setVisible)
exports('SetNeeds', function(values)
    if type(values) ~= 'table' then return false end
    for _, key in ipairs({ 'hunger', 'thirst' }) do
        if values[key] ~= nil then needs[key] = percent(values[key]) end
    end
    return true
end)

RegisterCommand(Config.Command, function() setVisible(not enabled) end, false)
RegisterNUICallback('pop_hud_ready', function(_, cb)
    previous = nil
    cb(true)
end)

AddEventHandler('esx_status:onTick', function(values)
    if Bridge.Framework ~= 'esx' or type(values) ~= 'table' then return end
    for _, status in ipairs(values) do
        if type(status) == 'table' and (status.name == 'hunger' or status.name == 'thirst') then
            needs[status.name] = percent(status.percent)
        end
    end
end)
Bridge.OnPlayerLoaded(function() needs = {} end)

local function setRadar(visible, vehicle)
    local mode = Config.Radar
    if mode == 'unchanged' then return end
    local target = visible and (mode == 'visible' or (mode == 'vehicle' and vehicle ~= 0))
    if defaultsRadar == nil then defaultsRadar = not IsRadarHidden() end
    if radarShown ~= target then
        DisplayRadar(target)
        radarShown = target
    end
end

local function appendNeeds(snapshot)
    local threshold = percent(Config.NeedThreshold) or 80
    local metadata = (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') and Bridge.GetPlayerData().metadata
    for _, key in ipairs({ 'hunger', 'thirst' }) do
        local value = needs[key]
        if value == nil and metadata then value = percent(metadata[key]) end
        if value ~= nil and value < threshold then snapshot[key] = value end
    end
end

local function getFuel(vehicle)
    local external = percent(Entity(vehicle).state.fuel)
    if external then return external end
    if not DoesVehicleUseFuel(vehicle) then return end
    local tank = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume')
    if tank > 0 then return percent(GetVehicleFuelLevel(vehicle) * 100 / tank) end
end

local function capture()
    local snapshot = { action = 'pop_hud:update', visible = false }
    local active = enabled and Bridge.IsLoaded() and not IsPauseMenuActive() and not LocalPlayer.state.charcreatorOpen
    if not active then
        setRadar(false, 0)
        return snapshot, 750
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    setRadar(true, vehicle)
    snapshot.visible = true
    local health = GetEntityHealth(ped)
    local maximum = GetEntityMaxHealth(ped)
    local floor = maximum > 100 and 100 or 0
    local life = percent((health - floor) * 100 / math.max(1, maximum - floor))
    if life and life < 100 then snapshot.health = life end
    local armor = percent(GetPedArmour(ped))
    if armor and armor > 0 then snapshot.armor = armor end
    appendNeeds(snapshot)
    if Config.ShowClock then
        local _, _, _, hours, minutes = GetLocalTime()
        snapshot.clock = ('%02d:%02d'):format(hours, minutes)
    end
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        local miles = Config.SpeedUnit == 'mph'
        snapshot.unit = miles and 'mph' or 'kmh'
        snapshot.speed = math.max(0, math.floor(GetEntitySpeed(vehicle) * (miles and 2.236936 or 3.6) + 0.5))
        snapshot.fuel = getFuel(vehicle)
        return snapshot, 125
    end
    local showing = snapshot.health or snapshot.armor or snapshot.hunger or snapshot.thirst
    return snapshot, showing and 250 or 750
end

local function changed(snapshot)
    if not previous then return true end
    for key, value in pairs(snapshot) do if previous[key] ~= value then return true end end
    for key in pairs(previous) do if snapshot[key] == nil then return true end end
    return false
end

CreateThread(function()
    local locale = GetLocaleTable()
    for _, point in ipairs(Config.Blips) do
        if type(point.label) == 'string' and locale[point.label] and point.coords then
            local coords = point.coords
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            ownedBlips[#ownedBlips + 1] = blip
            SetBlipSprite(blip, point.sprite or 1)
            SetBlipColour(blip, point.color or 0)
            SetBlipScale(blip, point.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(L(point.label))
            EndTextCommandSetBlipName(blip)
        end
    end
    while true do
        local snapshot, interval = capture()
        if changed(snapshot) then
            previous = snapshot
            SendNUIMessage(snapshot)
        end
        Wait(interval)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(ownedBlips) do RemoveBlip(blip) end
    if defaultsRadar ~= nil then DisplayRadar(defaultsRadar) end
end)
