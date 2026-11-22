-- Lasers de sécurité du showroom (dessinés et détectés par le script, sans ressource externe).
-- Allumés au lancement du casse, éteints par 'mission:local:lasers' false (coupure, alarme, fin de mission).
-- Visibles seulement chez les joueurs de la mission (tout est côté client).

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

local LASER_COLOR = { r = 255, g = 0, b = 0 }
local VIEW_DISTANCE = 40.0      -- dessin + détection seulement près du showroom
local TOUCH_DISTANCE = 0.25     -- distance corps-laser qui déclenche l'alarme
local TOUCH_COOLDOWN = 10000    -- ms entre deux déclenchements
local TOUCH_DAMAGE = 5

-- Points du corps testés : pieds, bassin, tête (os du ped)
local BODY_BONES = { 14201, 52301, 11816, 31086 } -- pied G, pied D, bassin, tête

-- Segments précalculés : origine, direction, longueur au carré
local segments = {}
for i, pts in ipairs(LaserPoints) do
    local a, b = pts[1], pts[2]
    local d = b - a
    segments[i] = { a = a, b = b, d = d, len2 = d.x * d.x + d.y * d.y + d.z * d.z }
end

local lasersActive = false
local lastTouch = 0

-- Distance au carré entre un point et un segment
local function DistToSegment2(p, s)
    local ap = p - s.a
    local t = 0.0
    if s.len2 > 0.0 then
        t = (ap.x * s.d.x + ap.y * s.d.y + ap.z * s.d.z) / s.len2
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
    end
    local c = s.a + s.d * t
    local dx, dy, dz = p.x - c.x, p.y - c.y, p.z - c.z
    return dx * dx + dy * dy + dz * dz
end

local function OnLaserTouched(ped)
    lastTouch = GetGameTimer()
    ApplyDamageToPed(ped, TOUCH_DAMAGE, false)
    TriggerEvent('grandtheftauto:alarme')
end

local loopRunning = false
local function StartLaserLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local touch2 = TOUCH_DISTANCE * TOUCH_DISTANCE
        while lasersActive do
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - Config.ShowroomPos) > VIEW_DISTANCE then
                Wait(1000) -- veille : loin du showroom
            else
                -- Léger scintillement
                local t = GetGameTimer()
                local alpha = math.floor(190 + 40 * math.sin(t * 0.015) + math.random(0, 25))
                for i = 1, #segments do
                    local s = segments[i]
                    DrawLine(s.a.x, s.a.y, s.a.z, s.b.x, s.b.y, s.b.z, LASER_COLOR.r, LASER_COLOR.g, LASER_COLOR.b, alpha)
                end

                if t - lastTouch > TOUCH_COOLDOWN and not IsEntityDead(ped) then
                    local touched = false
                    for j = 1, #BODY_BONES do
                        local p = GetPedBoneCoords(ped, BODY_BONES[j], 0.0, 0.0, 0.0)
                        for i = 1, #segments do
                            if DistToSegment2(p, segments[i]) <= touch2 then
                                touched = true
                                break
                            end
                        end
                        if touched then break end
                    end
                    if touched then OnLaserTouched(ped) end
                end
                Wait(0)
            end
        end
        loopRunning = false
    end)
end

local function SetLasers(active)
    lasersActive = active == true
    if lasersActive then StartLaserLoop() end
end

AddEventHandler('mission:local:lasers', function(active) SetLasers(active == true) end)

-- Lasers allumés au lancement du casse (avant la coupure de courant)
AddEventHandler('startheist', function()
    SetLasers(true)
end)

AddEventHandler('mission:local:reset', function() SetLasers(false) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetLasers(false) end
end)
