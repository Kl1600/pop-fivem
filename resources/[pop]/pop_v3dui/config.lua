Config = {}

-- Script d'affichage sans framework : pas de bridge (utilisé par les autres scripts via ses exports).
Config.Debug = false

Config.DefaultDrawDistance = 15.0 -- distance d'affichage si l'élément n'en précise pas
Config.RefreshNear = 30           -- ms entre deux mises à jour quand un élément est à portée (lissé en CSS)
Config.RefreshIdle = 500          -- ms quand aucun élément n'est à portée
Config.OffscreenGrace = 250       -- ms de maintien d'un élément sorti de l'écran (évite les clignotements)
Config.PosEpsilon = 0.0005        -- déplacement minimum à l'écran avant un nouvel envoi
