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

Config.Command = 'character'
Config.AutoCreate = true
Config.AllowAdminEdit = true
Config.SessionSeconds = 600
Config.Birth = { minYear = 1900, minAge = 18, serverYear = false }

Config.Spawns = {
    { id = 'city', label = 'spawn_city', coords = vector4(-545.14, -204.08, 38.22, 205.0) },
    { id = 'county', label = 'spawn_county', coords = vector4(1852.18, 3688.04, 34.27, 203.0) },
}
Config.DefaultSpawn = 'city'

Config.Models = {
    mp_m_freemode_01 = { hair = 18, hairColor = 30 },
    mp_f_freemode_01 = { hair = 20, hairColor = 30 },
}
