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
-- pop_vehiclepersistence
------------------------------------------------------------------------

-- Si true, le script vérifiera que le joueur possède l'item 'carkeys' correspondant à la plaque de son véhicule via l'inventaire pop_inventory pour le sauvegarder.
-- Si false, le script sauvegardera tous les véhicules dans lesquels le joueur monte, sans distinction de clefs.
Config.UseTabInventory = true

-- Durée maximale de persistance d'un véhicule SANS interaction du joueur, en JOURS.
-- Si un véhicule n'est ni conduit ni sauvegardé pendant cette durée, il est
-- automatiquement supprimé (base de données + monde) pour éviter l'accumulation
-- de véhicules abandonnés.
-- "Interaction" = monter/conduire/sauvegarder le véhicule. Une simple connexion au
-- serveur NE compte PAS comme une interaction (sinon rien n'expirerait jamais).
-- Mettre à 0 pour désactiver l'expiration (persistance illimitée).
Config.MaxPersistenceDays = 30

-- Identifiant utilisé comme propriétaire (owner_id) des véhicules :
--   'license'   = license Rockstar (universel, recommandé, indépendant du framework)
--   'framework' = identifier ESX / citizenid QB/Qbox
-- ⚠️ À fixer AVANT la mise en service : changer cette valeur sur une base existante
--    "détache" les véhicules déjà enregistrés (leur owner_id ne correspondra plus).
Config.OwnerKey = 'license'

-- Hooks avancés (laisser nil pour le comportement auto). À définir uniquement pour
-- un cas vraiment spécifique, sans toucher au code du script :
--   Config.CustomIdentifier = function(src) return ... end          -- côté serveur
--   Config.CustomNotify     = function(msg, ntype) ... end           -- côté client
Config.CustomIdentifier = nil
Config.CustomNotify     = nil

-- Vérification des clés (opt-in). nil = comportement par défaut INCHANGÉ :
--   • UseTabInventory = true  -> clés via pop_inventory (item 'carkeys')
--   • UseTabInventory = false -> tout véhicule conduit est sauvegardé
-- Définir cette fonction pour brancher TON système de clés nominatives (qb-vehiclekeys,
-- système maison, etc.). Reçoit (src, plate), doit renvoyer true/false. Quand elle est
-- définie, elle remplace entièrement la vérif pop_inventory. Exemple :
--   Config.HasVehicleKey = function(src, plate)
--       return exports['mon_systeme_cles']:HasKey(src, plate)
--   end
Config.HasVehicleKey = nil

-- Rayon (m) autour des joueurs dans lequel les véhicules persistés apparaissent.
Config.CullRadius = 250.0

-- Distance max (m) entre le joueur et le véhicule dont il envoie les données.
Config.MaxClientDistance = 75.0
