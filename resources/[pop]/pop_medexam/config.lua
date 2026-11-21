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
-- pop_medexam
------------------------------------------------------------------------

-- Mode dev : tout le monde peut examiner (ignore le job)
Config.DevMode = false

-- Jobs autorisés à examiner un joueur
-- (nom du job ESX : 'ambulance' = job médical standard d'ESX ; 'youtool' retiré, nom inconnu)
Config.EmsJobs = {
  ['ambulance'] = true,
  ['ems']       = true,
}

-- Distance max entre le soignant et le patient pour soigner (vérifiée par le serveur)
Config.MaxTreatDistance = 5.0

-- Distance d'interaction ox_target
Config.TargetDistance = 2.5

-- Distance max pour garder l'examen ouvert (le joueur examiné s'éloigne -> fermeture)
Config.MaxExamDistance = 3.5

-- Touche pour fermer l'examen (control id) : 73 = X, 322 = ESC
Config.CloseControl = 73

-- Définition des zones du corps.
--  key     : identifiant interne (texte affiché : locales/fr.lua, clé part_<key>)
--  boneTag : "bone tag" GTA utilisé par GetPedBoneCoords pour positionner
--            l'étiquette à l'endroit réel de l'os à l'écran
Config.BodyParts = {
  { key = 'head', boneTag = 31086 }, -- SKEL_Head
  { key = 'torso', boneTag = 24818 }, -- SKEL_Spine3
  { key = 'leftArm', boneTag = 61163 }, -- SKEL_L_Forearm
  { key = 'rightArm', boneTag = 28252 }, -- SKEL_R_Forearm
  { key = 'leftLeg', boneTag = 63931 }, -- SKEL_L_Calf
  { key = 'rightLeg', boneTag = 36864 }, -- SKEL_R_Calf
}

-- Mapping des "bone tags" renvoyés par GetPedLastDamageBone -> zone du corps.
-- Permet d'attribuer les dégâts subis à la bonne zone.
Config.BoneToPart = {
  -- Tête / cou
  [31086] = 'head',  [39317] = 'head',
  -- Torse / colonne / bassin
  [57597] = 'torso', [23553] = 'torso', [24816] = 'torso',
  [24817] = 'torso', [24818] = 'torso', [11816] = 'torso', [0] = 'torso',
  -- Bras gauche
  [64729] = 'leftArm', [45509] = 'leftArm', [61163] = 'leftArm', [18905] = 'leftArm',
  -- Bras droit
  [10706] = 'rightArm', [40269] = 'rightArm', [28252] = 'rightArm', [57005] = 'rightArm',
  -- Jambe gauche
  [58271] = 'leftLeg', [63931] = 'leftLeg', [14201] = 'leftLeg', [2108] = 'leftLeg',
  -- Jambe droite
  [51826] = 'rightLeg', [36864] = 'rightLeg', [52301] = 'rightLeg', [20781] = 'rightLeg',
}
