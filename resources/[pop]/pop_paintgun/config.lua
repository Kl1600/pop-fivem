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

-- ─── pop_paintgun ────────────────────────────────────────────

-- Pistolet à peinture (non consommé) et pot de peinture consommé à chaque utilisation (nil = aucun).
Config.Item      = 'spray_gun'
Config.PaintItem = 'paint_can'

-- false = tout porteur de l'item ; sinon jobs requis (format Bridge.HasJob, en service). Ex. { 'mechanic' }
Config.Jobs = false

-- Durée de la peinture (ms).
Config.Duration = 8000

-- Couleurs proposées : id = couleur native GTA, hex = aperçu de la pastille.
Config.Colors = {
    { id = 0,   hex = '#0a0a0a' }, { id = 1,   hex = '#1c1d21' }, { id = 4,   hex = '#999da0' },
    { id = 111, hex = '#ffffff' }, { id = 112, hex = '#eaeaea' }, { id = 158, hex = '#9a9fa0' },
    { id = 27,  hex = '#c01618' }, { id = 28,  hex = '#8c1b1d' }, { id = 150, hex = '#c0171c' },
    { id = 37,  hex = '#e25a29' }, { id = 38,  hex = '#f6901a' }, { id = 88,  hex = '#ffc400' },
    { id = 89,  hex = '#fcea5f' }, { id = 92,  hex = '#9acc40' }, { id = 53,  hex = '#777c4c' },
    { id = 54,  hex = '#2f592a' }, { id = 49,  hex = '#bfad8f' }, { id = 45,  hex = '#584635' },
    { id = 64,  hex = '#59667c' }, { id = 70,  hex = '#355e9c' }, { id = 71,  hex = '#4e6dc9' },
    { id = 74,  hex = '#6ea9c4' }, { id = 135, hex = '#f21896' }, { id = 137, hex = '#bf5bb0' },
    { id = 145, hex = '#622699' }, { id = 132, hex = '#0d1116' }, { id = 91,  hex = '#dec397' },
}
