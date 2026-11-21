Config = {}

Config.GouvUSAccount = 'society_gouv'
Config.GouvMXAccount = 'society_gouv2'

-- Mode développeur (ignore les permissions de job pour tester)
Config.DevMode = false

-- Prix du chéquier d'entreprise commandé depuis SecuroServ (Finances), débité du
-- compte société (esx_addonaccount) — livré au patron via pop_inventory (checkbook_company).
Config.CompanyCheckbookPrice = 1500

-- Choix du style visuel du laptop (affecte uniquement l'UI, pas la logique)
-- '2026' = look moderne (défaut, photos HD, glassmorphism, fonts Inter)
-- '80s'  = look retro CRT / phosphore vert, scanlines, font pixel
Config.Style = '2026'

-- =============================================================
-- POSITION / TAILLE DE L'ÉCRAN DUI (par style)
-- -------------------------------------------------------------
-- Valeurs lues au démarrage du client par Config.Style.
-- Tu peux les éditer in-game avec /lapedity (gizmo 3D) ou la
-- touche F6 — les coords finales sont printées en F8, à coller
-- ici dans le bon bloc.
--
--  offset      : position du centre de l'écran, RELATIVE à
--                l'entité hôte (computer / prop_laptop_lester)
--  localNormal : vecteur normal sortant de l'écran (= où le
--                joueur regarde)
--  localUp     : vecteur "haut" de l'écran (orientation)
--  width/height: dimensions du quad DUI en mètres
--
--  screenPitch : ROTATION écran (degrés), additive sur
--                localNormal/localUp. + = haut de l'écran
--                bascule vers l'arrière (s'incline en arrière),
--                - = se penche en avant. Axe = "droite" du plan.
--  screenYaw   : + = tourne l'écran vers la droite (vu d'au-dessus),
--                - = vers la gauche. Axe = localUp.
--  screenRoll  : + = penche l'image dans le plan vers la droite
--                (Dutch angle sur la DUI), - = à gauche.
--                Axe = localNormal.
-- =============================================================
Config.ScreenTransform = {
    ['80s'] = {
        offset      = vector3(-0.2, 0.3180, 0.2293),
        localNormal = vector3(0.75, 0.0, -0.0763),
        localUp     = vector3(0.0, 0.0, -0.9924),
        width       = 0.1990,
        height      = 0.1590,
        screenPitch = 0.0,
        screenYaw   = 0.0,
        screenRoll  = 0.0,
    },
    ['2026'] = {
        offset      = vector3(0.1690, 0.3460, 0.2693),
        localNormal = vector3(-0.9944, 0.0697, -0.9),
        localUp     = vector3(0.0164, 0.0, -0.9924),
        width       = 0.4400,
        height      = 0.2800,
        screenPitch = 0.00,
        screenYaw   = 0.00,
        screenRoll  = 0.00,
    },
}

