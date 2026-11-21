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
-- pop_bank
------------------------------------------------------------------------

-- Deux agences : USA (vraie Fleeca Bank de la map, cf. pop_management Config.Blips) et Mexique.
-- Mexique : aucune banque modélisée dans la zone actuelle, position provisoire à ajuster par l'équipe.
Config.Locations = {
    {
        id      = 'usa',
        label   = 'Banque - Los Santos',
        coords  = vector3(150.2, -1040.2, 30.3),
        heading = 110.0,
    },
    {
        id      = 'mexico',
        label   = 'Banque - Mexique (provisoire)',
        coords  = vector3(2469.0, 4071.0, 39.0),
        heading = 0.0,
    },
}

Config.TargetZoneSize = vector3(1.5, 1.5, 2.0)

-- Distance max (m) entre le joueur et une agence pour accepter une action bancaire.
Config.MaxBankDistance = 10.0

-- Taille des coffres servant de compte (pop_inventory).
Config.AccountSlots = 50
Config.AccountMaxWeight = 1000.0

-- Durée d'affichage des notifications (ms).
Config.NotifyDuration = 6000
