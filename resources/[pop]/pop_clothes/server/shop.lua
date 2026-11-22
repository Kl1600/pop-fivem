-- Achat du panier (vêtements en objets pop_inventory, barbier, tatouages) et mode créateur.

-- Marqueurs serveur "mode créateur" pour offrir les tatouages gratuitement
-- pendant la création de personnage (et empêcher un spoof depuis un vrai shop).
local CreatorModePlayers = {}

RegisterNetEvent('pop_clothes:server:setCreatorMode', function(enabled)
    local src = source
    -- Sécurité : le mode créateur n'est accepté que si le joueur est dans
    -- l'instance du créateur de personnage (bucket src + 1000, cf. pop_charcreator).
    if enabled and GetPlayerRoutingBucket(src) ~= src + 1000 then return end
    CreatorModePlayers[src] = enabled and true or nil
end)

AddEventHandler('playerDropped', function()
    CreatorModePlayers[source] = nil
end)

local ItemMap = {
    ['Hats'] = 'hat', ['Masks'] = 'mask', ['Ears'] = 'ears', ['Glasses'] = 'glasses',
    ['Torsos'] = 'tshirt', ['Legs'] = 'panta', ['Bags'] = 'backpack', ['Shoes'] = 'shoes',
    ['Accessories'] = 'accessory', ['Undershirts'] = 'tshirt', ['Body Armors'] = 'kevlar',
    ['Tops'] = 'hoddie', ['Watches'] = 'watch', ['Bracelets'] = 'bracelet', ['Decals'] = 'decal'
}

RegisterNetEvent('clothes:buy_all')
AddEventHandler('clothes:buy_all', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local cart = type(data.cart) == 'table' and data.cart or {}
    local shopType = data.type or 'clothing'
    if not Clothes.SHOP_TYPES[shopType] then return end
    local xPlayer = Clothes.ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    for category, selection in pairs(cart) do
        if type(selection) ~= 'table' or type(category) ~= 'string' then return end
        -- Valeurs typées : index de -1 à 2000, texture de 0 à 255
        local index = Clothes.ToInt(selection.index, -1, 2000)
        if not index then return end
        selection.index = index
        selection.texture = Clothes.ToInt(selection.texture or 0, 0, 255) or 0
        if shopType == 'tattoo' and index ~= -1 then
            if type(selection.collection) ~= 'string' or type(selection.hash) ~= 'string'
                or not Clothes.AllowedTattoos[selection.collection .. '|' .. selection.hash] then
                return
            end
        end
    end

    local isCreatorMode = CreatorModePlayers[src] == true
    -- Achat seulement près d'un magasin (sauf dans le créateur de personnage)
    if not isCreatorMode and not Clothes.IsNearShop(src, shopType) then return end
    local totalCost = 0
    for category, selection in pairs(cart) do
        if tonumber(selection.index) ~= -1 then
            totalCost = totalCost + (Config.Prices[category] or Config.Prices['default'] or 50)
        end
    end

    -- En mode créateur, on offre les tatouages (le joueur n'a pas encore d'argent).
    if isCreatorMode and shopType == 'tattoo' then
        totalCost = 0
    end

    local success, method, finalCost = Clothes.ChargePlayer(src, totalCost, data.currency)
    if not success then
        Clothes.Notify(src, L(method == 'cash' and 'shop_no_money_cash' or method == 'bank' and 'shop_no_money_bank' or 'shop_no_money'))
        return
    end

    if shopType == 'clothing' then
        for category, selection in pairs(cart) do
            if tonumber(selection.index) ~= -1 then
                local defId = ItemMap[category]
                local compInfo = Config.Components[category]
                if defId and compInfo then
                    local meta = { components = {}, props = {} }
                    if compInfo.type == 'clothing' then
                        meta.components[tostring(compInfo.component)] = {
                            drawable = selection.index, texture = selection.texture or 0, palette = 0
                        }
                    else
                        meta.props[tostring(compInfo.component)] = {
                            drawable = selection.index, texture = selection.texture or 0
                        }
                    end
                    -- pop_inventory direct : objet vêtement porté aussitôt (hors bridge).
                    exports.pop_inventory:GiveAndEquip(src, defId, 1, meta)
                end
            end
        end
    elseif shopType == 'tattoo' then
        local newTattoos = {}
        for zone, selection in pairs(cart) do
            if selection.collection and selection.hash then
                newTattoos[#newTattoos + 1] = {
                    zone = zone,
                    collection = selection.collection,
                    hash = selection.hash,
                }
            end
        end

        local existing = xPlayer.get('tattoos') or {}
        local merged = {}
        local replacedZones = {}
        for _, t in ipairs(newTattoos) do
            merged[#merged + 1] = t
            replacedZones[t.zone] = true
        end
        for _, t in ipairs(existing) do
            if not replacedZones[t.zone] then
                merged[#merged + 1] = t
            end
        end
        xPlayer.set('tattoos', merged)

        if MySQL then
            MySQL.update('UPDATE users SET tattoos = ? WHERE identifier = ?', {
                json.encode(merged),
                xPlayer.identifier
            })
        end
    end

    local msg = L('purchase_cash', finalCost)
    if method == 'bank' then
        msg = L('purchase_bank', finalCost)
    elseif method == 'free' then
        msg = L('purchase_free')
    end

    TriggerClientEvent('clothes:purchaseSuccess', src, shopType)
    Clothes.Notify(src, msg)
end)
