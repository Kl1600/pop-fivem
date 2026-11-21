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

-- ─── pop_bikerental ──────────────────────────────────────────

-- Compte débité / crédité : 'cash' | 'bank'. En standalone (aucun argent), mettre prix et caution à 0.
Config.Account = 'cash'

-- Durée d'une location (minutes) et caution rendue au retour (véhicule non abîmé).
Config.Duration = 30
Config.Deposit  = 100

-- Véhicules proposés partout. type : GetVehicleType ('bike' pour vélos et scooters).
Config.Vehicles = {
    { model = 'bmx',     price = 50,  type = 'bike' },
    { model = 'cruiser', price = 50,  type = 'bike' },
    { model = 'faggio',  price = 150, type = 'bike' },
}

-- Points de location. coords : comptoir. spawn : place de sortie (x, y, z, cap).
Config.Locations = {
    { coords = vec3(-512.29, -251.18, 35.77), spawn = vec4(-509.6, -253.9, 35.1, 202.75), blip = true },
    { coords = vec3(1882.68, 3696.54, 33.61), spawn = vec4(1885.4, 3699.0, 32.9, 218.75), blip = true },
}
