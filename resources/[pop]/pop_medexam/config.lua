Config = {}

-- Mode dev : tout le monde peut examiner (ignore le job)
Config.DevMode = false

-- Jobs autorisés à examiner un joueur
Config.EmsJobs = {
  ['youtool'] = true,
  ['ems']       = true,
}

-- Distance max pour garder l'examen ouvert (le joueur examiné s'éloigne -> fermeture)
Config.MaxExamDistance = 3.5

-- Touche pour fermer l'examen (control id) : 73 = X, 322 = ESC
Config.CloseControl = 73

-- Définition des zones du corps.
--  key     : identifiant interne
--  label   : texte affiché
--  boneTag : "bone tag" GTA utilisé par GetPedBoneCoords pour positionner
--            l'étiquette à l'endroit réel de l'os à l'écran
Config.BodyParts = {
  { key = 'head',     label = 'Tête',         boneTag = 31086 }, -- SKEL_Head
  { key = 'torso',    label = 'Torse',        boneTag = 24818 }, -- SKEL_Spine3
  { key = 'leftArm',  label = 'Bras Gauche',  boneTag = 61163 }, -- SKEL_L_Forearm
  { key = 'rightArm', label = 'Bras Droit',   boneTag = 28252 }, -- SKEL_R_Forearm
  { key = 'leftLeg',  label = 'Jambe Gauche', boneTag = 63931 }, -- SKEL_L_Calf
  { key = 'rightLeg', label = 'Jambe Droite', boneTag = 36864 }, -- SKEL_R_Calf
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
