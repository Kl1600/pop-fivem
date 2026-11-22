Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false  -- prints serveur + notifications de debug
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
-- pop_territories
------------------------------------------------------------------------
-- ─────────────────────────────────────────────
-- Réglages généraux de la guerre de territoires
-- ─────────────────────────────────────────────

-- Part de territoire gagnée par le crew du vendeur à chaque vente (en %)
Config.SharePerSale     = 2.0

-- Délai minimum (secondes) entre deux gains de part pour un même joueur.
-- Les ventes pendant ce délai profitent du multiplicateur mais ne font pas monter la part.
Config.ShareCooldown    = 60

-- Seuil de contrôle : à partir de ce % de parts, le crew CONTRÔLE le territoire
Config.ControlThreshold = 80.0

-- Seuil de déclenchement de guerre : si un crew RIVAL atteint ce % de parts
-- dans un territoire contrôlé par un autre crew → guerre des gangs déclenchée
Config.WarThreshold     = 60.0

-- Multiplicateur appliqué au crew qui CONTRÔLE le territoire (≥ ControlThreshold)
Config.ControlMultiplier = 2.5

-- Multiplicateur par défaut d'une zone si non précisée dans Config.Zones
Config.DefaultMultiplier = 1.0

-- Vendre HORS de tout territoire : multiplicateur appliqué (1.0 = prix normal)
Config.OutsideMultiplier = 1.0

-- Quand un crew vend, érode-t-on les parts des autres crews dans la zone ?
-- 0.0 = pas d'érosion (parts indépendantes). 1.0 = retire SharePerSale aux autres.
Config.ErosionFactor    = 0.0

-- Le crew du vendeur doit-il contrôler la zone pour profiter du ControlMultiplier ?
-- (laisser true : c'est le principe du contrôle de territoire)
-- Un rival qui vend dans une zone contrôlée touche seulement le multiplicateur de base de la zone.

-- ─────────────────────────────────────────────
-- Territoires (zones internes, plus besoin de MapZones)
-- id         → identifiant stocké en base (ne pas changer une fois en jeu)
-- label      → nom affiché
-- center     → centre de la zone
-- radius     → rayon en mètres (si deux zones se chevauchent, la plus proche gagne)
-- multiplier → multiplicateur de vente de base (sinon Config.DefaultMultiplier)
-- dealZone   → false pour un territoire où la vente n'est pas comptée (true par défaut)
-- blipColor  → couleur du cercle sur la carte quand personne ne contrôle (index GTA, 1 = rouge)
-- ─────────────────────────────────────────────

Config.ShowZoneBlips = true    -- cercles des territoires sur la carte
Config.BlipAlpha     = 90      -- transparence des cercles (0-255)

Config.Zones = {
    ['davis']          = { label = 'Davis',             center = vec3(80.0, -1956.0, 21.1),   radius = 220.0 },
    ['strawberry']     = { label = 'Strawberry',        center = vec3(167.0, -1717.0, 29.3),  radius = 180.0 },
    ['chamberlain']    = { label = 'Chamberlain Hills', center = vec3(-160.0, -1620.0, 33.6), radius = 180.0 },
    ['rancho']         = { label = 'Rancho',            center = vec3(420.0, -1830.0, 28.0),  radius = 220.0 },
    ['vespucci_beach'] = { label = 'Vespucci Beach',    center = vec3(-1223.0, -1481.0, 4.4), radius = 250.0 },
    ['sandy_shores']   = { label = 'Sandy Shores',      center = vec3(1850.0, 3700.0, 33.5),  radius = 400.0 },
}

-- ─────────────────────────────────────────────
-- Réglages techniques (valeurs d'origine)
-- ─────────────────────────────────────────────

Config.WeedItem          = 'pochonweed' -- objet qui affiche le guide (checklist) à gauche
Config.ChecklistInterval = 1500         -- ms entre deux vérifications de l'objet (checklist)
Config.ChecklistRaise    = 420          -- décalage des notifications quand le guide est affiché
Config.ZoneCheckInterval = 1000         -- ms entre deux détections de zone côté client
Config.NotifyDuration    = 6000         -- notifications de crew (prise de contrôle, guerre)
Config.CommandNotifyDuration = 7000     -- /territory dans un territoire
Config.NoZoneNotifyDuration  = 5000     -- /territory hors territoire
