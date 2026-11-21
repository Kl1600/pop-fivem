Config = {}

-- Script d'affichage sans framework : pas de bridge.
Config.Debug = false

-- Unité : km/h par défaut ; mettre la convar sh_miles à 1 pour les mph.
Config.UseMetric = GetConvarInt('sh_miles', 0) == 0

Config.RefreshDriving = 150  -- ms entre deux mises à jour en conduite
Config.RefreshIdle    = 750  -- ms quand le compteur est caché
Config.MileageTicks   = 7    -- le kilométrage (pop_kilometrage) est relu toutes les N mises à jour (~1 s)
