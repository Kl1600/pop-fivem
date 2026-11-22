Config = {}

Config.Debug = false

-- Commande qui affiche / cache la barre de voix
Config.Command = 'voice-ui'

-- Cadence de mise à jour (ms) : barre affichée (20 FPS) / barre cachée
Config.ActiveInterval = 50
Config.IdleInterval = 500

-- Débit simulé quand le joueur parle : entre VolumeMin et VolumeMin + VolumeRange (0 à 1)
Config.VolumeMin = 0.6
Config.VolumeRange = 0.4
