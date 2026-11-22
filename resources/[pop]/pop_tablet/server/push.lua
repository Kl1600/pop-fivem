-- Envoi serveur -> client ciblé. Aucun polling : on envoie seulement quand quelque chose arrive.
-- Chaque paquet fait au plus Tablet.PushMaxBytes (1 Ko) ; un paquet trop gros est refusé, jamais tronqué.

Tablet = Tablet or {}
Tablet.Push = {}
local Push = Tablet.Push

--- Envoie `pop_tablet:client:<name>` à `src`. Sans `force`, seulement si ce joueur a une session de tablette.
--- Renvoie true + taille en octets, ou false.
function Push.To(src, name, data, force)
    if not Tablet.PushNames[name] then return false end
    if not force and not Tablet.Device.HasSession(src) then return false end
    local payload = data or {}
    local bytes = #json.encode(payload)
    if bytes > Tablet.PushMaxBytes then
        if Config.Debug then print(('[pop_tablet] push "%s" refused: %d bytes'):format(name, bytes)) end
        return false
    end
    if Config.Debug then print(('[pop_tablet] push "%s" to %s: %d bytes'):format(name, tostring(src), bytes)) end
    TriggerClientEvent('pop_tablet:client:' .. name, src, payload)
    return true, bytes
end

--- Envoie à la tablette `serial` si son porteur est en ligne avec une session.
function Push.ToSerial(serial, name, data)
    local src = Tablet.Device.SrcOf(serial)
    if not src then return false end
    return Push.To(src, name, data)
end

--- Demande la fermeture de la tablette (objet perdu, mort, tablette volée), même sans session.
function Push.ForceClose(src, reason)
    return Push.To(src, 'forceClose', { reason = reason }, true)
end
