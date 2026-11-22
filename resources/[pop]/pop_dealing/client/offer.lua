-- ─────────────────────────────────────────────
-- pop_dealing - menu d'offre (NUI) et résultats serveur
-- ─────────────────────────────────────────────

local notify = Dealing.notify

function Dealing.closeUi()
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
    Dealing.stopDealCam()
end

function Dealing.openUi(offer)
    -- Ferme l'inventaire si ouvert (on vient d'y glisser la weed)
    TriggerEvent('pop_inventory:client:forceClose')

    SendNUIMessage({
        action = 'show',
        offer  = {
            id           = offer.id,
            label        = offer.drugLabel,
            icon         = offer.drugIcon or 'fas fa-cannabis',
            qty          = offer.qty,
            hintUnit     = offer.hintUnit,
            attemptsLeft = offer.attemptsLeft,
            maxAttempts  = offer.maxAttempts,
        },
    })
    SetNuiFocus(true, true)

    local entry = Dealing.customers[offer.id]
    if entry and DoesEntityExist(entry.ped) then
        Dealing.startDealCam(entry.ped)
    end
end

RegisterNetEvent('pop_dealing:offerDetails', function(offer)
    if Config.Debug then
        print(('[pop_dealing] offerDetails id=%s drug=%s qty=%s hint=%s attempts=%s/%s'):format(
            tostring(offer.id), tostring(offer.drugLabel), tostring(offer.qty),
            tostring(offer.hintUnit), tostring(offer.attemptsLeft), tostring(offer.maxAttempts)))
    end
    Dealing.currentOffer = offer
    local entry  = Dealing.customers[offer.id]
    if entry then entry.state = Dealing.STATE_NEGO end
    Dealing.openUi(offer)
end)

RegisterNUICallback('propose', function(data, cb)
    local currentOffer = Dealing.currentOffer
    if currentOffer and currentOffer.id == data.id then
        TriggerServerEvent('pop_dealing:propose', data.id, data.unitPrice)
    end
    cb({ ok = true })
end)

RegisterNUICallback('refuse', function(data, cb)
    local currentOffer = Dealing.currentOffer
    if currentOffer and currentOffer.id == data.id then
        TriggerServerEvent('pop_dealing:refuse', data.id)
    end
    Dealing.closeUi()
    Dealing.currentOffer = nil
    cb({ ok = true })
end)

-- Résultat du serveur après une proposition
RegisterNetEvent('pop_dealing:proposeResult', function(data)
    SendNUIMessage({ action = 'result', status = data.status, hintDir = data.hintDir,
                     attemptsLeft = data.attemptsLeft, unitPrice = data.unitPrice, totalPrice = data.totalPrice })
    if data.status == 'accept' or data.status == 'walkaway' or data.status == 'cancel' then
        SetTimeout(900, function()
            if Dealing.currentOffer and Dealing.currentOffer.id == data.id then Dealing.currentOffer = nil end
            Dealing.closeUi()
        end)
    end
end)

-- ─────────────────────────────────────────────
-- Résultats serveur
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:dealComplete', function(data)
    notify({
        title    = L('deal_done_title'),
        message  = L('deal_done_message', data.qty, data.drugLabel, data.totalPrice),
        icon     = 'fas fa-money-bill-wave',
        badge    = '+$' .. data.totalPrice,
        badgeColor = '#3aa856',
        duration = Config.NotifyDurations.deal,
    })

    -- Petite anim de remerciement
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 4.0, -4.0, 1500, 49, 0, false, false, false)
end)

RegisterNetEvent('pop_dealing:bust', function()
    notify({
        title      = L('bust_title'),
        message    = L('bust_message'),
        icon       = 'fas fa-handcuffs',
        badge      = L('bust_badge'),
        badgeColor = '#e74c3c',
        duration   = Config.NotifyDurations.bust,
    })
    Dealing.currentOffer = nil
    Dealing.closeUi()
end)

RegisterNetEvent('pop_dealing:dispatchAlert', function(data)
    -- À brancher sur ton script de dispatch police ; pour l'instant juste un log local
    local pc = GetEntityCoords(cache.ped)
    if #(pc - data.coords) <= data.radius then
        notify({
            title    = L('alert_title'),
            message  = data.label,
            icon     = 'fas fa-walkie-talkie',
            badge    = L('alert_badge'),
            badgeColor = '#3498db',
            duration = Config.NotifyDurations.alert,
        })
    end
end)

-- Notifications envoyées par le serveur (aussi écouté par pop_territories : checklist)
RegisterNetEvent('pop_dealing:notify', notify)