-- =============================================================
-- CAMÉRA DE FOCUS (par style)
-- -------------------------------------------------------------
-- camMode : 'scripted' = caméra scriptée fixe sur l'écran (défaut).
--           'none'     = AUCUNE caméra scriptée. Le joueur garde sa
--                        vue normale (FPV/TPV), peut bouger sa tête
--                        à la souris, etc. Utile pour les PC où tu
--                        veux laisser le joueur cadrer lui-même.
--                        Les paramètres camPos/lookAt/etc sont
--                        ignorés dans ce mode.
--
-- camPos / lookAt : VRAIES POSITIONS, vector3 en LOCAL ENTITÉ
--   (x = axe right entité, y = axe forward, z = axe up).
--   Même repère que ScreenTransform.offset. (0,0,0) = origine
--   du PC. Pour un écran qui regarde -x (cas typique :
--   localNormal ≈ (-0.99, ...)), la caméra se met avec
--   camPos.x négatif (= en face de l'écran).
--
-- lookAt : si nil → vise auto le centre de l'écran
--   (= ScreenTransform.offset du même style).
--
-- camOffset{Right,Up} / pointOffset{Right,Up} : AJUSTEMENTS
--   additifs dans le PLAN DE L'ÉCRAN (R = droite vue de face,
--   U = haut vrai du plan, suit l'inclinaison). Pratique pour
--   cadrer en "épaule" / décaler la vue sans recalculer camPos.
--
-- camPitch / camYaw / camRoll : SURCHARGES de rotation (degrés),
--   additives sur la rotation que PointCamAtCoord calcule depuis
--   lookAt. Permettent d'override le cadrage sans déplacer lookAt.
--
--   camPitch  : + = relève la cam (regarde plus haut),
--               - = plonge (regarde plus bas)
--   camYaw    : + = tourne à droite (heading), - = à gauche
--   camRoll   : + = penche à droite (Dutch angle),
--               - = penche à gauche. 0 = horizon parfait.
--
-- fov : zoom optique en degrés. ↓ = + zoomé.
--       ~25 = serré, ~50 = neutre, ~70 = grand angle.
-- =============================================================
Config.CameraTransform = {
    ['80s'] = {
        camMode          = 'scripted', -- 'scripted' | 'none'
        camPos           = vector3(-0.2, 0.0, 0.20),
        lookAt           = nil, -- nil = centre écran (ScreenTransform.offset)
        camOffsetRight   = 0.00,
        camOffsetUp      = 0.00,
        pointOffsetRight = 0.00,
        pointOffsetUp    = 0.00,
        camPitch         = 0.00,
        camYaw           = 0.00,
        camRoll          = 0.00,
        fov              = 30.0,
    },
    ['2026'] = {
        -- ⚠ ATTENTION : pour le style '2026' la caméra est hardcodée dans
        -- client.lua (copie verbatim de pos/client.lua). Les valeurs ci-dessous
        -- ne sont PAS lues — on les garde uniquement pour référence/doc.
        -- Si tu veux modifier la cam laptop, va dans client.lua, fonction
        -- startLaptopCam, bloc "2026 LAPTOP".
        camMode          = 'scripted',
        camPos           = vector3(-0.48, 0.00, 0.40), -- inerte
        lookAt           = vector3( 0.00, 0.00, 0.15), -- inerte
        camOffsetRight   = 0.00, -- inerte
        camOffsetUp      = 0.00, -- inerte
        pointOffsetRight = 0.00, -- inerte
        pointOffsetUp    = 0.00, -- inerte
        camPitch         = 0.00, -- inerte
        camYaw           = 0.00, -- inerte
        camRoll          = 0.00, -- inerte
        fov              = 30.0, -- inerte
    },
}

-- Choix du système de notification (Messages textuels)
-- 'custom' = Notification perso (export: exports["pop_notify"]:ShowNotify)
-- 'esx' = Notification ESX de base (ESX.ShowNotification)
Config.NotificationType = 'custom'

-- Choix du système de Help Notification (Instruction "Appuyez sur E...")
-- 'pop_v3dui' = Utilise l'export 3D personnalisée pop_v3dui
-- 'esx' = Utilise l'instruction haut à gauche classique (ESX.ShowHelpNotification)
Config.HelpNotificationType = 'pop_v3dui'

-- Choix du système de clés
-- true = Donne un item clé via l'export pop_inventory (Inventaire avancé pop_inventory)
-- false = Ne donne aucun item (la plaque est juste assignée à Society, pour un cardealer basique)
Config.UseTabInventoryKeys = true

-- Liste des emplacements de laptops prédéfinis
Config.Laptops = {
    {
        pos = vector3(359.4530, -1590.5414, 30.8404), -- Exemple: gouv
        heading = 236.758
    },
    {
        pos = vector3(-542.2896, -595.4548, 35.5426), -- Exemple: lspd
        heading = 89.3108
    },
    {
        pos = vector3(78.7052, -265.9535, 47.9536), -- Exemple: dynasty8
        heading = 71.6251
    },
    {
        pos = vector3(2662.3699, 3474.7129, 55.6938), -- vegatech
        heading = 154.3257
    },
    {
        pos = vector3(-33.0906, -1086.1802, 26.2561), -- concess sud
        heading = 180.6400
    },
    {
        pos = vector3(797.3143, -829.7857, 26.2357), -- concess occasion
        heading = 12.0
    },
        {
        pos = vector3(-587.1224, -883.0185, 26.0541), -- lucky plucker
        heading = 2.0
    },

    {
        pos = vector3(-1839.5942, -1183.7007, 14.2435), -- lucky plucker
        heading = 182.9008
    },

    {
        pos = vector3(949.8949, -968.6208, 39.292), -- rusty garage
        heading = 88.5622
    },

        {
        pos = vector3(2467.6191, 4098.4697, 37.8921), -- gopostal mexique
        heading = 48.6855
    },

            {
        pos = vector3(1847.4642, 3679.3723, 39.7237), -- policia federal
        heading = 299.5321
        },

                    {
            pos = vector3(2713.7114, 4327.7017, 46.2757), -- rex dinner
            heading = 229.510
        },

        
                    {
            pos = vector3(1768.0421, 3641.3420, 34.7329), -- NARedCross
            heading =  158.4413
        },

                            {
            pos = vector3(1072.5665, -2393.1553, 33.3677), -- FIB
            heading =  170.1933
        },

                                    {
            pos = vector3(-537.2267, -194.9765, 43.2890), -- doj
            heading =  8.2056
        },

                                            {
            pos = vector3(1186.7952, 2637.7412, 38.2697), -- HARMONY
            heading =  1.8481
        },

        {
            pos = vector3(1213.3263, 2731.7400, 38.6496), -- LARRY'S
            heading =  152.367
        },



}

-- =============================================================
-- BLIPS CENTRALISES (TOUS LES BLIPS STATIQUES DU SERVEUR)
-- -------------------------------------------------------------
-- Format par entrée:
--   title  = nom affiché sur la map
--   colour = couleur GTA (https://docs.fivem.net/docs/game-references/blips/)
--   id     = sprite id (https://docs.fivem.net/docs/game-references/blips/)
--   coords = vector3
--   scale  = (optionnel) taille du blip — défaut Config.DefaultBlipScale
--
-- Les autres ressources peuvent enregistrer leurs blips dynamiquement
-- via:  exports['pop_management']:RegisterBlip({ ... })
-- (utilisé p.ex. par pop_clothes pour ses boutiques de fringues).
-- =============================================================
Config.DefaultBlipScale = 0.9

Config.Blips = {
    -- LTDs
    { title = "LTD Gasoline", colour = 4, id = 521, coords = vector3(-48.2, -1757.5, 29.4),  scale = 0.8 },
    { title = "LTD Gasoline", colour = 4, id = 521, coords = vector3(1163.6, -323.8, 69.2),  scale = 0.8  },
    { title = "LTD Gasoline", colour = 4, id = 521, coords = vector3(-707.6, -914.2, 19.2),  scale = 0.8 },
    { title = "LTD Gasoline", colour = 4, id = 521, coords = vector3(-1820.5, 792.5, 138.1), scale = 0.8 },

    -- Fleeca Banks
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(150.2, -1040.2, 29.3),    scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(-1212.9, -330.8, 37.7),   scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(-2962.5, 482.6, 15.7),    scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(-112.2, 6469.3, 31.6),    scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(314.1, -278.6, 54.1),     scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(-351.5, -49.5, 49.0),     scale = 0.7 },
    { title = "Fleeca Bank", colour = 4, id = 512, coords = vector3(1175.0, 2706.6, 38.0),    scale = 0.7 },



    -- Restaurants / divers (déplacé depuis beavers_blips)
    { title = "~y~ENTREPRISE~p~ : Pearls", colour = 21, id = 532,  coords = vector3(-585.1157, -868.0085, 25.7061), scale = 1.2},
    { title = "~y~ENTREPRISE~p~ : Lucky Plucker", colour = 21, id = 532,  coords = vector3(-585.1157, -868.0085, 25.7061), scale = 1.2},
    { title = "~y~ENTREPRISE~p~ : Rusty Garage",              colour = 5,  id = 639, coords = vector3(945.5189, -984.3013, 39.4997),    scale = 1.0 },

    -- Stations services (déplacé depuis ox_fuel — pense à laisser showBlips=0 dans ox_fuel/config.lua)
    -- Los Santos
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-71.28, -1761.16, 29.48),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(264.74, -1260.98, 29.18),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1208.66, -1402.64, 35.22), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(818.83, -1029.89, 26.17),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1181.27, -329.57, 69.18),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(621.07, 269.52, 103.04),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-1437.58, -276.38, 46.21), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-2096.6, -318.15, 13.02),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-1799.03, 803.11, 138.4),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-524.84, -1211.02, 18.18), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(2581.56, 622.65, 108.46),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-319.84, -1471.77, 30.55), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(175.31, -1561.73, 29.26),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-723.72, -935.51, 19.21),  scale = 0.7 },
    -- Blaine County
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-2555.31, 2334.01, 33.06), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(49.69, 2778.33, 57.88),    scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(264.15, 2607.05, 44.95),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1207.56, 2660.2, 37.81),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(2538.0, 2593.83, 37.94),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(2680.01, 3265.0, 55.24),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(2005.07, 3774.33, 32.18),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1688.42, 4930.85, 42.08),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1039.34, 2671.78, 39.55),  scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(1702.79, 6416.86, 33.64), scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(179.94, 6602.6, 31.85),   scale = 0.7 },
    { title = "Station-service", colour = 4, id = 622, coords = vector3(-93.98, 6420.1, 31.48),   scale = 0.7 },

    -- Vêtements (déplacé depuis pop_clothes)
    { title = "Suburban",        colour = 4, id = 523, coords = vector3(72.254, -1399.102, 28.376),    scale = 0.6 },
    { title = "Ponsonbys",       colour = 4, id = 523, coords = vector3(-703.776, -152.258, 36.415),   scale = 0.6 },
    { title = "Ponsonbys",       colour = 4, id = 523, coords = vector3(-167.863, -298.969, 38.51523), scale = 0.6 },
    { title = "Binco",           colour = 4, id = 523, coords = vector3(428.694, -800.106, 28.491),    scale = 0.6 },
    { title = "Binco",           colour = 4, id = 523, coords = vector3(-829.413, -10523.710, 10.328), scale = 0.6 },
    { title = "Suburban",        colour = 4, id = 523, coords = vector3(-1193.136, -772.262, 16.324),  scale = 0.6 },
    { title = "Ponsonbys",       colour = 4, id = 523, coords = vector3(-1450.71, -238.16, 48.81),     scale = 0.6 },
    { title = "Discount Store",  colour = 4, id = 523, coords = vector3(4.25, 6512.81, 30.87),         scale = 0.6 },
    { title = "Discount Store",  colour = 4, id = 523, coords = vector3(1693.32, 4823.48, 41.06),      scale = 0.6 },
    { title = "Suburban",        colour = 4, id = 523, coords = vector3(125.55, -224.20, 53.55),       scale = 0.6 },
    { title = "Discount Store",  colour = 4, id = 523, coords = vector3(614.20, 2762.79, 41.08),       scale = 0.6 },
    { title = "Suburban",        colour = 4, id = 523, coords = vector3(1196.78, 2709.55, 37.22),      scale = 0.6 },
    { title = "Suburban",        colour = 4, id = 523, coords = vector3(-3171.49, 1043.85, 19.86),     scale = 0.6 },
    { title = "Discount Store",  colour = 4, id = 523, coords = vector3(-1100.95, 2710.21, 189.10),    scale = 0.6 },

    -- Barbiers (déplacé depuis pop_clothes)
    { title = "Barbier", colour = 4, id = 524, coords = vector3(-814.308, -183.823, 37.568),  scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(136.811, -1708.392, 29.291),  scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(-1282.604, -1116.757, 6.990), scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(1931.513, 3729.671, 32.844), scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(1212.840, -472.921, 66.208), scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(-32.885, -152.319, 57.076),  scale = 0.8 },
    { title = "Barbier", colour = 4, id = 524, coords = vector3(-278.077, 6228.463, 31.695), scale = 0.8 },

    -- Tatoueurs (déplacé depuis pop_clothes)
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(1322.642, -1651.976, 51.275),  scale = 0.8 },
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(-1153.676, -1425.68, 4.954),   scale = 0.8 },
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(322.139, 180.467, 103.587),    scale = 0.8 },
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(-293.713, 6200.028, 31.487),   scale = 0.8 },
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(1864.633, 3747.5238, 33.032), scale = 0.8 },
    { title = "Tatoueur", colour = 4, id = 627, coords = vector3(-1293.481, -416.5235, 33.348), scale = 0.8 },

    -- Gouvernement (City Hall LS)
    { title = "~y~ENTREPRISE~b~ : Gouvernement",   colour = 42, id = 558, coords = vector3(-545.3355, -604.3497, 100.7547),  scale = 1.0 },

    -- Hôpitaux


        { title = "~y~ENTREPRISE~g~ : Dept. of Justice",        colour = 2, id = 559, coords = vector3(-547.6927, -199.4976, 38.2269),   scale = 1.0 }, -- Pillbox Hill Medical
        { title = "~y~ENTREPRISE~g~ : Federal Bureau of Investigation",        colour = 40, id = 547, coords = vector3(1062.5751, -2412.6545, 29.4019),   scale = 1.0 }, -- Pillbox Hill Medical
        { title = "~y~ENTREPRISE~g~ : Los Santos Fire Dept.",        colour = 2, id = 578, coords = vector3(315.7462, -1040.8605, 29.2459),   scale = 1.0 }, -- Pillbox Hill Medical

    -- Simon's Safes (TODO: ajuster les coords)
    -- { title = "~y~ENTREPRISE~b~ : Simon's Safes",  colour = 36, id = 649, coords = vector3(0.0, 0.0, 72.0),        scale = 1.0 },

    -- LSPD
    { title = "~y~~y~ENTREPRISE~b~ : LSPD",           colour = 29, id = 634, coords = vector3(370.3372, -1601.5863, 41.7813),   scale = 1.0 }, -- Mission Row scale = 0.9 }, -- Sandy Shores

    -- Casino Diamond
    { title = "~y~ENTREPRISE~b~ : Casino",            colour = 15,  id = 575, coords = vector3(921.2241, 44.6155, 81.1053),     scale = 1.0 },

    -- YouTool


    -- Intérim
    { title = "~y~Intérim",           colour = 9,   id = 563, coords = vector3(-268.0, -957.0, 31.2),  scale = 1.0 },

    -- Concessionnaire (PDM)
    { title = "~y~ENTREPRISE~b~ : Premium Deluxe Motosport",   colour = 11,  id = 620, coords = vector3(-52.0449, -1095.3884, 26.4374), scale = 1.0 },

    { title = "~y~ENTREPRISE~b~ : Auto Prestige",   colour = 5,  id = 525, coords = vector3(811.6188, -822.2485, 26.1867), scale = 1.0 },

    -- Policia Federal
    { title = "~y~ENTREPRISE~b~ : Policia Federal", colour = 5, id = 634, coords = vector3(1824.9944, 3678.0046, 34.2176), scale = 1.0 },

    -- Restauration (Rex's Diner)
    { title = "~y~ENTREPRISE~b~ : Rex's Diner", colour = 47, id = 58, coords = vector3(2693.7388, 4326.0522, 45.8526), scale = 1.0 },

    -- Mécano (Harmony Repair)
    { title = "~y~ENTREPRISE~b~ : Harmony Repair", colour = 40, id = 639, coords = vector3(1179.3512, 2654.1863, 37.8364), scale = 1.0 },

    -- Magasin (Vega technologie)
    { title = "~y~ENTREPRISE~b~ : Vega Tech.", colour = 7, id = 629, coords = vector3(2650.8787, 3467.1035, 55.6173), scale = 1.0 },

    -- Concessionnaire (Larry's)
    { title = "~y~ENTREPRISE~b~ : Larry's", colour = 12, id = 620, coords = vector3(1213.3263, 2731.7400, 38.6496), scale = 1.0 },

    -- Service médical (North American Red Cross)
    { title = "~y~ENTREPRISE~b~ : North American Red Cross", colour = 1, id = 153, coords = vector3(1769.7070, 3635.0867, 34.7666), scale = 1.2 },

    -- Transport (Go Postal)
    { title = "~y~ENTREPRISE~b~ : GoPostal Mexique", colour = 5, id = 557, coords = vector3(2479.4954, 4084.4993, 37.8479), scale = 1.0 },
    { title = "~y~ENTREPRISE~b~ : GoPostal USA", colour = 5, id = 557, coords = vector3(208.1691, -2072.1458, 18.1511), scale = 1.0 },

    -- Agence immobilière (Dynasty 8)
    { title = "~y~ENTREPRISE~b~ : Dynasty 8", colour = 2, id = 577, coords = vector3(71.2740, -271.0648, 48.1881), scale = 1.0 },

}

-- =============================================================
-- DEV: BLIPS DE TEST À L'AÉROPORT (sprite 512 → 700)
-- -------------------------------------------------------------
-- Génère 189 blips alignés en grille sur le tarmac de LSIA pour
-- visualiser chaque sprite et choisir lesquels utiliser dans
-- le serveur. Actif uniquement si Config.DevMode est true.
-- Désactive (Config.DevMode = false) pour la prod.
-- =============================================================
if Config.DevMode then
    local devOrigin  = vector3(-1400.0, -3000.0, 13.95) -- coin SO grille (tarmac LSIA)
    local devCols    = 14    -- 14 cols x 14 rows = 196 cases (on en pose 189)
    local devSpacing = 8.0   -- mètres entre 2 blips
    for sprite = 512, 600 do
        local idx  = sprite - 512
        local col  = idx % devCols
        local row  = math.floor(idx / devCols)
        table.insert(Config.Blips, {
            title  = string.format("DEV Blip #%d", sprite),
            colour = 0, -- blanc
            id     = sprite,
            coords = vector3(
                devOrigin.x + col * devSpacing,
                devOrigin.y + row * devSpacing,
                devOrigin.z
            ),
            scale  = 0.9,
        })
    end
end

-- CONFIG LIVRAISON
Config.DeliveryTime = 45 * 60 * 1000 -- 60 minutes
Config.EnableDeliverySystem = true
Config.PaymentAccount = 'society_cardealer' -- Compte société utilisé pour les achats (ex: 'society_cardealer', 'society_police')

Config.Port = {
    Ped = {
        model = GetHashKey('s_m_m_dockwork_01'),
        coords = vector4(1194.57, -3253.25, 5.79, 87.0)
    },
    SpawnPoint = vector4(1185.0, -3253.0, 5.8, 270.0)
}

-- =============================================================
-- ÉTAGÈRE DE RÉCEPTION YOUTOOL (au Port)
-- -------------------------------------------------------------
-- Une étagère `v_med_cor_shelfrack` apparaît à coords. Elle est VIDE par
-- défaut : un carton apparaît sur un slot UNIQUEMENT pour chaque commande
-- COLIS en attente. Le livreur (job youtool) interagit avec le carton
-- (ox_target "Prendre le colis") -> il reçoit le vrai carton container
-- (items dedans) à livrer, et le prop disparaît.
--
-- coords         : position/orientation de l'étagère (vector4). La BASE du
--                  prop est posée exactement à coords.z. Place-toi à
--                  l'endroit voulu puis /ytshelf pour récupérer ces coords.
--
-- cartons.list   : les SLOTS où les cartons de commande apparaissent, en
--                  OFFSET RELATIF à l'étagère (x, y, z, heading relatif).
--                  La 1ère commande prend le slot 1, etc. Reste correct même
--                  si tu déplaces l'étagère. Enregistre-les avec le gizmo :
--                    /ytcarton    -> place un carton (souris), ENTRÉE valide
--                                    puis ENTRÉE = un autre / RETOUR = annuler
--                    /ytcartonfin -> termine + dump du bloc à coller (F8)
-- =============================================================
Config.YouToolShelf = {
    enabled = true,
    model   = GetHashKey('v_med_cor_shelfrack'),
    coords  = vector4(1194.8865, -3249.3145, 6.0952, 139.7573),
    camera  = {
        coords = vector3(1193.5732, -3250.8467, 7.2810),
        rot    = vector3(-4.5048, -0.0000, -41.0927),
        fov    = 74.00
    },
    cartons = {
        model = GetHashKey('prop_cs_cardbox_01'),
        list  = {
            vector4(0.415, 0.174, 0.283, -60.0),
            vector4(-0.065, 0.054, 0.282, 5.6),
            vector4(-0.594, -0.002, 0.281, -11.2),

            vector4(0.420, 0.073, 0.721, 9.5),
            vector4(-0.068, -0.038, 0.712, -8.8),
            vector4(-0.545, -0.003, 0.716, 2.5),

            vector4(0.504, -0.002, 1.279, 0.0),
            vector4(0.000, 0.000, 1.281, -15.4),
            vector4(-0.462, -0.066, 1.277, -263.6),
        },
    },
}

-- =============================================================
-- JOB YOUTOOL — gestion centralisée des livraisons
-- -------------------------------------------------------------
-- Toutes les commandes (véhicules PDM + colis YouTool B2B) sont
-- envoyées au job ci-dessous : ses employés les voient dans l'app
-- "Livraisons YouTool" et reçoivent une notif à chaque commande.
-- Tant que YouToolValidationRequired = true, un employé YouTool
-- doit VALIDER la commande (pending -> ready) avant que le client
-- (commettant) puisse la récupérer. Le retrait se fait au Port
-- (Config.Port), véhicules comme colis. Le client voit un blip
-- "Ma commande" au Port dès la commande (même non validée).
-- =============================================================
Config.YouToolJob = 'gopostal'          -- nom du job ESX qui gère les livraisons
Config.YouToolValidationRequired = true -- true = validation employé obligatoire (désactive les timers auto)
Config.YouToolDeliveryBonus = 75        -- prime ($) versée au livreur à la remise physique du colis

-- CONFIG LIVRAISON YOUTOOL B2B
Config.YouToolDeliveryTime = 10 * 60 * 1000 -- délai de secours : si personne ne valide, le client peut récupérer au dépôt après 10 min
Config.YouToolDeliveries = {

    default = {
        Ped = {
            model = GetHashKey('s_m_m_dockwork_01'),
            coords = vector4(128.5576, -1072.3440, 29.1923, 0.0)
        },
        Van = {
            model = GetHashKey('speedo'),
            coords = vector4(135.9132, -1071.9292, 29.1923, 0.0)
        }
    }
}

-- =============================================================
-- COMMANDES "BOT" (cas de figure 3 : aucun patron ne commande)
-- -------------------------------------------------------------
-- Toutes les Config.YouToolBotInterval ms, si au moins un livreur (job/job2
-- youtool) est en ligne, une commande PNJ est générée : un carton apparaît
-- sur l'étagère comme une vraie commande, et sa livraison pointe vers un PNJ
-- éphémère (pas un blip joueur) sur l'un des spots ci-dessous.
-- ⚠️ Coordonnées à ajuster (placeholders Los Santos) : place-toi à l'endroit
-- voulu et récupère tes coords (ex: /coords) pour remplir `pos`.
-- =============================================================
Config.YouToolBotEnabled  = true
Config.YouToolBotInterval = 5 * 60 * 1000 -- 5 minutes

Config.YouToolBotCatalog = {
    { model = 'bouteille', label = "Bouteille d'eau (x5)" },
    { model = 'soda',      label = 'Canette de Soda (x5)' },
    { model = 'cola',      label = 'Canette de Cola (x5)' },
    { model = 'hotdog',    label = 'Hotdog Classique (x5)' },
}

Config.YouToolBotSpots = {
    { pos = vector4(-1037.0, -2737.6, 20.2, 30.0),  pedModel = GetHashKey('a_m_m_business_01'), label = 'Client (Aéroport)' },
    { pos = vector4(-141.0, -620.9, 168.8, 200.0),  pedModel = GetHashKey('a_f_y_business_02'), label = 'Client (Rockford)' },
    { pos = vector4(215.0, -800.0, 30.7, 340.0),    pedModel = GetHashKey('a_m_m_business_01'), label = 'Client (Centre-ville)' },
}

-- CONFIG TERRITOIRES
Config.Territories = {
   --[[ -- Families (Davis)
    {
        title = "Territoire Families",
        color = 52, -- Vert (Families)
        alpha = 100,
        areas = {
            { coords = vector3(53.95, -1818.36, 27.66), width = 390.0, height = 210.0, heading = 50.0 },
            { coords = vector3(169.062, -1587.663, 77.28895), width = 260.0, height = 300.0, heading = 50.0 }
        }
    },
    -- Ballas (Chamberlain Hills)
    {
        title = "Territoire Ballas",
        color = 27, -- Violet (Ballas - approx)
        alpha = 100,
        areas = {
            { coords = vector3(-147.9323, -1600.784, 38.29156), width = 200.0, height = 280.0, heading = 50.0 }
        }
    },
    -- Vagos (Rancho)
    {
        title = "Territoire Vagos",
        color = 66, -- Jaune (Vagos)
        alpha = 100,
        areas = {
            { coords = vector3(320.2412, -2039.633, 28.96141), width = 290.0, height = 220.0, heading = 50.0 },
            { coords = vector3(413.2437, -1782.743, 40.27221), width = 370.0, height = 300.0, heading = 50.0 }
        }
    },
    -- Madrazo Ranch (La Fuente Blanca)
    {
        title = "Madrazo Ranch",
        color = 75, -- Rouge (Cartel Madrazo)
        alpha = 100,
        areas = {
            { coords = vector3(1392.51, 1140.24, 114.0), width = 250.0, height = 300.0, heading = 0.0 }
        }
    }]]
}

-- =============================================================
-- DYNASTY 8 — ZONES MLO
-- -------------------------------------------------------------
-- Chaque entrée correspond à un bien immobilier Dynasty 8.
-- coords  : un point DANS l'intérieur du MLO (récupérer avec
--           /d8coords ou print(GetEntityCoords(PlayerPedId())) en F8
--           depuis l'intérieur du MLO).
-- radius  : rayon de la sphere de détection en mètres.
--           15 = appartement standard, 30 = entrepôt/villa large.
-- =============================================================
Config.D8Zones = {
    -- EXEMPLE (à remplacer par tes vraies coords + radius)
    --[[
    {
        id     = 1,
        name   = 'Eclipse Tower N°40',
        coords = vector3(-774.2, 312.0, 87.3),
        radius = 15.0,
    },
    {
        id     = 2,
        name   = 'Eclipse Tower N°41',
        coords = vector3(-774.2, 312.0, 100.0),
        radius = 15.0,
    },
    {
        id     = 10,
        name   = 'Entrepôt La Mesa',
        coords = vector3(800.0, -1200.0, 20.0),
        radius = 30.0,
    },
    ]]
}
