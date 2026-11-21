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

-- ─── pop_bank ───────────────────────────────────────────────

-- Guichets (zone d'interaction centrée sur le comptoir).
Config.Banks = {
    vector3(149.46, -1042.09, 29.37),   -- Legion Square
    vector3(314.23, -278.83, 54.17),    -- Hawick
    vector3(-350.80, -49.57, 49.04),    -- Burton
    vector3(-1213.00, -330.39, 37.79),  -- Rockford Hills
    vector3(-2962.71, 482.99, 15.70),   -- Great Ocean Highway
    vector3(1175.06, 2706.64, 38.09),   -- Route 68
    vector3(-112.20, 6469.20, 31.63),   -- Paleto Bay
    vector3(241.73, 220.70, 106.29),    -- Pacific Standard
}

Config.AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

-- Map ATM prop positions from the DurtyFree GTA V data dump (worldAtms.json).
-- Add custom map ATMs here so the server can validate their location.
Config.Atms = {
    vector3(-301.657, -829.589, 31.420),
    vector3(-303.226, -829.312, 31.420),
    vector3(-204.019, -861.009, 29.271),
    vector3(118.642, -883.569, 30.139),
    vector3(24.593, -945.543, 28.333),
    vector3(5.686, -919.955, 28.481),
    vector3(296.176, -896.232, 28.290),
    vector3(296.877, -894.320, 28.261),
    vector3(147.473, -1036.217, 28.368),
    vector3(145.839, -1035.625, 28.368),
    vector3(112.476, -819.808, 30.340),
    vector3(111.389, -774.840, 30.438),
    vector3(114.547, -775.972, 30.417),
    vector3(-256.639, -715.890, 32.788),
    vector3(-259.277, -723.265, 32.702),
    vector3(-254.522, -692.887, 32.578),
    vector3(-27.890, -724.109, 43.223),
    vector3(-30.100, -723.286, 43.223),
    vector3(228.032, 337.850, 104.501),
    vector3(158.797, 234.745, 105.643),
    vector3(527.778, -160.661, 56.137),
    vector3(-57.170, -92.379, 56.751),
    vector3(89.813, 2.880, 67.352),
    vector3(285.349, 142.975, 103.162),
    vector3(357.128, 174.084, 102.060),
    vector3(1137.811, -468.863, 65.699),
    vector3(1167.060, -455.654, 65.819),
    vector3(1077.779, -776.966, 57.257),
    vector3(289.530, -1256.788, 28.441),
    vector3(289.268, -1282.320, 28.655),
    vector3(-165.584, 234.766, 93.929),
    vector3(-165.584, 232.695, 93.929),
    vector3(-1044.466, -2739.641, 8.124),
    vector3(-1205.378, -326.529, 36.851),
    vector3(-1206.142, -325.032, 36.851),
    vector3(-846.654, -341.509, 37.669),
    vector3(-847.204, -340.429, 37.679),
    vector3(-720.629, -415.524, 33.980),
    vector3(-867.013, -187.993, 36.882),
    vector3(-867.975, -186.342, 36.882),
    vector3(-1415.480, -212.332, 45.495),
    vector3(-1430.663, -211.359, 45.472),
    vector3(-1410.736, -98.928, 51.397),
    vector3(-1410.183, -100.645, 51.397),
    vector3(-1282.098, -210.560, 41.430),
    vector3(-1286.704, -213.783, 41.430),
    vector3(-1289.742, -227.165, 41.430),
    vector3(-1285.137, -223.942, 41.430),
    vector3(-712.936, -818.483, 22.741),
    vector3(-710.083, -818.476, 22.736),
    vector3(-617.803, -708.859, 29.043),
    vector3(-617.803, -706.852, 29.043),
    vector3(-614.519, -705.598, 30.224),
    vector3(-611.858, -705.598, 30.224),
    vector3(-660.676, -854.488, 23.457),
    vector3(-537.805, -854.936, 28.275),
    vector3(-594.614, -1160.852, 21.334),
    vector3(-596.125, -1160.850, 21.334),
    vector3(-526.779, -1223.374, 17.453),
    vector3(-1569.840, -547.031, 33.932),
    vector3(-1570.765, -547.703, 33.932),
    vector3(-1305.708, -706.688, 24.314),
    vector3(-1315.416, -834.431, 15.952),
    vector3(-1314.466, -835.691, 15.952),
    vector3(-2071.928, -317.286, 12.318),
    vector3(-821.894, -1081.555, 10.137),
    vector3(-1110.228, -1691.154, 3.378),
    vector3(-2956.848, 487.216, 14.478),
    vector3(-2958.977, 487.307, 14.478),
    vector3(-2974.586, 380.127, 14.000),
    vector3(-1091.888, 2709.053, 17.919),
    vector3(-2295.852, 357.935, 173.601),
    vector3(-2295.069, 356.256, 173.601),
    vector3(-2294.300, 354.606, 173.601),
    vector3(-3144.887, 1127.811, 19.838),
    vector3(-3043.835, 594.164, 6.733),
    vector3(-3241.455, 997.909, 11.548),
    vector3(2563.999, 2584.553, 37.068),
    vector3(2558.324, 350.988, 107.597),
    vector3(156.189, 6643.200, 30.594),
    vector3(173.825, 6638.217, 30.594),
    vector3(-282.714, 6226.430, 30.496),
    vector3(-95.870, 6457.462, 30.474),
    vector3(-97.637, 6455.732, 30.468),
    vector3(-132.666, 6366.877, 30.473),
    vector3(-386.460, 6046.411, 30.474),
    vector3(1687.395, 4815.900, 41.006),
    vector3(1700.694, 6426.762, 31.633),
    vector3(1822.971, 3682.577, 33.267),
    vector3(1171.523, 2703.139, 37.148),
    vector3(1172.457, 2703.139, 37.148),
    vector3(238.268, 217.109, 105.406),
    vector3(238.698, 216.187, 105.406),
    vector3(237.838, 218.031, 105.406),
    vector3(237.408, 218.954, 105.406),
    vector3(236.978, 219.876, 105.406),
    vector3(264.869, 209.949, 105.406),
    vector3(265.217, 210.905, 105.406),
    vector3(265.565, 211.861, 105.406),
    vector3(265.913, 212.817, 105.406),
    vector3(266.261, 213.773, 105.406),
    vector3(380.656, 322.842, 102.566),
    vector3(1153.111, -326.902, 68.205),
    vector3(33.194, -1348.806, 28.497),
    vector3(130.579, -1292.369, 28.271),
    vector3(130.150, -1291.626, 28.271),
    vector3(129.698, -1290.842, 28.271),
    vector3(-57.402, -1751.747, 28.421),
    vector3(-718.261, -915.713, 18.216),
    vector3(-273.367, -2024.208, 29.170),
    vector3(-262.361, -2012.054, 29.170),
    vector3(-1391.344, -589.863, 29.316),
    vector3(-1827.689, 784.465, 137.315),
    vector3(-3040.205, 593.297, 6.909),
    vector3(-3240.028, 1008.545, 11.831),
    vector3(2559.052, 389.474, 107.623),
    vector3(1703.315, 4934.053, 41.064),
    vector3(1735.011, 6410.010, 34.037),
    vector3(2683.592, 3286.300, 54.241),
    vector3(1968.392, 3743.078, 31.344),
    vector3(540.221, 2671.683, 41.156),
}

Config.Blip = { sprite = 108, color = 2, scale = 0.7 } -- guichets uniquement (false : pas de blip)

Config.MaxAmount   = 1000000 -- montant max par opération (dépôt, retrait au guichet)
Config.AtmWithdraw = 5000    -- retrait max par opération à l'ATM
Config.MaxTransfer = 100000  -- virement max par opération

-- Suggested amounts selected by index. Each operation still applies its own cap.
Config.Amounts = { 100, 500, 1000, 5000, 10000, 100000, 1000000 }

Config.HistorySize = 20      -- opérations affichées
Config.HistoryDays = 30      -- les opérations plus anciennes sont supprimées au démarrage
