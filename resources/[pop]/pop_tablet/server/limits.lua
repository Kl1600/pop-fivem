-- Tailles maximales et validation des types : rejet immédiat, jamais de troncature silencieuse.

Tablet = Tablet or {}
Tablet.Limits = {}
local Limits = Tablet.Limits

local MAX_DEPTH, MAX_NODES = 8, 50000

local function size(v, depth, counter)
    local t = type(v)
    if t == 'string' then return #v end
    if t == 'number' then return 8 end
    if t == 'boolean' then return 1 end
    if t == 'table' then
        if depth > MAX_DEPTH then return nil end
        local n = 2
        for k, x in pairs(v) do
            counter.n = counter.n + 1
            if counter.n > MAX_NODES then return nil end
            local ks, vs = size(k, depth + 1, counter), size(x, depth + 1, counter)
            if not ks or not vs then return nil end
            n = n + ks + vs + 2
        end
        return n
    end
    return nil -- nil, fonction, userdata : refusés
end

--- Taille approximative en octets d'une charge utile, nil si invalide (trop profonde, trop de nœuds, type interdit).
function Limits.Size(v)
    return size(v, 0, { n = 0 })
end

--- true si la charge est valide et <= max octets.
function Limits.Payload(v, max)
    local s = Limits.Size(v)
    return s ~= nil and s <= max
end

--- Valide une chaîne utilisateur pour le champ `field` (clé de Tablet.Max).
--- opts : min (défaut 0), multiline (autorise retours à la ligne et tabulations).
--- Renvoie true, ou false + clé de locale.
function Limits.Field(field, v, opts)
    opts = opts or {}
    local max = Tablet.Max[field]
    if type(v) ~= 'string' or not max then return false, 'err_payload' end
    if #v > max * 4 then return false, 'err_too_large' end
    local len = utf8.len(v)
    if not len then return false, 'err_payload' end
    if len > max then return false, 'err_too_large' end
    if len < (opts.min or 0) then return false, 'err_payload' end
    for i = 1, #v do
        local b = v:byte(i)
        if b == 127 or (b < 32 and not (opts.multiline and (b == 10 or b == 9 or b == 13))) then
            return false, 'err_payload'
        end
    end
    return true
end

--- Entier borné, ou nil.
function Limits.Int(v, min, max)
    if type(v) ~= 'number' then return nil end
    local n = math.tointeger(v)
    if not n or n < min or n > max then return nil end
    return n
end

--- true si v est une clé de l'ensemble `set`.
function Limits.Enum(v, set)
    return type(v) == 'string' and set[v] == true
end

function Limits.Trim(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Anti-spam par joueur et par clé : `max` appels par seconde.
local windows = {} -- [src][key] = { t, n }

function Limits.Rate(src, key, max)
    if not max or max <= 0 then return true end
    local t = Tablet.Now and Tablet.Now() or os.time()
    local byKey = windows[src]
    if not byKey then byKey = {} windows[src] = byKey end
    local w = byKey[key]
    if not w or w.t ~= t then
        byKey[key] = { t = t, n = 1 }
        return true
    end
    w.n = w.n + 1
    return w.n <= max
end

function Limits.Forget(src)
    windows[src] = nil
end
