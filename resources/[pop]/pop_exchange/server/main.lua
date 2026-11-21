-- pop_exchange : serveur. Taux, monnaies et limites viennent de la config ; le client n'envoie
-- qu'un index de lieu, un id d'offre et un montant, tous revérifiés ici.

local ACTION_DISTANCE = 3.0
local HOUR = 3600
local MAX_AMOUNT = 10000000

local busy = {}    -- [identifier] = true pendant un échange
local lastExchange = {} -- [identifier] = time of the last operation
local validOffers = {}
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
    history[identifier][id] = #kept > 0 and kept or nil
    return total
end

local function remainingLimit(identifier, id, offer)
    return math.max(0, math.floor(offer.limit) - used(identifier, id))
end

local function expireHistory(identifier)
    local last = lastExchange[identifier]
    if not last then return end
    local left = last + HOUR - os.time()
    if left > 0 then
        SetTimeout(left * 1000, function() expireHistory(identifier) end)
        return
    end
    history[identifier] = nil
    lastExchange[identifier] = nil
end

local function record(identifier, id, n)
    local now = os.time()
    local first = lastExchange[identifier] == nil
    lastExchange[identifier] = now
    history[identifier] = history[identifier] or {}
    local list = history[identifier][id] or {}
    list[#list + 1] = { t = now, n = n }
    history[identifier][id] = list
    if first then SetTimeout(HOUR * 1000, function() expireHistory(identifier) end) end
end

------------------------------------------------------------------------
-- Vues envoyées au client (jamais le champ alert)
------------------------------------------------------------------------

local function presetAmount(preset, offer, max)
    if preset == 'max' then return max end
    local index = type(preset) == 'string' and preset:match('^preset_([1-9]%d*)$')
    return index and (offer.amounts or Config.Amounts)[tonumber(index)] or nil
end

local function presetsFor(offer, max)
    local result = {}
    for i, amount in ipairs(offer.amounts or Config.Amounts) do
        if type(amount) == 'number' and math.tointeger(amount) and amount > 0
            and amount <= max and amount * offer.rate >= 1 then
            result[#result + 1] = { id = 'preset_' .. i, amount = amount }
        end
    end
    return result
end

local function buildOffers(src, identifier, loc)
    local views = {}
    for _, id in ipairs(loc.offers or {}) do
        local offer = validOffers[id]
        if offer then
            local bal = math.max(0, balance(src, offer.from))
            local max = math.min(remainingLimit(identifier, id, offer), bal, MAX_AMOUNT)
            views[#views + 1] = {
                id = id,
                from = name(offer.from),
                to = name(offer.to),
                rate = offer.rate + 0.0,
                balance = bal,
                remaining = max,
                presets = presetsFor(offer, max),
            }
        end
    end
    return views
end

local function getLocation(loc)
    if math.type(loc) ~= 'integer' then return nil end
    return Config.Locations[loc]
end

local function offeredHere(loc, id)
    if type(id) ~= 'string' or not validOffers[id] then return false end
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
    if Bridge.IsDead(src) then return false, 'error' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    return true, nil, nil, buildOffers(src, identifier, loc)
end)

-- Toutes les vérifications ; renvoie ok, reason, arg. Le verrou est géré par l'appelant.
local function doExchange(src, identifier, loc, id, preset)
    if not offeredHere(loc, id) then return false, 'offer_unknown' end
    local offer = validOffers[id]

    local available = balance(src, offer.from)
    local remaining = remainingLimit(identifier, id, offer)
    local max = math.min(remaining, available, MAX_AMOUNT)
    local amount = presetAmount(preset, offer, max)
    local n = math.tointeger(type(amount) == 'number' and amount or 0)
    if not n or n < 1 or n > MAX_AMOUNT then
        return false, 'invalid_amount'
    end

    local received = math.floor(n * (offer.rate + 0.0))
    if received < 1 then return false, 'amount_too_low' end

    if n > remaining then return false, 'hourly_limit', remaining end

    if available < n then return false, 'not_enough' end
    if not canReceive(src, offer.to, received) then return false, 'inventory_full' end

    if not take(src, offer.from, n) then return false, 'not_enough' end
    if Bridge.GetIdentifier(src) ~= identifier or not give(src, offer.to, received) then
        -- Échange atomique : on rend ce qui a été pris.
        if Bridge.GetIdentifier(src) ~= identifier or not give(src, offer.from, n) then
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

Callback.Register('pop_exchange:exchange', function(src, locIndex, id, preset)
    local loc = getLocation(locIndex)
    if not loc then return false, 'error' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    if busy[identifier] then return false, 'busy' end
    if not Bridge.IsNear(src, loc.coords, ACTION_DISTANCE) then return false, 'too_far' end
    if Bridge.IsDead(src) then return false, 'error' end

    busy[identifier] = true
    local success, ok, reason, arg = pcall(doExchange, src, identifier, loc, id, preset)
    busy[identifier] = nil -- libéré dans tous les cas, même sur erreur Lua

    if not success then
        print(('[pop_exchange] exchange error: %s'):format(ok))
        ok, reason, arg = false, 'error', nil
    end
    local offers
    if Bridge.GetIdentifier(src) == identifier and Bridge.IsNear(src, loc.coords, ACTION_DISTANCE) then
        offers = buildOffers(src, identifier, loc)
    end
    return ok == true, reason or 'error', arg, offers
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('GetRate', function(id)
    local offer = validOffers[id]
    return offer and offer.rate or nil
end)

exports('ResetLimits', function(src)
    local identifier = Bridge.GetIdentifier(tonumber(src))
    if not identifier then return false end
    if busy[identifier] then return false end
    history[identifier] = nil
    return true
end)

------------------------------------------------------------------------
-- Vérification de la config au démarrage
------------------------------------------------------------------------

local accounts = { cash = true, bank = true, black = true }
local function validCurrency(cur)
    if type(cur) ~= 'table' then return false end
    if cur.money then return cur.item == nil and accounts[cur.money] == true end
    return type(cur.item) == 'string' and cur.item ~= ''
end

for id, offer in pairs(Config.Offers) do
    local limit = math.tointeger(offer.limit)
    local rate = tonumber(offer.rate)
    if validCurrency(offer.from) and validCurrency(offer.to)
        and type(offer.rate) == 'number' and rate > 0 and rate <= MAX_AMOUNT
        and limit and limit > 0 and MAX_AMOUNT >= math.min(limit, MAX_AMOUNT) * rate then
        validOffers[id] = offer
    else
        print(('[pop_exchange] offer "%s" disabled: invalid currency, rate or limit'):format(id))
    end
end
for i, loc in ipairs(Config.Locations) do
    for _, id in ipairs(loc.offers or {}) do
        if not Config.Offers[id] then
            print(('[pop_exchange] location %d: unknown offer "%s"'):format(i, id))
        end
    end
end
