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
-- pop_passport
------------------------------------------------------------------------

-- Distance max (m) côté client pour photographier le titulaire.
Config.HolderRange = 15.0

-- Distance max (m) côté serveur entre le lecteur et le titulaire pour renvoyer son server id.
Config.HolderServerRange = 20.0

-- Délai max (ms) d'attente de la réponse du serveur pour la photo.
Config.HolderTimeout = 2000

-- Durée de validité d'un passeport (années).
Config.ValidityYears = 10

-- Durée d'affichage des notifications (ms).
Config.NotifyUnreadable = 3000
Config.NotifyReceived = 5000
