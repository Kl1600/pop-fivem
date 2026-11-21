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

-- ─── pop_radio ───────────────────────────────────────────────

-- Item radio (à déclarer dans votre inventaire, voir README).
Config.Item = 'radio'

-- Touche par défaut pour ouvrir la radio ('' = aucune ; chaque joueur peut la choisir dans les raccourcis FiveM).
Config.OpenKey = ''

-- Fréquences disponibles : 1 à MaxFrequency (entiers).
Config.MaxFrequency = 999

-- Plages réservées (format Bridge.HasJob, en service).
Config.Reserved = {
    { min = 1,  max = 10, jobs = { 'police', 'sheriff' } },
    { min = 11, max = 20, jobs = { 'ambulance' } },
}

-- Secondes entre deux vérifications de l'item pour les joueurs en radio.
Config.CheckInterval = 15
