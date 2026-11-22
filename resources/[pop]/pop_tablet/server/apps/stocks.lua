-- Bourse : marché fictif simulé côté serveur (marche aléatoire bornée entre 5 % et 10 fois le cours de base).
-- Aucune boucle : UNE échéance (Tablet.Scheduler) tant qu'au moins une tablette a l'appli ouverte (abonnement). Sans abonné,
-- rien ne tourne et rien n'est envoyé. Paquet push : les cours en centimes, dans l'ordre de Tablet.StockDefs (<= 200 octets).

Tablet = Tablet or {}
Tablet.Stocks = {}
local S = Tablet.Stocks
local defs, bounds = Tablet.StockDefs, Tablet.StockBounds
local K = Tablet.Tools

local state = {}      -- [i] = { price, prev, trend }
local loaded = false
local subs, subCount = {}, 0
local armed = false
local lastSave = 0

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- Cours minimal et maximal (arrondis au centime, toujours dans [5 %, 10x] du cours de base).
function S.Limits(d)
    return math.ceil(d.price * bounds.min * 100) / 100, math.floor(d.price * bounds.max * 100) / 100
end

local function clamp(d, v)
    local lo, hi = S.Limits(d)
    return math.max(lo, math.min(hi, round2(v)))
end

--- Un pas de simulation. `rnd` : tirage dans [0, 1). Élan amorti, rappel vers le cours de base, bruit propre au symbole.
function S.Step(d, st, rnd)
    st.trend = math.max(-0.01, math.min(0.01, st.trend * 0.9 + (rnd() - 0.5) * 0.002))
    local revert = (d.price - st.price) / d.price * 0.01
    st.price = clamp(d, st.price * (1 + st.trend + revert + (rnd() - 0.5) * 2 * d.vol))
end

--- Charge l'état enregistré (une fois). Un état de plus de 24 h repart d'une clôture égale au cours.
function S.Load()
    if loaded then return end
    loaded = true
    local by = {}
    for _, r in ipairs(Tablet.DB.LoadMarket()) do by[r.symbol] = r end
    local now = Tablet.Now()
    for i, d in ipairs(defs) do
        local r = by[d.sym]
        local price = r and tonumber(r.price)
        if price and price > 0 then
            price = clamp(d, price)
            local stale = now - (tonumber(r.updated_at) or 0) > 86400
            state[i] = { price = price, prev = stale and price or clamp(d, tonumber(r.prev_close) or price), trend = tonumber(r.trend) or 0 }
        else
            state[i] = { price = d.price, prev = d.price, trend = 0 }
        end
    end
end

--- Écrit l'état dans la base (toutes les 10 minutes avec abonnés, à l'arrêt de la ressource, après un choc).
function S.Save()
    if not loaded then return end
    local rows = {}
    for i, d in ipairs(defs) do rows[i] = { sym = d.sym, price = state[i].price, prev = state[i].prev, trend = state[i].trend } end
    Tablet.DB.SaveMarket(rows, Tablet.Now())
    lastSave = Tablet.Now()
end

--- Cours courants (copie) : { price, prev } par symbole, dans l'ordre des définitions.
function S.Prices()
    local out = {}
    for i = 1, #defs do out[i] = { price = state[i].price, prev = state[i].prev } end
    return out
end

function S.SubscriberCount() return subCount end

local function prune()
    for src in pairs(subs) do
        if not Tablet.Device.HasSession(src) then subs[src] = nil subCount = subCount - 1 end
    end
end

local function broadcast()
    local p = {}
    for i = 1, #defs do p[i] = math.floor(state[i].price * 100 + 0.5) end
    for src in pairs(subs) do Tablet.Push.To(src, 'market', { p = p }) end
end

local arm

--- Échéance : un pas, un envoi aux abonnés, la suivante. Sans abonné : on s'arrête là (rien n'est ré-armé).
function S.Tick()
    armed = false
    prune()
    if subCount == 0 then S.Save() return end
    for i, d in ipairs(defs) do S.Step(d, state[i], math.random) end
    broadcast()
    if Tablet.Now() - lastSave >= Tablet.StockPersistSeconds then S.Save() end
    arm()
