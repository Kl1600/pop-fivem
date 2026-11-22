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
-- pop_charcreator
------------------------------------------------------------------------

-- Durée d'affichage des notifications (ms).
Config.NotifyDuration = 5000

-- =============================================================
-- LIEU D'APPARITION (sortie du créateur de personnage)
-- -------------------------------------------------------------
-- Le joueur choisit son spawn dans l'UI du créateur (USA / Mexique).
-- Définis ici les coordonnées + heading de chaque lieu.
--
--  coords  : position d'apparition (vector3)
--  heading : orientation du joueur (degrés)
--  label   : texte affiché sur le bouton dans le créateur
--
-- DefaultSpawn = clé utilisée si le joueur n'a rien choisi / valeur
-- invalide reçue (sécurité).
-- =============================================================
Config.DefaultSpawn = 'losantos'

Config.SpawnPoints = {
    ['losantos'] = {
        label   = 'Los Santos',      -- Ville du sud
        coords  = vector3(-536.7485, -217.9594, 37.6498),
        heading = 206.7365,
    },
    ['nuevopaso'] = {
        label   = 'Nuevo Paso',      -- Ville du nord
        coords  = vector3(1841.5447, 3668.9382, 33.6800),
        heading = 220.8411,
    },
}

-- =============================================================
-- MODE "80s" (thème rétro années 80)
-- -------------------------------------------------------------
-- true  : applique l'habillage rétro 80s à l'interface du créateur.
-- false : interface moderne par défaut.
-- =============================================================
Config.Mode80s = true

-- =============================================================
-- DATE DE NAISSANCE : saisie libre au format JJ/MM/AAAA
-- (les « / » s'ajoutent automatiquement, aucune limite d'année).
-- =============================================================
Config.BirthDate = {}

-- =============================================================
-- GESTION DE LA TAILLE DU PERSONNAGE (HAUTEUR)
-- -------------------------------------------------------------
-- true  : active le réglage de la taille dans le créateur.
-- false : désactive l'onglet / la modification de la taille.
-- =============================================================
Config.EnableHeight = false

