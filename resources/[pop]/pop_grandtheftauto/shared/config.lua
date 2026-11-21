Config = Config or {}

Config.Framework = 'esx' -- 'esx', 'qbcore', 'none'
Config.Inventory = 'pop_inventory' -- 'pop_inventory', 'esx', 'qbcore'
Config.Notifications = 'notification' -- 'notification', 'esx', 'qbcore'
Config.UI = 'pop_v3dui' -- 'pop_v3dui', 'esx', 'qbcore' (for prompts)

-- ============================================================
-- MISSION
-- ============================================================
Config.SvetlanaPos  = vector3(-51.8229, -2523.5183, 7.4012)  -- donneuse de mission (docks)
Config.ShowroomPos  = vector3(-69.0, 64.0, 71.9)             -- showroom Benefactor
Config.DeliveryPos  = vector3(-462.1116, -2805.2249, 5.9963) -- zone de livraison

Config.MaxMembers      = 4        -- joueurs max dans l'équipe
Config.TeamRadius      = 15.0     -- joueurs proches de Svetlana au départ = équipe
Config.Cooldown        = 20 * 60  -- secondes avant un nouveau casse (après la fin)
Config.MissionDuration = 45 * 60  -- secondes max d'un casse avant arrêt automatique
Config.PendingDuration = 15 * 60  -- secondes pour rejoindre le showroom après Svetlana
Config.Timer           = 240      -- secondes avant le retour du courant et des lasers
Config.RewardPerCar    = 15000    -- argent liquide (objet cash) par voiture livrée
Config.GiveKit         = true     -- Svetlana donne 1 flipper et 1 module pirate si besoin
Config.PoliceJobs      = { 'police' }
Config.PoliceAlertCooldown = 60   -- secondes entre deux alertes police

-- Emplacements des camions de livraison
Config.DeliverySlots = {
    { pos = vector3(-455.0746, -2799.6641, 6.2348), heading = 224.6269 },
    { pos = vector3(-393.7933, -2833.2856, 6.2378), heading = 315.8362 },
    { pos = vector3(-509.3272, -2852.3975, 6.2344), heading = 225.9956 },
    { pos = vector3(-415.8460, -2788.2461, 6.2344), heading = 136.7724 },
}

Cars = {
    {
        pos = vec(-59.5476, 65.6447, 72.1878), --inside 1
        heading = 182.9710,
        model = 'krieger',
        spin = false,
        text = "test",
        plate = "763 BEN"
    },
    {
        pos = vec(-64.8891, 68.4905, 70.9675), --inside 2
        heading = 160.2049,
        model = 'sm722',
        spin = false,
        text = "test",
        plate = "968 BEN"
    },
    {
        pos = vec(-70.2728, 71.3453, 70.9213), --inside 3
        heading = 131.2714,
        model = 'schlagen',
        spin = false,
        text = "test",
        plate = "119 BEN"
    },
    {
        pos = vec(-75.7869, 74.1420, 71.1026), --inside 4
        heading = 121.9297,
        model = 'schweizer2',
        fallback = 'schwarzer', -- si 'schweizer2' n'est pas installé sur le serveur
        spin = false,
        text = "test",
        plate = "317 BEN"
    }
}
