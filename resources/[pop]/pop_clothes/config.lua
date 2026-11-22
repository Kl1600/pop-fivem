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
-- pop_clothes
------------------------------------------------------------------------
Config.GouvUSAccount = 'society_gouv'
Config.GouvMXAccount = 'society_gouv2'
Config.Currency = '$'
Config.Mode80s = true

-- Notifications de la boutique (pop_notify).
Config.NotifyImage = 'nui://pop_management/html/Trevor.png'
Config.NotifyDuration = 5000


-- Shop Locations and Types
--
-- Optional fields per shop to lock the opening camera (avoids spawning in a wall/prop):
--   pedCoords  = vector3(x, y, z)             -- teleport the player here on open (restored on close)
--   pedHeading = number                       -- force the player heading (so they face the cam)
--   cam = {
--       coords = vector3(x, y, z),            -- absolute camera world position (REQUIRED to lock)
--       lookAt = vector3(x, y, z),            -- absolute point the camera looks at (defaults to pedCoords/shop.coords)
--       fov    = number,                      -- optional, default 45
--   }
-- When `cam.coords` is set: mouse zoom and vertical drag are disabled, category focus is ignored.
-- Mouse horizontal drag still rotates the ped so the player can see all sides.
-- NOTE: les blips de ces shops sont entièrement gérés dans
-- pop_management/config.lua (Config.Blips). Ne PAS recréer
-- de blips ici, sinon doublons.
Config.Shops = {
    -- Vêtements
    { coords = vector3(72.254, -1399.102, 28.376),     name = "Suburban",       type = "clothing" },
    { coords = vector3(-703.776, -152.258, 36.415),    name = "Ponsonbys",      type = "clothing" },
    { coords = vector3(-167.863, -298.969, 38.51517),  name = "Ponsonbys",      type = "clothing" },
    { coords = vector3(428.694, -800.106, 28.491),     name = "Binco",          type = "clothing" },
    { coords = vector3(-829.413, -1073.710, 10.328),   name = "Binco",          type = "clothing" }, -- Binco Vespucci (Y corrigé)
    { coords = vector3(-1193.136, -772.262, 16.324),   name = "Suburban",       type = "clothing" },
    { coords = vector3(-1450.71, -238.16, 48.81),      name = "Ponsonbys",      type = "clothing" },
    { coords = vector3(4.25, 6512.81, 30.87),          name = "Discount Store", type = "clothing" },
    { coords = vector3(1693.32, 4823.48, 41.06),       name = "Discount Store", type = "clothing" },
    { coords = vector3(125.55, -224.20, 53.55),        name = "Suburban",       type = "clothing" },
    { coords = vector3(614.20, 2762.79, 41.08),        name = "Discount Store", type = "clothing" },
    { coords = vector3(1196.78, 2709.55, 37.22),       name = "Suburban",       type = "clothing" },
    { coords = vector3(-3171.49, 1043.85, 19.86),      name = "Suburban",       type = "clothing" },
    { coords = vector3(-1100.95, 2710.21, 18.10),      name = "Discount Store", type = "clothing" }, -- Route 68 (Z corrigé)

    -- Barbiers
    { coords = vector3(-814.308, -183.823, 37.568),    name = "Barbier", type = "barber" },
    { coords = vector3(136.811, -1708.392, 29.291),    name = "Barbier", type = "barber" },
    { coords = vector3(-1282.604, -1116.757, 6.990),   name = "Barbier", type = "barber" },
    { coords = vector3(1931.513, 3729.671, 32.844),    name = "Barbier", type = "barber" },
    { coords = vector3(1212.840, -472.921, 66.208),    name = "Barbier", type = "barber" },
    { coords = vector3(-32.885, -152.319, 57.076),     name = "Barbier", type = "barber" },
    { coords = vector3(-278.077, 6228.463, 31.695),    name = "Barbier", type = "barber" },

    -- Tatoueurs
    { coords = vector3(1322.642, -1651.976, 51.275),   name = "Tatoueur", type = "tattoo" },
    { coords = vector3(-1153.676, -1425.68, 4.954),    name = "Tatoueur", type = "tattoo" },
    { coords = vector3(322.139, 180.467, 103.587),     name = "Tatoueur", type = "tattoo" },
    { coords = vector3(-293.713, 6200.028, 31.487),    name = "Tatoueur", type = "tattoo" },
    { coords = vector3(1864.633, 3747.5178, 33.032),   name = "Tatoueur", type = "tattoo" },
    { coords = vector3(-1293.481, -416.5175, 33.348),  name = "Tatoueur", type = "tattoo" },
}

