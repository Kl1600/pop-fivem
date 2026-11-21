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

-- Use false for free shops. Standalone sessions are always free.
Config.Account = 'cash'
Config.Currency = '$'
Config.ShopDistance = 4.0
Config.SessionSeconds = 180

-- Optional job restriction: job = { 'tailor' }, onDuty = true.
Config.Shops = {
    { kind = 'clothing', coords = vector3(72.24, -1399.12, 29.38) },
    { kind = 'clothing', coords = vector3(-708.42, -152.31, 37.42) },
    { kind = 'clothing', coords = vector3(425.7, -806.1, 29.49) },
    { kind = 'clothing', coords = vector3(5.2, 6513.2, 31.88) },
    { kind = 'barber', coords = vector3(-814.11, -183.64, 37.57) },
    { kind = 'barber', coords = vector3(138.05, -1709.12, 29.30) },
    { kind = 'tattoo', coords = vector3(1323.46, -1652.04, 52.28) },
    { kind = 'tattoo', coords = vector3(-1153.55, -1425.58, 4.96) },
}

-- Component/prop values are { drawable, texture }, for male and female respectively.
-- A drawable of -1 clears a prop or a head overlay.
Config.Catalog = {
    { id = 'tops', kind = 'clothing', native = 'component', slot = 11, options = {
        { id = 'basic', label = 'basic', price = 60, male = { 0, 0 }, female = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 80, male = { 2, 0 }, female = { 2, 0 } },
        { id = 'colorway', label = 'colorway', price = 80, male = { 2, 1 }, female = { 2, 1 } },
    } },
    { id = 'legs', kind = 'clothing', native = 'component', slot = 4, options = {
        { id = 'basic', label = 'basic', price = 55, male = { 0, 0 }, female = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 70, male = { 3, 0 }, female = { 3, 0 } },
        { id = 'colorway', label = 'colorway', price = 70, male = { 3, 1 }, female = { 3, 1 } },
    } },
    { id = 'shoes', kind = 'clothing', native = 'component', slot = 6, options = {
        { id = 'basic', label = 'basic', price = 45, male = { 1, 0 }, female = { 1, 0 } },
        { id = 'alternate', label = 'alternate', price = 60, male = { 3, 0 }, female = { 3, 0 } },
    } },
    { id = 'hats', kind = 'clothing', native = 'prop', slot = 0, options = {
        { id = 'none', label = 'none', price = 0, male = { -1, 0 }, female = { -1, 0 } },
        { id = 'basic', label = 'basic', price = 50, male = { 0, 0 }, female = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 65, male = { 2, 0 }, female = { 2, 0 } },
    } },
    { id = 'glasses', kind = 'clothing', native = 'prop', slot = 1, options = {
        { id = 'none', label = 'none', price = 0, male = { -1, 0 }, female = { -1, 0 } },
        { id = 'basic', label = 'basic', price = 30, male = { 0, 0 }, female = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 65, male = { 1, 0 }, female = { 1, 0 } },
    } },
    { id = 'hair', kind = 'barber', native = 'hair', slot = 2, options = {
        { id = 'basic', label = 'basic', price = 45, male = { 0, 0 }, female = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 55, male = { 4, 0 }, female = { 4, 0 } },
        { id = 'colorway', label = 'colorway', price = 65, male = { 4, 12 }, female = { 4, 12 } },
    } },
    { id = 'beard', kind = 'barber', native = 'overlay', slot = 1, options = {
        { id = 'none', label = 'none', price = 0, male = { -1, 0 } },
        { id = 'basic', label = 'basic', price = 30, male = { 0, 0 } },
        { id = 'alternate', label = 'alternate', price = 35, male = { 2, 0 } },
    } },
    { id = 'tattoos', kind = 'tattoo', native = 'tattoo', options = {
        { id = 'none', label = 'none', price = 0, male = {}, female = {} },
        { id = 'winged', label = 'winged', price = 240,
            male = { 'mpairraces_overlays', 'MP_Airraces_Tattoo_002_M' },
            female = { 'mpairraces_overlays', 'MP_Airraces_Tattoo_002_F' } },
        { id = 'barrel', label = 'barrel', price = 300,
            male = { 'mpairraces_overlays', 'MP_Airraces_Tattoo_007_M' },
            female = { 'mpairraces_overlays', 'MP_Airraces_Tattoo_007_F' } },
    } },
}
