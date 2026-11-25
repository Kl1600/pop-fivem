Config = {}

-- Display-only resource, no framework needed (used by other scripts through its exports).
-- (Script d'affichage sans framework : utilisé par les autres scripts via ses exports.)

Config.Locale = 'fr'               -- fr, en, es, de, ar (en = fallback / secours)
Config.Debug = false

Config.DefaultDrawDistance = 15.0  -- draw distance when the element gives none (distance d'affichage par défaut)
Config.RefreshNear = 30            -- ms between updates when an element is in range (smoothed in CSS)
Config.RefreshIdle = 500           -- ms when nothing is in range (aucun élément à portée)
Config.OffscreenGrace = 250        -- ms an off-screen element is kept (avoids flicker / évite les clignotements)
Config.PosEpsilon = 0.0005         -- minimum on-screen move before a new update
