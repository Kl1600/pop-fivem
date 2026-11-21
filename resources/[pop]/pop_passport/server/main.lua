-- pop_passport : évènements serveur (délivrance interne, photo du titulaire).

-- Appelé par pop_charcreator (serveur uniquement, pas de RegisterNetEvent).
AddEventHandler('pop_passport:server:issueInternal', function(targetId, passportType, containerId, customData)
    Passport.Issue(targetId, passportType, containerId, customData)
end)

-- Photo : renvoie le server id du titulaire du passeport (identifiant ESX stocké dans l'item)
-- uniquement s'il est connecté et proche du lecteur, sinon 0.
RegisterNetEvent('pop_passport:server:holder', function(reqId, identifier)
    local src = source
    local holderId = 0
    if type(identifier) == 'string' and identifier ~= '' and #identifier <= 80 then
        local xHolder = Passport.ESX.GetPlayerFromIdentifier(identifier) -- ESX direct
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
    TriggerClientEvent('pop_passport:client:holder', src, tonumber(reqId) or 0, holderId)
end)
