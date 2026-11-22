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
-- pop_affiche
------------------------------------------------------------------------

-- Statut VIP : 'group' (groupe ESX du joueur) ou 'custom' (votre logique dans server/common.lua).
Config.VIPCheckMethod = 'group'

-- Groupes autorisés à poser, modifier et supprimer des affiches (si VIPCheckMethod = 'group').
Config.VIPGroups = {
    ['vip'] = true,
    ['vip_gold'] = true,
    ['vip_diamond'] = true,
    ['admin'] = true,      -- les administrateurs ont l'autorisation par défaut
    ['superadmin'] = true,
}

-- Affichage : le panneau DUI est créé sous LoadDistance et détruit au-delà de UnloadDistance (mémoire GPU).
Config.LoadDistance = 40.0
Config.UnloadDistance = 60.0

-- Affiche posée par défaut.
Config.DefaultWidth = 0.76
Config.DefaultHeight = 0.95
Config.PlaceRange = 10.0           -- portée du rayon de placement (m)

-- Image des notifications.
Config.NotifyImage = 'https://static.wikia.nocookie.net/gta/images/4/4e/Bahama_Mamas-GTAV-Logo.png'

-- Sécurité (serveur).
Config.ActionCooldown = 2000       -- ms entre deux enregistrements/suppressions d'un joueur
Config.MaxDistance = 30.0          -- distance max du joueur à l'affiche
