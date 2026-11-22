-- pop_idcard serveur : évènements, photo du titulaire, commande admin.

-- Sécurité : un client ne peut pas se générer (ou générer à un autre) des cartes à volonté.
-- L'événement n'est accepté que s'il vient du serveur (source vide).
RegisterNetEvent('pop_idcard:server:issueCard', function(targetId)
    local src = source
    if src and src ~= '' and tonumber(src) and tonumber(src) > 0 then return end
    if not targetId then return end
    IdCard.Issue(targetId)
end)

-- Appelé par pop_charcreator (serveur uniquement : AddEventHandler, pas d'accès réseau).
AddEventHandler('pop_idcard:server:issueCardInternal', function(targetId, containerId, customData)
    IdCard.Issue(targetId, containerId, customData)
end)

-- Photo : renvoie le server id du titulaire de la carte (identifiant ESX stocké dans l'item)
-- uniquement s'il est connecté et proche du lecteur, sinon 0.
RegisterNetEvent('pop_idcard:server:holder', function(reqId, identifier)
    local src = source
    local holderId = 0
    if type(identifier) == 'string' and identifier ~= '' and #identifier <= 80 then
        local xHolder = IdCard.ESX.GetPlayerFromIdentifier(identifier) -- ESX direct
        if xHolder then
            local target = xHolder.source
            if target == src then
                holderId = target
            else
                local pa, pb = GetPlayerPed(src), GetPlayerPed(target)
                if pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.HolderServerRange then
                    holderId = target
                end
            end
        end
    end
    TriggerClientEvent('pop_idcard:client:holder', src, tonumber(reqId) or 0, holderId)
end)

-- ESX direct : commande réservée au groupe admin ESX, utilisable depuis la console.
IdCard.ESX.RegisterCommand('giveidcard', 'admin', function(xPlayer, args, showError)
    -- Depuis la console, xPlayer est nil : l'ID du joueur est alors obligatoire
    local target = args.id or (xPlayer and xPlayer.source)
    if not target or not GetPlayerName(target) then
        return print(L('cmd_usage'))
    end
    IdCard.Issue(target)
end, true, {
    help = L('cmd_help'),
    arguments = {{name = 'id', help = L('cmd_arg_id'), type = 'number'}}
})
