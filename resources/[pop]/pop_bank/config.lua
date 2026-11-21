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

-- ─── pop_bank ───────────────────────────────────────────────

-- Guichets (zone d'interaction centrée sur le comptoir).
Config.Banks = {
    vector3(149.46, -1042.09, 29.37),   -- Legion Square
    vector3(314.23, -278.83, 54.17),    -- Hawick
    vector3(-350.80, -49.57, 49.04),    -- Burton
    vector3(-1213.00, -330.39, 37.79),  -- Rockford Hills
    vector3(-2962.71, 482.99, 15.70),   -- Great Ocean Highway
    vector3(1175.06, 2706.64, 38.09),   -- Route 68
    vector3(-112.20, 6469.20, 31.63),   -- Paleto Bay
    vector3(241.73, 220.70, 106.29),    -- Pacific Standard
}

Config.AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

Config.Blip = { sprite = 108, color = 2, scale = 0.7 } -- guichets uniquement (false : pas de blip)

Config.MaxAmount   = 1000000 -- montant max par opération (dépôt, retrait au guichet)
Config.AtmWithdraw = 5000    -- retrait max par opération à l'ATM
Config.MaxTransfer = 100000  -- virement max par opération

Config.HistorySize = 20      -- opérations affichées
Config.HistoryDays = 30      -- les opérations plus anciennes sont supprimées au démarrage
