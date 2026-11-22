-- pop_fuel : consommation. Le niveau d'essence est celui de GTA (GetVehicleFuelLevel), déjà
-- sauvegardé par pop_vehiclepersistence et lu par pop_speedometer. Il est partagé entre joueurs
-- par le statebag du véhicule (state.fuel), mis à jour par le conducteur.

Fuel = {}

local electric = {}
for _, model in ipairs(Config.Electric) do electric[GetHashKey(model)] = true end

function Fuel.IsElectric(vehicle)
    return electric[GetEntityModel(vehicle)] == true
end

function Fuel.Get(vehicle)
    return GetVehicleFuelLevel(vehicle)
end

-- Met à jour le niveau local et partagé.
function Fuel.Set(vehicle, level)
    level = math.max(0.0, math.min(100.0, level + 0.0))
    SetVehicleFuelLevel(vehicle, level)
    if NetworkGetEntityIsNetworked(vehicle) then
        Entity(vehicle).state:set('fuel', level, true)
    end
end

local function usagePerSecond(vehicle)
    local rpm = math.floor(GetVehicleCurrentRpm(vehicle) * 10 + 0.5) / 10
    local byRpm = Config.RpmUsage[rpm] or 0.0
    local byClass = Config.ClassUsage[GetVehicleClass(vehicle)] or 1.0
    return byRpm * byClass / 10
end

CreateThread(function()
    local current, lastShared = 0, nil
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and not Fuel.IsElectric(vehicle) then
            -- En prenant le volant : on reprend le niveau partagé s'il existe.
            if vehicle ~= current then
                current = vehicle
                local shared = Entity(vehicle).state.fuel
                if shared then SetVehicleFuelLevel(vehicle, shared + 0.0) end
                lastShared = Fuel.Get(vehicle)
            end

            local level = Fuel.Get(vehicle)
            if GetIsVehicleEngineRunning(vehicle) then
                level = math.max(0.0, level - usagePerSecond(vehicle))
                SetVehicleFuelLevel(vehicle, level)
            end
            if level <= 0.0 then
                SetVehicleEngineOn(vehicle, false, true, true) -- panne sèche
            end
            -- Partage avec les autres joueurs : seulement si le niveau a bougé d'au moins 1 L.
            if not lastShared or math.abs(lastShared - level) >= 1.0 then
                Fuel.Set(vehicle, level)
                lastShared = level
            end
            Wait(1000)
        else
            current = 0
            Wait(1500)
        end
    end
end)

exports('GetFuel', function(vehicle) return Fuel.Get(vehicle) end)
exports('SetFuel', function(vehicle, level) Fuel.Set(vehicle, level) end)
