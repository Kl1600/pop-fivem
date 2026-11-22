-- pop_fuel : serveur. Calcule le prix à partir du niveau partagé du véhicule (jamais d'un prix
-- envoyé par le client), vérifie la station et la distance, puis encaisse.

local function nearStation(src)
    for _, coords in ipairs(Config.Stations) do
        if Bridge.IsNear(src, coords, Config.StationRadius) then return true end
    end
    return false
end

Callback.Register('pop_fuel:pay', function(source, netId, method)
    if method ~= 'cash' and method ~= 'bank' then return false end
    if not nearStation(source) then return false, 0, 0, 'too_far' end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local playerCoords = Bridge.GetCoords(source)
    if not playerCoords or #(GetEntityCoords(vehicle) - playerCoords) > Config.MaxVehicleDistance + 3.0 then
        return false, 0, 0, 'too_far'
    end

    local level = tonumber(Entity(vehicle).state.fuel) or 0.0
    local liters = math.floor(100.0 - math.max(0.0, math.min(100.0, level)))
    if liters < 1 then return false, 0, 0, 'already_full' end
    local price = math.ceil(liters * Config.PricePerLiter)

    if Bridge.GetMoney(source, method) < price
        or not Bridge.RemoveMoney(source, method, price, 'pop_fuel') then
        return false, 0, 0, method == 'cash' and 'no_money_cash' or 'no_money_bank'
    end

    Entity(vehicle).state:set('fuel', 100.0, true)
    return true, liters, price
end)
