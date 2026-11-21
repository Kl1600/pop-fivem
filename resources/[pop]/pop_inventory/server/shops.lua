-- pop_inventory : boutiques (Config.Shops + export RegisterShop), callback pop_inventory:buy (SPEC §11.2.3, §12).
-- Le client n'envoie que l'index de l'article, la quantité et le slot : prix, item et metadata sont relus ici.

Containers = Containers or {}
Containers.Types = Containers.Types or {}

local TOLERANCE = 1.0      -- m : marge serveur (latence)
local POINT_DISTANCE = 2.0 -- m : portée d'un point de vente (serveur : + TOLERANCE)
local BUY_MAX = 1000       -- quantité max par achat
local ID_MAX_LENGTH = 64
local ACCOUNTS = { cash = true, bank = true }

local Shops = {} -- [id] = { id, label, account, coords = { vector3, ... }, blip, jobs, items }

local function validPrice(p)
    p = tonumber(p)
    if not p or p ~= p or p < 0 or p == math.huge then return nil end
    return math.tointeger(math.floor(p))
end

local function itemsReady()
    return Database ~= nil and Database.ready == true
end

-- Articles normalisés ; checkItems = retirer les items absents du registre (avertissement console).
local function buildItems(id, list, checkItems)
    local out = {}
    for i, art in ipairs(list) do
        local name = type(art) == 'table' and type(art.name) == 'string' and art.name:lower() or nil
        local price = name and validPrice(art.price)
        if not name or not price then
            Containers.Warn('shop "%s": article %d ignored (invalid name or price)', id, i)
        elseif checkItems and not Items.Get(name) then
            Containers.Warn('shop "%s": unknown item "%s" ignored', id, name)
        else
            out[#out + 1] = {
                name = name, price = price,
                metadata = type(art.metadata) == 'table' and Inventory.Copy(art.metadata) or nil,
                jobs = art.jobs,
            }
        end
    end
    return out
end

