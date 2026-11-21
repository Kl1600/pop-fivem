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

------------------------------------------------------------------------
-- pop_territories
------------------------------------------------------------------------

-- Appartenance : pop_crew est utilisé s'il est lancé. Sinon, les jobs listés ci-dessous servent de crews.
Config.UseJobsAsCrews = true
Config.JobCrews = {        -- nom du job = couleur du crew
    ballas   = '#8b5cf6',
    families = '#22c55e',
    vagos    = '#facc15',
}

-- Influence (0 à 100 par crew et par zone ; le total d'une zone ne dépasse jamais 100).
Config.Influence = {
    PerSale      = 2.0,  -- gagnée par vente dans la zone
    PerTick      = 0.5,  -- gagnée par minute de présence d'un membre (ne fait pas prendre la zone)
    Decay        = 0.1,  -- perdue par minute sans membre présent
    Capture      = 60,   -- influence pour prendre la zone
    Keep         = 30,   -- le propriétaire garde la zone tant qu'il reste au-dessus
    SaleCooldown = 10,   -- secondes minimum entre deux ventes comptées pour un même joueur
}

-- Multiplicateurs de prix, appliqués après le prix de la zone.
Config.Prices = {
    Owner = 1.25, -- vendeur du crew propriétaire
    Rival = 0.85, -- zone tenue par un autre crew
}

-- Secondes entre deux alertes "vente rivale" par zone (0 = désactivé).
Config.RivalAlertCooldown = 120

-- Zones colorées sur la carte selon le propriétaire.
Config.ZoneBlips = true

-- Durée d'affichage du HUD en entrant dans une zone, en secondes (0 = tant qu'on y est).
Config.HudDuration = 8

Config.Commands = {
    Info  = 'territory',      -- réaffiche le HUD de la zone actuelle
    Admin = 'territoryadmin', -- info | reset | set (admin)
}

-- Territoires. Cercle : center + radius. Polygone : points (au moins 3 vec2).
-- label : clé de traduction (ou texte brut). price : multiplicateur de prix de la zone (défaut 1.0, 0.1-10).
-- price se CUMULE avec le "mult" de la zone de vente pop_dealing (déjà 1.2 à Vespucci) puis Prices.Owner/Rival :
-- laissez 1.0 sauf si pop_dealing ne gère pas lui-même le prix du quartier.
-- Les zones de vente de pop_dealing doivent recouvrir les territoires : sans vente possible, une zone est imprenable.
Config.Zones = {
    { id = 'grove',    label = 'zone_grove',    center = vec3(105.0, -1940.0, 20.8),  radius = 130.0 },
    { id = 'forum',    label = 'zone_forum',    center = vec3(-165.0, -1620.0, 33.0), radius = 110.0 },
    { id = 'vespucci', label = 'zone_vespucci', price = 1.0, points = {
        vec2(-1450.0, -1380.0), vec2(-1250.0, -1250.0), vec2(-1150.0, -1450.0), vec2(-1350.0, -1600.0),
    } },
    { id = 'sandy',    label = 'zone_sandy',    center = vec3(1850.0, 3700.0, 33.0),  radius = 250.0 },
}
