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
    Interact = { control = 38, label = 'E' }, -- touche de récolte (prompt pop_v3dui)
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_weed
------------------------------------------------------------------------

Config.TotalDuration = 1800         -- 30 minutes pour la récolte
Config.HarvestAmount = 5           -- weed donnés à la récolte
Config.WaterDuration = 1 * 3600    -- eau vide en 1h
Config.DrawDistance  = 4.0         -- distance max du HUD 3D
Config.SpawnDistance = 80.0        -- les props ne sont créés que près du joueur
Config.MaxPlantsPerPlayer = 6      -- plantes max par joueur (0 = illimité), vérifié côté serveur

-- Stages de croissance : minTime = secondes depuis la plantation
Config.Stages = {
    { model = 'bkr_prop_weed_01_small_01c', minTime = 0,    zOffset = 0.0 },  -- stade 1 : tout petit
    { model = 'bkr_prop_weed_01_small_01a', minTime = 300,  zOffset = 0.0 },  -- stade 2 : petit (5 min)
    { model = 'bkr_prop_weed_med_01a',      minTime = 600,  zOffset = -2.5 }, -- stade 3 : moyen (10 min)
    { model = 'bkr_prop_weed_med_01b',      minTime = 900,  zOffset = -2.5 }, -- stade 4 : moyen + (15 min)
    { model = 'bkr_prop_weed_lrg_01a',      minTime = 1350, zOffset = -2.5 }, -- stade 5 : grand (22.5 min)
    { model = 'bkr_prop_weed_lrg_01b',      minTime = 1800, zOffset = -2.5 }, -- stade 6 : prêt à récolter (30 min)
}

Config.ZOffset = 0.0 -- Offset vertical pour le spawn (ajuster si les plantes flottent ou s'enfoncent)

-- Objets pop_inventory utilisés
Config.Items = {
    Pot     = 'pot',
    Seed    = 'grainecana',
    Water   = 'bouteille',
    Harvest = 'weed',
}

-- Distances (m)
Config.ActionDistance     = 5.0  -- serveur : arroser / récolter une plante
Config.PlantDistance      = 15.0 -- serveur : point de plantation
Config.WaterBottleRange   = 3.0  -- client : plante la plus proche quand on utilise la bouteille
Config.HarvestKeyDistance = 2.0  -- client : récolte à la touche E

Config.HarvestDuration  = 5000 -- ms, barre de récolte
Config.WaterLossPerStage = 0.5 -- part d'eau gardée à chaque stade franchi (0.5 = -50 %)
Config.TickInterval     = 5000 -- ms, vérification de la croissance côté serveur

-- Durée d'affichage des notifications (ms)
Config.NotifyDuration = {
    Short  = 2000,
    Normal = 3000,
    Long   = 4000,
}
