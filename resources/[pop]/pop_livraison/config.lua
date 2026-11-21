Config = {}

-- Langue : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
Config.Locale = 'en'

-- Affiche les messages de diagnostic dans la console.
Config.Debug = false

-- 'auto' détecte ce qui est lancé. Sinon, forcer :
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- 'framework' | 'ox_lib' | 'pop' | 'native'

-- Couleur d'accent de l'interface. Rose néon par défaut, cyan : '#22d3ee'.
Config.AccentColor = '#ff2e88'

-- Touches (numéros de contrôle GTA : https://docs.fivem.net/docs/game-references/controls/).
Config.Keys = {
    Interact = { control = 38, label = 'E' }, -- prompt natif (sans ox_target / qb-target)
    Cancel   = { control = 73, label = 'X' }, -- annuler une barre de progression
}

-- Anti-spam des callbacks : appels max par seconde, par joueur et par callback (0 = illimité).
Config.CallbackRateLimit = 10

-- ─── pop_livraison ──────────────────────────────────────────

-- Job requis (format Bridge.HasJob), false = tout le monde.
Config.Job = false

-- Dépôt : PNJ chef de quai.
Config.Depot = { coords = vector4(1175.53, -3309.27, 5.92, 71.0), ped = 's_m_m_postal_01', blip = true }

Config.Blip = { sprite = 478, color = 5, scale = 0.8 }

-- Camionnette fournie (false : pas de camionnette, uniquement le mode à pied / véhicule perso).
Config.Vehicle = { model = 'boxville2', spawn = vector4(1178.56, -3307.38, 5.95, 89.27), deposit = 500 }

Config.Account   = 'bank'  -- compte de la paie et de la caution : 'cash' | 'bank'
Config.Packages  = 3       -- colis par tournée
Config.Pay       = { base = 150, perKm = 100 } -- paie par colis
Config.TimeLimit = 1200    -- secondes par tournée
Config.Cooldown  = 60      -- secondes entre deux tournées

Config.Durations = { take = 2000, deliver = 3000 } -- ms

-- Adresses de livraison (porte : x, y, z, heading). Au moins Config.Packages entrées.
Config.Destinations = {
    vector4(-14.13, -1441.00, 31.10, 180.0),
    vector4(126.40, -1929.50, 21.38, 210.0),
    vector4(250.20, -1730.90, 29.67, 50.0),
    vector4(-1150.70, -1520.70, 10.63, 35.0),
    vector4(-815.90, 178.60, 72.15, 110.0),
    vector4(7.90, 538.40, 176.03, 150.0),
    vector4(1393.00, 1141.80, 114.33, 90.0),
    vector4(1973.00, 3815.50, 33.43, 30.0),
    vector4(1661.30, 4776.20, 42.00, 280.0),
    vector4(-347.60, 6225.60, 31.88, 225.0),
}
