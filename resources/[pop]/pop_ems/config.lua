Config = {}

------------------------------------------------------------------------
-- Common POP settings (do not remove)
------------------------------------------------------------------------
Config.Locale = 'fr'          -- fr, en, es, de, ar (missing key falls back to 'en')
Config.Debug = false
Config.Framework = 'auto'     -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto'     -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto'     -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto'     -- 'framework' | 'ox_lib' | 'pop' | 'native'
Config.AccentColor = '#5d90ec'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_ems
------------------------------------------------------------------------

-- Job (standalone: ACE 'pop.ems' instead)
Config.Job = { name = 'ambulance', minGrade = 0 }

-- Key to take the latest pending call (players can change it in FiveM key bindings)
Config.AcceptCallKey = 'Y'

-- Items used (false = no item required)
Config.Items = { bandage = 'bandage', kit = 'kitsoins', defib = 'defib' }

-- Action durations (ms)
Config.Durations = { diagnose = 3000, bandage = 4000, kit = 8000, revive = 10000, load = 3000 }

-- Prices billed to the patient (0 = free)
Config.Prices = { bandage = 50, kit = 150, revive = 500, admit = 800 }

-- Health given back (GTA health: 100 = dead, 200 = full)
Config.ReviveHealth = 150
Config.BandageHealth = 20

-- Distances (m)
Config.Distances = { interact = 3.0, vehicle = 6.0, admit = 15.0, zone = 2.0 }

-- Seconds between two finished actions for the same medic (anti-spam)
Config.ActionCooldown = 3

-- Calls: expire (s), arrival distance that closes the call (m), cards shown
Config.Calls = { expire = 600, arrive = 20.0, maxShown = 3 }

-- Light injuries (bleeding, limp)
Config.Injuries = {
    enabled = true,
    bleedDamage = 15,   -- damage in one hit that starts bleeding
    bleedLoss = 2,      -- health lost per tick while bleeding
    interval = 10,      -- seconds between ticks
    limpClipset = 'move_m@injured',
}

-- Player ped models that can be treated (add your addon peds)
Config.PlayerModels = { 'mp_m_freemode_01', 'mp_f_freemode_01' }

-- Service vehicles (label can be renamed)
Config.Vehicles = {
    { model = 'ambulance', label = 'Ambulance' },
}

-- Patient position in the back of the ambulance (offset from the vehicle)
Config.PatientOffset = vec3(0.0, -2.2, 0.6)

-- EMS outfit: [component id] = { drawable, texture }
Config.Outfits = {
    male   = { [3] = { 85, 0 }, [4] = { 96, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 250, 0 } },
    female = { [3] = { 109, 0 }, [4] = { 99, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [11] = { 258, 0 } },
}

-- Blips: sprite, colour, scale
Config.Blips = {
    station = { sprite = 61, color = 2, scale = 0.8 },
    call    = { sprite = 153, color = 1, scale = 0.9 },
}

-- Hospitals (same as pop_death). Coordinates to check in game.
Config.Stations = {
    {
        label = 'Pillbox Hill',
        locker  = vec3(301.6, -599.3, 43.3),
        garage  = vec3(294.5, -600.8, 43.3),
        spawn   = vec4(290.8, -610.6, 43.4, 70.0),
        dropoff = vec3(294.0, -574.5, 43.2),
        bed     = vec4(298.6, -584.5, 43.3, 70.0),
    },
    {
        label = 'Sandy Shores',
        locker  = vec3(1834.2, 3688.4, 34.3),
        garage  = vec3(1828.3, 3693.2, 34.2),
        spawn   = vec4(1820.6, 3692.1, 34.2, 300.0),
        dropoff = vec3(1836.5, 3669.6, 34.3),
        bed     = vec4(1839.4, 3672.9, 34.3, 210.0),
    },
    {
        label = 'Paleto Bay',
        locker  = vec3(-254.2, 6324.6, 32.4),
        garage  = vec3(-259.5, 6334.9, 32.4),
        spawn   = vec4(-270.6, 6337.6, 32.4, 225.0),
        dropoff = vec3(-243.5, 6326.2, 32.4),
        bed     = vec4(-247.8, 6331.2, 32.4, 225.0),
    },
}
