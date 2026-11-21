-- pop_management : offre reçue (recrutement ou facture), touches [E] accepter / [X] refuser.
-- La boucle Wait(0) n'existe que pendant qu'une offre est affichée (Config.OfferTimeout max).

Offer = {}

local current = nil -- offre affichée

function Offer.IsShown()
    return current ~= nil
end

-- Masque l'offre (seulement celle-ci si un id est donné).
local function hide(id)
    if not current or (id ~= nil and current.id ~= id) then return end
    current = nil
    SendNUIMessage({ action = 'pop_management:offer', show = false })
end

local function answer(offer, accept)
    hide(offer.id)
    local ok, reason, arg = Callback.Await('pop_management:answerOffer', offer.id, accept)
    if ok == true then return end
    if type(reason) ~= 'string' then reason = 'error' end
    if arg ~= nil then
        Bridge.Notify(L(reason, arg), 'error')
    else
        Bridge.Notify(L(reason), 'error')
    end
end

RegisterNetEvent('pop_management:client:offer', function(offer)
    if current or type(offer) ~= 'table' or type(offer.id) ~= 'number' then return end
    if offer.kind ~= 'invoice' and offer.kind ~= 'recruit' then return end

    local timeout = tonumber(offer.timeout) or Config.OfferTimeout
    timeout = math.max(1, math.min(timeout, 120))
    current = offer

    SendNUIMessage({
        action = 'pop_management:offer', show = true,
        kind = offer.kind, society = offer.society,
        amount = offer.amount, note = offer.note, gradeLabel = offer.gradeLabel,
        timeout = timeout,
        acceptKey = Config.Keys.Interact.label, refuseKey = Config.Keys.Cancel.label,
    })

    CreateThread(function()
        local deadline = GetGameTimer() + timeout * 1000
        local acceptKey, refuseKey = Config.Keys.Interact.control, Config.Keys.Cancel.control
        while current == offer and GetGameTimer() < deadline do
            DisableControlAction(0, acceptKey, true)
            DisableControlAction(0, refuseKey, true)
            if not IsNuiFocused() and not IsPauseMenuActive() then
                if IsDisabledControlJustReleased(0, acceptKey) then
                    return answer(offer, true)
                elseif IsDisabledControlJustReleased(0, refuseKey) then
                    return answer(offer, false)
                end
            end
            Wait(0)
        end
        if current == offer then hide() end
    end)
end)

RegisterNetEvent('pop_management:client:offerClosed', function(offerId)
    hide(offerId)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hide()
end)
