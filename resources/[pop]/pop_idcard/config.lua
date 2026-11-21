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
-- pop_idcard
------------------------------------------------------------------------

-- Objets pop_inventory donnés selon la nationalité.
Config.CardItem   = 'idcard'
Config.CardItemMx = 'idcard_mx'

-- Nationalité (pop_charcreator) qui donne la carte mexicaine.
Config.MexicoNationality = 'nuevopaso'

-- Photo du titulaire : distance max (m) côté client pour photographier son ped,
-- et côté serveur pour renvoyer son server id.
Config.HolderRange       = 15.0
Config.HolderServerRange = 20.0

-- Délai max (ms) d'attente de la réponse du serveur pour la photo.
Config.HolderTimeout = 2000

-- Durée des notifications (ms).
Config.NotifyUnreadableDuration = 3000
Config.NotifyReceivedDuration   = 5000
