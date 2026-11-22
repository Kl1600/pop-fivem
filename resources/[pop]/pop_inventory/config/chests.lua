-- Coffres fixes et salles de casiers.

-- Conteneurs distants configurables (inventaires partagés, sans prop physique).
-- Chaque entrée définit une zone interactive dans le monde.
-- L'inventaire est persistant et partagé entre tous les joueurs.
Config.StaticChests = {
  -- Exemple de conteneur : supprimer ou modifier selon vos besoins
  {
    id        = 'depot_central',       -- Identifiant unique (clé DB)
    label     = 'Dépôt Central',       -- Nom affiché dans l'UI
    coords    = vector3(492.4869, -992.4598, 27.6993), -- Position dans le monde
    slots     = 40,                    -- Nombre de slots
    maxWeight = 200.0,                 -- Poids max en kg
    radius    = 1.0,                   -- Rayon d'interaction (en mètres)
    marker = {
      enabled = false,
      type    = 1,                     -- Type de marqueur GTA (1 = cylindre)
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'sams',
    label     = 'le dépôt Médical',
    coords    = vector3(-820.0074, -1242.9933, 7.3374),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'ambulance' },       -- Restreint aux ambulanciers
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'bennys',
    label     = 'le dépôt',
    coords    = vector3(-820.0074, -1242.9933, 7.3374),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'mechanic' },        -- Restreint aux mécanos/bennys
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'cleelspd',
    label     = 'le coffret à clés',
    coords    = vector3(469.1551, -974.7968, 27.2727),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'police' },          -- Restreint aux policiers
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'armurerielspd',
    label     = "l'Armurerie LSPD",
    coords    = vector3(364.6354, -1604.0372, 25.4517),
    heading   = 219.6837,
    slots     = 80,
    maxWeight = 500.0,
    radius    = 1.5,
    jobs      = { 'police', 'lspd', 'bcso', 'sasp' },
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'saisieslspd',
    label     = 'les Saisies LSPD',
    coords    = vector3(381.1659, -1609.1726, 30.2028),
    heading   = 228.9951,
    slots     = 100,
    maxWeight = 1000.0,
    radius    = 1.5,
    jobs      = { 'police', 'lspd', 'bcso', 'sasp' },
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  -- {
  --   id        = 'entrepot_sud',
  --   label     = 'Entrepôt Sud',
  --   coords    = vector3(0.0, 0.0, 0.0),
  --   slots     = 20,
  --   maxWeight = 100.0,
  --   radius    = 2.5,
  --   marker    = { enabled = true, type = 1, color = { r = 255, g = 150, b = 50, a = 180 } },
  -- },
}

-- ==========================================
-- SALLES DE CASIERS (matricule = numéro de casier)
-- ==========================================
-- Chaque salle est un conteneur distant persistant et partagé, peuplé automatiquement
-- de `count` items 'casier' (un par matricule possible). Point FIXE : l'interaction se
-- fait par prompt v3DUI + touche (pas d'ox_target), géré dans standby_client.lua. Deux
-- touches sur le même point :
--  - [E] "Mon casier" -> ouvre DIRECTEMENT le contenu de VOTRE casier (matricule = votre
--    numéro d'employé pour ce job), sans liste ni code (sous-conteneur ouvert d'office).
--  - [G] "Parcourir les casiers" -> ouvre la salle entière (grille de tous les casiers) ;
--    ouvrir un casier qui n'est pas le vôtre demande le code (géré dans pop_management,
--    fiche employé).
-- Le matricule/code de chaque employé est attribué et consultable via pop_management.
-- NB : le help-notification suit Config.UI.HelpNotificationType ('pop_v3dui' recommandé).
Config.LockerRooms = {
  {
    id        = 'lspd_lockers',
    label     = 'les Casiers du LSPD',
    coords    = vector3(452.6, -984.5, 30.69),
    job       = 'police',              -- Job requis + filtre matricule/code
    count     = 20,                    -- Nombre de casiers (matricules 1 à 20)
    slots     = 8,                     -- Slots par casier
    maxWeight = 15.0,
    radius    = 1.5,                   -- Rayon d'interaction (touche E/G)
  },
}
