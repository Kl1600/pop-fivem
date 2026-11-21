-- pop_bennys : constantes et règles pures (chargé côté client et serveur).
-- Bennys.Valid et Bennys.Price n'appellent aucune native : le serveur fait autorité, le client affiche.

Bennys = {}
Bennys.ZONE_TOLERANCE  = 3.0   -- serveur : marge ajoutée au rayon de l'atelier
Bennys.SESSION_TIMEOUT = 900   -- secondes
Bennys.MAX_CHANGES     = 64
Bennys.BODY = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 48 }   -- index de mods de carrosserie proposés
Bennys.PERF = { modEngine = 'engine', modBrakes = 'brakes', modTransmission = 'transmission',
                modSuspension = 'suspension', modArmor = 'armor' }  -- clé Props -> clé de Config.Prices
Bennys.TYPES = { automobile = true, bike = true, quadbike = true }   -- GetVehicleType autorisés
Bennys.CATEGORIES = { 'paint', 'wheels', 'body', 'performance', 'lights', 'windows' }

local PAINT = { color1 = true, color2 = true, pearlescentColor = true, wheelColor = true }

-- Entier exact (accepte 2.0 venant d'un JSON), sinon nil.
local function toInt(v)
    if type(v) ~= 'number' then return nil end
    return math.tointeger(v)
end

local function intIn(v, min, max)
    local n = toInt(v)
    if n and n >= min and n <= max then return n end
    return nil
end

-- Montant de la config : entier >= 0.
local function money(n)
    n = tonumber(n)
    if not n or n ~= n or n <= 0 or n == math.huge then return 0 end
    return math.floor(n)
end

-- NOTE: common/*.lua est chargé par ordre alphabétique (bennys.lua avant props.lua) :
-- les clés de carrosserie sont donc construites au premier appel, pas au chargement.
local bodyKeys
local function body()
    if bodyKeys then return bodyKeys end
    if type(Props) ~= 'table' or type(Props.MODS) ~= 'table' then return {} end
    bodyKeys = {}
    for _, i in ipairs(Bennys.BODY) do
        local k = Props.MODS[i]
        if k then bodyKeys[k] = true end
    end
    return bodyKeys
end

-- Liste séquentielle d'exactement n éléments (aucune autre clé).
local function exactList(t, n)
    if type(t) ~= 'table' then return false end
    local count = 0
    for k in pairs(t) do
        if math.type(k) ~= 'integer' or k < 1 or k > n then return false end
        count = count + 1
    end
    return count == n
end

local function perfMax(perf)
    local list = Config.Prices and Config.Prices[perf]
    return (type(list) == 'table' and #list or 0) - 1
end

local function colorAllowed(id)
    for _, c in ipairs(Config.Colors or {}) do
        if c.id == id then return true end
    end
    return false
end

local function neonColorAllowed(rgb)
    for _, c in ipairs(Config.NeonColors or {}) do
        if c[1] == rgb[1] and c[2] == rgb[2] and c[3] == rgb[3] then return true end
    end
    return false
end

--- Clés modifiables par l'atelier (format Props), construites au premier appel.
local editableKeys
function Bennys.Editable()
    if editableKeys then return editableKeys end
    local keys = {
        color1 = true, color2 = true, pearlescentColor = true, wheelColor = true, wheels = true,
        modFrontWheels = true, modBackWheels = true, modTurbo = true, modXenon = true, xenonColor = true,
        neonEnabled = true, neonColor = true, windowTint = true,
    }
    for k in pairs(Bennys.PERF) do keys[k] = true end
    local b = body()
    if next(b) == nil then return keys end -- Props pas encore chargé : ne pas mettre en cache
    for k in pairs(b) do keys[k] = true end
    editableKeys = keys
    return keys
end

--- Comparaison profonde (listes de néons, couleurs RGB).
function Bennys.Equal(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do
        if not Bennys.Equal(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- Valeur valide pour cette clé ? Renvoie `true, valeurNormalisée` (entiers, copie des listes) ou `false`.
function Bennys.Valid(key, value)
    if type(key) ~= 'string' then return false end
    local n

    if PAINT[key] then
        n = toInt(value)
        if n and colorAllowed(n) then return true, n end
    elseif key == 'wheels' then
        n = intIn(value, 0, 12)
        if n then return true, n end
    elseif key == 'modFrontWheels' or body()[key] then
        n = intIn(value, -1, 255)
        if n then return true, n end
    elseif Bennys.PERF[key] then
        n = intIn(value, -1, perfMax(Bennys.PERF[key]))
        if n then return true, n end
    elseif key == 'modTurbo' or key == 'modXenon' then
        if type(value) == 'boolean' then return true, value end
    elseif key == 'xenonColor' then
        n = intIn(value, -1, 12)
        if n then return true, n end
    elseif key == 'neonEnabled' then
        if exactList(value, 4) then
            local out = {}
            for i = 1, 4 do
                if type(value[i]) ~= 'boolean' then return false end
                out[i] = value[i]
            end
            return true, out
        end
    elseif key == 'neonColor' then
        if exactList(value, 3) then
            local out = {}
            for i = 1, 3 do
                out[i] = intIn(value[i], 0, 255)
                if not out[i] then return false end
            end
            if neonColorAllowed(out) then return true, out end
        end
    elseif key == 'windowTint' then
        n = intIn(value, 0, 6)
        if n then return true, n end
    end

    return false
end

local SIMPLE_PRICE = {
    modFrontWheels = 'wheels', modTurbo = 'turbo', modXenon = 'xenon', xenonColor = 'xenon',
    neonEnabled = 'neon', neonColor = 'neon', windowTint = 'tint',
}

--- Clé de Config.Prices pour cette clé Props (nil : gratuite, ex. 'wheels').
function Bennys.PriceKey(key)
    if PAINT[key] then return 'paint' end
    if Bennys.PERF[key] then return Bennys.PERF[key] end
    if SIMPLE_PRICE[key] then return SIMPLE_PRICE[key] end
    if body()[key] then return 'body' end
    return nil
end

--- Prix d'une ligne (valeur supposée valide). Entier >= 0 lu dans Config.Prices.
function Bennys.Price(key, value)
    local P = Config.Prices or {}
    local pk = Bennys.PriceKey(key)
    if not pk then return 0 end
    if Bennys.PERF[key] then
        local n = toInt(value)
        local list = P[pk]
        if not n or n < 0 or type(list) ~= 'table' then return 0 end
        return money(list[n + 1])
    end
    if (key == 'modTurbo' or key == 'modXenon') and value ~= true then return 0 end
    return money(P[pk])
end
