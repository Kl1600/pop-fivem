-- pop_kilometrage : lecture du statebag posé par le serveur et affichage HUD (sans focus NUI).

local KM_TO_MI = 0.621371
local STATE_KEY = 'pop_kilometrage'
local RES = GetCurrentResourceName()

-- Kilométrage du véhicule actuel (km), ou nil à pied / valeur inconnue.
local function currentKm()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return nil end
    local km = Entity(veh).state[STATE_KEY]
    return type(km) == 'number' and km or nil
end

exports('GetMileage', currentKm)

local shown, sentValue = nil, nil

local function hide()
    if shown == false then return end
    shown, sentValue = false, nil
    SendNUIMessage({ action = 'pop_kilometrage:hud', show = false })
end

local function display(km)
    local unit = Config.Unit == 'mi' and 'mi' or 'km'
    local value = unit == 'mi' and km * KM_TO_MI or km
    value = math.floor(value * 10 + 0.5) / 10
    if shown and value == sentValue then return end
    shown, sentValue = true, value
    SendNUIMessage({ action = 'pop_kilometrage:hud', show = true, value = value, unit = unit })
end

if Config.Hud then
    CreateThread(function()
        while true do
            local km = not IsPauseMenuActive() and currentKm() or nil
            if km then display(km) else hide() end
            Wait(1000)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == RES then
        SendNUIMessage({ action = 'pop_kilometrage:hud', show = false })
    end
end)
