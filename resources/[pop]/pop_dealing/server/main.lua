-- pop_dealing serveur : mode vente, clients PNJ, négociation, paiement, exports.
-- Tout est revalidé ici : le client n'envoie que des identifiants et un prix unitaire borné.

local RES = GetCurrentResourceName()

local sellers = {}   -- [src] = { zone, nextAt, customer }
local customers = {} -- [id]  = { id, owner, item, qty, ref, maxUnit, min, max, step, attempts, isCop, model, hash, entity, claimed, readyBy, expiresAt }
local bustUntil = {} -- [identifier] = os.time() de fin du délai après un piège
local leaving = {}   -- [entity] = hash : PNJ partis, en attente de suppression (nettoyés aussi à l'arrêt)
local lastId = 0
local loopRunning = false

local DELETE_DELAY = 15000 -- ms avant suppression d'un PNJ parti
local READY_DELAY = 15     -- s pour que le client crée le PNJ
local CLAIM_DIST = 4.0     -- m, distance max joueur / client pour claim et propose
local ZONE_MARGIN = 10.0   -- m de tolérance hors zone pendant la vente

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

local function notify(src, key, notifyType, ...)
    Bridge.Notify(src, L(key, ...), notifyType or 'info')
end

-- Entier Lua à partir d'un nombre (accepte 96.0 venant d'un décodage JSON), sinon nil.
-- NOTE: SPEC exige un entier ; un flottant à valeur entière est converti, tout le reste est rejeté.
local function toInt(v)
    if type(v) ~= 'number' then return nil end
    return math.tointeger(v)
end

-- Hash de modèle normalisé en non signé (GetEntityModel et joaat peuvent différer de signe).
local function uhash(h)
    return (math.tointeger(h) or 0) & 0xFFFFFFFF
end

local function randRange(r)
    local a, b = math.floor(r[1]), math.floor(r[2])
    if b < a then a, b = b, a end
    return math.random(a, b)
end

local function randFloat(r)
    return r[1] + math.random() * (r[2] - r[1])
end

local function nextDelay()
    return os.time() + randRange(Config.Customers.interval)
end

-- Identifiant persistant du joueur (nil si introuvable : la vente est alors refusée).
local function bustKey(src)
    return Bridge.GetIdentifier(src)
end

-- Purge les délais de piège expirés (appelé au toggle, coût négligeable).
local function purgeBusts(now)
    for key, untilAt in pairs(bustUntil) do
        if untilAt <= now then bustUntil[key] = nil end
    end
end

local function drugLabel(item)
    local d = Config.Drugs[item]
    return L(d and d.label or item)
end

-- Index de la zone où se trouve le joueur (0 si aucune zone configurée), nil si hors zone.
local function zoneIndex(src, margin)
    if #Config.Zones == 0 then return 0 end
    for i, z in ipairs(Config.Zones) do
        if Bridge.IsNear(src, z.coords, z.radius + (margin or 0.0)) then return i end
    end
    return nil
end