-- Categories Definitions
Config.Categories = {
    ['clothing'] = {
        'Hats', 'Masks', 'Ears', 'Glasses', 'Torsos', 'Legs', 'Bags',
        'Shoes', 'Accessories', 'Watches', 'Bracelets', 'Undershirts',
        'Body Armors', 'Tops', 'Decals'
    },
    ['barber'] = {
        'Hair', 'Beard', 'Eyebrows', 'ChestHair', 'Makeup', 'Lipstick', 'Blush'
    },
    ['tattoo'] = {
        'Head', 'Torso', 'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg'
    }
}

-- Prices Configuration
Config.Prices = {
    -- Clothes
    ['Hats'] = 50, ['Masks'] = 100, ['Ears'] = 25, ['Glasses'] = 30, ['Torsos'] = 40,
    ['Accessories'] = 35, ['Watches'] = 200, ['Bracelets'] = 150, ['Undershirts'] = 25,
    ['Body Armors'] = 500, ['Tops'] = 60, ['Legs'] = 55, ['Shoes'] = 45, ['Bags'] = 120, ['Decals'] = 25,
    -- Barber
    ['Hair'] = 50, ['Beard'] = 30, ['Eyebrows'] = 20, ['ChestHair'] = 40, ['Makeup'] = 60, ['Lipstick'] = 25, ['Blush'] = 25,
    -- Tattoos
    ['Head'] = 150, ['Torso'] = 300, ['LeftArm'] = 200, ['RightArm'] = 200, ['LeftLeg'] = 180, ['RightLeg'] = 180,
    ['default'] = 50
}

-- Component Configuration
Config.Components = {
    ['Hats'] = { type = 'prop', component = 0 },
    ['Masks'] = { type = 'clothing', component = 1 },
    ['Ears'] = { type = 'prop', component = 2 },
    ['Glasses'] = { type = 'prop', component = 1 },
    ['Torsos'] = { type = 'clothing', component = 3 },
    ['Legs'] = { type = 'clothing', component = 4 },
    ['Bags'] = { type = 'clothing', component = 5 },
    ['Shoes'] = { type = 'clothing', component = 6 },
    ['Accessories'] = { type = 'clothing', component = 7 },
    ['Undershirts'] = { type = 'clothing', component = 8 },
    ['Body Armors'] = { type = 'clothing', component = 9 },
    ['Tops'] = { type = 'clothing', component = 11 },
    ['Watches'] = { type = 'prop', component = 6 },
    ['Bracelets'] = { type = 'prop', component = 7 },
    ['Decals'] = { type = 'clothing', component = 10 },
    -- Barber Overlays
    ['Hair'] = { type = 'clothing', component = 2 },
    ['Beard'] = { type = 'overlay', component = 1 },
    ['Eyebrows'] = { type = 'overlay', component = 2 },
    ['ChestHair'] = { type = 'overlay', component = 10 },
    ['Makeup'] = { type = 'overlay', component = 4 },
    ['Lipstick'] = { type = 'overlay', component = 8 },
    ['Blush'] = { type = 'overlay', component = 5 },
    -- Tattoos (handled by zones)
    ['Head'] = { type = 'tattoo', zone = 'ZONE_HEAD' },
    ['Torso'] = { type = 'tattoo', zone = 'ZONE_TORSO' },
    ['LeftArm'] = { type = 'tattoo', zone = 'ZONE_LEFT_ARM' },
    ['RightArm'] = { type = 'tattoo', zone = 'ZONE_RIGHT_ARM' },
    ['LeftLeg'] = { type = 'tattoo', zone = 'ZONE_LEFT_LEG' },
    ['RightLeg'] = { type = 'tattoo', zone = 'ZONE_RIGHT_LEG' }
}
