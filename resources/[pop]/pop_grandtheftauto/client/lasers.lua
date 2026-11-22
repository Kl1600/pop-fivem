-- Lasers de sécurité du showroom (kq_lasers, facultatif).

-- ==========================================
-- LASERS DE SÉCURITÉ (kq_lasers, facultatif)
-- ==========================================
-- Créés au lancement du casse (pas au démarrage de la ressource) et éteints par défaut.
-- Si kq_lasers est absent ou ne démarre pas (licence), la mission continue sans lasers.

local LaserPoints = {
    { vector3(-57.153, 64.519, 70.600), vector3(-59.235, 66.098, 74.006) },
    { vector3(-62.561, 65.485, 70.616), vector3(-55.872, 62.558, 73.966) },
    { vector3(-60.953, 70.252, 70.616), vector3(-70.540, 70.550, 74.032) },
    { vector3(-73.168, 70.077, 70.615), vector3(-71.556, 74.149, 74.033) },
    { vector3(-66.260, 72.684, 70.615), vector3(-71.196, 66.654, 74.032) },
    { vector3(-72.306, 74.974, 70.615), vector3(-74.276, 70.850, 74.032) },
    { vector3(-63.622, 71.386, 70.615), vector3(-76.291, 69.335, 73.020) },
    { vector3(-56.634, 68.014, 70.616), vector3(-63.154, 66.729, 74.006) },
    { vector3(-62.969, 65.034, 74.006), vector3(-59.910, 68.502, 70.616) },
    { vector3(-68.120, 77.455, 72.918), vector3(-71.873, 71.447, 70.629) },
    { vector3(-67.584, 71.863, 74.032), vector3(-69.374, 65.338, 71.534) },
    { vector3(-79.970, 73.918, 71.704), vector3(-76.041, 71.395, 70.615) },
    { vector3(-69.873, 74.781, 74.033), vector3(-76.042, 76.807, 70.615) },
    { vector3(-74.655, 70.445, 70.615), vector3(-76.440, 72.670, 74.020) },
    { vector3(-70.106, 73.888, 73.510), vector3(-57.158, 68.629, 70.616) },
    { vector3(-56.238, 68.734, 74.033), vector3(-63.947, 72.486, 70.615) },
    { vector3(-67.246, 64.109, 72.967), vector3(-61.745, 67.988, 70.616) },
    { vector3(-58.657, 72.421, 74.032), vector3(-59.259, 68.589, 70.616) },
    { vector3(-62.939, 75.054, 72.598), vector3(-60.672, 72.811, 70.615) },
    { vector3(-56.502, 68.483, 70.616), vector3(-53.087, 70.831, 73.388) },
    { vector3(-68.050, 67.081, 70.615), vector3(-65.585, 65.563, 74.006) },
    { vector3(-66.985, 65.808, 70.615), vector3(-69.140, 67.203, 74.006) },
    { vector3(-78.223, 78.288, 70.615), vector3(-79.313, 71.184, 74.033) },
}

local lasers = {}

local function CreateLasers()
    if #lasers > 0 then return end
    if GetResourceState('kq_lasers') ~= 'started' then return end
    for i, pts in ipairs(LaserPoints) do
        local ok, laser = pcall(function()
            return exports['kq_lasers']:CreateLaser('thornton_laser' .. i, {
                origin = pts[1],
                endPoint = pts[2],
                maxLength = 15.0,
                damage = 5,
                ragdoll = false,
                cooldown = 10000,
                active = false,
                triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = {} } }
            })
        end)
        if ok and laser then lasers[#lasers + 1] = laser end
    end
end

local function SetLasers(active)
    if active then CreateLasers() end
    for _, laser in ipairs(lasers) do
        pcall(function() laser.SetActive(active) end)
    end
end

local function DeleteLasers()
    for _, laser in ipairs(lasers) do
        pcall(function() laser.Delete() end)
    end
    lasers = {}
end

AddEventHandler('mission:local:lasers', function(active) SetLasers(active == true) end)

-- Lasers allumés au lancement du casse (avant la coupure de courant)
AddEventHandler('startheist', function()
    SetLasers(true)
end)

AddEventHandler('mission:local:reset', function() SetLasers(false) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DeleteLasers() end
end)
