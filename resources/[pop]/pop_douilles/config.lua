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

-- ─── pop_douilles ────────────────────────────────────────────

-- Item reçu en ramassant (à déclarer dans votre inventaire, voir README).
Config.Item = 'bullet_casing'

-- Jobs qui peuvent fouiller, ramasser et lire le rapport (format Bridge.HasJob, en service).
Config.PoliceJobs = { 'police', 'sheriff' }

-- Touche par défaut pour fouiller (modifiable par le joueur dans les raccourcis FiveM).
Config.SearchKey = 'K'

Config.SearchRadius   = 10.0  -- mètres
Config.SearchDuration = 3000  -- ms
Config.PickupDuration = 2000  -- ms
Config.RevealTime     = 120   -- secondes d'affichage des douilles trouvées
Config.Lifetime       = 1200  -- secondes avant disparition d'une douille
Config.MaxCasings     = 150   -- douilles max sur le serveur

-- Modèle du prop au sol (petit objet du jeu de base). Invalide = interaction sans prop.
Config.Prop = 'w_pi_flaregun_shell'

-- Armes qui ne laissent pas de douille.
Config.IgnoredWeapons = {
    'WEAPON_STUNGUN', 'WEAPON_STUNGUN_MP', 'WEAPON_FLAREGUN', 'WEAPON_RAYPISTOL', 'WEAPON_RAYCARBINE',
    'WEAPON_PETROLCAN', 'WEAPON_HAZARDCAN', 'WEAPON_FIREEXTINGUISHER', 'WEAPON_RPG', 'WEAPON_HOMINGLAUNCHER',
    'WEAPON_GRENADELAUNCHER', 'WEAPON_GRENADELAUNCHER_SMOKE', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_FIREWORK',
    'WEAPON_SNOWLAUNCHER',
}

-- Calibre par arme. Arme non listée = calibre inconnu.
Config.Calibers = {
    ['9mm']     = { 'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2',
                    'WEAPON_APPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_MACHINEPISTOL', 'WEAPON_MICROSMG', 'WEAPON_SMG',
                    'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW', 'WEAPON_MINISMG' },
    ['.45 ACP'] = { 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_GUSENBERG' },
    ['.50 AE']  = { 'WEAPON_PISTOL50' },
    ['.357']    = { 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION', 'WEAPON_NAVYREVOLVER' },
    ['5.56mm']  = { 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
                    'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2', 'WEAPON_MILITARYRIFLE' },
    ['7.62mm']  = { 'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_COMPACTRIFLE', 'WEAPON_HEAVYRIFLE',
                    'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_MARKSMANRIFLE', 'WEAPON_MARKSMANRIFLE_MK2' },
    ['12 ga']   = { 'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_BULLPUPSHOTGUN',
                    'WEAPON_ASSAULTSHOTGUN', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_COMBATSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN' },
    ['.50 BMG'] = { 'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2' },
}
