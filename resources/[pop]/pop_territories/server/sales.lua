-- ─────────────────────────────────────────────
-- pop_territories - ventes de drogue (appelé par pop_dealing)
-- ─────────────────────────────────────────────

local shares   = Territories.shares
local warState = Territories.warState
local lastGain = Territories.lastGain

local ICON_DEBUG = 'fas fa-bug'

-- Export pour les autres scripts (ex. pop_dealing) : zone d'une position
exports('getZoneAt', function(x, y)
    local zoneId, zoneData = Territories.getZoneAt(tonumber(x) or 0.0, tonumber(y) or 0.0)
    return zoneId, zoneData and zoneData.label or nil
end)

-- ─────────────────────────────────────────────
-- Point d'entrée : une vente de drogue a eu lieu (appelé par pop_dealing)
-- src        = vendeur
-- baseAmount = montant calculé par pop_dealing AVANT multiplicateur
-- retourne   : finalAmount, info
-- ─────────────────────────────────────────────

exports('recordDrugSale', function(src, baseAmount)
    baseAmount = tonumber(baseAmount) or 0

    src = tonumber(src)
    if not src or GetPlayerPed(src) == 0 then return baseAmount, { zone = nil } end

    -- Position serveur du vendeur → territoire
    local zoneId, zoneData = Territories.zoneOfPlayer(src)
    if not zoneId then
        -- Hors territoire
        if Config.Debug then Territories.Notify(src, L('debug_title'), L('debug_outside'), ICON_DEBUG, 5000) end
        return math.floor(baseAmount * Config.OutsideMultiplier + 0.5), { zone = nil }
    end

    -- Zone de vente ? (dealZone = false dans config.lua pour l'exclure)
    if not Territories.isDealZone(zoneData) then
        -- Territoire normal : aucune vente comptabilisée, pas de multiplicateur
        if Config.Debug then Territories.Notify(src, L('debug_title'), L('debug_not_deal_zone', zoneId), ICON_DEBUG, 5000) end
        return math.floor(baseAmount * Config.OutsideMultiplier + 0.5), { zone = zoneId, dealZone = false }
    end

    local baseMult = tonumber(zoneData.multiplier) or Config.DefaultMultiplier

    local crew = exports.pop_crew:getCrew(src)
    if not crew then
        -- Vendeur sans crew : multiplicateur de base, aucune prise de part
        if Config.Debug then Territories.Notify(src, L('debug_title'), L('debug_no_crew', zoneId), ICON_DEBUG, 6000) end
        return math.floor(baseAmount * baseMult + 0.5), { zone = zoneId, mult = baseMult }
    end

    -- Contrôleur AVANT la vente (pour détecter le déclenchement de guerre)
    local ctrlBefore = Territories.controllerOf(zoneId)

    -- Cooldown par joueur entre deux gains de part
    local now    = os.time()
    local gained = now - (lastGain[src] or 0) >= (Config.ShareCooldown or 60)

    -- Gain de part pour le crew du vendeur
    local newShare = Territories.getShare(zoneId, crew.id)
    if gained then
        lastGain[src] = now
        newShare = Territories.clampShare(newShare + Config.SharePerSale)
        Territories.setShare(zoneId, crew.id, newShare)
    end

    -- Érosion optionnelle des parts des autres crews
    if gained and Config.ErosionFactor and Config.ErosionFactor > 0 then
        local z = shares[zoneId]
        for cid, s in pairs(z) do
            if cid ~= crew.id then
                Territories.setShare(zoneId, cid, s - Config.SharePerSale * Config.ErosionFactor)
            end
        end
    end

    local ctrlAfter = Territories.controllerOf(zoneId)

    -- Multiplicateur : contrôleur → ControlMultiplier, sinon multiplicateur de base
    local mult = baseMult
    if ctrlAfter == crew.id and newShare >= Config.ControlThreshold then
        mult = Config.ControlMultiplier
    end

    -- Debug notification : part enregistrée
    if Config.Debug then
        Territories.Notify(src,
            gained and L('debug_share_saved') or L('debug_share_cooldown'),
            L('debug_share_line', zoneId, crew.name, newShare,
                ctrlAfter == crew.id and L('debug_control_yes') or L('debug_control_no')),
            'fas fa-chart-pie', 6000)
    end

    -- Prise de contrôle (ce crew vient de passer au-dessus du seuil)
    if ctrlAfter == crew.id and ctrlBefore ~= crew.id then
        Territories.notifyCrew(crew.id, L('territory_title'),
            L('crew_took_control', Territories.zoneLabel(zoneId, zoneData)), 'success')
    end

    -- Déclenchement de guerre : un rival pousse sa part au-dessus du seuil
    -- dans une zone contrôlée par un AUTRE crew
    if ctrlBefore and ctrlBefore ~= crew.id
       and newShare >= Config.WarThreshold and not warState[zoneId] then
        Territories.startWar(zoneId, crew.id, ctrlBefore, zoneData)
    end

    -- Synchro clients : contrôle de la zone (survol carte) + progression du crew (loadbar)
    TriggerClientEvent('pop_territories:client:drugSold', src)
    if gained then
        Territories.syncZoneControl(zoneId)
        Territories.pushCrewProgress(crew.id, zoneId, newShare)
    end

    local finalAmount = math.floor(baseAmount * mult + 0.5)
    return finalAmount, { zone = zoneId, mult = mult, share = newShare, crew = crew.id }
end)
