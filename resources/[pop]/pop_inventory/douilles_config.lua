-- =====================================================
--  tab_douilles - CONFIG
--  Systeme d'enquete balistique relie aux ARMES A FEU :
--    1) Un tir laisse une douille au sol (cote serveur, invisible par defaut)
--    2) CHERCHER  : /fouiller revele les douilles autour de soi
--    3) RAMASSER  : ox_target sur la douille -> item "douille" (avec metadonnees)
--    4) ANALYSER  : utiliser l'item "douille" -> rapport balistique
-- =====================================================

DouillesConfig = {}

-- =====================================================
--  CHERCHER (revele les douilles proches)
-- =====================================================
DouillesConfig.Search = {
    Command     = 'fouiller',   -- commande : /fouiller (aussi bindable a une touche)
    Jobs        = nil,          -- nil = tout le monde ; ex : { 'police' } pour limiter
                                -- (nil est volontaire : un criminel peut nettoyer ses douilles)
    Radius      = 8.0,          -- rayon de detection autour du joueur (metres)
    Duration    = 4000,         -- duree de la barre de fouille (ms)
    Cooldown    = 3000,         -- anti-spam de la commande (ms)
    RequireItem = false,        -- true = il faut l'item ci-dessous pour fouiller
    Item        = 'lampetorche',-- item requis si RequireItem = true
}

-- =====================================================
--  RAMASSER (transforme la douille du sol en item)
-- =====================================================
DouillesConfig.Pickup = {
    Jobs     = nil,        -- nil = tout le monde
    Item     = 'douille',  -- item recu (DOIT exister dans pop_inventory/config.lua)
    Duration = 2500,       -- barre de ramassage (ms)
    Distance = 2.0,        -- portee ox_target (metres)
}

