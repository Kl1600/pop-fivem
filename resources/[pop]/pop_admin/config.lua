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

-- ─── pop_admin ──────────────────────────────────────────────

-- Ouverture du panneau : commande et touche par défaut (chaque joueur peut la changer dans
-- Paramètres > Raccourcis > FiveM). Touche de noclip directe : '' = aucune par défaut.
Config.Command   = 'popadmin'
Config.OpenKey   = 'F10'
Config.NoclipKey = ''

-- Droits : avec l'ACE pop.admin, chaque action se règle par pop.admin.<action> (voir README).
-- true : un admin du framework (groupe admin/superadmin/god) SANS ACE pop.admin a tous les droits.
Config.FrameworkAdmins = true

-- Durées de ban proposées, en heures (0 = permanent).
Config.BanDurations = { 1, 24, 72, 168, 720, 0 }

-- Météo et heure synchronisées par ce script. Mettre false si un autre script gère déjà la météo.
Config.WorldSync = true
Config.Weathers = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY',
    'RAIN', 'THUNDER', 'CLEARING', 'SNOW', 'XMAS',
}
Config.DefaultWorld = { weather = 'CLEAR', hour = 12, minute = 0, frozen = false }

-- Durée d'affichage d'une annonce (secondes).
Config.AnnounceDuration = 8

-- Event client de votre script de mort pour la réanimation ('' = détection automatique, voir README).
Config.ReviveEvent = ''
