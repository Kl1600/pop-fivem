-- SHA-256 et HMAC-SHA256 en Lua 5.4 pur (opérateurs binaires), pour le code à 4 chiffres.
-- Le HMAC garde l'état intermédiaire des blocs ipad/opad : une itération = 2 compressions seulement.

Tablet = Tablet or {}
Tablet.Hash = {}
local H = Tablet.Hash

local MASK = 0xffffffff

-- Constantes : racines cubiques (K) et carrées (état initial) des premiers nombres premiers.
local K, INIT = {}, {}
do
    local primes, n = {}, 2
    while #primes < 64 do
        local isPrime = true
        for _, p in ipairs(primes) do
            if p * p > n then break end
            if n % p == 0 then isPrime = false break end
        end
        if isPrime then primes[#primes + 1] = n end
        n = n + 1
    end
    for i = 1, 64 do
        local c = primes[i] ^ (1 / 3)
        K[i] = math.floor((c - math.floor(c)) * 4294967296) & MASK
    end
    for i = 1, 8 do
        local s = primes[i] ^ 0.5
        INIT[i] = math.floor((s - math.floor(s)) * 4294967296) & MASK
    end
end

local function rrot(x, n)
    return ((x >> n) | (x << (32 - n))) & MASK
end

-- Traite un bloc de 64 octets et renvoie le nouvel état (le tableau d'entrée n'est pas modifié).
local function compress(state, block)
    local w = { string.unpack('>I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4', block) }
    for i = 17, 64 do
        local a, b = w[i - 15], w[i - 2]
        local s0 = rrot(a, 7) ~ rrot(a, 18) ~ (a >> 3)
        local s1 = rrot(b, 17) ~ rrot(b, 19) ~ (b >> 10)
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & MASK
    end
    local a, b, c, d, e, f, g, h = state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
    for i = 1, 64 do
        local S1 = rrot(e, 6) ~ rrot(e, 11) ~ rrot(e, 25)
        local ch = (e & f) ~ ((~e & MASK) & g)
        local t1 = (h + S1 + ch + K[i] + w[i]) & MASK
        local S0 = rrot(a, 2) ~ rrot(a, 13) ~ rrot(a, 22)
        local maj = (a & b) ~ (a & c) ~ (b & c)
        local t2 = (S0 + maj) & MASK
        h, g, f, e, d, c, b, a = g, f, e, (d + t1) & MASK, c, b, a, (t1 + t2) & MASK
    end
    return {
        (state[1] + a) & MASK, (state[2] + b) & MASK, (state[3] + c) & MASK, (state[4] + d) & MASK,
        (state[5] + e) & MASK, (state[6] + f) & MASK, (state[7] + g) & MASK, (state[8] + h) & MASK,
    }
end

-- Poursuit un hachage depuis `state` ; `prefixLen` = octets déjà absorbés (pour la longueur finale).
local function finish(state, msg, prefixLen)
    local total = prefixLen + #msg
    local padLen = (55 - #msg) % 64
    msg = msg .. '\128' .. string.rep('\0', padLen) .. string.pack('>I8', total * 8)
    for i = 1, #msg, 64 do
        state = compress(state, msg:sub(i, i + 63))
    end
    return state
end

local function toRaw(state)
    return string.pack('>I4I4I4I4I4I4I4I4', table.unpack(state))
end

--- SHA-256 : chaîne binaire de 32 octets.
function H.sha256raw(msg)
    return toRaw(finish(INIT, msg, 0))
end

function H.hex(raw)
    return (raw:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

--- SHA-256 en hexadécimal.
function H.sha256(msg)
    return H.hex(H.sha256raw(msg))
end

--- Prépare une clé HMAC (états après les blocs ipad et opad).
function H.hmacKey(key)
    if #key > 64 then key = H.sha256raw(key) end
    key = key .. string.rep('\0', 64 - #key)
    local ipad = key:gsub('.', function(c) return string.char(c:byte() ~ 0x36) end)
    local opad = key:gsub('.', function(c) return string.char(c:byte() ~ 0x5c) end)
    return { inner = compress(INIT, ipad), outer = compress(INIT, opad) }
end

--- HMAC-SHA256 avec une clé préparée : chaîne binaire de 32 octets.
function H.hmacRaw(prepared, msg)
    local inner = toRaw(finish(prepared.inner, msg, 64))
    return toRaw(finish(prepared.outer, inner, 64))
end

--- HMAC-SHA256 en hexadécimal.
function H.hmac(key, msg)
    return H.hex(H.hmacRaw(H.hmacKey(key), msg))
end

--- Condensat du code : HMAC(poivre, sel .. code) itéré `iterations` fois, en hexadécimal (64 caractères).
function H.code(pepper, salt, code, iterations)
    local prepared = H.hmacKey(pepper)
    local h = H.hmacRaw(prepared, salt .. code)
    for _ = 2, math.max(1, iterations or 1) do
        h = H.hmacRaw(prepared, h)
    end
    return H.hex(h)
end

--- Comparaison à temps constant (même durée quelle que soit la position de la première différence).
function H.equals(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then return false end
    local acc = 0
    for i = 1, #a do
        acc = acc | (a:byte(i) ~ b:byte(i))
    end
    return acc == 0
end
