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
-- pop_crew
------------------------------------------------------------------------

-- Commande du panneau ('' = repli sur 'crew') et touche par défaut ('' = aucune touche ;
-- chaque joueur peut la changer dans Paramètres > Raccourcis FiveM).
Config.Command = 'crew'
Config.Key     = 'F7'

-- Création : prix et compte débité ('cash' | 'bank'). 0 = gratuit. Toujours gratuit en standalone.
Config.CreateCost    = 25000
Config.CreateAccount = 'bank'

-- Nom du crew : longueur en caractères (max 32).
Config.NameLength = { min = 3, max = 20 }

-- Nombre maximum de membres par crew.
Config.MaxMembers = 20

-- Invitation : distance max (m) entre les deux joueurs, et durée de validité (s).
Config.InviteDistance = 5.0
Config.InviteTimeout  = 60

-- Couleurs proposées à la création (hex '#rrggbb').
Config.Colors = { '#ff2e88', '#22d3ee', '#a3e635', '#facc15', '#f97316', '#ef4444', '#8b5cf6', '#f5f5f5' }

-- Rangs, du plus haut (1 = chef, toutes permissions) au plus bas (rang des nouveaux membres). 3 ou 4 conseillés.
-- Libellé : clé de locale 'rank_<name>'. invite = inviter, kick = exclure, manage = changer les rangs inférieurs.
Config.Ranks = {
    { name = 'leader',  invite = true,  kick = true,  manage = true  },
    { name = 'officer', invite = true,  kick = true,  manage = false },
    { name = 'member',  invite = false, kick = false, manage = false },
    { name = 'recruit', invite = false, kick = false, manage = false },
}

-- Repère à la couleur du crew au-dessus des membres proches.
Config.ShowTags    = false
Config.TagDistance = 20.0
