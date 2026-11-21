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

-- ─── pop_enterprisegarage ────────────────────────────────────

-- Véhicules sortis en même temps par joueur.
Config.MaxPerPlayer = 1

-- Garages. id : unique. job : nom du job (en service). coords : comptoir (à pied).
-- spawns : places de sortie (x, y, z, cap). store : centre de la zone de rangement (au volant).
-- plate : préfixe de plaque (4 caractères max). blip : nil = aucun.
-- vehicles : model, grade minimum, type (GetVehicleType : 'automobile' par défaut, 'bike', 'heli', 'boat'...).
Config.Garages = {
    {
        id = 'lspd', job = 'police', plate = 'LSPD',
        coords = vec3(454.6, -1017.4, 28.4),
        spawns = { vec4(438.6, -1018.6, 28.4, 90.0), vec4(438.6, -1022.4, 28.4, 90.0) },
        store  = vec3(446.0, -1020.0, 28.4),
        blip   = { sprite = 357, color = 38 },
        vehicles = {
            { model = 'police',  grade = 0 },
            { model = 'police2', grade = 1 },
            { model = 'police3', grade = 2 },
            { model = 'policeb', grade = 2, type = 'bike' },
        },
    },
    {
        id = 'ems', job = 'ambulance', plate = 'EMS',
        coords = vec3(294.9, -574.6, 43.2),
        spawns = { vec4(294.6, -603.9, 43.1, 0.0) },
        store  = vec3(294.6, -598.0, 43.1),
        blip   = { sprite = 357, color = 1 },
        vehicles = {
            { model = 'ambulance', grade = 0 },
        },
    },
}