end

arm = function()
    if armed then return end
    armed = true
    Tablet.Scheduler.Add('stocks', Tablet.Now() + ((Config.Market or {}).TickSeconds or 5), S.Tick)
end

function S.Forget(src)
    if subs[src] then
        subs[src] = nil
        subCount = subCount - 1
    end
end

--- Choc de marché (export MarketShock) : variation en % du cours d'un symbole, bornée à +-50 %.
function S.Shock(sym, percent)
    local i = type(sym) == 'string' and Tablet.StockIndex[sym:upper()] or nil
    if not i or type(percent) ~= 'number' or percent ~= percent or math.abs(percent) > Tablet.StockMaxShock then return false end
    S.Load()
    local d, st = defs[i], state[i]
    st.price = clamp(d, st.price * (1 + percent / 100))
    st.trend = math.max(-0.01, math.min(0.01, percent / 100 * 0.05))
    prune()
    if subCount > 0 then broadcast() end
    S.Save()
    return true
end

local function watchList(serial)
    local data = Tablet.AppData.Get(serial, 'stocks', {})
    if data.watch == nil then
        local all = {}
        for i, d in ipairs(defs) do all[i] = d.sym end
        return all
    end
    local out, seen = {}, {}
    for _, sym in ipairs(type(data.watch) == 'table' and data.watch or {}) do
        if Tablet.StockIndex[sym] and not seen[sym] and #out < K.watch then out[#out + 1] = sym seen[sym] = true end
    end
    return out
end

--- pop_tablet:stocks:subscribe : abonne la tablette (cours poussés tant que l'appli est ouverte) et renvoie l'état complet
function S.Subscribe(src)
    local s, err = Tablet.Guard(src, nil, { name = 'stocksSub', rate = 2 })
    if not s then return Tablet.Fail(err) end
    S.Load()
    if not subs[src] then subs[src] = true subCount = subCount + 1 end
    arm()
    local items = {}
    for i, d in ipairs(defs) do
        items[i] = { sym = d.sym, name = d.name, index = d.index or nil, price = state[i].price, open = state[i].prev,
            volume = d.volume, cap = d.cap, per = d.per, div = d.div, ch = d.ch }
    end
    return { ok = true, items = items, watch = watchList(s.serial), tick = (Config.Market or {}).TickSeconds or 5 }
end

--- pop_tablet:stocks:unsubscribe
function S.Unsubscribe(src)
    local s, err = Tablet.Guard(src, nil, { name = 'stocksSub', rate = 2 })
    if not s then return Tablet.Fail(err) end
    S.Forget(src)
    return { ok = true }
end

--- pop_tablet:stocks:watch  { sym, on } : liste de suivi de la tablette
function S.Watch(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'stocksWatch', rate = 4, payload = data, maxBytes = 128 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' or type(data.sym) ~= 'string' or not Tablet.StockIndex[data.sym] then
        return Tablet.Fail('err_payload')
    end
    local out = {}
    for _, sym in ipairs(watchList(s.serial)) do if sym ~= data.sym then out[#out + 1] = sym end end
    if data.on then
        if #out >= K.watch then return Tablet.Fail('err_limit') end
        out[#out + 1] = data.sym
    end
    Tablet.AppData.Set(s.serial, 'stocks', { watch = out })
    return { ok = true, watch = out }
end

Callback.Register('pop_tablet:stocks:subscribe', function(src) return S.Subscribe(src) end)
Callback.Register('pop_tablet:stocks:unsubscribe', function(src) return S.Unsubscribe(src) end)
Callback.Register('pop_tablet:stocks:watch', function(src, data) return S.Watch(src, data) end)

if exports then
    exports('MarketShock', function(symbol, percent) return S.Shock(symbol, percent) end)
end
