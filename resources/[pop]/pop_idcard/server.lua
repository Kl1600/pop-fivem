-- ID Card Server Script
local ESX = exports['es_extended']:getSharedObject()

-- SQL Helper
local function dbQuery(query, params, cb)
    if MySQL then
        MySQL.query(query, params, cb)
    elseif exports.oxmysql then
        exports.oxmysql:query(query, params, cb)
    else
        print('^1[pop_idcard] MySQL/oxmysql introuvable^7')
    end
end

local function issueCard(targetId, containerId, customData)
    local xPlayer = ESX.GetPlayerFromId(targetId)
    if not xPlayer then 
        return 
    end

    local function proceed(firstname, lastname, skin)
        local skinData = json.decode(skin or '{}')
        local sex = (skinData and skinData.sex == 1) and "F" or "M"
        
        -- Determine card type based on nationality
        local isMexico = (customData and customData.nationality == 'nuevopaso')
        local cardItem = isMexico and 'idcard_mx' or 'idcard'
        
        -- Metadata for pop_inventory
        local metadata = {
            firstname = firstname or "Inconnu",
            lastname = lastname or "Inconnu",
            sex = sex,
            identifier = xPlayer.identifier,
            cardType = isMexico and 'mx' or 'us',
            description = string.format("Nom: %s %s", firstname or "?", lastname or "?")
        }

        if containerId then
            exports['pop_inventory']:addItemToContainer(xPlayer.source, containerId, cardItem, 1, metadata)
        else
            exports['pop_inventory']:GiveItem(xPlayer.source, cardItem, 1, metadata)
        end
        
        -- Notification via pop_notify (esx_notify absent du serveur)
        TriggerClientEvent('notification:client:ShowNotify', xPlayer.source, { icon = 'fas fa-id-card', message = 'Vous avez reçu votre carte d\'identité.', duration = 5000 })
    end

    if customData then
        proceed(customData.firstname, customData.lastname, customData.skin)
    else
        dbQuery('SELECT firstname, lastname, skin FROM users WHERE identifier = ?', {
            xPlayer.identifier
        }, function(result)
            if result and result[1] then
                local r = result[1]
                proceed(r.firstname, r.lastname, r.skin)
            else
            end
        end)
    end
end

-- Sécurité : un client ne peut pas se générer (ou générer à un autre) des cartes à volonté.
-- L'événement n'est accepté que s'il vient du serveur (source vide).
RegisterNetEvent('pop_idcard:server:issueCard', function(targetId)
    local src = source
    if src and src ~= '' and tonumber(src) and tonumber(src) > 0 then return end
    if not targetId then return end
    issueCard(targetId)
end)

AddEventHandler('pop_idcard:server:issueCardInternal', function(targetId, containerId, customData)
    issueCard(targetId, containerId, customData)
end)

ESX.RegisterCommand('giveidcard', 'admin', function(xPlayer, args, showError)
    local target = args.id or xPlayer.source
    issueCard(target)
end, true, {
    help = 'Donner une carte d\'identité',
    arguments = {{name = 'id', help = 'ID du joueur', type = 'number'}}
})
