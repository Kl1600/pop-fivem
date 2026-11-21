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

-- ─── pop_bennys ──────────────────────────────────────────────

-- Compte débité : 'cash' | 'bank'. En standalone (aucun argent), mettre tous les prix à 0.
Config.Account = 'bank'

-- Écrit les propriétés achetées dans la table du framework (owned_vehicles / player_vehicles) si le véhicule y est.
Config.SaveToFramework = true

-- Ateliers. jobs = false : public ; sinon format Bridge.HasJob, en service (ex. { mechanic = 0 }).
Config.Shops = {
    { coords = vec3(-211.94, -1324.53, 30.45), radius = 4.0, jobs = false, blip = true },
}

-- Prix. Performance : prix du niveau 1, 2, 3... (le nombre d'entrées limite les niveaux proposés).
Config.Prices = {
    paint = 500,        -- par couleur changée
    wheels = 800,       -- jante
    body = 600,         -- par pièce
    engine = { 2500, 5000, 7500, 10000 },
    brakes = { 1500, 3000, 4500 },
    transmission = { 2000, 4000, 6000 },
    suspension = { 1000, 2000, 3000, 4000 },
    armor = { 2500, 5000, 7500, 10000, 12500 },
    turbo = 7500,
    xenon = 1000,       -- activation ou couleur
    neon = 1500,        -- disposition ou couleur
    tint = 400,
}

-- Palette de peinture : id = couleur native GTA, hex = aperçu.
Config.Colors = {
    { id = 0,   hex = '#0a0a0a' }, { id = 1,   hex = '#1c1d21' }, { id = 4,   hex = '#999da0' },
    { id = 111, hex = '#ffffff' }, { id = 27,  hex = '#c01618' }, { id = 28,  hex = '#8c1b1d' },
    { id = 38,  hex = '#f6901a' }, { id = 88,  hex = '#ffc400' }, { id = 92,  hex = '#9acc40' },
    { id = 54,  hex = '#2f592a' }, { id = 64,  hex = '#59667c' }, { id = 70,  hex = '#355e9c' },
    { id = 74,  hex = '#6ea9c4' }, { id = 135, hex = '#f21896' }, { id = 145, hex = '#622699' },
    { id = 45,  hex = '#584635' }, { id = 49,  hex = '#bfad8f' }, { id = 156, hex = '#a3a3a3' },
}

-- Couleurs de néons proposées (r, g, b).
Config.NeonColors = {
    { 255, 46, 136 }, { 34, 211, 238 }, { 255, 255, 255 }, { 255, 0, 0 },
    { 0, 255, 0 }, { 0, 80, 255 }, { 255, 200, 0 }, { 150, 0, 255 },
}
