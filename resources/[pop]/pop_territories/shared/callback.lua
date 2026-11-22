-- Callbacks internes (sans ox_lib), dans les deux sens.
--
-- Client -> serveur
--   serveur : Callback.Register(name, function(source, ...) return ... end)
--   client  : local a, b = Callback.Await(name, ...)       -- dans un thread, nil si timeout
--             Callback.Trigger(name, function(a, b) end, ...)
-- Serveur -> client
--   client  : Callback.Register(name, function(...) return ... end)
--   serveur : local a = Callback.Await(name, playerId, ...)
--             Callback.Trigger(name, playerId, function(a) end, ...)
--
-- Les events sont préfixés par le nom de la ressource : deux scripts POP ne se gênent pas.

Callback = {}

local RES = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()
local TIMEOUT = 10000 -- ms

local EV_TO_SERVER   = RES .. ':cb:toServer'   -- requête client -> serveur
local EV_FROM_SERVER = RES .. ':cb:fromServer' -- réponse serveur -> client
local EV_TO_CLIENT   = RES .. ':cb:toClient'   -- requête serveur -> client
local EV_FROM_CLIENT = RES .. ':cb:fromClient' -- réponse client -> serveur

local handlers = {} -- [name] = fn
local pending = {}  -- [id] = { p = promise, target = playerId (serveur) }
local lastId = 0

local function debug(msg, ...)
    if Config.Debug then print(('[%s] callback: ' .. msg):format(RES, ...)) end
end

local function nextId()
    lastId = lastId < 2147483647 and lastId + 1 or 1
    return lastId
end

-- Exécute un handler protégé ; renvoie ses résultats empaquetés (vide en cas d'erreur).
local function run(name, fn, ...)
    local res = table.pack(pcall(fn, ...))
    if not res[1] then
        print(('[%s] callback "%s" error: %s'):format(RES, name, tostring(res[2])))
        return { n = 0 }
    end
    return table.pack(table.unpack(res, 2, res.n))
end

-- Enregistre la requête, l'envoie, puis attend la réponse ou le timeout.
local function request(name, send, target)
    local id = nextId()
    local entry = { p = promise.new(), target = target }
    pending[id] = entry
    send(id)
    SetTimeout(TIMEOUT, function()
        if pending[id] == entry then
            pending[id] = nil
            debug('"%s" timed out', name)
            entry.p:resolve({ n = 0 })
        end
    end)
    local r = Citizen.Await(entry.p)
    return table.unpack(r, 1, r.n)
end

local function resolve(id, ...)
    local entry = pending[id]
    if not entry then return end
    pending[id] = nil
    entry.p:resolve(table.pack(...))
end

--- Déclare un callback appelable depuis l'autre côté.
function Callback.Register(name, fn)
    handlers[name] = fn
end

if IS_SERVER then
    local limit = Config.CallbackRateLimit or 10
    local calls = {} -- [src][name] = { t = seconde, n = nombre d'appels }

    local function allowed(src, name)
        if limit <= 0 then return true end
        local now = os.time()
        local byName = calls[src]
        if not byName then
            byName = {}
            calls[src] = byName
        end
        local c = byName[name]
        if not c or c.t ~= now then
            byName[name] = { t = now, n = 1 }
            return true
        end
        c.n = c.n + 1
        return c.n <= limit
    end

    AddEventHandler('playerDropped', function()
        calls[source] = nil
    end)

    RegisterNetEvent(EV_TO_SERVER, function(name, id, ...)
        local src = source
        if type(name) ~= 'string' or math.type(id) ~= 'integer' then return end
        local fn = handlers[name]
        if not fn then
            debug('unknown callback "%s" from %s', name, src)
            return TriggerClientEvent(EV_FROM_SERVER, src, id)
        end
        if not allowed(src, name) then
            debug('rate limit "%s" for %s', name, src)
            return TriggerClientEvent(EV_FROM_SERVER, src, id)
        end
        local r = run(name, fn, src, ...)
        TriggerClientEvent(EV_FROM_SERVER, src, id, table.unpack(r, 1, r.n))
    end)

    RegisterNetEvent(EV_FROM_CLIENT, function(id, ...)
        local entry = pending[id]
        -- Seul le joueur interrogé peut répondre.
        if not entry or entry.target ~= source then return end
        resolve(id, ...)
    end)

    --- Demande une valeur au client `target` et attend sa réponse (nil si timeout).
    function Callback.Await(name, target, ...)
        target = tonumber(target)
        if not target then return nil end
        local args = table.pack(...)
        return request(name, function(id)
            TriggerClientEvent(EV_TO_CLIENT, target, name, id, table.unpack(args, 1, args.n))
        end, target)
    end

    --- Version sans attente : cb reçoit les valeurs renvoyées par le client.
    function Callback.Trigger(name, target, cb, ...)
        local args = table.pack(...)
        CreateThread(function()
            cb(Callback.Await(name, target, table.unpack(args, 1, args.n)))
        end)
    end
else
    RegisterNetEvent(EV_FROM_SERVER, function(id, ...)
        resolve(id, ...)
    end)

    RegisterNetEvent(EV_TO_CLIENT, function(name, id, ...)
        local fn = handlers[name]
        if not fn then return TriggerServerEvent(EV_FROM_CLIENT, id) end
        local r = run(name, fn, ...)
        TriggerServerEvent(EV_FROM_CLIENT, id, table.unpack(r, 1, r.n))
    end)

    --- Demande une valeur au serveur et attend sa réponse (nil si timeout). À appeler dans un thread.
    function Callback.Await(name, ...)
        local args = table.pack(...)
        return request(name, function(id)
            TriggerServerEvent(EV_TO_SERVER, name, id, table.unpack(args, 1, args.n))
        end)
    end

    --- Version sans attente : cb reçoit les valeurs renvoyées par le serveur.
    function Callback.Trigger(name, cb, ...)
        local args = table.pack(...)
        CreateThread(function()
            cb(Callback.Await(name, table.unpack(args, 1, args.n)))
        end)
    end
end
