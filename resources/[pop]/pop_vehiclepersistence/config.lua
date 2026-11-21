Config = {}

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

-- ─── Compatibilité framework ─────────────────────────────────────────────────
-- Tout est en 'auto' par défaut : le script détecte seul ESX / QBCore / Qbox, et
-- tombe en standalone si aucun n'est présent. Ne change ces valeurs que si la
-- détection se trompe ou pour forcer un comportement.

-- 'auto' | 'esx' | 'qb' | 'qbox' | 'standalone'
Config.Framework = 'auto'

-- Système de notification : 'auto' (ox_lib si présent, sinon le framework, sinon chat)
-- 'auto' | 'ox_lib' | 'esx' | 'qb' | 'chat'
Config.Notification = 'auto'

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
