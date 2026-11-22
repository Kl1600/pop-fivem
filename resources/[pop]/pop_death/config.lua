Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'auto'
Config.Inventory = 'auto'
Config.Target    = 'auto'
Config.Notify    = 'auto'
Config.AccentColor = '#ffffff'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_death
------------------------------------------------------------------------

-- Temps (secondes) avant la réapparition automatique à l'hôpital.
Config.RespawnTime = 300

-- Touche pour appeler les secours (modifiable par le joueur dans Paramètres > Raccourcis > FiveM).
Config.CallKey = 'G'

-- Délai (secondes) entre deux appels aux secours.
Config.CallCooldown = 60

-- Hôpitaux : le joueur réapparaît au plus proche de l'endroit où il est mort.
Config.Hospitals = {
    { label = 'Pillbox Hill',  coords = vector4(298.6, -584.5, 43.3, 70.0) },
    { label = 'Sandy Shores',  coords = vector4(1839.4, 3672.9, 34.3, 210.0) },
    { label = 'Paleto Bay',    coords = vector4(-247.8, 6331.2, 32.4, 225.0) },
}

-- Faim et soif remises à ce niveau à la réapparition (sur 1 000 000), pour ne pas remourir aussitôt.
Config.RespawnStatus = 500000
