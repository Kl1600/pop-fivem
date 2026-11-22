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
-- pop_chat
------------------------------------------------------------------------

Config.Distance = 20.0      -- distance (m) à laquelle les joueurs voient le /me
Config.Cooldown = 2000      -- ms minimum entre deux /me d'un même joueur
Config.MaxLength = 200      -- longueur max d'un message
Config.DisplayTime = 6000   -- ms d'affichage au-dessus de la tête

-- Chat staff : /staff message (ou /sc message), visible uniquement par le staff (même règle que le menu admin).
Config.StaffCommands = { 'staff', 'sc' }
Config.StaffColor = { 93, 144, 236 }   -- bleu du serveur (barre des notifications)
Config.StaffLogColor = { 160, 160, 170 } -- actions admin annoncées au staff
