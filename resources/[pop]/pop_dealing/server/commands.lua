-- ─────────────────────────────────────────────
-- pop_dealing - commandes dev (réservées aux admins : ace pop.admin)
-- Les print ci-dessous sont la réponse des commandes dans la console serveur (pas du debug).
-- ─────────────────────────────────────────────

local customers = Dealing.customers

-- Spawn un client juste devant le joueur (peu importe la zone)
RegisterCommand('dealing_spawn', function(src)
    if not Dealing.isAdmin(src) then return end
    if src == 0 then return print(L('admin_ingame_only')) end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pc      = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad     = math.pi / 180.0
    -- 2m devant le joueur (vecteur "avant" du ped)
    local fx      = pc.x - math.sin(heading * rad) * 2.0
    local fy      = pc.y + math.cos(heading * rad) * 2.0

    local drug     = Dealing.pickWeighted(Config.Drugs)
    local qty      = math.random(drug.qtyRange[1], drug.qtyRange[2])
    local maxUnit  = Dealing.rollMaxPrice(drug.basePrice)
    local hintUnit = math.floor(drug.basePrice * (Config.HintPriceMultiplier or 1.0) + 0.5)
    local model    = Config.CustomerModels[math.random(#Config.CustomerModels)]

    local id = Dealing.NextId()

    customers[id] = {
        id           = id,
        zoneIdx      = 0,
        drugDefId    = drug.defId,
        drugLabel    = drug.label,
        drugIcon     = drug.icon,
        qty          = qty,
        basePrice    = drug.basePrice,
        hintUnit     = hintUnit,
        maxUnit      = maxUnit,
        attemptsLeft = Config.MaxAttempts or 3,
        model        = model,
        x            = fx,
        y            = fy,
        z            = pc.z,
        heading      = (heading + 180.0) % 360.0,
        isCop        = false,
        claimedBy    = nil,
        expiresAt    = os.time() + Config.CustomerLifetime,
        sentTo       = {},
    }

    if Config.Debug then
        print(('[pop_dealing] spawn id=%d model=%s drug=%s x%d hint=$%d max=$%d @ %.2f,%.2f,%.2f'):format(
            id, model, drug.defId, qty, hintUnit, maxUnit, fx, fy, pc.z))
    end

    Dealing.sendCustomer(src, customers[id])
    Dealing.Notify(src, {
        icon = 'fas fa-info',
        message = L('admin_spawned', id, drug.label, qty, hintUnit, maxUnit),
        duration = Config.NotifyDurations.selling,
    })
end, false)

-- Liste les clients actifs côté serveur
RegisterCommand('dealing_list', function(src)
    if not Dealing.isAdmin(src) then return end
    local n = 0
    for id, c in pairs(customers) do
        n = n + 1
        local msg = L('admin_list_line',
            id, c.zoneIdx or 0, c.drugDefId, c.qty, c.maxUnit or 0, tostring(c.claimedBy), c.x, c.y, c.z)
        if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { '[dealing]', msg } }) end
    end
    if n == 0 then
        local msg = L('admin_list_empty')
        if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { '[dealing]', msg } }) end
    end
end, false)

-- Wipe tous les clients
RegisterCommand('dealing_clear', function(src)
    if not Dealing.isAdmin(src) then return end
    for id in pairs(customers) do Dealing.removeCustomer(id) end
    if src ~= 0 then
        Dealing.Notify(src, { icon = 'fas fa-trash', message = L('admin_cleared'), duration = Config.NotifyDurations.short })
    end
end, false)
