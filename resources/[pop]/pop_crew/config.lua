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
-- pop_crew
------------------------------------------------------------------------

-- Commande qui ouvre / ferme le menu
Config.Command   = 'crew'

-- Longueur max du tag (name) et du label affiché
Config.MaxTagLen   = 12   -- identifiant court unique, ex: "BLLS"
Config.MaxLabelLen = 32   -- nom affiché, ex: "Ballas"

-- Couleur par défaut d'un crew { r, g, b } (utilisée par pop_territories pour colorer la map)
Config.DefaultColor = { 200, 70, 190 }

-- Recrutement (ox_target sur un joueur)
Config.RecruitTargetDistance = 2.5  -- distance de l'option ox_target
Config.RecruitMaxDistance    = 10.0 -- distance max chef ↔ cible vérifiée par le serveur

-- Une ancienne version liait /crew à F7 (noclip admin) : appel ignoré si cette touche est enfoncée.
Config.IgnoredControl = 168

-- Durée d'affichage des notifications (ms)
Config.NotifyDuration       = 5000 -- serveur
Config.ClientNotifyDuration = 4000 -- client (joueur introuvable)
