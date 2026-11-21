-- ─────────────────────────────────────────────
-- pop_dealing - négociation : claim, proposition, refus
-- ─────────────────────────────────────────────

local customers      = Dealing.customers
local sellingPlayers = Dealing.sellingPlayers

-- ─────────────────────────────────────────────
-- Le joueur "approche" le client (verrouille pour éviter race)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:claim', function(customerId)
    local src = source
    local c   = customers[customerId]
    if Config.Debug then print(('[pop_dealing] claim src=%d id=%s c=%s'):format(src, tostring(customerId), tostring(c ~= nil))) end
    if not c then return end
    if not Dealing.isNearCustomer(src, c) then return end
    if c.claimedBy and c.claimedBy ~= src then
        Dealing.Notify(src, {
            icon = 'fas fa-circle-exclamation', message = L('customer_busy'), duration = Config.NotifyDurations.short,
        })
        return
    end
    c.claimedBy = src
    TriggerClientEvent('pop_dealing:offerDetails', src, {
        id           = c.id,
        drugDefId    = c.drugDefId,
        drugLabel    = c.drugLabel,
        drugIcon     = c.drugIcon,
        qty          = c.qty,
        hintUnit     = c.hintUnit,
        hintTotal    = c.hintUnit * c.qty,
        attemptsLeft = c.attemptsLeft,
        maxAttempts  = Config.MaxAttempts or 3,
    })
end)

RegisterNetEvent('pop_dealing:unclaim', function(customerId)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    if c.claimedBy == src then c.claimedBy = nil end
end)

-- ─────────────────────────────────────────────
-- Proposition (le joueur envoie son prix par unité)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:propose', function(customerId, proposedUnit)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    if c.claimedBy ~= src then return end
    if not Dealing.isNearCustomer(src, c) then return end

    proposedUnit = math.floor(tonumber(proposedUnit) or 0)
    if proposedUnit <= 0 then return end

    -- Vérif stock
    local have = Bridge.GetItemCount(src, c.drugDefId)
    if have < c.qty then
        Dealing.Notify(src, {
            icon = 'fas fa-circle-exclamation',
            message = L('not_enough_drug', c.drugLabel, have, c.qty),
            duration = Config.NotifyDurations.short,
        })
        c.claimedBy = nil
        TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
        return
    end

    -- Si flic infiltré → bust uniquement si le deal est accepté (sinon il joue le jeu)
    if proposedUnit <= c.maxUnit then
        if c.isCop then
            TriggerClientEvent('pop_dealing:bust', src, Dealing.publicData(c))
            -- Alerte envoyée uniquement à la police
            local alert = {
                coords = vec3(c.x, c.y, c.z),
                radius = Config.BustAlertRadius,
                label  = L('alert_label', Dealing.placeLabel(c)),
            }
            for _, copSrc in ipairs(Dealing.getPoliceSources()) do
                TriggerClientEvent('pop_dealing:dispatchAlert', copSrc, alert)
            end
            Dealing.removeCustomer(customerId)
            return
        end

        -- Échange
        local totalPrice = proposedUnit * c.qty
        local ok = Bridge.RemoveItem(src, c.drugDefId, c.qty)
        if not ok then
            c.claimedBy = nil
            TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
            return
        end

        -- Guerre de territoires : applique le multiplicateur de la zone + enregistre la vente
        local okT, finalPrice = pcall(function()
            return exports.pop_territories:recordDrugSale(src, totalPrice)
        end)
        if okT and finalPrice then
            totalPrice = finalPrice
        end

        -- Paiement en objet cash (pop_inventory, Config.CashItem), pas le compte ESX money
        local paid = Bridge.AddMoney(src, 'cash', totalPrice)
        if not paid then
            -- Inventaire plein : on rend la marchandise
            Bridge.AddItem(src, c.drugDefId, c.qty)
            c.claimedBy = nil
            Dealing.Notify(src, {
                icon = 'fas fa-circle-exclamation', message = L('deal_inventory_full'), duration = Config.NotifyDurations.short,
            })
            TriggerClientEvent('pop_dealing:proposeResult', src, { id = c.id, status = 'cancel' })
            return
        end

        TriggerClientEvent('pop_dealing:proposeResult', src, {
            id          = c.id,
            status      = 'accept',
            unitPrice   = proposedUnit,
            totalPrice  = totalPrice,
        })
        TriggerClientEvent('pop_dealing:dealComplete', src, {
            drugLabel  = c.drugLabel,
            qty        = c.qty,
            totalPrice = totalPrice,
        })
        Dealing.removeCustomer(customerId)

        -- Plus de drogue après cette vente → on coupe le mode vente
        if sellingPlayers[src] and not Dealing.hasSellableDrug(src) then
            Dealing.stopSelling(src, L('selling_last_sold'))
        end
        return
    end

    -- Refus : décrémenter les tentatives
    c.attemptsLeft = c.attemptsLeft - 1

    if c.attemptsLeft <= 0 then
        -- Le client en a marre, il s'en va
        TriggerClientEvent('pop_dealing:proposeResult', src, {
            id     = c.id,
            status = 'walkaway',
        })
        Dealing.removeCustomer(customerId)
        return
    end

    -- Indice : trop cher (haut) ; on pourrait raffiner pour donner un hint
    local hintDir = 'too_high'
    TriggerClientEvent('pop_dealing:proposeResult', src, {
        id           = c.id,
        status       = 'refuse',
        hintDir      = hintDir,
        attemptsLeft = c.attemptsLeft,
    })
end)

-- ─────────────────────────────────────────────
-- Refus du deal
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:refuse', function(customerId)
    local src = source
    local c   = customers[customerId]
    if not c then return end
    -- Claimé par ce joueur, ou client libre (timeout d'approche) à proximité de lui
    if c.claimedBy ~= src and (c.claimedBy ~= nil or not Dealing.isNearCustomer(src, c)) then return end
    -- Le client s'en va, vexé
    Dealing.removeCustomer(customerId)
end)
