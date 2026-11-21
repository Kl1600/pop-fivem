-- ESX is now handled by imports.lua

-- Sécurité : un personnage déjà créé ne peut pas être réécrit par le client.
-- adminReopen[src] = true uniquement si un admin a ouvert le créateur (/charcreator).
local adminReopen = {}
local saving = {}
local inCreatorInstance = {}

local function cleanText(value, maxLen)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maxLen)
end

RegisterNetEvent('vanguard_charcreator:save', function(skin, firstname, lastname, dateofbirth, spawnLocation, chosenClothes)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or saving[src] then return end
    if type(skin) ~= 'table' then return end
    if chosenClothes ~= nil and type(chosenClothes) ~= 'table' then return end

    saving[src] = true
    local row = MySQL.single.await('SELECT firstname FROM users WHERE identifier = ?', { xPlayer.identifier })
    local alreadyCreated = row and row.firstname and row.firstname ~= ''
    if alreadyCreated and not adminReopen[src] then
        saving[src] = nil
        return
    end
    local isReedit = alreadyCreated
    adminReopen[src] = nil

    if not (Config.SpawnPoints and Config.SpawnPoints[spawnLocation]) then
        spawnLocation = Config.DefaultSpawn
    end

    local fn = cleanText(firstname, 30) or "John"
    local ln = cleanText(lastname, 30) or "Doe"
    local dob = cleanText(dateofbirth, 10) or "01/01/1990"

    -- Identité visible sur la carte d'identité, dérivée du skin créé.
    local sex = (skin and skin.sex == 1) and "f" or "m"
    local height = (skin and tonumber(skin.height)) or 100

    -- Instantly update ESX Memory Cache so other scripts (like HUDs) see the new name
    xPlayer.set('firstName', fn)
    xPlayer.set('lastName', ln)

    local fullName = string.format('%s %s', fn, ln)
    if xPlayer.setName then
        xPlayer.setName(fullName)
    end
    -- Some older ESX versions use these exact string cases:
    xPlayer.set('firstname', fn)
    xPlayer.set('lastname', ln)
    xPlayer.set('dateofbirth', dob)
    xPlayer.set('sex', sex)
    xPlayer.set('height', height)

    -- 1. Asynchronously save skin, name and identity (dateofbirth/sex/height)
    MySQL.update('UPDATE users SET skin = ?, firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ? WHERE identifier = ?', {
        json.encode(skin), fn, ln, dob, sex, height, xPlayer.identifier
    })

    -- Réédition admin : on met seulement à jour l'apparence/identité, sans redonner le kit.
    if isReedit then
        saving[src] = nil
        inCreatorInstance[src] = nil
        TriggerClientEvent('vanguard_charcreator:client:finishSuccess', src)
        SetPlayerRoutingBucket(src, 0)
        return
    end

    -- 2. CLEAR INVENTORY COMPLETELY
    exports['pop_inventory']:ClearPlayerStore(src)

    -- 3. Vêtements de départ = la tenue choisie dans le créateur (haut/pantalon/
    -- chaussures). Repli sur des valeurs par défaut si une pièce n'a pas été
    -- envoyée (pour éviter un perso invisible).
    local cc = chosenClothes or {}
    local isMale = (skin and skin.sex == 0)

    local function comp(drawable, texture, fallback)
        return { drawable = tonumber(drawable) or fallback, texture = tonumber(texture) or 0, palette = 0 }
    end

    -- prop : drawable -1 = aucun (ex. pas de casquette) -> on laisse tel quel.
    local function prop(drawable, texture)
        return { drawable = tonumber(drawable) or -1, texture = tonumber(texture) or 0 }
    end

    -- Le haut porte aussi les accessoires/props et les composants annexes choisis
    -- (masque, gilet, chaîne, sac, décalques, casquette, lunettes…) pour que tout
    -- le look du joueur soit conservé au spawn.
    local hoddieMeta = { components = {
        ["11"] = comp(cc.torso_1,  cc.torso_2,  isMale and 12 or 5),
        ["8"]  = comp(cc.tshirt_1, cc.tshirt_2, 15),
        ["3"]  = comp(cc.arms,     cc.arms_2,   15),
        ["1"]  = comp(cc.mask_1,   cc.mask_2,   0),
        ["9"]  = comp(cc.bproof_1, cc.bproof_2, 0),
        ["7"]  = comp(cc.chain_1,  cc.chain_2,  0),
        ["5"]  = comp(cc.bags_1,   cc.bags_2,   0),
        ["10"] = comp(cc.decals_1, cc.decals_2, 0),
    }, props = {
        ["0"] = prop(cc.helmet_1,  cc.helmet_2),
        ["1"] = prop(cc.glasses_1, cc.glasses_2),
        ["2"] = prop(cc.ears_1,    cc.ears_2),
    } }
    local pantaMeta = { components = {
        ["4"] = comp(cc.pants_1, cc.pants_2, isMale and 1 or 5),
    } }
    local shoesMeta = { components = {
        ["6"] = comp(cc.shoes_1, cc.shoes_2, 1),
    } }

    -- 4. Give Clothes
    exports['pop_inventory']:GiveAndEquip(src, 'hoddie', 1, hoddieMeta)
    exports['pop_inventory']:GiveAndEquip(src, 'panta', 1, pantaMeta)
    exports['pop_inventory']:GiveAndEquip(src, 'shoes', 1, shoesMeta)

    -- 5. Give Wallet
    local okWallet, walletContainerId = exports['pop_inventory']:GiveAndEquip(src, 'wallet', 1)
    
    -- 6. Give Cash/Pesos, ID Card and Passport
    local isMexico = (spawnLocation == 'nuevopaso')
    local currencyItem = isMexico and 'pesos' or 'cash'
    local currencyAmount = 500
    local passportType = isMexico and 'mx' or 'us'
    local identityData = { firstname = fn, lastname = ln, dob = dob, skin = json.encode(skin), nationality = spawnLocation }

    if okWallet and walletContainerId then
        exports['pop_inventory']:addItemToContainer(src, walletContainerId, currencyItem, currencyAmount)
        TriggerEvent('pop_idcard:server:issueCardInternal', src, walletContainerId, identityData)
        TriggerEvent('pop_passport:server:issueInternal', src, passportType, walletContainerId, identityData)
    else
        exports['pop_inventory']:GiveItem(src, currencyItem, currencyAmount)
        TriggerEvent('pop_idcard:server:issueCardInternal', src, nil, identityData)
        TriggerEvent('pop_passport:server:issueInternal', src, passportType, nil, identityData)
    end

    -- 7. Kit de départ (poches) : hotdog + bouteille d'eau.
    -- Donné ici car l'étape 2 (ClearPlayerStore) efface le kit posé par esx:playerLoaded.
    exports['pop_inventory']:GiveItem(src, 'hotdog', 1)
    exports['pop_inventory']:GiveItem(src, 'bouteille', 1)

    TriggerClientEvent('vanguard_charcreator:client:finishSuccess', src)
    TriggerClientEvent('esx:showNotification', src, 'Apparence validée ! Heureux de vous revoir '..fn..' !')
    
    -- Retour au monde normal (Bucket 0)
    saving[src] = nil
    inCreatorInstance[src] = nil
    SetPlayerRoutingBucket(src, 0)
end)

RegisterNetEvent('vanguard_charcreator:server:enterInstance', function()
    local src = source
    -- Uniquement depuis le monde normal (évite de sortir d'une autre instance : prison, etc.)
    if GetPlayerRoutingBucket(src) ~= 0 then return end
    inCreatorInstance[src] = true
    -- On place le joueur dans un bucket unique basé sur son ID source (+1000 pour éviter les conflits)
    SetPlayerRoutingBucket(src, src + 1000)
end)

RegisterNetEvent('vanguard_charcreator:server:exitInstance', function()
    local src = source
    if not inCreatorInstance[src] then return end
    inCreatorInstance[src] = nil
    SetPlayerRoutingBucket(src, 0)
end)

AddEventHandler('playerDropped', function()
    local src = source
    adminReopen[src], saving[src], inCreatorInstance[src] = nil, nil, nil
end)

-- Commande admin : ouvrir le créateur (autorise une réédition du personnage)
ESX.RegisterCommand('charcreator', 'admin', function(xPlayer, args, showError)
    adminReopen[xPlayer.source] = true
    xPlayer.triggerEvent('vanguard_charcreator:open')
end, false, {help = 'Ouvrir le créateur de personnage'})
