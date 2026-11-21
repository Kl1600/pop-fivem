Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
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
-- pop_emotes
------------------------------------------------------------------------

-- Touches par défaut (RegisterKeyMapping : chaque joueur peut les changer dans les réglages GTA)
Config.MenuKey   = 'F5'        -- menu des animations (/animenu)
Config.CrouchKey = 'lcontrol'  -- s'accroupir (+crouch)

-- Emote partagée (/nearby) et copie : distance pour trouver le joueur le plus proche (client)
Config.NearbyRadius = 3.0
-- Contrôles serveur : distance max entre les deux joueurs et durée de validité d'une demande
Config.ShareMaxDistance = 10.0
Config.ShareRequestTTL  = 15     -- secondes
-- Temps pour accepter une emote partagée (touche Y)
Config.ShareAcceptTime  = 5000   -- ms

-- Compatibilité avec les listes d'emotes (format RPEmotes) : shared/emotes.lua lit
-- Config.Languages[Config.MenuLanguage][clé] pour les textes d'effets (PtfxInfo).
-- Comme avant, la clé est renvoyée telle quelle (ne pas supprimer).
Config.MenuLanguage = 'en'
Config.Languages = setmetatable({}, {
    __index = function()
        return setmetatable({}, {
            __index = function(_, term) return tostring(term or '') end
        })
    end
})
