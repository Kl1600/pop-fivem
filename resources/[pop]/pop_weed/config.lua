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

-- ─── pop_weed ───────────────────────────────────────────────

-- Noms des items (à déclarer dans votre inventaire, voir README).
Config.Items = {
    pot        = 'weed_pot',
    seed       = 'weed_seed',
    water      = 'water_bottle',     -- ox_inventory : 'water'
    fertilizer = 'weed_fertilizer',
    harvest    = 'weed',             -- reçoit la métadonnée { quality = 0-100 }
}

Config.GrowTime      = 3600   -- secondes de la plantation à la récolte
Config.WaterDuration = 1800   -- secondes pour passer de 100 % à 0 % d'eau
Config.RotTime       = 86400  -- une plante mûre non récoltée disparaît après ce délai (secondes)

Config.MaxPlants  = 5         -- plantes max par joueur
Config.MinSpacing = 1.5       -- distance minimale entre deux plantes (mètres)
Config.OwnerOnly  = false     -- true : seul le planteur peut récolter

-- Qualité finale = base + engrais - (temps à sec / GrowTime) * dryPenalty, bornée 0-100.
Config.Quality = { base = 75, fertilizer = 25, dryPenalty = 100 }

-- Quantité récoltée = min + (max - min) * qualité / 100 (arrondi inférieur).
Config.Harvest = { min = 2, max = 6 }

-- Durée des actions (ms).
Config.Durations = { plant = 4000, water = 3000, fertilize = 3000, harvest = 6000, destroy = 5000 }

Config.Police = {
    jobs        = { 'police', 'sheriff' }, -- format Bridge.HasJob ; doivent être en service
    alertChance = 0.25,                    -- chance d'alerte à chaque récolte (0 = jamais)
    blipTime    = 60,                      -- durée du blip d'alerte (secondes)
}

-- Distance d'apparition des plantes (mètres).
Config.SpawnDistance = 50.0

-- Stades visuels, répartis à parts égales sur GrowTime. offset = décalage vertical du modèle.
Config.Stages = {
    { model = 'bkr_prop_weed_01_small_01b', offset = 0.0 },
    { model = 'bkr_prop_weed_med_01b',      offset = -2.5 },
    { model = 'bkr_prop_weed_lrg_01b',      offset = -2.5 },
}
