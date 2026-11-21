-- Exemple minimal : à remplacer par le code du script.
-- Le serveur revérifie tout : distance, cooldown, et le montant vient de la config, jamais du client.

local POINT = vec3(215.76, -810.12, 30.73)
local COOLDOWN = 60 -- secondes
local lastUse = {}  -- [identifier] = os.time()

Callback.Register('pop_base:example', function(src)
    if not Bridge.IsNear(src, POINT, 5.0) then return false, 'too_far' end

    local id = Bridge.GetIdentifier(src)
    if not id then return false, 'error' end
    local now = os.time()
    if lastUse[id] and now - lastUse[id] < COOLDOWN then
        return false, 'cooldown', COOLDOWN - (now - lastUse[id])
    end
    lastUse[id] = now

    Bridge.Notify(src, L('interact'), 'success')
    return true
end)
