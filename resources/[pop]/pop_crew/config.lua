Config = {}

------------------------------------------------------------------------
-- Common POP settings (Réglages communs POP) — do not remove
------------------------------------------------------------------------
Config.Locale    = 'fr'   -- 'fr' | 'en' | 'es' | 'de' | 'ar' (English is the fallback)
Config.Debug     = false  -- console messages (messages console)
Config.Framework = 'auto' -- 'auto' | 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'auto' | 'pop_inventory' | 'ox_inventory' | 'qb-inventory' | ...
Config.Target    = 'auto' -- 'auto' | 'ox_target' | 'qb-target' | 'prompt' (E key / touche E)
Config.Notify    = 'auto' -- 'auto' : pop_notify if running, else framework, else native
Config.AccentColor = '#5d90ec'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_crew
------------------------------------------------------------------------

-- Command that opens / closes the menu (commande qui ouvre / ferme le menu)
Config.Command   = 'crew'

-- Longueur max du tag (name) et du label affiché
Config.MaxTagLen   = 12   -- identifiant court unique, ex: "BLLS"
Config.MaxLabelLen = 32   -- nom affiché, ex: "Ballas"

-- Default crew color { r, g, b }, used on the map by pop_territories (couleur par défaut d'un crew)
Config.DefaultColor = { 93, 144, 236 }

-- Recruiting a nearby player: ox_target, qb-target or E key (recrutement d'un joueur proche)
Config.RecruitTargetDistance = 2.5  -- distance de l'option ox_target
Config.RecruitMaxDistance    = 10.0 -- distance max chef ↔ cible vérifiée par le serveur

-- Une ancienne version liait /crew à F7 (noclip admin) : appel ignoré si cette touche est enfoncée.
Config.IgnoredControl = 168

-- Durée d'affichage des notifications (ms)
Config.NotifyDuration       = 5000 -- serveur
Config.ClientNotifyDuration = 4000 -- client (joueur introuvable)
