-- Fonctions communes du serveur pop_clothes (chargé en premier, voir fxmanifest).

Clothes = {}

-- ESX direct : variables joueur ('tattoos'), identifier. À passer par le bridge au moment du multi-framework.
Clothes.ESX = exports['es_extended']:getSharedObject()

-- Tatouages autorisés : "collection|hash" lus dans tattoos.json (refuse les tatouages hors liste).
Clothes.AllowedTattoos = {}

--- Notification au style d'origine (titre « Boutique » + image).
function Clothes.Notify(src, message)
    Bridge.Notify(src, {
        title = L('shop_title'),
        message = message,
        image = Config.NotifyImage,
        duration = Config.NotifyDuration
    })
end

local function payTax(taxAmount)
    if taxAmount <= 0 then return end
    local accountUsName = Config.GouvUSAccount or 'society_gouv'
    -- Sans esx_addonaccount, l'event n'a pas de réponse : écriture directe en base.
    if GetResourceState('esx_addonaccount') ~= 'started' then
        MySQL.update('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', { taxAmount, accountUsName })
        return
    end
    TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
        if gouvAccount then
            gouvAccount.addMoney(taxAmount)
        else
            MySQL.update('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', { taxAmount, accountUsName })
        end
    end)
end

-- Paiement en dollars : d'abord le cash (item de l'inventaire), sinon le compte bancaire.
-- Le joueur doit être près d'un magasin du bon type (ou de son point de téléportation).
Clothes.SHOP_TYPES = { clothing = true, barber = true, tattoo = true }

function Clothes.IsNearShop(src, shopType)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, shop in ipairs(Config.Shops or {}) do
        if shop.type == shopType then
            if #(pos - shop.coords) < 15.0 then return true end
            if shop.pedCoords and #(pos - shop.pedCoords) < 15.0 then return true end
        end
    end
    return false
end

-- Valeur entière bornée venant du client (nil si invalide).
function Clothes.ToInt(v, min, max)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if v < min or v > max then return nil end
    return v
end

-- Cash = objet 'cash' de pop_inventory (via le bridge), banque = compte ESX 'bank'.
-- method 'cash' ou 'bank' : choisi par le joueur dans le magasin ; sinon cash puis banque.
function Clothes.ChargePlayer(src, totalCost, method)
    if totalCost <= 0 then return true, 'free', 0 end
    if method ~= 'cash' and method ~= 'bank' then method = nil end
    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(totalCost * (tvaRate / 100))
    local finalCost = totalCost + taxAmount

    if method ~= 'bank' and Bridge.GetMoney(src, 'cash') >= finalCost then
        local success = Bridge.RemoveMoney(src, 'cash', finalCost, 'pop_clothes')
        if success then payTax(taxAmount) end
        return success, 'cash', finalCost
    end

    if method ~= 'cash' and Bridge.GetMoney(src, 'bank') >= finalCost then
        Bridge.RemoveMoney(src, 'bank', finalCost, 'pop_clothes')
        payTax(taxAmount)
        return true, 'bank', finalCost
    end
    return false, method, 0
end
