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

-- ─── pop_interim ────────────────────────────────────────────

-- Guichets. ped = modèle du PNJ (false : simple zone d'interaction). blip = afficher sur la carte.
Config.Locations = {
    { coords = vector4(-268.0, -957.0, 31.22, 205.0), ped = 'a_f_y_business_02', blip = true },
}

Config.Blip = { sprite = 407, color = 27, scale = 0.8 }

-- Métiers proposés. id = identifiant interne (libellés : locales job_<id> et job_<id>_desc).
-- job = nom EXACT du job dans le framework, grade = grade attribué.
Config.Jobs = {
    { id = 'taxi',    job = 'taxi',    grade = 0 },
    { id = 'trucker', job = 'trucker', grade = 0 },
    { id = 'tow',     job = 'tow',     grade = 0 },
    { id = 'garbage', job = 'garbage', grade = 0 },
}

-- Job attribué lors d'une démission.
Config.Unemployed = { job = 'unemployed', grade = 0 }

-- Délai entre deux changements de métier (secondes).
Config.Cooldown = 300
