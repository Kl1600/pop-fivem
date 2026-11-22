-- Location : paiement en espèces (objet 'cash' de pop_inventory) puis spawn côté client.

RegisterNetEvent('pop_bikerental:server:buyVehicle', function(model)
    local src = source
    if not Bridge.GetPlayer(src) then return end

    local loc = type(model) == 'string' and BikeRental.FindLocation(src, model)
    if not loc then return end
    local s = loc.spawnCoords
    local sx, sy, sz, sw = s.x, s.y, s.z, s.w

    local price = Config.Price or 150
    local cashAmount = Bridge.GetMoney(src, 'cash')

    if cashAmount >= price and Bridge.RemoveMoney(src, 'cash', price) then
        TriggerClientEvent('pop_bikerental:client:spawnVehicle', src, model, sx, sy, sz, sw)
        BikeRental.Notify(src, L('rent_ok_title'), L('rent_ok', price), 'fas fa-check')
        if Config.Debug then print(('[pop_bikerental] %s a loué %s pour %s$'):format(src, model, price)) end
    else
        BikeRental.Notify(src, L('rent_refused_title'), L('rent_refused', price), 'fas fa-triangle-exclamation')
    end
end)
