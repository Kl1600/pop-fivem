-- Géométrie des territoires (client et serveur). Construite une fois depuis Config.Zones, aucune boucle.
--   Zones.List            zones valides normalisées (ordre de la config)
--   Zones.Get(id)         zone | nil
--   Zones.At(coords)      première zone contenant coords (test 2D x, y) | nil
--   Zones.Contains(z, c)  bool
-- Zone normalisée : { id, label, price, center = vector3, radius, points = { vector2 } | nil, min = vector2, max = vector2 }

Zones = { List = {} }

local RES = GetCurrentResourceName()
local byId = {}

-- Nombre fini, sinon nil.
local function finite(n)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

-- Extrait (x, y) d'un vector2/3/4 ou d'une table { x, y } ; nil si invalide.
local XY_TYPES = { vector2 = true, vector3 = true, vector4 = true, table = true }
local function xy(v)
    if not XY_TYPES[type(v)] then return nil end
    local x, y = finite(v.x), finite(v.y)
    if not x or not y then return nil end
    return x, y
end

-- Normalise une entrée de Config.Zones ; nil si invalide.
local function normalize(def)
    if type(def) ~= 'table' then return nil end
    local id = def.id
    if type(id) ~= 'string' or #id < 1 or #id > 32 or not id:match('^[%w_]+$') or byId[id] then return nil end

    local price = finite(def.price)
    if not price or price < 0.1 or price > 10 then
        if def.price ~= nil then print(('[%s] invalid price for zone "%s" (0.1-10), using 1.0'):format(RES, id)) end
        price = 1.0
    end
    local label = (type(def.label) == 'string' and def.label ~= '') and def.label or id

    local zone = { id = id, label = label, price = price }

    if def.points ~= nil then
        -- Polygone : au moins 3 points valides.
        if type(def.points) ~= 'table' or #def.points < 3 then return nil end
        local pts = {}
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local sumX, sumY = 0.0, 0.0
        for i = 1, #def.points do
            local x, y = xy(def.points[i])
            if not x then return nil end
            pts[i] = vector2(x, y)
            sumX, sumY = sumX + x, sumY + y
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
        end
        local cx, cy = sumX / #pts, sumY / #pts
        local radius = 0.0
        for i = 1, #pts do
            local d = math.sqrt((pts[i].x - cx) ^ 2 + (pts[i].y - cy) ^ 2)
            if d > radius then radius = d end
        end
        zone.points = pts
        zone.center = vector3(cx, cy, 0.0)
        zone.radius = radius
        zone.min = vector2(minX, minY)
        zone.max = vector2(maxX, maxY)
    else
        -- Cercle : center + radius > 0.
        local x, y = xy(def.center)
        local radius = finite(def.radius)
        if not x or not radius or radius <= 0 then return nil end
        local z = (type(def.center) ~= 'vector2' and finite(def.center.z)) or 0.0
        zone.center = vector3(x, y, z)
        zone.radius = radius
        zone.min = vector2(x - radius, y - radius)
        zone.max = vector2(x + radius, y + radius)
    end
    return zone
end

for i, def in ipairs(type(Config.Zones) == 'table' and Config.Zones or {}) do
    local zone = normalize(def)
    if zone then
        Zones.List[#Zones.List + 1] = zone
        byId[zone.id] = zone
    else
        print(('[%s] invalid zone #%d'):format(RES, i))
    end
end

--- Zone par id, ou nil.
function Zones.Get(id)
    return type(id) == 'string' and byId[id] or nil
end

--- Vrai si coords (vector3 ou { x, y }) est dans la zone (test 2D).
function Zones.Contains(zone, coords)
    if type(zone) ~= 'table' then return false end
    local x, y = xy(coords)
    if not x then return false end
    -- Boîte englobante d'abord (rapide).
    if x < zone.min.x or x > zone.max.x or y < zone.min.y or y > zone.max.y then return false end
    local pts = zone.points
    if not pts then
        local dx, dy = x - zone.center.x, y - zone.center.y
        return dx * dx + dy * dy <= zone.radius * zone.radius
    end
    -- Ray casting.
    local inside = false
    local j = #pts
    for i = 1, #pts do
        local pi, pj = pts[i], pts[j]
        if (pi.y > y) ~= (pj.y > y) and x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x then
            inside = not inside
        end
        j = i
    end
    return inside
end

--- Première zone (ordre de la config) contenant coords, ou nil.
function Zones.At(coords)
    if not xy(coords) then return nil end
    for i = 1, #Zones.List do
        local zone = Zones.List[i]
        if Zones.Contains(zone, coords) then return zone end
    end
    return nil
end
