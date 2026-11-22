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
-- pop_boards
------------------------------------------------------------------------

-- Affichage : le panneau DUI est créé sous LoadDistance et détruit au-delà de UnloadDistance (mémoire GPU).
Config.LoadDistance = 40.0
Config.UnloadDistance = 60.0

-- Tableau posé par défaut (toile vierge).
Config.DefaultWidth = 0.76
Config.DefaultHeight = 0.95
Config.DefaultRes = 1024
Config.DefaultCanvas = 'nui://pop_boards/html/toile.png'
Config.PlaceRange = 10.0           -- portée du rayon de placement (m)

-- Image des notifications.
Config.NotifyImage = 'https://static.wikia.nocookie.net/gta/images/9/91/Auction-GTAO.png'

-- Sécurité (serveur).
Config.MaxDistance = 30.0          -- distance max du joueur au tableau (pose, peinture)
Config.RequestDistance = 80.0      -- distance max pour recevoir l'image d'un tableau
Config.MaxImageLen = 10000000      -- ~10 Mo par image
Config.MaxBoardsPerPlayer = 5      -- tableaux posés par joueur (admins illimités)
Config.SaveCooldown = 3000         -- ms entre deux sauvegardes d'un même joueur
Config.RequestCooldown = 5000      -- ms entre deux demandes du même tableau par un joueur
Config.RequestMaxPer10s = 12       -- demandes de tableaux max par joueur sur 10 s
