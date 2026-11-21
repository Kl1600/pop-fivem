Config = {}

-- ─────────────────────────────────────────────
-- Mode dev
-- ─────────────────────────────────────────────

Config.Debug                 = false      -- prints + logs pour debug
Config.DevIgnoreZone         = true       -- ignore le check "joueur dans la zone" pour test
Config.DevIgnoreItemCheck    = true       -- ignore le check "joueur a la drogue" pour test

-- ─────────────────────────────────────────────
-- Réglages généraux
-- ─────────────────────────────────────────────

Config.MaxCustomersPerZone   = 2          -- nombre max de clients actifs simultanément par zone
Config.CustomerSpawnCooldown = 30         -- secondes entre 2 spawns dans une même zone
Config.CustomerDetectRange   = 40.0       -- portée à laquelle un client repère un joueur en zone
Config.CustomerApproachRange = 1.8        -- distance à laquelle le client s'arrête face au joueur
Config.OfferTimeout          = 25         -- secondes avant que le client s'en aille (refus implicite)
Config.WalkSpeed             = 1.0        -- vitesse d'approche du client
Config.DrawDistance          = 6.0        -- distance d'affichage du HUD 3D
Config.MoneyItem             = 'cash'     -- item d'argent (pop_inventory)

Config.BustChance            = 0.02       -- 2% que le client soit un flic (dev: laisser bas)
Config.BustAlertRadius       = 250.0      -- portée d'alerte police en cas de bust

-- ─────────────────────────────────────────────
-- Mode "vente de drogue" déclenché par l'item (pochonweed)
-- Utilise le pochon → des clients viennent à toi tant que tu as de la weed.
-- ─────────────────────────────────────────────

Config.SellingMaxCustomers  = 3      -- clients simultanés autour d'un vendeur actif
Config.SellingSpawnInterval = 18     -- secondes entre 2 apparitions de clients
Config.SellingSpawnMin      = 25.0   -- distance min de spawn autour du joueur
Config.SellingSpawnMax      = 70.0   -- distance max de spawn autour du joueur

-- Blip carte/minimap sur chaque client à aller voir
Config.CustomerBlip = {
    sprite = 1,                 -- icône du blip
    color  = 2,                 -- 2 = vert
    scale  = 0.8,
    label  = 'Client (deal)',
}

-- ─────────────────────────────────────────────
-- Négociation (Schedule 1)
-- Le joueur propose un prix; le client accepte si <= maxPrice du client.
-- Le client est généré avec un prix max = basePrice * mult random entre min/max.
-- ─────────────────────────────────────────────

Config.MaxPriceMultiplier = { 1.10, 1.50 }   -- multiplicateur sur basePrice pour le maxPrice du client
Config.HintPriceMultiplier = 1.0             -- prix "indicatif" affiché au joueur = basePrice * ça
Config.MaxAttempts         = 3               -- nombre de propositions max avant que le client s'en aille

-- ─────────────────────────────────────────────
-- Items vendables
-- defId          → identifiant inventaire (pop_inventory)
-- label          → nom affiché
-- basePrice      → prix de base par unité (référence)
-- qtyRange       → quantité possible que le client demande (min, max)
-- demand         → poids relatif (probabilité qu'un client veuille ce produit)
-- ─────────────────────────────────────────────

Config.Drugs = {
    {
        defId         = 'pochonweed',
        label         = 'Pochon de Weed',
        icon          = 'fas fa-cannabis',
        basePrice     = 180,
        qtyRange      = { 1, 3 },
        demand        = 100,
    },
    -- Ajouter d'autres drogues ici (cocaïne, meth, etc.) en suivant le même schéma
    -- {
    --     defId         = 'pochoncoke',
    --     label         = 'Pochon de Coke',
    --     icon          = 'fas fa-snowflake',
    --     basePrice     = 450,
    --     qtyRange      = { 1, 2 },
    --     demand        = 60,
    -- },
}

-- ─────────────────────────────────────────────
-- Modèles de PNJ clients (random pick)
-- ─────────────────────────────────────────────

Config.CustomerModels = {
    'a_m_y_hipster_01',
    'a_m_y_hipster_02',
    'a_m_y_hipster_03',
    'a_f_y_hipster_01',
    'a_f_y_hipster_02',
    'a_m_y_skater_01',
    'a_m_y_skater_02',
    'a_m_y_downtown_01',
    'a_f_y_business_01',
    'a_m_y_business_01',
    'a_m_m_eastsa_01',
    'a_m_m_eastsa_02',
    'a_f_y_runner_01',
}

-- ─────────────────────────────────────────────
-- Zones de deal
-- center  → centre de la zone
-- radius  → rayon dans lequel les clients peuvent spawn et se balader
-- ─────────────────────────────────────────────

Config.Zones = {
    {
        name   = 'Vespucci Beach',
        center = vec3(-1223.0, -1481.0, 4.4),
        radius = 60.0,
    },
    {
        name   = 'Strawberry',
        center = vec3(167.0, -1717.0, 29.3),
        radius = 50.0,
    },
    {
        name   = 'Davis',
        center = vec3(80.0, -1956.0, 21.1),
        radius = 60.0,
    },
}
