Config = {}

-- Langue : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
Config.Locale = 'en'

-- Affiche les messages de diagnostic dans la console.
Config.Debug = false

-- 'auto' détecte ce qui est lancé. Sinon, forcer :
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- 'framework' | 'ox_lib' | 'pop' | 'native'

-- Couleur d'accent de l'interface. Rose néon par défaut, cyan : '#22d3ee'.
Config.AccentColor = '#ff2e88'

-- Touches (numéros de contrôle GTA : https://docs.fivem.net/docs/game-references/controls/).
Config.Keys = {
    Interact = { control = 38, label = 'E' }, -- prompt natif (sans ox_target / qb-target)
    Cancel   = { control = 73, label = 'X' }, -- annuler une barre de progression
}

-- Anti-spam des callbacks : appels max par seconde, par joueur et par callback (0 = illimité).
Config.CallbackRateLimit = 10

-- ─── pop_medexam ────────────────────────────────────────────

-- 'auto'  : borne en libre-service
-- 'ems'   : un EMS en service fait passer la visite
-- 'mixed' : EMS, ou borne automatique quand aucun EMS n'est en service
Config.Mode = 'mixed'

Config.EmsJobs = { 'ambulance' } -- format Bridge.HasJob ; doivent être en service

Config.Price    = 250      -- prix de la visite
Config.Account  = 'bank'   -- compte débité (patient) et crédité (médecin) : 'cash' | 'bank'
Config.Item     = 'medical_certificate'
Config.Validity = 30       -- jours de validité (0 = n'expire jamais)
Config.Cooldown = 300      -- secondes avant de repasser une visite (après un échec ou un certificat)

-- Durée des étapes en barre de progression (ms). En mode auto, seule la tension est une barre :
-- vision et réflexes sont des mini-jeux.
Config.Durations = { pressure = 4000, vision = 3000, reflex = 3000 }

-- Cliniques. ped = PNJ à l'accueil (false : simple zone). blip = afficher sur la carte.
Config.Locations = {
    { coords = vector4(311.2, -593.5, 43.28, 340.0), ped = 's_m_m_doctor_01', blip = true },
}

Config.Blip = { sprite = 61, color = 2, scale = 0.8 }
