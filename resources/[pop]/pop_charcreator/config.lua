Config = {}

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
-- DATE DE NAISSANCE
-- -------------------------------------------------------------
-- Le serveur se déroule en 1980 : le champ reste librement
-- modifiable, mais on interdit une année incohérente avec l'époque
-- (impossible d'être né après le serveur, ex. 1990) tout en imposant
-- un âge minimum réaliste.
--
--  serverYear : année en jeu (le perso ne peut pas être né après).
--  minAge     : âge minimum -> année de naissance max = serverYear - minAge.
--  minYear    : borne basse de sécurité.
-- =============================================================
Config.BirthDate = {
    serverYear = 1980,
    minAge     = 18,
    minYear    = 1900,
}

-- =============================================================
-- GESTION DE LA TAILLE DU PERSONNAGE (HAUTEUR)
-- -------------------------------------------------------------
-- true  : active le réglage de la taille dans le créateur.
-- false : désactive l'onglet / la modification de la taille.
-- =============================================================
Config.EnableHeight = false

