-- pop_exchange : serveur. Taux, monnaies et limites viennent de la config ; le client n'envoie
-- qu'un index de lieu, un id d'offre et un montant, tous revérifiés ici.

local ACTION_DISTANCE = 3.0
local HOUR = 3600
local MAX_AMOUNT = 10000000

local busy = {}    -- [src] = true pendant un échange
local history = {} -- [identifier][offerId] = { { t = os.time(), n = quantité donnée }, ... }

local function debug(...)
    if Config.Debug then print(('[pop_exchange] ' .. string.format(...))) end
end

------------------------------------------------------------------------
-- Monnaies : { money = 'cash' | 'bank' | 'black' } ou { item = 'nom' }
------------------------------------------------------------------------

local function name(cur)
    return cur.money or cur.item
end

local function balance(src, cur)
    if cur.money then return math.floor(tonumber(Bridge.GetMoney(src, cur.money)) or 0) end
    return math.floor(tonumber(Bridge.GetItemCount(src, cur.item)) or 0)
end

local function take(src, cur, n)
    if cur.money then return Bridge.RemoveMoney(src, cur.money, n, 'pop_exchange') == true end
    return Bridge.RemoveItem(src, cur.item, n) == true
end

local function give(src, cur, n)
    if cur.money then return Bridge.AddMoney(src, cur.money, n, 'pop_exchange') == true end
    return Bridge.AddItem(src, cur.item, n) == true
end

local function canReceive(src, cur, n)
    if cur.money then return true end
    return Bridge.CanCarry(src, cur.item, n) == true
end

local function label(n, cur)
    return ('%d %s'):format(n, L('currency_' .. name(cur)))
end

------------------------------------------------------------------------
-- Limites horaires (fenêtre glissante, purgée à la lecture)
------------------------------------------------------------------------

