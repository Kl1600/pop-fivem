Config = {}

-- THEME : 'modern' (2026) ou 'retro80' (MDT année 80s phosphore ambre)
-- Cette ressource (pop_police80) est dédiée au MDT 80s : on force le thème retro.
Config.Theme = 'retro80'

-- DEV MODE : ignore le job, tout le monde peut ouvrir/utiliser le dispatch
Config.DevMode = false

-- Nom affiché dans le header de l'UI selon le job du joueur
-- Clé 'default' = fallback si le job ne correspond à aucune entrée
Config.DeptNames = {
  ['police'] = 'POLICE',
  ['lspd']   = 'LSPD',
  ['bcso']   = 'BCSO',
  ['sasp']   = 'SASP',
  ['ems']    = 'EMS',
  ['default'] = 'LSPD',
}

Config.ManagementGrades = {
  ['Capitaine'] = true,
  ['Commandant'] = true,
  ['Commissaire'] = true
}

-- Jobs considérés comme police (ou autorisés à utiliser le dispatch)
Config.PoliceJobs = { 'police', 'lspd', 'bcso', 'sasp', 'ems' }

-- Job simulé en DevMode (pour tester l'affichage d'un département spécifique)
-- Valeurs possibles : 'police', 'lspd', 'bcso', 'sasp', 'ems'
Config.DevJob = 'bcso'

-- Grade affiché en DevMode quand le vrai job ESX n'est pas un job police
Config.DevGrade = 'Capitaine'

-- Liste des grades disponibles dans le menu d'édition des agents
Config.Grades = {
  'Stagiaire', 'Agent', 'Brigadier', 'Inspecteur',
  'Sergent', 'Lieutenant', 'Capitaine', 'Commandant', 'Commissaire',
}

-- Touche par défaut pour ouvrir l'UI
Config.OpenKey = 'F10'

-- Touche par défaut pour le bind renfort (modifiable dans l'UI)
Config.DefaultBackupKey = 'F7'

-- Modèles de véhicules considérés comme véhicules de police
-- (laisser vide pour utiliser le détection par classe/22 = LE)
Config.PoliceVehicleClass = 18

-- Cadence d'envoi de la position véhicule (ms)
Config.VehicleSyncInterval = 500

-- Niveaux de renfort
Config.BackupLevels = {
  [1] = { label = 'Faible',  color = '#3498db', sprite = 161, soundFile = nil    },
  [2] = { label = 'Modéré',  color = '#f39c12', sprite = 161, soundFile = 'Beep_Red' },
  [3] = { label = 'Urgent',  color = '#e74c3c', sprite = 161, soundFile = 'Beep_Red' }
}

-- Codes de situation (10-codes)
Config.SituationCodes = {
  { code = '10-8',  label = 'En service / Disponible' },
  { code = '10-6',  label = 'Occupé' },
  { code = '10-7',  label = 'Hors service' },
  { code = '10-23', label = 'Sur place' },
  { code = '10-50', label = 'Accident' },
  { code = '10-80', label = 'Poursuite' },
  { code = 'CODE 2', label = 'Intervention prioritaire' },
  { code = 'CODE 3', label = 'Intervention urgente sirène' },
  { code = 'CODE 4', label = 'Situation sous contrôle' },
}
