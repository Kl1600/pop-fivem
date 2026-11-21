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
-- pop_kilometrage
------------------------------------------------------------------------

-- Intervalle de verification de la distance parcourue (ms)
Config.CheckInterval = 1000

-- Distance minimale (en km) parcourue avant d'envoyer une mise a jour au serveur,
-- pour eviter de spam la base de donnees.
Config.ServerUpdateThreshold = 0.1

-- Écriture groupée en base toutes les X ms
Config.FlushInterval = 60000

-- Saut maximal accepté (km) entre deux mises à jour (anti-triche)
Config.MaxStepKm = 10.0
