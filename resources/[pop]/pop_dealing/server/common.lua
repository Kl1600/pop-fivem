-- ─────────────────────────────────────────────
-- pop_dealing - fonctions communes du serveur (chargé en premier, voir fxmanifest)
-- ─────────────────────────────────────────────

Dealing = {}

Dealing.customers      = {}   -- [id] = { zoneIdx, drugDefId, qty, unitPrice, totalPrice, model, coords, heading, isCop, claimedBy, expiresAt, sentTo }
Dealing.sellingPlayers = {}   -- [src] = { lastSpawn = os.time() }

local customers = Dealing.customers
local nextId    = 1

math.randomseed(os.time())

function Dealing.NextId()
    local id = nextId
    nextId = nextId + 1
    return id
end

-- ─────────────────────────────────────────────
-- Notifications
-- L'évènement 'pop_dealing:notify' est gardé : pop_territories (checklist) l'écoute
-- pour valider l'étape « Vente activée ». Le client l'affiche avec Bridge.Notify.
-- ─────────────────────────────────────────────

function Dealing.Notify(src, data)
    TriggerClientEvent('pop_dealing:notify', src, data)
end

function Dealing.dealNotify(src, message, icon)
    Dealing.Notify(src, {
        icon = icon or 'fas fa-cannabis', message = message, duration = Config.NotifyDurations.selling,
    })
end

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

function Dealing.pickWeighted(drugs)
    local total = 0
    for _, d in ipairs(drugs) do total = total + (d.demand or 1) end
    local roll = math.random() * total
    local acc  = 0
    for _, d in ipairs(drugs) do
        acc = acc + (d.demand or 1)
        if roll <= acc then return d end
    end
    return drugs[1]
end

-- Génère un maxPrice unitaire (limite haute du client) à partir de basePrice
function Dealing.rollMaxPrice(basePrice)
    local minM, maxM = Config.MaxPriceMultiplier[1], Config.MaxPriceMultiplier[2]
    local mult = minM + math.random() * (maxM - minM)
    return math.floor(basePrice * mult + 0.5)
end

-- Données envoyées au client : sans le prix max ni le flag flic (secrets serveur)
function Dealing.publicData(c)
    return {
        id        = c.id,
        zoneIdx   = c.zoneIdx,
        static    = c.static,
        drugDefId = c.drugDefId,
        drugLabel = c.drugLabel,
        drugIcon  = c.drugIcon,
        qty       = c.qty,
        model     = c.model,
        x         = c.x,
        y         = c.y,
        z         = c.z,
        heading   = c.heading,
    }
end

-- Crée le PNJ chez un seul joueur (et retient qu'il l'a)
function Dealing.sendCustomer(src, c)
    c.sentTo = c.sentTo or {}
    if c.sentTo[src] then return end
    c.sentTo[src] = true
    TriggerClientEvent('pop_dealing:spawnCustomer', src, Dealing.publicData(c))
end

-- Anti-abus : le joueur doit être physiquement proche du client
function Dealing.isNearCustomer(src, c)
    -- clients statiques : ne bougent pas ; clients de zone : marchent vers le joueur
    local maxDist = c.static and Config.StaticCustomerRange
        or ((Config.CustomerDetectRange or 40.0) + Config.CustomerRangeMargin)
    return Bridge.IsNear(src, vec3(c.x, c.y, c.z), maxDist)
end

function Dealing.removeCustomer(id)
    local c = customers[id]
    if not c then return end
    customers[id] = nil
    -- Uniquement aux joueurs qui ont ce PNJ
    for src in pairs(c.sentTo or {}) do
        TriggerClientEvent('pop_dealing:removeCustomer', src, id)
    end
end

-- Joueurs dont le job fait partie de Config.PoliceJobs
function Dealing.getPoliceSources()
    local jobs = Config.PoliceJobs or { 'police' }
    local list = {}
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Bridge.HasJob(src, jobs) then
            list[#list + 1] = src
        end
    end
    return list
end

-- Nom du lieu pour l'alerte : zone de deal, sinon territoire (pop_territories)
function Dealing.placeLabel(c)
    local zone = Config.Zones[c.zoneIdx]
    if zone then return zone.name end
    local ok, _, label = pcall(function() return exports.pop_territories:getZoneAt(c.x, c.y) end)
    return (ok and label) or L('unknown_place')
end

-- Le joueur a-t-il au moins une drogue vendable sur lui ?
function Dealing.hasSellableDrug(src)
    if Config.DevIgnoreItemCheck then return true end
    for _, d in ipairs(Config.Drugs) do
        if Bridge.GetItemCount(src, d.defId) > 0 then return true end
    end
    return false
end

-- Admins : ace pop.admin (ou console)
function Dealing.isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'pop.admin')
end
