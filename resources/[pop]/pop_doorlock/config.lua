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

-- pop_doorlock -------------------------------------------------------------

-- Commande de l'éditeur en jeu (réservée aux admins : ACE pop.admin ou groupe admin du framework).
Config.Command = 'doorlock'

-- Item clé. Chaque clé porte la metadata pop_door = clé du groupe
-- (ox_inventory, qs-inventory, qb-inventory, ps-inventory, pop_inventory ; pas l'inventaire ESX de base).
Config.KeyItem = 'door_key'

Config.Lockpick = {
    Item          = 'lockpick',
    Cooldown      = 5,                       -- secondes entre deux tentatives (par joueur)
    AlertJobs     = { 'police', 'sheriff' }, -- reçoivent l'alerte des groupes « alerte »
    AlertBlipTime = 60,                      -- secondes d'affichage du blip d'alerte
    -- Par niveau de sécurité. Le niveau 2 (impossible) n'a pas d'entrée.
    -- hits : coups à réussir | zone : largeur de la cible (0-1) | speed : allers-retours/s
    -- time : temps max (ms) | failChance : échec tiré par le serveur même si le mini-jeu est réussi
    -- breakChance : l'outil casse en cas d'échec
    Levels = {
        [0] = { hits = 2, zone = 0.20, speed = 0.8, time = 6000, failChance = 0.10, breakChance = 0.20 },
        [1] = { hits = 3, zone = 0.12, speed = 1.2, time = 7000, failChance = 0.30, breakChance = 0.40 },
    },
}
