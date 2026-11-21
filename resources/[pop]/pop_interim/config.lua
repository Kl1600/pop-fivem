Config = Config or {}

-- =============================================================
-- AGENCE D'INTÉRIM
-- -------------------------------------------------------------
-- Interface NUI (style pop_emotes) ouverte à l'emplacement du blip
-- "Intérim" déjà défini dans pop_management/config.lua.
-- Le blip n'est PAS recréé ici : pop_management en reste la source.
-- =============================================================

-- Emplacement de l'agence (= coords du blip Intérim de pop_management).
Config.Location = vector3(-268.0, -957.0, 31.2)

-- Marqueur au sol + interaction.
Config.OpenKey       = 38     -- touche E (control 38)
Config.DrawDistance  = 12.0   -- distance d'affichage du marqueur
Config.InteractDist  = 1.6    -- distance pour pouvoir appuyer sur E

Config.Marker = {
    type  = 1,
    sizeX = 1.5, sizeY = 1.5, sizeZ = 1.0,
    r = 70, g = 170, b = 240, a = 110,
}

-- Caméra de prévisualisation du poste.
-- Le `w` de chaque `camera` (vector4) = orientation (heading). Pitch/FOV
-- sont communs et ajustables ici.
Config.CameraPitch = 0.0    -- inclinaison verticale (négatif = vers le bas)
Config.CameraFov   = 50.0   -- zoom (plus petit = plus zoomé)
Config.CameraBlend = 700    -- durée (ms) de la transition de caméra

