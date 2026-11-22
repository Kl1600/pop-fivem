-- Plans : lieux (shared/places.lua + Config.Places), favoris et récents par tablette. L'itinéraire (SetNewWaypoint, distance
-- native) se fait côté client (client/map.lua) ; le serveur ne croit que des identifiants de lieux qu'il connaît.

Tablet = Tablet or {}
Tablet.Plans = {}
local P = Tablet.Plans
local K = Tablet.Tools

local DEFAULT_FAVS = { 'home', 'police', 'garage' }

local function num(v) return type(v) == 'number' and v == v and v > -100000 and v < 100000 end
local function str(v, max) return type(v) == 'string' and #v <= max end

--- Un lieu de la config est accepté s'il a un identifiant propre, des textes courts et des coordonnées numériques.
local function valid(p)
    return type(p) == 'table' and type(p.id) == 'string' and p.id:match('^[a-z0-9_]+$') ~= nil and #p.id <= 24
        and str(p.name, 80) and str(p.short or '', 24) and str(p.area or '', 40) and str(p.cat or '', 16) and str(p.addr or '', 80)
        and str(p.phone or '', 24) and str(p.hours or '', 8) and str(p.icon or '', 12) and str(p.col or '', 9)
        and num(p.x) and num(p.y) and num(p.z) and num(p.mx) and num(p.my)
end

--- Lieux de la ressource, complétés par `Config.Places` (un id identique remplace l'original). 60 lieux au plus.
function P.Places()
    local list, at = {}, {}
    local function add(p)
        if not valid(p) then return end
        local row = { id = p.id, name = p.name, short = p.short or '', area = p.area or '', cat = p.cat or '', addr = p.addr or '',
            phone = p.phone or '', hours = p.hours or 'always', icon = p.icon or 'pin', col = p.col or '#0a84ff',
            x = p.x, y = p.y, z = p.z, mx = p.mx, my = p.my }
        if at[p.id] then list[at[p.id]] = row elseif #list < Tablet.MaxPlaces then list[#list + 1] = row at[p.id] = #list end
    end
    for _, p in ipairs(Tablet.Places) do add(p) end
    for _, p in ipairs(Config.Places or {}) do add(p) end
    return list, at
end

local function known(id)
    local _, at = P.Places()
    return type(id) == 'string' and at[id] ~= nil
end

local function cleanList(list, max)
    local out, seen = {}, {}
    for _, id in ipairs(type(list) == 'table' and list or {}) do
        if known(id) and not seen[id] and #out < max then out[#out + 1] = id seen[id] = true end
    end
    return out
end

local function load(serial)
    local data = Tablet.AppData.Get(serial, 'plans', {})
    local favs = data.favs == nil and cleanList(DEFAULT_FAVS, K.favPlaces) or cleanList(data.favs, K.favPlaces)
    return favs, cleanList(data.recents, K.recentPlaces)
end

--- pop_tablet:plans:state : lieux, favoris, récents
function P.State(src)
    local s, err = Tablet.Guard(src, nil, { name = 'plansState', rate = 4 })
    if not s then return Tablet.Fail(err) end
    local favs, recents = load(s.serial)
    return { ok = true, places = (P.Places()), favs = favs, recents = recents }
end

--- pop_tablet:plans:fav  { id, on }
function P.Fav(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'plansFav', rate = 4, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' or not known(data.id) then return Tablet.Fail('err_payload') end
    local favs, recents = load(s.serial)
    local out = {}
    for _, id in ipairs(favs) do if id ~= data.id then out[#out + 1] = id end end
    if data.on then
        if #out >= K.favPlaces then return Tablet.Fail('err_limit') end
        out[#out + 1] = data.id
    end
    Tablet.AppData.Set(s.serial, 'plans', { favs = out, recents = recents })
    return { ok = true, favs = out }
end

--- pop_tablet:plans:recent  id : place le lieu en tête des récents (5 au plus)
function P.Recent(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'plansRecent', rate = 4, payload = id, maxBytes = 64 })
    if not s then return Tablet.Fail(err) end
    if not known(id) then return Tablet.Fail('err_payload') end
    local favs, recents = load(s.serial)
    local out = { id }
    for _, r in ipairs(recents) do if r ~= id and #out < K.recentPlaces then out[#out + 1] = r end end
    Tablet.AppData.Set(s.serial, 'plans', { favs = favs, recents = out })
    return { ok = true, recents = out }
end

Callback.Register('pop_tablet:plans:state', function(src) return P.State(src) end)
Callback.Register('pop_tablet:plans:fav', function(src, data) return P.Fav(src, data) end)
Callback.Register('pop_tablet:plans:recent', function(src, id) return P.Recent(src, id) end)
