-- Fonctions communes du serveur pop_bikerental (chargé en premier, voir fxmanifest).

BikeRental = {}

--- Notification au style d'origine (titre + icône).
function BikeRental.Notify(src, title, message, icon)
    Bridge.Notify(src, {
        title = title,
        message = message,
        icon = icon,
        duration = Config.NotifyDuration
    })
end

-- Retrouve le point de location proche du joueur qui propose ce modèle
-- (le modèle et le point de spawn envoyés par le client ne sont jamais utilisés tels quels)
function BikeRental.FindLocation(src, model)
    for _, loc in ipairs(Config.Locations) do
        if Bridge.IsNear(src, loc.spawnCoords.xyz, Config.MaxRentDistance) then
            for _, v in ipairs(loc.displayVehicles) do
                if v.model == model then return loc end
            end
        end
    end
end
