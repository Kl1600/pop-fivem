-- pop_death : serveur. Garde l'heure de la mort de chaque joueur (par identifiant) pour :
--   - refuser une réapparition avant la fin du délai ;
--   - remettre l'écran de mort à un joueur qui se reconnecte pendant ce délai.

local deaths = {}    -- [identifier] = os.time() de la mort
local lastCall = {}  -- [identifier] = os.time() du dernier appel aux secours

local function remaining(identifier)
    local at = deaths[identifier]
    if not at then return nil end
    return math.max(0, Config.RespawnTime - (os.time() - at))
end

local function nearestHospital(coords)
    local best, bestDist = Config.Hospitals[1], math.huge
    if coords then
        for _, h in ipairs(Config.Hospitals) do
            local c = h.coords
            local d = #(vector3(c.x, c.y, c.z) - coords)
            if d < bestDist then best, bestDist = h, d end
        end
    end
    return best
end

RegisterNetEvent('pop_death:server:died', function()
    local identifier = Bridge.GetIdentifier(source)
    if identifier and not deaths[identifier] then
        deaths[identifier] = os.time()
        if Config.Debug then print(('[pop_death] %s est mort'):format(identifier)) end
    end
end)

-- Réanimé sur place (défibrillateur, admin...) : plus de mort en cours.
RegisterNetEvent('pop_death:server:revived', function()
    local identifier = Bridge.GetIdentifier(source)
    if identifier then deaths[identifier] = nil end
end)

-- Fin du délai : le serveur choisit l'hôpital le plus proche.
Callback.Register('pop_death:respawn', function(source)
    local identifier = Bridge.GetIdentifier(source)
    local left = identifier and remaining(identifier)
    if not left or left > 2 then return nil end -- 2 s de marge (latence)
    deaths[identifier] = nil
    local hospital = nearestHospital(Bridge.GetCoords(source))
    return hospital.coords, hospital.label
end)

-- Appel aux secours. Pas encore de métier EMS : l'appel est transmis par un évènement serveur
-- que le futur script EMS écoutera : AddEventHandler('pop_death:emsCalled', function(src, coords) ... end)
RegisterNetEvent('pop_death:server:callEms', function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier or not deaths[identifier] then return end
    local now = os.time()
    if lastCall[identifier] and now - lastCall[identifier] < Config.CallCooldown then return end
    lastCall[identifier] = now
    TriggerEvent('pop_death:emsCalled', src, Bridge.GetCoords(src))
    TriggerClientEvent('pop_death:client:callSent', src)
end)

-- Reconnexion pendant le délai : l'écran de mort revient avec le temps restant.
Bridge.OnPlayerLoaded(function(src)
    local identifier = Bridge.GetIdentifier(src)
    local left = identifier and remaining(identifier)
    if left then
        TriggerClientEvent('pop_death:client:restore', src, left)
    end
end)

-- Export pour d'autres scripts (EMS, admin) : le joueur est-il mort ?
exports('isDead', function(src)
    local identifier = Bridge.GetIdentifier(src)
    return identifier ~= nil and deaths[identifier] ~= nil
end)
