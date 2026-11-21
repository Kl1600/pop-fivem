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

-- ─── pop_vehiclekeys ─────────────────────────────────────────

-- Item clé (à déclarer dans votre inventaire, voir README). Métadonnée : { plate = 'ABC123' }.
Config.KeyItem = 'vehicle_key'

-- Touche par défaut de la télécommande (chaque joueur peut la changer dans Paramètres > Raccourcis > FiveM).
Config.LockKey = 'U'

-- Portée de la télécommande (mètres).
Config.LockDistance = 10.0

-- Le moteur ne démarre pas sans la clé.
Config.RequireKeyForEngine = true

-- Classes de véhicules qui n'ont pas besoin de clé (13 = vélos).
Config.NoKeyClasses = { 13 }

-- Serrurier : utiliser sa clé sur place pour faire un double.
Config.Locksmith = {
    price    = 150,     -- prix d'un double (0 = gratuit ; en standalone, mettre 0)
    account  = 'cash',  -- 'cash' | 'bank'
    duration = 5000,    -- durée de fabrication (ms)
    blip     = true,
    locations = {
        vec3(170.0, -1799.4, 29.3), -- exemple, à ajuster
    },
}
