Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'auto'
Config.Inventory = 'auto'
Config.Target    = 'auto'
Config.Notify    = 'auto'
Config.AccentColor = '#ffffff'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_fuel
------------------------------------------------------------------------

-- Prix du litre ($). Un plein complet = 100 litres.
Config.PricePerLiter = 2

-- Durée du remplissage : millisecondes par litre (bornée entre 3 et 15 s).
Config.RefuelMsPerLiter = 120

-- Consommation par seconde selon le régime moteur (0.0 à 1.0), comme les scripts d'essence classiques.
Config.RpmUsage = {
    [1.0] = 1.4, [0.9] = 1.2, [0.8] = 1.0, [0.7] = 0.9, [0.6] = 0.8,
    [0.5] = 0.7, [0.4] = 0.5, [0.3] = 0.4, [0.2] = 0.2, [0.1] = 0.1, [0.0] = 0.0,
}

-- Multiplicateur par classe de véhicule (GetVehicleClass). 0.0 = ne consomme pas.
Config.ClassUsage = {
    [0] = 1.0,  -- compactes
    [1] = 1.0,  -- berlines
    [2] = 1.0,  -- SUV
    [3] = 1.0,  -- coupés
    [4] = 1.0,  -- muscle
    [5] = 1.0,  -- sport classiques
    [6] = 1.0,  -- sport
    [7] = 1.0,  -- super
    [8] = 1.0,  -- motos
    [9] = 1.0,  -- tout-terrain
    [10] = 1.0, -- industriels
    [11] = 1.0, -- utilitaires
    [12] = 1.0, -- vans
    [13] = 0.0, -- vélos
    [14] = 1.0, -- bateaux
    [15] = 1.0, -- hélicoptères
    [16] = 1.0, -- avions
    [17] = 1.0, -- service
    [18] = 1.0, -- urgence
    [19] = 1.0, -- militaires
    [20] = 1.0, -- commerciaux
    [21] = 0.0, -- trains
}

-- Véhicules électriques : ne consomment pas d'essence.
Config.Electric = {
    'voltic', 'voltic2', 'raiden', 'cyclone', 'cyclone2', 'tezeract', 'neon', 'surge', 'khamelion',
    'imorgon', 'iwagen', 'omnisegt', 'virtue', 'powersurge', 'dilettante', 'dilettante2',
    'caddy', 'caddy2', 'caddy3', 'airtug', 'rcbandito',
}

-- Modèles de pompes de GTA (interaction ox_target).
Config.PumpModels = {
    'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c', 'prop_gas_pump_1d',
    'prop_gas_pump_old2', 'prop_gas_pump_old3', 'prop_vintage_pump',
}

-- Distance max (m) entre la pompe et le véhicule à remplir.
Config.MaxVehicleDistance = 5.0

-- Stations de GTA : icônes sur la carte et contrôle côté serveur (le joueur doit être à moins de 40 m).
Config.ShowBlips = true
Config.Blip = { sprite = 361, color = 1, scale = 0.6 }
Config.StationRadius = 40.0
Config.Stations = {
    vector3(49.4, 2778.8, 58.0),     vector3(263.9, 2606.5, 45.0),    vector3(1040.0, 2671.1, 39.6),
    vector3(1207.3, 2660.2, 37.9),   vector3(2539.7, 2594.2, 37.9),   vector3(2679.9, 3263.9, 55.2),
    vector3(2005.1, 3773.9, 32.4),   vector3(1687.2, 4929.4, 42.1),   vector3(1701.3, 6416.0, 32.8),
    vector3(179.9, 6602.8, 31.9),    vector3(-94.5, 6419.6, 31.5),    vector3(-2555.0, 2334.4, 33.1),
    vector3(-1800.4, 803.7, 138.7),  vector3(-1437.6, -276.7, 46.2),  vector3(-2096.2, -320.3, 13.2),
    vector3(-724.6, -935.2, 19.2),   vector3(-526.0, -1211.0, 18.2),  vector3(-70.2, -1761.8, 29.5),
    vector3(265.6, -1261.3, 29.3),   vector3(819.7, -1028.8, 26.4),   vector3(1209.0, -1402.6, 35.2),
    vector3(1181.4, -330.8, 69.3),   vector3(620.8, 269.1, 103.1),    vector3(2581.3, 362.0, 108.5),
    vector3(176.6, -1562.0, 29.3),   vector3(-319.3, -1471.7, 30.5),  vector3(1784.3, 3330.6, 41.3),
}
