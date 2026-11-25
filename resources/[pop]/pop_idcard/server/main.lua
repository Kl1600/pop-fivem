-- pop_idcard serveur : évènements, objets utilisables, photo du titulaire, commande admin.

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

-- Objets utilisables : pop_inventory les déclare dans sa config (onUse) ; avec un autre
-- inventaire, on les enregistre ici. Sans métadonnées (inventaire de base), on montre
-- la carte du joueur lui-même.
CreateThread(function()
    if Bridge.Inventory == 'pop_inventory' then return end
    for _, item in ipairs({ Config.CardItem, Config.CardItemMx }) do
        Bridge.RegisterUsableItem(item, function(src, _, metadata)
            local meta = metadata
            if type(meta) ~= 'table' or not meta.firstname then
                local first, last = (Bridge.GetName(src) or ''):match('^(%S+)%s+(.+)$')
                meta = IdCard.BuildMetadata(src, first, last, nil, item == Config.CardItemMx and Config.MexicoNationality or nil)
            end
            TriggerClientEvent('pop_idcard:display', src, { meta = meta })
        end)
    end
end)

-- Photo : renvoie le server id du titulaire de la carte (identifiant stocké dans l'objet)
-- uniquement s'il est connecté et proche du lecteur, sinon 0.
RegisterNetEvent('pop_idcard:server:holder', function(reqId, identifier)
    local src = source
    local holderId = 0
    if type(identifier) == 'string' and identifier ~= '' and #identifier <= 80 then
        local target = IdCard.FindSource(identifier)
        if target then
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

-- Commande admin (ACE pop.admin ou groupe admin du framework), utilisable depuis la console.
RegisterCommand(Config.GiveCommand, function(src, args)
    if src ~= 0 and not Bridge.IsAdmin(src) then
        return Bridge.Notify(src, { icon = 'fas fa-id-card', message = L('no_permission') })
    end
    local target = tonumber(args[1]) or (src ~= 0 and src or nil)
    if not target or not GetPlayerName(target) then
        if src == 0 then return print(L('cmd_usage', Config.GiveCommand)) end
        return Bridge.Notify(src, { icon = 'fas fa-id-card', message = L('cmd_usage', Config.GiveCommand) })
    end
    IdCard.Issue(target)
end, false)