-- =====================================================
--  ANALYSER (lit la balistique de l'item douille)
-- =====================================================
DouillesConfig.Analyze = {
    Jobs        = { 'police' }, -- seuls ces jobs peuvent analyser ; nil = tout le monde
    Duration    = 6000,         -- barre d'analyse (ms)
    RequireZone = false,        -- true = doit etre pres d'un labo (Zones ci-dessous)
    ZoneRadius  = 3.0,
    Zones       = {
        -- vector3(451.7, -980.0, 30.7), -- exemple : labo du MRPD (a ajuster)
    },
}

-- =====================================================
--  APPARITION DES DOUILLES (au tir)
-- =====================================================
DouillesConfig.Spawn = {
    Chance        = 1.0,   -- proba qu'un tir laisse une douille (1.0 = toujours)
    Cooldown      = 40,    -- intervalle min entre 2 douilles d'un meme tireur (ms) -> chaque tir compte
    ScatterRadius = 0.0,   -- 0 = pile aux pieds du tireur
    GroundOffset  = 0.04,  -- hauteur de la douille au-dessus du sol
    MaxDistance   = 12.0,  -- securite : on rejette un tir signale trop loin du tireur (anti-triche)
}

-- Duree de vie / limites. Les douilles vivent en memoire (perdues au restart du serveur).
-- Les ITEMS douille ramasses, eux, sont persistes par pop_inventory.
DouillesConfig.Lifetime   = 1800   -- secondes avant disparition auto d'une douille au sol (1800 = 30 min)
DouillesConfig.MaxCasings = 250    -- nombre max de douilles dans le monde (les plus vieilles sont supprimees)

-- =====================================================
--  VISUEL DE LA DOUILLE AU SOL
-- =====================================================
-- Le MARKER est garanti (aucune dependance de modele).
DouillesConfig.Marker = {
    Enabled      = true,
    Type         = 28,                                  -- petite sphere ; 1 = cylindre
    Scale        = 0.10,
    Color        = { r = 255, g = 200, b = 40, a = 200 }, -- laiton
    DrawDistance = 15.0,
    BobUpAndDown = false,
}

-- Prop physique OPTIONNEL. ATTENTION : aucune douille n'existe dans le GTA de base.
-- Si le modele est invalide ou ne charge pas, on retombe AUTOMATIQUEMENT sur le marker seul
-- (aucun risque de plantage). Mets ici ton propre modele si tu en streams un.
DouillesConfig.Prop = {
    Enabled = true,
    Model   = 'prop_ld_casing', -- non garanti : remplace par un modele que tu streams si besoin
}

-- =====================================================
--  ARMES IGNOREES (ne laissent pas de douille)
-- =====================================================
DouillesConfig.IgnoredByName = {
    'WEAPON_UNARMED',
    'WEAPON_STUNGUN',
    'WEAPON_FLAREGUN',
    'WEAPON_FLARE',
    'WEAPON_PETROLCAN',
    'WEAPON_FIREEXTINGUISHER',
    'WEAPON_HAZARDCAN',
    'WEAPON_BALL',
    'WEAPON_SNOWBALL',
    'WEAPON_MOLOTOV',
    'WEAPON_GRENADE',
    'WEAPON_STICKYBOMB',
    'WEAPON_BZGAS',
    'WEAPON_SMOKEGRENADE',
    'WEAPON_FIREWORK',
    'WEAPON_RPG',
    'WEAPON_GRENADELAUNCHER',
}

-- =====================================================
--  DONNEES BALISTIQUES PAR ARME (pour le rapport d'analyse)
--  Toute arme non listee retombe sur DouillesConfig.DefaultWeapon.
-- =====================================================
DouillesConfig.DefaultWeapon = { caliber = 'Inconnu', label = 'Arme non identifiee' }

DouillesConfig.Weapons = {
    -- Pistolets
    ['WEAPON_PISTOL']         = { caliber = '9mm',     label = 'Pistolet' },
    ['WEAPON_PISTOL_MK2']     = { caliber = '9mm',     label = 'Pistolet Mk II' },
    ['WEAPON_COMBATPISTOL']   = { caliber = '9mm',     label = 'Pistolet de combat' },
    ['WEAPON_PISTOL50']       = { caliber = '.50 AE',  label = 'Pistolet .50' },
    ['WEAPON_SNSPISTOL']      = { caliber = '9mm',     label = 'Pistolet SNS' },
    ['WEAPON_SNSPISTOL_MK2']  = { caliber = '9mm',     label = 'Pistolet SNS Mk II' },
    ['WEAPON_HEAVYPISTOL']    = { caliber = '.45 ACP', label = 'Pistolet lourd' },
    ['WEAPON_VINTAGEPISTOL']  = { caliber = '.45 ACP', label = 'Pistolet vintage' },
    ['WEAPON_APPISTOL']       = { caliber = '9mm',     label = 'Pistolet automatique' },
    ['WEAPON_CERAMICPISTOL']  = { caliber = '9mm',     label = 'Pistolet ceramique' },
    ['WEAPON_MACHINEPISTOL']  = { caliber = '9mm',     label = 'Pistolet-mitrailleur' },
    ['WEAPON_REVOLVER']       = { caliber = '.500',    label = 'Revolver' },
    ['WEAPON_REVOLVER_MK2']   = { caliber = '.500',    label = 'Revolver Mk II' },
    ['WEAPON_DOUBLEACTION']   = { caliber = '.38',     label = 'Revolver double action' },
    ['WEAPON_NAVYREVOLVER']   = { caliber = '.45',     label = 'Revolver Navy' },
    -- SMG
    ['WEAPON_MICROSMG']       = { caliber = '9mm',     label = 'Micro-SMG' },
    ['WEAPON_SMG']            = { caliber = '9mm',     label = 'SMG' },
    ['WEAPON_SMG_MK2']        = { caliber = '9mm',     label = 'SMG Mk II' },
    ['WEAPON_ASSAULTSMG']     = { caliber = '9mm',     label = 'SMG d\'assaut' },
    ['WEAPON_COMBATPDW']      = { caliber = '9mm',     label = 'PDW de combat' },
    ['WEAPON_MINISMG']        = { caliber = '9mm',     label = 'Mini-SMG' },
    ['WEAPON_GUSENBERG']      = { caliber = '.45 ACP', label = 'Mitraillette Gusenberg' },
    -- Fusils d'assaut
    ['WEAPON_ASSAULTRIFLE']     = { caliber = '7.62mm', label = 'Fusil d\'assaut' },
    ['WEAPON_ASSAULTRIFLE_MK2'] = { caliber = '7.62mm', label = 'Fusil d\'assaut Mk II' },
    ['WEAPON_CARBINERIFLE']     = { caliber = '5.56mm', label = 'Carabine' },
    ['WEAPON_CARBINERIFLE_MK2'] = { caliber = '5.56mm', label = 'Carabine Mk II' },
    ['WEAPON_ADVANCEDRIFLE']    = { caliber = '5.56mm', label = 'Fusil avance' },
    ['WEAPON_SPECIALCARBINE']   = { caliber = '5.56mm', label = 'Carabine speciale' },
    ['WEAPON_SPECIALCARBINE_MK2']={ caliber = '5.56mm', label = 'Carabine speciale Mk II' },
    ['WEAPON_BULLPUPRIFLE']     = { caliber = '5.56mm', label = 'Fusil bullpup' },
    ['WEAPON_BULLPUPRIFLE_MK2'] = { caliber = '5.56mm', label = 'Fusil bullpup Mk II' },
    ['WEAPON_COMPACTRIFLE']     = { caliber = '7.62mm', label = 'Fusil compact' },
    ['WEAPON_MILITARYRIFLE']    = { caliber = '5.56mm', label = 'Fusil militaire' },
    ['WEAPON_HEAVYRIFLE']       = { caliber = '7.62mm', label = 'Fusil lourd' },
    -- Mitrailleuses
    ['WEAPON_MG']             = { caliber = '7.62mm', label = 'Mitrailleuse' },
    ['WEAPON_COMBATMG']       = { caliber = '7.62mm', label = 'Mitrailleuse de combat' },
    ['WEAPON_COMBATMG_MK2']   = { caliber = '7.62mm', label = 'Mitrailleuse de combat Mk II' },
    -- Fusils a pompe
    ['WEAPON_PUMPSHOTGUN']     = { caliber = 'Cal. 12', label = 'Fusil a pompe' },
    ['WEAPON_PUMPSHOTGUN_MK2'] = { caliber = 'Cal. 12', label = 'Fusil a pompe Mk II' },
    ['WEAPON_SAWNOFFSHOTGUN']  = { caliber = 'Cal. 12', label = 'Fusil a canon scie' },
    ['WEAPON_BULLPUPSHOTGUN']  = { caliber = 'Cal. 12', label = 'Fusil bullpup' },
    ['WEAPON_ASSAULTSHOTGUN']  = { caliber = 'Cal. 12', label = 'Fusil d\'assaut a pompe' },
    ['WEAPON_HEAVYSHOTGUN']    = { caliber = 'Cal. 12', label = 'Fusil a pompe lourd' },
    ['WEAPON_COMBATSHOTGUN']   = { caliber = 'Cal. 12', label = 'Fusil a pompe de combat' },
    ['WEAPON_DBSHOTGUN']       = { caliber = 'Cal. 12', label = 'Fusil a deux canons' },
    ['WEAPON_AUTOSHOTGUN']     = { caliber = 'Cal. 12', label = 'Fusil a pompe automatique' },
    -- Fusils de precision
    ['WEAPON_SNIPERRIFLE']     = { caliber = '.338',    label = 'Fusil de precision' },
    ['WEAPON_HEAVYSNIPER']     = { caliber = '.50 BMG', label = 'Fusil de precision lourd' },
    ['WEAPON_HEAVYSNIPER_MK2'] = { caliber = '.50 BMG', label = 'Fusil de precision lourd Mk II' },
    ['WEAPON_MARKSMANRIFLE']     = { caliber = '7.62mm', label = 'Fusil de tireur d\'elite' },
    ['WEAPON_MARKSMANRIFLE_MK2'] = { caliber = '7.62mm', label = 'Fusil de tireur d\'elite Mk II' },
}
