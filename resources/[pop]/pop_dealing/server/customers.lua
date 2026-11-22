-- ─────────────────────────────────────────────
-- pop_dealing - clients de zone (spawn, streaming, sync à la connexion)
-- ─────────────────────────────────────────────

local customers       = Dealing.customers
local lastSpawnAtZone = {}  -- [zoneIdx] = os.time()

local function randomPointInZone(zone)
    local angle = math.random() * math.pi * 2
    local dist  = math.sqrt(math.random()) * zone.radius
    return vec3(zone.center.x + math.cos(angle) * dist,
                zone.center.y + math.sin(angle) * dist,
                zone.center.z)
end

local function countCustomersInZone(zoneIdx)
    local n = 0
    for _, c in pairs(customers) do
        if c.zoneIdx == zoneIdx then n = n + 1 end
    end
    return n
end

-- Clients de zone : envoyés uniquement aux joueurs proches, retirés quand ils s'éloignent
local function streamZoneCustomers()
    local range = Config.CustomerStreamRange or 150.0
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local pc  = Bridge.GetCoords(src)
        if pc then
            for id, c in pairs(customers) do
                if not c.ownerSrc then
                    c.sentTo = c.sentTo or {}
                    local dist = #(pc - vec3(c.x, c.y, c.z))
                    if not c.sentTo[src] and dist <= range then
                        Dealing.sendCustomer(src, c)
                    elseif c.sentTo[src] and dist > range + Config.CustomerStreamMargin and c.claimedBy ~= src then
                        c.sentTo[src] = nil
                        TriggerClientEvent('pop_dealing:removeCustomer', src, id)
                    end
                end
            end
        end
    end
end

local function generateCustomer(zoneIdx)
    local zone = Config.Zones[zoneIdx]
    if not zone then return end

    local drug     = Dealing.pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = Dealing.rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]
    local coords   = randomPointInZone(zone)

    local id = Dealing.NextId()

    customers[id] = {
        id           = id,
        zoneIdx      = zoneIdx,
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,            -- prix indicatif affiché au joueur
        maxUnit      = maxUnit,             -- limite haute par unité (secret)
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = coords.x,
        y            = coords.y,
        z            = coords.z,
        heading      = math.random(0, 359) + 0.0,
        isCop        = math.random() < (Config.BustChance or 0.0),
        claimedBy    = nil,
        expiresAt    = os.time() + Config.CustomerLifetime,
        sentTo       = {},
    }

    -- Envoyé seulement aux joueurs proches (voir streamZoneCustomers)
    streamZoneCustomers()
    return customers[id]
end

-- ─────────────────────────────────────────────
-- Tick de spawn
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        -- Despawn auto des clients trop vieux
        for id, c in pairs(customers) do
            if now >= c.expiresAt then Dealing.removeCustomer(id) end
        end

        -- Clients de zone : création / retrait selon la distance des joueurs
        streamZoneCustomers()

        -- En mode dev: pas de spawn automatique, on passe par /dealing_spawn
        if Config.DevIgnoreZone then
            goto continue
        end

        -- Spawn dans chaque zone si sous la limite
        for idx in ipairs(Config.Zones) do
            local last = lastSpawnAtZone[idx] or 0
            if now - last >= (Config.CustomerSpawnCooldown or 30)
               and countCustomersInZone(idx) < (Config.MaxCustomersPerZone or 2) then
                generateCustomer(idx)
                lastSpawnAtZone[idx] = now
            end
        end

        ::continue::
    end
end)

-- ─────────────────────────────────────────────
-- Sync à la connexion
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:requestSync', function()
    local src = source
    local pc  = Bridge.GetCoords(src)
    local range = Config.CustomerStreamRange or 150.0
    local list = {}
    for _, c in pairs(customers) do
        c.sentTo = c.sentTo or {}
        local mine = c.ownerSrc == src
        local near = not c.ownerSrc and pc and #(pc - vec3(c.x, c.y, c.z)) <= range
        if mine or near then
            c.sentTo[src] = true
            list[#list + 1] = Dealing.publicData(c)
        end
    end
    TriggerClientEvent('pop_dealing:syncAll', src, list)
end)
