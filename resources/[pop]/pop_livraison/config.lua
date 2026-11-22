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
-- pop_livraison
------------------------------------------------------------------------

-- Commande de dev (admins : ACE pop.admin ou groupe admin, voir Bridge.IsAdmin)
Config.Command = 'previewlivraison'

-- Délai max (ms) de chargement d'un modèle ou d'une animation
Config.LoadTimeout = 5000

-- Véhicules de la preview (figés). Champs facultatifs : colours {primaire, secondaire},
-- extraColours {nacré, jantes}, interior, dashboard, livery, door (porte ouverte).
Config.Vehicles = {
    -- 1. Boxville4
    { model = 'boxville4', coords = vector4(1178.5614, -3307.3799, 5.9486, 89.2651) },
    -- 2. Rumpo (open back left door)
    { model = 'rumpo', coords = vector4(1177.3879, -3314.0940, 6.0510, 203.1342), door = 2 },
    -- SCENE 2: Quickie Pharm Vehicles
    -- Vehicle 1: Sentinel5 (trunk open)
    {
        model = 'sentinel5',
        coords = vector4(360.4900, -610.6686, 28.2080, 213.5158),
        colours = { 54, 11 },      -- Petrol Green Metallic (54) with Anthracite secondary (11)
        extraColours = { 0, 54 },  -- Force Black pearlescent, Wheels match primary color (54)
        interior = 11,             -- Anthracite Interior
        dashboard = 11,            -- Anthracite Trim
        livery = 10,               -- Livery 10 (Quickie Pharm)
        door = 5,                  -- Trunk open
    },
    -- Vehicle 2: Sentinel5 (right back door open)
    {
        model = 'sentinel5',
        coords = vector4(357.9776, -605.2109, 28.1367, 17.8637),
        colours = { 111, 11 },       -- Ice White Classic (111) with Anthracite secondary (11)
        extraColours = { 111, 111 }, -- Ice White pearlescent, Wheels match primary color (111)
        interior = 11,               -- Anthracite Interior
        dashboard = 11,              -- Anthracite Trim
        livery = 10,                 -- Livery 10 (Quickie Pharm)
        door = 3,                    -- Right back door open
    },
}

-- Peds de la preview (figés, avec animation, objet porté ou arme)
Config.Peds = {
    -- Ped with box (boite en carton)
    {
        model = "s_m_m_postal_01",
        coords = vector4(1176.8125, -3310.5674, 6.0288 - 1.0, 160.5903),
        animDict = "anim@heists@box_carry@",
        animName = "idle",
        prop = "hei_prop_heist_box",
        boneIndex = 60309,
        propPlacement = {0.025, 0.08, 0.255, -145.0, 290.0, 0.0}
    },
    -- Ped with charriot (trolley 4 / pallet 4)
    {
        model = "s_m_m_postal_01",
        coords = vector4(1180.2562, -3310.1536, 6.0288 - 1.0, 68.8752),
        animDict = "anim@mp_ferris_wheel",
        animName = "idle_a_player_two",
        prop = "prop_flattruck_01c",
        boneIndex = -1,
        propPlacement = {0.0, 1.3, -0.97, 0.0, 0.0, 180.0}
    },
    -- Ped with notepad
    {
        model = "s_m_m_postal_01",
        coords = vector4(1175.5317, -3309.2703, 5.9170 - 1.0, 71.1752),
        animDict = "missheistdockssetup1clipboard@base",
        animName = "base",
        prop = "prop_notepad_01",
        boneIndex = 18905,
        propPlacement = {0.1, 0.02, 0.05, 10.0, 0.0, 0.0},
        extraProp = "prop_pencil_01",
        extraBoneIndex = 58866,
        extraPropPlacement = {0.11, -0.02, 0.001, -120.0, 0.0, 0.0}
    },
    -- SCENE 2: Quickie Pharm Peds
    -- Inspecter 2
    {
        model = "s_m_m_postal_01",
        coords = vector4(358.5620, -608.4681, 28.6855 - 1.0, 223.5900),
        animDict = "anim@amb@carmeet@checkout_engine@",
        animName = "female_c_idle_d"
    },
    -- Attendre
    {
        model = "s_m_m_postal_01",
        coords = vector4(360.2576, -607.1755, 28.6857 - 1.0, 276.8391),
        animDict = "random@shop_tattoo",
        animName = "_idle_a"
    },
    -- Briefcase Ped
    {
        model = "s_m_m_postal_01",
        coords = vector4(359.9845, -605.8492, 28.6747 - 1.0, 266.2759),
        weapon = "WEAPON_BRIEFCASE_02" -- _03 n'existe pas en vanilla
    }
}
