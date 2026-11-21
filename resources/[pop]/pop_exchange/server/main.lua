local ESX = exports['es_extended']:getSharedObject()

local INV = exports['pop_inventory']

local function getCount(source, item)
    return INV:getItemCount(source, item) or 0
end

-- Récupérer les soldes du joueur en cash et pesos
ESX.RegisterServerCallback('pop_exchange:getPlayerBalances', function(source, cb)
    cb(getCount(source, 'cash'), getCount(source, 'pesos'))
end)

-- Anti-abus : l'échange n'est accepté qu'à proximité d'un bureau de change.
local function isNearExchange(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for i = 1, #Config.Locations do
        if #(pos - Config.Locations[i].coords) < 10.0 then return true end
    end
    return false
end

-- Traiter l'échange de monnaie
ESX.RegisterServerCallback('pop_exchange:processExchange', function(source, cb, fromCurrency, amount)
    if not isNearExchange(source) then
        cb(false, Config.Translate.exchange_failed)
        return
    end
    amount = tonumber(amount) or 0
    if amount ~= amount or amount >= 1e9 then amount = 0 end
    amount = math.floor(amount)
    if amount <= 0 then
        cb(false, Config.Translate.invalid_amount)
        return
    end

    if fromCurrency == 'usd' then
        -- Vente de USD, achat de Pesos
        if getCount(source, 'cash') < amount then
            cb(false, Config.Translate.not_enough_money)
            return
        end

        local payout = math.floor(amount * Config.Rates.UsdToPesos)
        if payout <= 0 then
            cb(false, "Le montant converti est trop faible.")
            return
        end

        if not INV:removeItem(source, 'cash', amount) then
            cb(false, Config.Translate.not_enough_money)
            return
        end
        INV:GiveItem(source, 'pesos', payout)

        cb(true, nil, {cash = getCount(source, 'cash'), pesos = getCount(source, 'pesos')})
    elseif fromCurrency == 'pesos' then
        -- Vente de Pesos, achat de USD
        if getCount(source, 'pesos') < amount then
            cb(false, Config.Translate.not_enough_money)
            return
        end

        local payout = math.floor(amount * Config.Rates.PesosToUsd)
        if payout <= 0 then
            cb(false, "Le montant converti est trop faible pour obtenir au moins 1$.")
            return
        end

        if not INV:removeItem(source, 'pesos', amount) then
            cb(false, Config.Translate.not_enough_money)
            return
        end
        INV:GiveItem(source, 'cash', payout)

        cb(true, nil, {cash = getCount(source, 'cash'), pesos = getCount(source, 'pesos')})
    else
        cb(false, "Type d'échange inconnu.")
    end
end)
