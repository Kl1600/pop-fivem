-- Constantes partagées client / serveur (non configurables).
Clamp = {}
Clamp.STATE           = 'popClamp' -- clé du statebag véhicule (true ou nil)
Clamp.PLACE_DISTANCE  = 3.0        -- client : recherche du véhicule à l'utilisation de l'item
Clamp.ACTION_DISTANCE = 4.0        -- serveur : Bridge.IsNear sur le véhicule
Clamp.TARGET_DISTANCE = 2.0        -- client : interaction sur le sabot
Clamp.PROP_DISTANCE   = 60.0       -- client : prop créé en deçà, supprimé au-delà de +20 m
