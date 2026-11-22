-- ─────────────────────────────────────────────
-- pop_dealing - mode "vente de drogue" par joueur (déclenché via l'item pochonweed)
-- ─────────────────────────────────────────────

local customers      = Dealing.customers
local sellingPlayers = Dealing.sellingPlayers

local function countSellerCustomers(src)
    local n = 0
    for _, c in pairs(customers) do
        if c.ownerSrc == src then n = n + 1 end
    end
    return n
end

function Dealing.stopSelling(src, message)
    if not sellingPlayers[src] then return end
    sellingPlayers[src] = nil
    for id, c in pairs(customers) do
        if c.ownerSrc == src then Dealing.removeCustomer(id) end
    end
    if message then Dealing.dealNotify(src, message, 'fas fa-ban') end
end

-- Génère un client à une distance aléatoire autour du joueur (il marchera vers lui)
local function generateCustomerNear(src)
    local pc = Bridge.GetCoords(src)
    if not pc then return end

    local angle = math.random() * math.pi * 2
    local dmin  = Config.SellingSpawnMin or 12.0
    local dmax  = Config.SellingSpawnMax or 25.0
    local dist  = dmin + math.random() * (dmax - dmin)

    local drug     = Dealing.pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = Dealing.rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]

    local id = Dealing.NextId()

    customers[id] = {
        id           = id,
        zoneIdx      = 0,
        ownerSrc     = src,
        static       = true,   -- reste sur place + blip ; le joueur vient à lui
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,
        maxUnit      = maxUnit,
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = pc.x + math.cos(angle) * dist,
        y            = pc.y + math.sin(angle) * dist,
        z            = pc.z,
        heading      = math.random(0, 359) + 0.0,
        isCop        = math.random() < (Config.BustChance or 0.0),
        claimedBy    = nil,
        expiresAt    = os.time() + Config.CustomerLifetime,
        sentTo       = {},
    }

    -- Client personnel : créé uniquement chez le vendeur
    Dealing.sendCustomer(src, customers[id])
end

-- Bascule le mode vente (appelé par pochonweed.onUse côté pop_inventory)
exports('toggleSelling', function(src)
    src = tonumber(src)
    if not src then return end

    if sellingPlayers[src] then
        Dealing.stopSelling(src, L('selling_stopped'))
        return
    end

    if not Dealing.hasSellableDrug(src) then
        return Dealing.dealNotify(src, L('selling_no_drug'), 'fas fa-circle-exclamation')
    end

    sellingPlayers[src] = { lastSpawn = 0 }
    Dealing.dealNotify(src, L('selling_started'), 'fas fa-handshake')
end)

-- Tick de spawn pour les vendeurs actifs
CreateThread(function()
    while true do
        Wait(3000)
        local now = os.time()
        for src, sess in pairs(sellingPlayers) do
            if GetPlayerPed(src) == 0 then
                Dealing.stopSelling(src)
            elseif not Dealing.hasSellableDrug(src) then
                Dealing.stopSelling(src, L('selling_out_of_stock'))
            elseif countSellerCustomers(src) < (Config.SellingMaxCustomers or 3)
                   and now - (sess.lastSpawn or 0) >= (Config.SellingSpawnInterval or 18) then
                generateCustomerNear(src)
                sess.lastSpawn = now
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Cleanup à la déco
-- ─────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    Dealing.stopSelling(src)
    for _, c in pairs(customers) do
        if c.claimedBy == src then c.claimedBy = nil end
        if c.sentTo then c.sentTo[src] = nil end
    end
end)