--- Enregistre (ou remplace) une boutique. data = une entrée Config.Shops sans id.
function Containers.RegisterShop(id, data)
    if type(id) ~= 'string' or id == '' or #id > ID_MAX_LENGTH or type(data) ~= 'table' or type(data.items) ~= 'table' then
        Containers.Warn('RegisterShop: invalid id or data "%s"', tostring(id))
        return false
    end
    local account = data.account == nil and 'cash' or data.account
    if not ACCOUNTS[account] then
        Containers.Warn('RegisterShop: invalid account for "%s"', id)
        return false
    end

    local coords, raw = {}, data.coords
    local rt = type(raw)
    if rt == 'vector3' or rt == 'vector4' or (rt == 'table' and raw.x ~= nil) then raw = { raw } end
    if type(raw) == 'table' then
        for i, c in ipairs(raw) do
            local v = Containers.ToVec(c)
            if v then
                coords[#coords + 1] = v
            else
                Containers.Warn('shop "%s": invalid coords %d ignored', id, i)
            end
        end
    end

    local blip = nil
    if type(data.blip) == 'table' and tonumber(data.blip.sprite) then
        blip = { sprite = math.floor(tonumber(data.blip.sprite)), color = math.floor(tonumber(data.blip.color) or 0) }
    end

    Shops[id] = {
        id = id,
        label = LabelOf(type(data.label) == 'string' and data.label ~= '' and data.label or 'inv_shop'),
        account = account,
        coords = coords,
        blip = blip,
        jobs = data.jobs,
        items = buildItems(id, data.items, itemsReady()),
    }
    Containers.Log('shop registered: %s', id)
    return true
end

--- Boutiques avec coords : { { id, label, coords = { {x,y,z}, ... }, blip }, ... }.
function Containers.ShopPoints()
    local list = {}
    for id, shop in pairs(Shops) do
        if #shop.coords > 0 then
            local pts = {}
            for i, c in ipairs(shop.coords) do pts[i] = Containers.Plain(c) end
            list[#list + 1] = { id = id, label = shop.label, coords = pts, blip = shop.blip }
        end
    end
    return list
end

local function nearestPoint(src, shop)
    local pos = Bridge.GetCoords(src)
    if not pos then return nil, nil end
    local best, bestDist
    for _, c in ipairs(shop.coords) do
        local d = #(pos - c)
        if not bestDist or d < bestDist then best, bestDist = c, d end
    end
    return best, bestDist
end

local function shopAccess(src, shop, s)
    if s.forced then return true end
    if shop.jobs and not Bridge.HasJob(src, shop.jobs) then return false, 'wrong_job' end
    local _, dist = nearestPoint(src, shop)
    if not dist or dist > POINT_DISTANCE + TOLERANCE then return false, 'too_far' end
    return true
end

Containers.Types.shop = {
    isShop = true,

    -- Construit la ShopView : articles autorisés seulement ; la session garde slot -> article.
    open = function(src, request, s)
        local shop = type(request.id) == 'string' and Shops[request.id]
        if not shop then return nil, 'error' end
        local ok, why = shopAccess(src, shop, s)
        if not ok then return nil, why end

        local articles, items = {}, {}
        for _, art in ipairs(shop.items) do
            if Items.Get(art.name) and (not art.jobs or Bridge.HasJob(src, art.jobs)) then
                local n = #articles + 1
                articles[n] = art
                items[n] = { slot = n, name = art.name, count = 1, price = art.price, metadata = Inventory.Copy(art.metadata) or {} }
            end
        end
        s.shopId, s.shop, s.articles = shop.id, shop, articles
        return { type = 'shop', label = shop.label, account = shop.account, slots = #articles, items = items }
    end,

    watch = function(src, s)
        local point = nearestPoint(src, s.shop)
        if not point then return nil end
        return { coords = Containers.Plain(point), distance = POINT_DISTANCE + 1.0 }
    end,

    -- data = id de boutique.
    forceRequest = function(data)
        if type(data) == 'string' then return { id = data } end
        return nil
    end,
}

------------------------------------------------------------------------
-- Achat
------------------------------------------------------------------------

Callback.Register('pop_inventory:buy', function(src, index, count, toSlot)
    local pinv = Containers.PlayerInv(src)
    if not Bridge.GetPlayer(src) or not pinv then return false, 'not_loaded' end
    ReconcileCash(src) -- item d'argent aligné sur le framework avant les contrôles de poids et de paiement
    index, count = Inventory.ToInt(index), Inventory.ToInt(count)
    if not index or not count then return false, 'error' end
    if toSlot ~= nil then
        toSlot = Inventory.ToInt(toSlot)
        if not toSlot or toSlot < 1 or toSlot > pinv.slots then return false, 'error' end
    end

    local s = Containers.GetSession(src)
    if not s or s.kind ~= 'shop' then return false, 'error' end
    local shop = Shops[s.shopId]
    if not shop or shop ~= s.shop then
        -- Boutique supprimée ou réenregistrée depuis l'ouverture.
        Containers.EndSession(src, true)
        return false, 'error'
    end
    if Bridge.IsDead(src) or InvPlayers.IsBusy(src) then return false, 'cannot_now' end
    local ok, why = shopAccess(src, shop, s)
    if ok then ok, why = Containers.ForcedInRange(src, s) end
    if not ok then
        Containers.EndSession(src, true)
        return false, why
    end

    local art = s.articles[index]
    if not art then return false, 'error' end
    local def = Items.Get(art.name)
    if not def then return false, 'invalid_item' end
    -- NOTE: item non empilable : une seule unité par achat (quantité ramenée à 1).
    if def.stack == false or def.weapon then count = 1 end
    if count < 1 or count > BUY_MAX then return false, 'error' end

    local price = art.price * count
    local metadata = Inventory.Copy(art.metadata) or {}
    if def.weapon then metadata.registered = Bridge.GetName(src) end

    if not Inventory.CanCarry(pinv, art.name, count, metadata) then return false, 'inventory_full' end
    -- Slot visé occupé par un autre item : placement automatique.
    if toSlot then
        local cur = pinv.items[toSlot]
        if cur and (cur.name ~= art.name or def.stack == false) then toSlot = nil end
    end

    -- Paiement (aucune attente entre ici et l'ajout).
    local cashItem = InvPlayers.CashItem()
    local paidWithItem = false
    if price > 0 then
        if cashItem and shop.account == 'cash' then
            -- Solde du framework vérifié avant de retirer l'item (resynchronisé au début de l'achat).
            if not InvPlayers.CashGuard(src, cashItem, price) then return false, 'not_enough_money' end
            if not Inventory.RemoveItem(pinv, cashItem, price) then return false, 'not_enough_money' end
            paidWithItem = true
        elseif not Bridge.RemoveMoney(src, shop.account, price, 'pop_inventory') then
            return false, 'not_enough_money'
        end
    end

    local added, reason = Inventory.AddItem(pinv, art.name, count, metadata, toSlot)
    if not added then
        -- Remboursement intégral.
        if price > 0 then
            if paidWithItem then
                if not Inventory.AddItem(pinv, cashItem, price) then Bridge.AddMoney(src, 'cash', price, 'pop_inventory') end
            else
                Bridge.AddMoney(src, shop.account, price, 'pop_inventory')
            end
        end
        Containers.Log('buy refunded: %s %dx %s (%s)', src, count, art.name, tostring(reason))
        return false, reason == 'invalid_item' and 'invalid_item' or 'inventory_full'
    end

    Containers.Log('buy: %s bought %dx %s for %d (%s) at %s', src, count, art.name, price, shop.account, shop.id)
    Bridge.Notify(src, L('bought_item', count, Items.Label(art.name)), 'success')
    return true
end)

------------------------------------------------------------------------
-- Boutiques de la config
------------------------------------------------------------------------

CreateThread(function()
    Wait(0) -- après le chargement de tous les fichiers
    for i, shop in ipairs(Config.Shops or {}) do
        if type(shop) ~= 'table' or not Containers.RegisterShop(shop.id, shop) then
            Containers.Warn('Config.Shops[%d] ignored', i)
        end
    end
    -- Les définitions importées du framework arrivent avec la base (LOT 1) : on retire ensuite les items inconnus.
    if itemsReady() then return end
    Containers.WaitReady()
    for id, shop in pairs(Shops) do
        shop.items = buildItems(id, shop.items, true)
    end
end)
