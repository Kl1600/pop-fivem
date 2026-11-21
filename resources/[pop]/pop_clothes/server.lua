local ESX = exports['es_extended']:getSharedObject()

local tattooListRaw = nil

-- Tatouages autorisés : "collection|hash" lus dans tattoos.json (refuse les tatouages hors liste).
local AllowedTattoos = {}

CreateThread(function()
    tattooListRaw = LoadResourceFile(GetCurrentResourceName(), "tattoos.json")
    if not tattooListRaw then
        print("^1[pop_clothes] Error: Failed to load tattoos.json on the server!^0")
        return
    end
    local ok, list = pcall(json.decode, tattooListRaw)
    if ok and type(list) == 'table' then
        for _, zoneList in pairs(list) do
            for _, t in ipairs(zoneList) do
                if t.collection then
                    if t.hashMale and t.hashMale ~= '' then AllowedTattoos[t.collection .. '|' .. t.hashMale] = true end
                    if t.hashFemale and t.hashFemale ~= '' then AllowedTattoos[t.collection .. '|' .. t.hashFemale] = true end
                end
            end
        end
    end
end)

RegisterNetEvent('clothes:requestTattooList')
AddEventHandler('clothes:requestTattooList', function()
    local src = source
    if tattooListRaw then
        TriggerClientEvent('clothes:setTattooList', src, tattooListRaw)
    end
end)

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
local SHOP_TYPES = { clothing = true, barber = true, tattoo = true }
local function isNearShop(src, shopType)
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
local function toInt(v, min, max)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if v < min or v > max then return nil end
    return v
end

local function chargePlayer(src, totalCost)
    if totalCost <= 0 then return true, 'free', 0 end
    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(totalCost * (tvaRate / 100))
    local finalCost = totalCost + taxAmount

    local cashCount = exports.pop_inventory:getItemCount(src, 'cash') or 0
    if cashCount >= finalCost then
        local success = exports.pop_inventory:removeItem(src, 'cash', finalCost) == true
        if success then payTax(taxAmount) end
        return success, 'cash', finalCost
    end

    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    local bank = xPlayer and xPlayer.getAccount('bank')
    if bank and bank.money >= finalCost then
        xPlayer.removeAccountMoney('bank', finalCost, 'pop_clothes')
        payTax(taxAmount)
        return true, 'bank', finalCost
    end
    return false, nil, 0
end

RegisterNetEvent('clothes:buy_all')
AddEventHandler('clothes:buy_all', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local cart = type(data.cart) == 'table' and data.cart or {}
    local shopType = data.type or 'clothing'
    if not SHOP_TYPES[shopType] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    for category, selection in pairs(cart) do
        if type(selection) ~= 'table' or type(category) ~= 'string' then return end
        -- Valeurs typées : index de -1 à 2000, texture de 0 à 255
        local index = toInt(selection.index, -1, 2000)
        if not index then return end
        selection.index = index
        selection.texture = toInt(selection.texture or 0, 0, 255) or 0
        if shopType == 'tattoo' and index ~= -1 then
            if type(selection.collection) ~= 'string' or type(selection.hash) ~= 'string'
                or not AllowedTattoos[selection.collection .. '|' .. selection.hash] then
                return
            end
        end
    end

    local isCreatorMode = CreatorModePlayers[src] == true
    -- Achat seulement près d'un magasin (sauf dans le créateur de personnage)
    if not isCreatorMode and not isNearShop(src, shopType) then return end
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

    local success, method, finalCost = chargePlayer(src, totalCost)
    if not success then
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title = "Boutique",
            message = "Pas assez d'argent.",
            image = "nui://pop_management/html/Trevor.png",
            duration = 5000
        })
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

    local msg = "Achat effectué — <span style=\"color:#e74c3c; font-weight:bold;\">-" .. finalCost .. "$</span>."
    if method == 'bank' then
        msg = "Achat payé par carte — <span style=\"color:#e74c3c; font-weight:bold;\">-" .. finalCost .. "$</span>."
    elseif method == 'free' then
        msg = "Achat effectué (Gratuit)."
    end

    TriggerClientEvent('clothes:purchaseSuccess', src, shopType)
    TriggerClientEvent('notification:client:ShowNotify', src, {
        title = "Boutique",
        message = msg,
        image = "nui://pop_management/html/Trevor.png",
        duration = 5000
    })
end)


RegisterNetEvent('clothes:requestTattoos')
AddEventHandler('clothes:requestTattoos', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local memTattoos = xPlayer.get('tattoos')
    if memTattoos then
        TriggerClientEvent('clothes:applyTattoos', src, memTattoos)
    else
        if MySQL then
            MySQL.query('SELECT tattoos FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
                local tattoos = {}
                if result and result[1] and result[1].tattoos then
                    tattoos = json.decode(result[1].tattoos) or {}
                end
                xPlayer.set('tattoos', tattoos)
                TriggerClientEvent('clothes:applyTattoos', src, tattoos)
            end)
        else
            xPlayer.set('tattoos', {})
            TriggerClientEvent('clothes:applyTattoos', src, {})
        end
    end
end)

RegisterNetEvent('clothes:clearTattoos')
AddEventHandler('clothes:clearTattoos', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    xPlayer.set('tattoos', {})
    MySQL.update('UPDATE users SET tattoos = ? WHERE identifier = ?', { '[]', xPlayer.identifier })
    TriggerClientEvent('clothes:applyTattoos', src, {})
end)

CreateThread(function()
    while not MySQL do Wait(500) end
    MySQL.query('SHOW COLUMNS FROM users LIKE "tattoos"', {}, function(result)
        if not result or #result == 0 then
            MySQL.query('ALTER TABLE users ADD COLUMN tattoos LONGTEXT NULL')
            print('^2[pop_clothes] Added tattoos column to users table.^0')
        end
    end)
end)
