local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function HasItem(source, item)
    if Config.Inventory == 'pop_inventory' and exports['pop_inventory'] then
        local count = exports['pop_inventory']:getItemCount(source, item)
        return (count and count > 0)
    elseif Config.Inventory == 'qbcore' and Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local itemData = Player.Functions.GetItemByName(item)
            return itemData ~= nil and itemData.amount > 0
        end
    elseif Config.Inventory == 'esx' and Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local inventoryItem = xPlayer.getInventoryItem(item)
            return inventoryItem and inventoryItem.count > 0
        end
    end
    -- Fallbacks
    if Config.Framework == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local inventoryItem = xPlayer.getInventoryItem(item)
            return inventoryItem and inventoryItem.count > 0
        end
    elseif Config.Framework == 'qbcore' and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local itemData = Player.Functions.GetItemByName(item)
            return itemData ~= nil and itemData.amount > 0
        end
    end
    return false
end

-- Compatibilité ESX et QBCore Callbacks pour 'hasItem'
if Config.Framework == 'esx' then
    ESX.RegisterServerCallback('grandtheftauto:hasItem', function(source, cb, item)
        cb(HasItem(source, item))
    end)
elseif Config.Framework == 'qbcore' then
    QBCore.Functions.CreateCallback('grandtheftauto:hasItem', function(source, cb, item)
        cb(HasItem(source, item))
    end)
end

-- (L'ancien évènement 'grandtheftauto:removeItem' est retiré : le module pirate
-- est maintenant consommé par le serveur à la réussite du piratage, voir alert.lua.)

if Config.Framework == 'esx' then
    ESX.RegisterUsableItem('pcb', function(source)
        TriggerClientEvent('grandtheftauto:usePCB', source)
    end)
elseif Config.Framework == 'qbcore' then
    QBCore.Functions.CreateUseableItem('pcb', function(source, item)
        TriggerClientEvent('grandtheftauto:usePCB', source)
    end)
end