local function used(identifier, id)
    local list = history[identifier] and history[identifier][id]
    if not list then return 0 end
    local since, total, kept = os.time() - HOUR, 0, {}
    for _, e in ipairs(list) do
        if e.t > since then
            total = total + e.n
            kept[#kept + 1] = e
        end
    end
    history[identifier][id] = kept
    return total
end

local function remainingLimit(identifier, id, offer)
    return math.max(0, math.floor(offer.limit) - used(identifier, id))
end

local function record(identifier, id, n)
    history[identifier] = history[identifier] or {}
    local list = history[identifier][id] or {}
    list[#list + 1] = { t = os.time(), n = n }
    history[identifier][id] = list
end

------------------------------------------------------------------------
-- Vues envoyées au client (jamais le champ alert)
------------------------------------------------------------------------

local function buildOffers(src, identifier, loc)
    local views = {}
    for _, id in ipairs(loc.offers or {}) do
        local offer = Config.Offers[id]
        if offer then
            local bal = balance(src, offer.from)
            views[#views + 1] = {
                id = id,
                from = name(offer.from),
                to = name(offer.to),
                rate = offer.rate + 0.0,
                balance = bal,
                remaining = math.min(remainingLimit(identifier, id, offer), bal),
            }
        end
    end
    return views
end

local function getLocation(loc)
    loc = tonumber(loc)
    if not loc or loc ~= math.floor(loc) then return nil end
    return Config.Locations[loc]
end

local function offeredHere(loc, id)
    if type(id) ~= 'string' or not Config.Offers[id] then return false end
    for _, o in ipairs(loc.offers or {}) do
        if o == id then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Alerte police
------------------------------------------------------------------------

local function alertPolice(coords)
    local payload = { x = coords.x, y = coords.y, z = coords.z }
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Bridge.HasJob(src, Config.Police.jobs) then
            local job = Bridge.GetJob(src)
            if job and job.onDuty then
                TriggerClientEvent('pop_exchange:client:policeAlert', src, payload)
            end
        end
    end
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_exchange:getOffers', function(src, locIndex)
    local loc = getLocation(locIndex)
    if not loc then return false, 'error' end
    if not Bridge.IsNear(src, loc.coords, ACTION_DISTANCE) then return false, 'too_far' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    return true, nil, nil, buildOffers(src, identifier, loc)
end)

-- Toutes les vérifications ; renvoie ok, reason, arg. Le verrou est géré par l'appelant.
local function doExchange(src, identifier, loc, id, amount)
    if Bridge.IsDead(src) then return false, 'error' end
    if not Bridge.IsNear(src, loc.coords, ACTION_DISTANCE) then return false, 'too_far' end
    if not offeredHere(loc, id) then return false, 'offer_unknown' end
    local offer = Config.Offers[id]

    local n = tonumber(amount)
    if not n or n ~= n or n == math.huge or n == -math.huge or n ~= math.floor(n) or n < 1 or n > MAX_AMOUNT then
        return false, 'invalid_amount'
    end
    n = math.floor(n)

    local received = math.floor(n * offer.rate)
    if received < 1 then return false, 'amount_too_low' end

    local remaining = remainingLimit(identifier, id, offer)
    if n > remaining then return false, 'hourly_limit', remaining end

    if balance(src, offer.from) < n then return false, 'not_enough' end
    if not canReceive(src, offer.to, received) then return false, 'inventory_full' end

    if not take(src, offer.from, n) then return false, 'not_enough' end
    if not give(src, offer.to, received) then
        -- Échange atomique : on rend ce qui a été pris.
        if not give(src, offer.from, n) then
            print(('[pop_exchange] refund failed for %s: %d %s (offer %s)'):format(identifier, n, name(offer.from), id))
        end
        return false, 'error'
    end
    record(identifier, id, n)

    debug('%s (%s) exchanged %d %s -> %d %s (offer %s)', GetPlayerName(src) or src, identifier,
        n, name(offer.from), received, name(offer.to), id)

    if (tonumber(offer.alert) or 0) > 0 and math.random() < offer.alert then
        alertPolice(loc.coords)
        debug('police alerted (offer %s)', id)
    end

    return true, 'exchanged', { label(n, offer.from), label(received, offer.to) }
end

Callback.Register('pop_exchange:exchange', function(src, locIndex, id, amount)
    local loc = getLocation(locIndex)
    if not loc then return false, 'error' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    if busy[src] then return false, 'busy' end

    busy[src] = true
    local success, ok, reason, arg = pcall(doExchange, src, identifier, loc, id, amount)
    busy[src] = nil -- libéré dans tous les cas, même sur erreur Lua

    if not success then
        print(('[pop_exchange] exchange error: %s'):format(ok))
        ok, reason, arg = false, 'error', nil
    end
    return ok == true, reason or 'error', arg, buildOffers(src, identifier, loc)
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src) busy[src] = nil end)
Bridge.OnPlayerUnloaded(function(src) busy[src] = nil end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('GetRate', function(id)
    local offer = Config.Offers[id]
    return offer and offer.rate or nil
end)

exports('ResetLimits', function(src)
    local identifier = Bridge.GetIdentifier(tonumber(src))
    if not identifier then return false end
    history[identifier] = nil
    return true
end)

------------------------------------------------------------------------
-- Vérification de la config au démarrage
------------------------------------------------------------------------

CreateThread(function()
    for id, offer in pairs(Config.Offers) do
        if type(offer.rate) ~= 'number' or offer.rate <= 0 then
            print(('[pop_exchange] offer "%s": rate must be > 0'):format(id))
        end
        if type(offer.limit) ~= 'number' or offer.limit ~= math.floor(offer.limit) then
            print(('[pop_exchange] offer "%s": limit must be an integer'):format(id))
        end
    end
    for i, loc in ipairs(Config.Locations) do
        for _, id in ipairs(loc.offers or {}) do
            if not Config.Offers[id] then
                print(('[pop_exchange] location %d: unknown offer "%s"'):format(i, id))
            end
        end
    end
end)
