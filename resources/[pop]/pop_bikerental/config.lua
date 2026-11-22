Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | ...
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- pop_notify s'il est lancé
Config.AccentColor = '#ffffff'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_bikerental
------------------------------------------------------------------------

-- Prix de location (payé en item 'cash' pop_inventory)
Config.Price = 150

-- Points de location : partagés client/serveur (le serveur valide modèle + point de spawn)
-- label = clé de locales/fr.lua (le prix y est inséré : %s$)
-- 'ventoso' retiré : modèle custom de l'ancien script supprimé (introuvable en jeu)
Config.Locations = {
    -- Location 1 : LSX Bikerental (centre-ville)
    {
        spawnCoords = vector4(-512.2866, -251.1761, 34.7723, 202.7517),
        displayVehicles = {
            {
                model = 'inductor',
                coords = vector4(-511.1458, -248.1631, 35.3218, 83.3264),
                label = 'rent_inductor'
            }
        }
    },
    -- Location 2 : Bikerental (Mexico)
    {
        -- 4 m devant les véhicules exposés (même cap), le point d'origine était sur le vélo exposé
        spawnCoords = vector4(1885.1800, 3693.4200, 32.6095, 218.7509),
        displayVehicles = {
            {
                model = 'inductor',
                coords = vector4(1882.6793, 3696.5371, 32.6095, 218.7509),
                label = 'rent_bike'
            }
        }
    }
}

-- Rayon (m) dans lequel le point de spawn doit être libre (véhicules d'exposition exclus)
Config.SpawnClearRadius = 3.0

-- Distance max (m) entre le joueur et le point de spawn pour accepter une location (serveur)
Config.MaxRentDistance = 20.0

-- Délai max (ms) de chargement d'un modèle
Config.ModelTimeout = 5000

-- Abaissement (m) des véhicules d'exposition par rapport à leurs coordonnées
Config.DisplayZOffset = 0.2

-- Modèle qui donne des clés (vehicle_keys, seulement s'il est lancé)
Config.KeysModel = 'ventoso'

-- Durée d'affichage des notifications (ms)
Config.NotifyDuration = 5000
