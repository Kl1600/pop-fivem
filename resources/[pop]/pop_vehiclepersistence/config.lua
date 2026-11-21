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

-- ─── pop_vehiclepersistence ──────────────────────────────────

-- Véhicules gardés : 'auto' | 'framework' (table owned_vehicles / player_vehicles)
-- | 'keys' (le conducteur a la clé pop_vehiclekeys) | 'all' (tout véhicule conduit par un joueur).
-- 'auto' : framework si ESX / QBCore / Qbox, sinon keys si pop_vehiclekeys est lancé, sinon all.
Config.Mode = 'auto'

-- Un véhicule garé apparaît quand un joueur est à moins de cette distance (mètres).
Config.SpawnDistance = 150.0

-- Véhicules garés max par propriétaire : au-delà, le plus ancien est remorqué.
Config.MaxPerOwner = 5

-- Un véhicule non conduit depuis ce nombre de jours est supprimé (0 = jamais).
Config.ExpireDays = 14
