local ESX = exports['es_extended']:getSharedObject()

-- Retrouve le point de location proche du joueur qui propose ce modèle
-- (le modèle et le point de spawn envoyés par le client ne sont jamais utilisés tels quels)
local function findLocation(src, model)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pc = GetEntityCoords(ped)
    for _, loc in ipairs(Config.Locations) do
        if #(pc - loc.spawnCoords.xyz) <= 20.0 then
            for _, v in ipairs(loc.displayVehicles) do
                if v.model == model then return loc end
            end
        end
    end
end

RegisterNetEvent('pop_bikerental:server:buyVehicle', function(model)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end

    local loc = type(model) == 'string' and findLocation(src, model)
    if not loc then return end
    local s = loc.spawnCoords
    local sx, sy, sz, sw = s.x, s.y, s.z, s.w

    local price = Config.Price or 150
    local cashAmount = exports.pop_inventory:getItemCount(src, 'cash')

    if cashAmount >= price and exports.pop_inventory:removeItem(src, 'cash', price) then
        TriggerClientEvent('pop_bikerental:client:spawnVehicle', src, model, sx, sy, sz, sw)
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title = 'Location réussie',
            message = 'Vous avez payé ' .. price .. '$ en espèces pour louer le véhicule.',
            icon = 'fas fa-check',
            duration = 5000
        })
    else
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title = 'Paiement refusé',
            message = 'Fonds en espèces insuffisants. ' .. price .. '$ requis.',
            icon = 'fas fa-triangle-exclamation',
            duration = 5000
        })
    end
end)
