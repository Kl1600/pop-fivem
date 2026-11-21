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

Config.InteractionDistance = 2.5
Config.StreamDistance = 35.0

Config.Terminals = {
    {
        coords = vec3(441.05, -978.86, 31.05),
        heading = 90.0,
        model = 'prop_monitor_01c',
        -- jobs = { police = 0 },
        -- onDuty = true,
        -- ace = 'pop.computer.access',
        -- bucket = 0,
        -- screen = {
        --     position = vec3(441.2, -978.86, 31.16),
        --     normal = vec3(1.0, 0.0, 0.0),
        --     worldWidth = 0.33,
        --     worldHeight = 0.24,
        -- },
    },
}