-- =============================================================
-- MÉTIERS PROPOSÉS (3 cases images, en bas de l'écran)
-- -------------------------------------------------------------
-- Chaque entrée :
--   id     = identifiant interne (whitelist serveur, ne pas dupliquer)
--   label  = nom affiché sur la case
--   image  = visuel de la case. `nui://pop_management/html/<fichier>`
--            pointe vers les images servies par pop_management.
--   job    = ⚠️ nom EXACT du job dans ta table ESX `jobs`
--   grade  = grade attribué (0 par défaut)
--   camera = vector4(x, y, z, heading) — vue caméra au clic (nil = aucune)
--
-- ⚠️ Vérifie que chaque `job` existe bien côté ESX, sinon SetJob est
--    ignoré (warning dans la console serveur).
-- =============================================================
Config.Jobs = {
    {
        id          = 'pesticides',
        label       = 'Répandeur de pesticides',
        description = 'Traitement aérien des cultures',
        image  = 'nui://pop_management/html/b8f1f98587_sparrow.jpg',
        job    = 'pesticides',
        grade  = 0,
        camera = {
            pos = vector3(-1748.3857, 1991.1857, 117.8160),
            rot = vector3(3.2499, -0.0000, -168.1393),
            fov = 22.00,
            dof = true,
            focusDist = 3.85
        },
        pedPos = vector4(-1747.5060, 1987.4343, 117.6647, 18.6467),
        pedAnimDict = "anim@heists@heist_corona@single_team",
        pedAnimName = "single_team_loop_boss",
        previewPeds = {
            {
                model = "s_m_m_security_01",
                coords = vector4(-1746.6111, 1986.6731, 117.8354, 81.0269),
                animDict = "anim@tactical_kneel_walkie",
                animName = "kneel_walkie_clip"
            },
            {
                model = "s_m_m_gardener_01",
                coords = vector4(-1747.8359, 1986.2761, 117.8937, 20.0265),
                animDict = "anim@scripted@cbr5@ig3_drill_box@pattern_03@lockbox_03@male@",
                animName = "rest"
            }
        },
        previewVehicles = {
            {
                model = "seasparrow2",
                coords = vector4(-1746.1069, 1985.0380, 118.7495, 61.9805)
            }
        },
    },
    {
        id          = 'youtool',
        label       = 'Livreur GoPostal',
        description = 'Livraison de marchandise',
        image  = 'nui://pop_management/html/gopostal.png',
        job    = 'gopostal',
        grade  = 1,
        isJob2 = true,
        camera = {
            pos = vector3(1173.0841, -3309.5552, 6.2709),
            rot = vector3(1.9870, 0.0, -94.3564),
            fov = 30.00,
            dof = true,
            focusDist = 6.93,
            nearDof = 5.0
        },
        pedPos = vector4(1175.5, -3311.5, 6.0, 225.0),
        pedAnimDict = "anim@amb@carmeet@checkout_engine@",
        pedAnimName = "female_c_idle_d",
        previewPeds = {
            -- Ped with box (boite en carton)
            {
                model = "s_m_m_postal_01",
                coords = vector4(1176.8125, -3310.5674, 6.0288, 160.5903),
                animDict = "anim@heists@box_carry@",
                animName = "idle",
                animFlag = 49,
                prop = "hei_prop_heist_box",
                boneIndex = 60309,
                propPlacement = {0.025, 0.08, 0.255, -145.0, 290.0, 0.0}
            },
            -- Ped with charriot (trolley 4 / pallet 4)
            {
                model = "s_m_m_postal_01",
                coords = vector4(1180.2562, -3310.1536, 6.0288, 68.8752),
                animDict = "anim@mp_ferris_wheel", 
                animName = "idle_a_player_two",
                animFlag = 49,
                prop = "prop_flattruck_01c",
                boneIndex = -1,
                propPlacement = {0.0, 1.3, -0.97, 0.0, 0.0, 180.0}
            },
            -- Ped with notepad
            {
                model = "s_m_m_postal_01",
                coords = vector4(1175.5317, -3309.2703, 5.9170, 71.1752),
                animDict = "missheistdockssetup1clipboard@base",
                animName = "base",
                animFlag = 49,
                prop = "prop_notepad_01",
                boneIndex = 18905,
                propPlacement = {0.1, 0.02, 0.05, 10.0, 0.0, 0.0},
                extraProp = "prop_pencil_01",
                extraBoneIndex = 58866,
                extraPropPlacement = {0.11, -0.02, 0.001, -120.0, 0.0, 0.0}
            }
        },
        previewVehicles = {
            -- 1. Boxville4
            {
                model = "boxville4",
                coords = vector4(1178.5614, -3307.3799, 5.9486, 89.2651)
            },
            -- 2. Rumpo (open back left door)
            {
                model = "rumpo",
                coords = vector4(1177.3879, -3314.0940, 6.0510, 203.1342),
                doorOpen = 2
            }
        }
    },
    {
        id          = 'transport_urgence',
        label       = "Transport d'urgence",
        description = "Transport médical d'urgence",
        image  = 'nui://pop_management/html/sentinelqp.png',
        job    = 'transport_organe',
        grade  = 0,
        camera = {
            pos = vector3(366.1452, -606.4926, 29.2108),
            rot = vector3(-4.3079, 0.0, 96.4414),
            fov = 26.00,
            dof = true,
            focusDist = 5.69
        },
        pedPos = vector4(360.2576, -607.1755, 28.6857, 276.8391),
        pedAnimDict = "random@shop_tattoo",
        pedAnimName = "_idle_a",
        previewPeds = {
            -- Inspecter 2
            {
                model = "s_m_m_postal_01",
                coords = vector4(358.5620, -608.4681, 28.6855, 223.5900),
                animDict = "anim@amb@carmeet@checkout_engine@",
                animName = "female_c_idle_d",
                animFlag = 1
            },
            -- Briefcase Ped
            {
                model = "s_m_m_postal_01",
                coords = vector4(359.9845, -605.8492, 28.6747, 266.2759),
                weapon = "WEAPON_BRIEFCASE_03"
            }
        },
        previewVehicles = {
            -- Vehicle 1: Sentinel5 (trunk open)
            {
                model = "sentinel5",
                coords = vector4(360.4900, -610.6686, 28.2080, 213.5158),
                colours = {54, 11},
                extraColours = {0, 54},
                interiorColour = 11,
                dashboardColour = 11,
                modKit = 0,
                livery = 10,
                doorOpen = 5
            },
            -- Vehicle 2: Sentinel5 (right back door open)
            {
                model = "sentinel5",
                coords = vector4(357.9776, -605.2109, 28.1367, 17.8637),
                colours = {111, 11},
                extraColours = {111, 111},
                interiorColour = 11,
                dashboardColour = 11,
                modKit = 0,
                livery = 10,
                doorOpen = 3
            }
        }
    },
}
