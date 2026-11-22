Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | ...
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- pop_notify s'il est lancé
Config.AccentColor = '#ffffff'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_hud
------------------------------------------------------------------------

Config.StatusRefresh = 200   -- ms entre deux lectures vie / faim / soif / voix (envoi seulement si changement)
Config.RadarRefresh  = 200   -- ms entre deux réapplications des réglages de la mini-carte
Config.RadarZoom     = 1100  -- zoom fixe de la mini-carte

-- Position de la mini-carte ronde (texture stream/circlemap.ytd)
Config.Minimap = {
    { 'minimap',      'L', 'B', -0.0045, 0.002, 0.150, 0.18888 },
    { 'minimap_mask', 'L', 'B', 0.021, 0.032, 0.1112, 0.159 },
    { 'minimap_blur', 'L', 'B', -0.0005, 0.008, 0.199999, 0.272 },
}
