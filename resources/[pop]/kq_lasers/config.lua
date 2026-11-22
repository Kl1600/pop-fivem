Config = {}

Config.debug = false

--- SETTINGS FOR ESX
Config.esxSettings = {
    enabled = false,
    -- Whether or not to use the new ESX export method
    useNewESXExport = true,
}

--- SETTINGS FOR QBCORE
Config.qbSettings = {
    enabled = false,
}

--- IF USING A STANDALONE SOLUTION. SIMPLY DISABLE BOTH FRAMEWORKS



-- https://docs.fivem.net/docs/game-references/controls/
-- Use the input index for the "input" value
Config.keybinds = {
    debug = {
        label = 'E',
        name = 'INPUT_PICKUP',
        input = 38,
    },
}


------------------------------------------
--- LASERS
------------------------------------------

Config.laser = {
    -- Overal maximum render distance for all lasers
    maxRenderDistance = 50.0,
    
    -- Laser prop
    prop = {
        -- Whether to use the laser prop
        enabled = true,
        -- The prop model
        model = 'w_at_sr_supp_2',
        -- The prop offset
        offset = vector3(-0.022, 0.0, 0.0),
        -- The prop rotation offset
        rotation = vector3(0.0, 180.0, 0.0),
    },
    
    -- All lasers
    -- Please refer to the documentation.md file to learn more.
    lasers = {
--[[
['laser1'] = {
        origin = vector3(-57.153, 64.519, 70.600),
        endPoint = vector3(-59.235, 66.098, 74.006),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser2'] = {
        origin = vector3(-62.561, 65.485, 70.616),
        endPoint = vector3(-55.872, 62.558, 73.966),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser3'] = {
        origin = vector3(-60.953, 70.252, 70.616),
        endPoint = vector3(-70.540, 70.550, 74.032),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser4'] = {
        origin = vector3(-73.168, 70.077, 70.615),
        endPoint = vector3(-71.556, 74.149, 74.033),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser5'] = {
        origin = vector3(-66.260, 72.684, 70.615),
        endPoint = vector3(-71.196, 66.654, 74.032),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },
    ['laser6'] = {
        origin = vector3(-72.306, 74.974, 70.615),
        endPoint = vector3(-74.276, 70.850, 74.032),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser7'] = {
        origin = vector3(-63.622, 71.386, 70.615),
        endPoint = vector3(-76.291, 69.335, 73.020),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser8'] = {
        origin = vector3(-56.634, 68.014, 70.616),
        endPoint = vector3(-63.154, 66.729, 74.006),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser9'] = {
        origin = vector3(-62.969, 65.034, 74.006),
        endPoint = vector3(-59.910, 68.502, 70.616),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser10'] = {
        origin = vector3(-68.120, 77.455, 72.918),
        endPoint = vector3(-71.873, 71.447, 70.629),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser11'] = {
        origin = vector3(-67.584, 71.863, 74.032),
        endPoint = vector3(-69.374, 65.338, 71.534),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },
    ['laser12'] = {
        origin = vector3(-79.970, 73.918, 71.704),
        endPoint = vector3(-76.041, 71.395, 70.615),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser13'] = {
        origin = vector3(-69.873, 74.781, 74.033),
        endPoint = vector3(-76.042, 76.807, 70.615),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser14'] = {
        origin = vector3(-74.655, 70.445, 70.615),
        endPoint = vector3(-76.440, 72.670, 74.020),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser15'] = {
        origin = vector3(-70.106, 73.888, 73.510),
        endPoint = vector3(-57.158, 68.629, 70.616),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser16'] = {
        origin = vector3(-56.238, 68.734, 74.033),
        endPoint = vector3(-63.947, 72.486, 70.615),
    },

    ['laser17'] = {
        origin = vector3(-67.246, 64.109, 72.967),
        endPoint = vector3(-61.745, 67.988, 70.616),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser18'] = {
        origin = vector3(-58.657, 72.421, 74.032),
        endPoint = vector3(-59.259, 68.589, 70.616),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },
    ['laser19'] = {
        origin = vector3(-62.939, 75.054, 72.598),
        endPoint = vector3(-60.672, 72.811, 70.615),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser20'] = {
        origin = vector3(-56.502, 68.483, 70.616),
        endPoint = vector3(-53.087, 70.831, 73.388),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser21'] = {
        origin = vector3(-68.050, 67.081, 70.615),
        endPoint = vector3(-65.585, 65.563, 74.006),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser22'] = {
        origin = vector3(-66.985, 65.808, 70.615),
        endPoint = vector3(-69.140, 67.203, 74.006),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },

    ['laser23'] = {
        origin = vector3(-78.223, 78.288, 70.615),
        endPoint = vector3(-79.313, 71.184, 74.033),
        maxLength = 15.0,
                cooldown = 5000,
                    -- This is an example of a handler which spawns enemies after the laser is triggered
            handler = function()
                   print('alarm')
            end
    },
    ]]
    }
}

------------------------------------------
--- DISPATCH
------------------------------------------

Config.dispatch = {
    system = 'default',   -- Setting for the dispatch system to use ('default' for the built-in system or 'cd-dispatch', 'core-dispatch-old', 'core-dispatch-new' or 'ps-dispatch' for external systems)

    globalCooldown = 30,  -- The global cooldown in seconds
    blip = {
        sprite = 788,     -- Sprite for the blip
        color = 75,       -- Color for the blip
        scale = 1.0,      -- Scale for the blip

        timeout = 60,     -- Time in seconds for the blip to disappear

        showRadar = true, -- Setting to show the radar blip on the radar
    },
}


-- (Commandes de test /alarme et /stopalarm retirées.)
