if not Config.WorldSync then return end

local key = 'pop_admin:world'
local world
local transition = 0

local function update(value)
    if type(value) ~= 'table' then return end
    if not world or world.weather ~= value.weather then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        if world then
            SetWeatherTypeOverTime(value.weather, 15.0)
            transition = GetGameTimer() + 15000
        else
            SetWeatherTypeNowPersist(value.weather)
        end
        local snow = value.weather == 'XMAS'
        SetForceVehicleTrails(snow)
        SetForcePedFootstepsTracks(snow)
    end
    world = value
end

local handler = AddStateBagChangeHandler(key, 'global', function(_, _, value) update(value) end)
update(GlobalState[key])

CreateThread(function()
    while true do
        if world then
            local elapsed = math.max(0, GetCloudTimeAsInt() - world.t)
            local minutes = (world.hour * 60 + world.minute + (world.frozen and 0 or elapsed // 2)) % 1440
            NetworkOverrideClockTime(minutes // 60, minutes % 60, 0)
            if transition > 0 and GetGameTimer() >= transition then
                transition = 0
                SetWeatherTypeNowPersist(world.weather)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    RemoveStateBagChangeHandler(handler)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
    NetworkClearClockTimeOverride()
end)
