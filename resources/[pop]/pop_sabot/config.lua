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

-- ─── pop_sabot ───────────────────────────────────────────────

-- Items (à déclarer dans votre inventaire, voir README). cutter = nil : découpe impossible.
Config.Items = {
    clamp  = 'wheel_clamp',   -- poser (rendu quand un agent le retire)
    cutter = 'angle_grinder', -- découper (non consommé)
}

-- Jobs qui posent et retirent le sabot (format Bridge.HasJob, en service).
Config.Jobs = { 'police', 'mechanic' }

-- Durées (ms).
Config.Durations = { place = 5000, remove = 4000, cut = 20000 }

-- Alerte police quand quelqu'un commence à découper un sabot.
Config.CutAlert   = true
Config.PoliceJobs = { 'police', 'sheriff' }
Config.BlipTime   = 60 -- secondes

-- Prop du sabot (modèle à streamer, voir README). Modèle absent = sabot actif sans prop.
Config.Prop = {
    model    = 'prop_clamp',
    bone     = 'wheel_lf',
    offset   = vec3(-0.1, 0.15, -0.3),
    rotation = vec3(180.0, 200.0, 90.0),
}
