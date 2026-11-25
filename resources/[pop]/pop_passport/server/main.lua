-- pop_passport : évènements serveur (délivrance interne, photo du titulaire).

-- Appelé par pop_charcreator (serveur uniquement, pas de RegisterNetEvent).
AddEventHandler('pop_passport:server:issueInternal', function(targetId, passportType, containerId, customData)
    Passport.Issue(targetId, passportType, containerId, customData)
end)

-- Objets utilisables : pop_inventory les déclare dans sa config (onUse) ; avec un autre
-- inventaire, on les enregistre ici. Sans métadonnées, on montre le passeport du joueur lui-même.
CreateThread(function()
    if Bridge.Inventory == 'pop_inventory' then return end
    for pType, info in pairs({ us = Config.USA, mx = Config.Mexico }) do
        Bridge.RegisterUsableItem(info.item, function(src, _, metadata)
            local meta = metadata
            if type(meta) ~= 'table' or not meta.firstname then
                local first, last = (Bridge.GetName(src) or ''):match('^(%S+)%s+(.+)$')
                meta = Passport.BuildMetadata(src, pType, first, last)
            end
            TriggerClientEvent('pop_passport:display:' .. pType, src, { meta = meta })
        end)
    end
end)

-- Photo : renvoie le server id du titulaire du passeport (identifiant stocké dans l'objet)
-- uniquement s'il est connecté et proche du lecteur, sinon 0.
RegisterNetEvent('pop_passport:server:holder', function(reqId, identifier)
    local src = source
    local holderId = 0
    if type(identifier) == 'string' and identifier ~= '' and #identifier <= 80 then
        local target = Passport.FindSource(identifier)
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
    TriggerClientEvent('pop_passport:client:holder', src, tonumber(reqId) or 0, holderId)
end)