-- Liste des drogues possédées : { { item, count }, ... }
local function ownedDrugs(src)
    local list = {}
    for item in pairs(Config.Drugs) do
        local n = math.floor(Bridge.GetItemCount(src, item))
        if n >= 1 then list[#list + 1] = { item = item, count = n } end
    end
    return list
end

local function hasAnyDrug(src)
    for item in pairs(Config.Drugs) do
        if Bridge.HasItem(src, item, 1) then return true end
    end
    return false
end

-- Supprime un PNJ client seulement s'il s'agit toujours du même ped non joueur (l'id réseau a pu être réutilisé).
local function deletePed(ent, hash)
    if ent and DoesEntityExist(ent) and GetEntityType(ent) == 1 and not IsPedAPlayer(ent)
        and uhash(GetEntityModel(ent)) == hash then
        DeleteEntity(ent)
    end
end

-- Position du deal : PNJ client, sinon joueur. Jamais de coordonnées venant du client.
local function dealCoords(c)
    if c.entity and DoesEntityExist(c.entity) then return GetEntityCoords(c.entity) end
    return Bridge.GetCoords(c.owner)
end

------------------------------------------------------------------------
-- Clients et sessions
------------------------------------------------------------------------

--- Fonction unique de retrait d'un client. mode = 'walk' | 'sold' | 'flee'.
local function removeCustomer(id, mode)
    local c = customers[id]
    if not c then return end
    customers[id] = nil
    TriggerClientEvent('pop_dealing:client:customerLeave', c.owner, id, mode or 'walk')
    local s = sellers[c.owner]
    if s and s.customer == id then
        s.customer = nil
        s.nextAt = nextDelay()
    end
    if c.entity then
        local ent, hash = c.entity, c.hash
        leaving[ent] = hash
        SetTimeout(DELETE_DELAY, function()
            if leaving[ent] ~= hash then return end
            leaving[ent] = nil
            deletePed(ent, hash)
        end)
    end
end

--- Arrête la session ; msgKey = clé de notification ou nil (aucun message).
local function stopSession(src, msgKey, notifyType)
    local s = sellers[src]
    if not s then return false end
    if s.customer then removeCustomer(s.customer, 'walk') end
    sellers[src] = nil
    TriggerClientEvent('pop_dealing:client:stop', src)
    if msgKey then notify(src, msgKey, notifyType or 'info') end
    log('selling stopped: %s (%s)', src, msgKey or 'silent')
    return true
end

-- Crée un client pour le vendeur (drogue, quantité, prix secret choisis ici).
local function spawnCustomer(src, s)
    local owned = ownedDrugs(src)
    if #owned == 0 then return false end
    local pick = owned[math.random(#owned)]
    local drug = Config.Drugs[pick.item]
    local zone = Config.Zones[s.zone]
    local mult = zone and zone.mult or 1.0
    local neg = Config.Negotiation

    local ref = math.max(1, math.floor(drug.price * mult + 0.5))
    local models = Config.Customers.models
    local model = models[math.random(#models)]

    lastId = lastId < 2147483647 and lastId + 1 or 1
    local now = os.time()
    local c = {
        id = lastId,
        owner = src,
        item = pick.item,
        qty = math.min(randRange(drug.amount), pick.count),
        ref = ref,
        maxUnit = math.floor(ref * randFloat(neg.accept) + 0.5),
        min = math.max(1, math.floor(ref * neg.range[1])),
        max = math.ceil(ref * neg.range[2]),
        step = math.max(1, math.floor(ref * 0.05 + 0.5)),
        attempts = neg.attempts,
        isCop = math.random() < Config.Undercover.chance,
        model = model,
        hash = uhash(joaat(model)),
        entity = nil,
        claimed = false,
        readyBy = now + READY_DELAY,
        expiresAt = now + Config.Customers.timeout,
    }
    customers[c.id] = c
    s.customer = c.id
    TriggerClientEvent('pop_dealing:client:customer', src, { id = c.id, model = model })
    log('customer %d for %s: %s x%d ref=%d', c.id, src, c.item, c.qty, ref)
    return true
end

-- Contrôle d'un vendeur (appelé toutes les 2 s par la boucle).
local function tickSeller(src, s)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then
        return stopSession(src, 'selling_stopped')
    end
    -- SPEC §10.2 : un vendeur qui prend son service de police est arrêté.
    if Police.IsOnDuty(src) then return stopSession(src, 'police_cannot_sell', 'error') end

    local zone = zoneIndex(src, ZONE_MARGIN)
    if not zone then return stopSession(src, 'left_zone', 'error') end
    s.zone = zone
    if not hasAnyDrug(src) then return stopSession(src, 'out_of_drugs') end

    local now = os.time()
    local c = s.customer and customers[s.customer]
    if s.customer and not c then s.customer = nil end
    if c then
        if not c.entity then
            if now > c.readyBy then removeCustomer(c.id, 'walk') end
        elseif not DoesEntityExist(c.entity) then
            removeCustomer(c.id, 'walk')
        elseif now > c.expiresAt then
            removeCustomer(c.id, 'walk')
            notify(src, 'customer_left')
        end
    elseif now >= s.nextAt then
        spawnCustomer(src, s)
    end
end

-- Une seule boucle, active seulement s'il y a des vendeurs.
local function startLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while next(sellers) do
            Wait(2000)
            for src, s in pairs(sellers) do
                local ok, err = pcall(tickSeller, src, s)
                if not ok then print(('[%s] tick error for %s: %s'):format(RES, src, tostring(err))) end
            end
        end
        loopRunning = false
    end)
end

-- Client valide et appartenant à src, sinon nil.
local function ownCustomer(src, id)
    id = toInt(id)
    if not id then return nil end
    local c = customers[id]
    if not c or c.owner ~= src then return nil end
    return c
end

------------------------------------------------------------------------
-- Events client -> serveur
------------------------------------------------------------------------

RegisterNetEvent('pop_dealing:server:customerReady', function(customerId, netId)
    local src = source
    local c = ownCustomer(src, customerId)
    netId = toInt(netId)
    if not c or c.entity or c.validating or not netId then return end
    c.validating = true

    -- L'entité peut mettre un instant à exister côté serveur.
    local ent = 0
    for _ = 1, 5 do
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        ent = 0
        Wait(200)
    end
    if customers[c.id] ~= c then return end -- retiré pendant l'attente
    c.validating = nil

    -- Jamais d'entité retenue (donc jamais supprimée) si une condition échoue : véhicule, joueur, autre ped...
    local valid = ent ~= 0
        and GetEntityType(ent) == 1
        and not IsPedAPlayer(ent)
        and uhash(GetEntityModel(ent)) == c.hash
        and NetworkGetEntityOwner(ent) == src
        and Bridge.IsNear(src, GetEntityCoords(ent), Config.Customers.distance[2] + 20.0)
    if not valid then
        log('customerReady rejected: %s customer %d netId %d', src, c.id, netId)
        return removeCustomer(c.id, 'walk')
    end
    c.entity = ent
end)

RegisterNetEvent('pop_dealing:server:customerLost', function(customerId)
    local c = ownCustomer(source, customerId)
    if c then removeCustomer(c.id, 'walk') end
end)

RegisterNetEvent('pop_dealing:server:refuse', function(customerId)
    local c = ownCustomer(source, customerId)
    if c then removeCustomer(c.id, 'walk') end
end)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_dealing:toggle', function(src)
    if sellers[src] then
        stopSession(src, 'selling_stopped')
        return false
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local now = os.time()
    purgeBusts(now)
    local key = bustKey(src)
    if not key then
        notify(src, 'error', 'error')
        return false
    end
    local untilAt = bustUntil[key]
    if untilAt and untilAt > now then
        notify(src, 'cooldown', 'error', untilAt - now)
        return false
    end
    if Police.IsOnDuty(src) then
        notify(src, 'police_cannot_sell', 'error')
        return false
    end
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        notify(src, 'in_vehicle', 'error')
        return false
    end
    local zone = zoneIndex(src, 0.0)
    if not zone then
        notify(src, 'not_in_zone', 'error')
        return false
    end
    if not hasAnyDrug(src) then
        notify(src, 'no_drugs', 'error')
        return false
    end
    if Police.Count() < Config.Police.minOnline then
        notify(src, 'not_enough_police', 'error')
        return false
    end

    sellers[src] = { zone = zone, nextAt = nextDelay(), customer = nil }
    startLoop()
    notify(src, 'selling_started', 'success')
    log('selling started: %s zone=%d', src, zone)
    return true
end)

Callback.Register('pop_dealing:claim', function(src, customerId)
    local c = ownCustomer(src, customerId)
    if not c or c.claimed or not c.entity or not sellers[src] then return nil end
    if not DoesEntityExist(c.entity) then
        removeCustomer(c.id, 'walk')
        return nil
    end
    if not Bridge.IsNear(src, GetEntityCoords(c.entity), CLAIM_DIST) then
        notify(src, 'too_far', 'error')
        return nil
    end
    if not Bridge.HasItem(src, c.item, c.qty) then
        notify(src, 'not_enough_drug', 'error', c.qty, drugLabel(c.item))
        removeCustomer(c.id, 'walk')
        return nil
    end

    c.claimed = true
    c.expiresAt = os.time() + Config.Customers.timeout
    -- maxUnit et isCop ne quittent jamais le serveur.
    return {
        id = c.id,
        label = Config.Drugs[c.item].label,
        qty = c.qty,
        hint = c.ref,
        min = c.min,
        max = c.max,
        step = c.step,
        attempts = c.attempts,
        maxAttempts = Config.Negotiation.attempts,
    }
end)

-- Paiement selon Config.Payment. Renvoie true si payé.
local function pay(src, amount)
    local p = Config.Payment
    if p.type == 'item' then
        return Bridge.AddItem(src, p.item, amount)
    elseif p.type == 'black' then
        -- Repli sur 'cash' si le framework n'a pas de compte sale (ex. QBCore).
        return Bridge.AddMoney(src, 'black', amount, RES) or Bridge.AddMoney(src, 'cash', amount, RES)
    end
    return Bridge.AddMoney(src, 'cash', amount, RES)
end

-- Déclare la vente à pop_territories s'il est lancé ; renvoie le montant final (sécurisé).
local function applyTerritories(src, coords, amount)
    if GetResourceState('pop_territories') ~= 'started' then return amount end
    local ok, final, info = pcall(function()
        return exports.pop_territories:RecordDrugSale(src, coords, amount)
    end)
    if not ok then
        log('pop_territories error: %s', tostring(final))
        return amount
    end
    if type(final) ~= 'number' or final ~= final or final < 0 then return amount end
    final = math.min(math.floor(final), amount * 3)
    if Config.Debug then
        -- info = { zone, owner = { key, label, color } | nil, mult, rival } : utilisé pour les logs uniquement.
        local zone, owner, mult
        if type(info) == 'table' then
            zone, mult = info.zone, info.mult
            if type(info.owner) == 'table' then owner = info.owner.label or info.owner.key end
        end
        log('territories: %d -> %d (zone=%s owner=%s mult=%s)', amount, final, tostring(zone), tostring(owner), tostring(mult))
    end
    return final
end

-- Erreur de proposition : le client est retiré (la négociation est fermée côté client).
-- keep = true quand le client a déjà été retiré (verrouillé avant les appels externes).
local function proposeError(c, key, keep, ...)
    if key then notify(c.owner, key, 'error', ...) end
    if not keep then removeCustomer(c.id, 'walk') end
    return { status = 'error' }
end

Callback.Register('pop_dealing:propose', function(src, customerId, price)
    local c = ownCustomer(src, customerId)
    if not c or not c.claimed or not c.entity or c.closing then return nil end
    if not sellers[src] then return proposeError(c) end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then
        return proposeError(c, 'in_vehicle')
    end
    if not zoneIndex(src, ZONE_MARGIN) then
        return proposeError(c, 'left_zone')
    end

    if not DoesEntityExist(c.entity) or not Bridge.IsNear(src, GetEntityCoords(c.entity), CLAIM_DIST) then
        return proposeError(c, 'too_far')
    end
    price = toInt(price)
    if not price or price < c.min or price > c.max or c.attempts <= 0 then
        return proposeError(c)
    end
    local label = drugLabel(c.item)
    if not Bridge.HasItem(src, c.item, c.qty) then
        return proposeError(c, 'not_enough_drug', false, c.qty, label)
    end

    local coords = dealCoords(c)

    -- Trop cher : une tentative en moins.
    if price > c.maxUnit then
        c.attempts = c.attempts - 1
        if c.attempts <= 0 then
            removeCustomer(c.id, 'walk')
            notify(src, 'deal_walkaway', 'error')
            return { status = 'walkaway' }
        end
        return { status = 'refused', hint = price > c.maxUnit * 1.2 and 'too_high' or 'almost', attempts = c.attempts }
    end

    -- Place pour le paiement en item (x3 : plafond du montant après pop_territories). Lecture seule, avant verrou.
    if not c.isCop and Config.Payment.type == 'item'
        and not Bridge.CanCarry(src, Config.Payment.item, price * c.qty * 3) then
        return proposeError(c, 'inventory_full')
    end

    -- Client accepté : retiré AVANT tout appel externe (aucune double vente possible pendant un yield).
    if c.closing or customers[c.id] ~= c then return nil end -- autre appel concurrent passé pendant un yield
    c.closing = true
    local entity = c.entity

    -- Flic infiltré : piège.
    if c.isCop then
        removeCustomer(c.id, 'flee')
        local key = bustKey(src)
        if key then bustUntil[key] = os.time() + Config.Undercover.cooldown end
        if Config.Undercover.seize then Bridge.RemoveItem(src, c.item, c.qty) end
        Police.Alert(coords, 'bust')
        notify(src, 'bust', 'error')
        stopSession(src, nil)
        log('BUST: %s %s x%d at %d', src, c.item, c.qty, price)
        return { status = 'bust' }
    end

    -- Vente.
    local qty, item = c.qty, c.item
    local amount = price * qty
    removeCustomer(c.id, 'sold')
    if not Bridge.RemoveItem(src, item, qty) then
        return proposeError(c, 'not_enough_drug', true, qty, label)
    end

    amount = applyTerritories(src, coords, amount)
    if amount >= 1 and not pay(src, amount) then
        Bridge.AddItem(src, item, qty) -- rendre la drogue
        log('payment failed: %s %s x%d amount=%d', src, item, qty, amount)
        return proposeError(c, 'payment_failed', true)
    end

    notify(src, 'sold', 'success', qty, label, L('money', amount))
    TriggerEvent('pop_dealing:sold', src, item, qty, amount, coords)
    log('SOLD: %s %s x%d unit=%d final=%d', src, item, qty, price, amount)

    -- Témoins : plus il y a de monde et plus le prix est élevé, plus le risque est grand.
    local w = Police.CountWitnesses(coords, entity)
    local chance = math.min(0.9, w * Config.Witnesses.chance * (price / c.ref))
    if w > 0 and math.random() < chance then
        Police.Alert(coords, 'deal')
        notify(src, 'witness_called', 'warning')
        log('witness called police: %s (%d witnesses)', src, w)
    end

    if not hasAnyDrug(src) then stopSession(src, 'out_of_drugs') end
    return { status = 'accepted' }
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('IsSelling', function(src)
    return sellers[tonumber(src)] ~= nil
end)

exports('StopSelling', function(src)
    return stopSession(tonumber(src), 'selling_stopped')
end)

------------------------------------------------------------------------
-- Déconnexion et arrêt
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src)
    src = tonumber(src)
    local s = src and sellers[src]
    if not s then return end
    local c = s.customer and customers[s.customer]
    if c then
        customers[c.id] = nil
        deletePed(c.entity, c.hash)
    end
    sellers[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, c in pairs(customers) do deletePed(c.entity, c.hash) end
    for ent, hash in pairs(leaving) do deletePed(ent, hash) end
end)

------------------------------------------------------------------------
-- Validation de la configuration au démarrage
------------------------------------------------------------------------

CreateThread(function()
    local models = Config.Customers and Config.Customers.models
    if type(models) ~= 'table' or #models == 0 then
        print(('[%s] ^1config error: Config.Customers.models is empty^7'):format(RES))
    end
    for item, d in pairs(Config.Drugs or {}) do
        if type(d.amount) ~= 'table' or (tonumber(d.amount[1]) or 0) < 1 then
            print(('[%s] ^1config error: Config.Drugs[%s].amount[1] must be >= 1^7'):format(RES, item))
        end
    end
end)
