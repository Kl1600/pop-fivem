-- Instance du créateur (routing bucket), ouverture auto, commande admin /charcreator.

local adminReopen = CharCreator.adminReopen
local saving = CharCreator.saving
local inCreatorInstance = CharCreator.inCreatorInstance

RegisterNetEvent('pop_charcreator:server:enterInstance', function()
    local src = source
    -- Uniquement depuis le monde normal (évite de sortir d'une autre instance : prison, etc.)
    if GetPlayerRoutingBucket(src) ~= 0 then return end

    local function enter()
        inCreatorInstance[src] = true
        -- On place le joueur dans un bucket unique basé sur son ID source (+1000 pour éviter les conflits)
        SetPlayerRoutingBucket(src, src + 1000)
    end

    -- Instance réservée à une vraie création : perso sans prénom, ou créateur rouvert
    -- par un admin (sinon n'importe qui s'isolait et avait les tatouages gratuits).
    if adminReopen[src] then return enter() end
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.scalar('SELECT firstname FROM users WHERE identifier = ?', { xPlayer.identifier }, function(firstname)
        if firstname == nil or firstname == '' then enter() end
    end)
end)

RegisterNetEvent('pop_charcreator:server:exitInstance', function()
    local src = source
    if not inCreatorInstance[src] then return end
    inCreatorInstance[src] = nil
    SetPlayerRoutingBucket(src, 0)
end)

-- Décision serveur : le créateur s'ouvre tant que le personnage n'a pas de prénom
-- en base (joueur qui a quitté pendant la création, pas seulement isNew).
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local src = tonumber(playerId)
    if not src or not xPlayer or not xPlayer.identifier then return end
    MySQL.scalar('SELECT firstname FROM users WHERE identifier = ?', { xPlayer.identifier }, function(firstname)
        if firstname == nil or firstname == '' then
            TriggerClientEvent('pop_charcreator:client:needCreator', src)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    adminReopen[src], saving[src], inCreatorInstance[src] = nil, nil, nil
end)

-- Commande admin (ESX direct) : ouvrir le créateur (autorise une réédition du personnage)
ESX.RegisterCommand('charcreator', 'admin', function(xPlayer, args, showError)
    adminReopen[xPlayer.source] = true
    xPlayer.triggerEvent('pop_charcreator:open')
end, false, {help = L('cmd_charcreator')})
