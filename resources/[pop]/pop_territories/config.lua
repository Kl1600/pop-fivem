Config = {}

Config.Debug = false  -- prints serveur pour debug

-- ─────────────────────────────────────────────
-- Réglages généraux de la guerre de territoires
-- ─────────────────────────────────────────────

-- Part de territoire gagnée par le crew du vendeur à CHAQUE vente (en %)
Config.SharePerSale     = 10.0

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
-- Multiplicateurs PAR TERRITOIRE
-- Principal : se définit directement dans l'éditeur /mapzones
--   → coche "Zone de vente (drogue)" + règle le "Multiplicateur de vente".
-- Ces réglages sont stockés dans MapZones/zones.json et lus automatiquement.
--
-- Optionnel (ci-dessous) : override/forçage par id de zone si tu préfères le code.
-- Une zone listée ici est traitée comme zone de vente même si la case n'est pas cochée.
-- ─────────────────────────────────────────────

Config.Zones = {
    -- ['z1'] = { multiplier = 1.5 },   -- override éventuel
}
