Config = {}

Config.TotalDuration = 1800         -- 30 minutes pour la récolte
Config.HarvestAmount = 5           -- weed donnés à la récolte
Config.WaterDuration = 1 * 3600    -- eau vide en 1h
Config.DrawDistance  = 4.0         -- distance max du HUD 3D

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
