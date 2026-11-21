-- pop_paintgun : serveur.
-- Le serveur ne fait confiance à rien : session ouverte par l'item, durée minimale, couleur
-- relue dans Config.Colors, distance mesurée côté serveur, job et items revérifiés.

-- NOTE: VEHICLE_DISTANCE (4.0, recherche du véhicule) n'existe que côté client ; marge serveur plus large.
local ACTION_DISTANCE = 6.0 -- distance max joueur / véhicule (position serveur)
local SESSION_TIMEOUT = 120 -- secondes entre l'utilisation de l'item et la peinture

local TARGETS = { primary = true, secondary = true, both = true }

local sessions = {} -- [src] = { t = os.time() }
local busy = {}     -- [src] = true pendant le traitement d'un callback

-- Ensemble des couleurs autorisées (id natif GTA).
local allowedColors = {}
for _, c in ipairs(Config.Colors or {}) do
    local id = math.tointeger(c.id)
    if id then allowedColors[id] = true end
end

local function log(msg, ...)
    if Config.Debug then
        print(('[pop_paintgun] ' .. msg):format(...))
    end
end

-- Job requis (si Config.Jobs) et en service.
local function hasRequiredJob(src)
    if not Config.Jobs then return true end
    if not Bridge.HasJob(src, Config.Jobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

------------------------------------------------------------------------
-- Item utilisable : ouvre une session et le sélecteur côté client. Rien n'est retiré.
------------------------------------------------------------------------

Bridge.RegisterUsableItem(Config.Item, function(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end

    if not hasRequiredJob(src) then
        Bridge.Notify(src, L('wrong_job'), 'error')
        return
    end

    -- Session encore valide (peinture en cours, sélecteur rouvert) : conservée, sinon la durée minimale
    -- de la peinture en cours serait remise à zéro et le callback refusé.
    local s = sessions[src]
    if not s or os.time() - s.t > SESSION_TIMEOUT then
        sessions[src] = { t = os.time() }
    end
    TriggerClientEvent('pop_paintgun:client:open', src)
    log('open src=%d', src)
end)

------------------------------------------------------------------------
-- Callback pop_paintgun:paint(netId, color, target) -> ok, reason, arg
------------------------------------------------------------------------

local function paint(src, netId, color, target)
    -- Session : une peinture par utilisation d'item, supprimée dès ce contrôle.
    local session = sessions[src]
    sessions[src] = nil
    if not session then return false, 'error' end
    local elapsed = os.time() - session.t
    if elapsed > SESSION_TIMEOUT then return false, 'error' end
    if elapsed < (tonumber(Config.Duration) or 0) / 1000 - 1 then
        log('too fast src=%d elapsed=%ds', src, elapsed)
        return false, 'error'
    end

    -- Types.
    -- NOTE: math.tointeger accepte aussi 27.0 (nombre décodé du JSON NUI) mais refuse 27.5, les chaînes et nil :
    -- même sécurité que math.type == 'integer', plus tolérant sur la sérialisation.
    netId = math.type(netId) and math.tointeger(netId) or nil
    color = math.type(color) and math.tointeger(color) or nil
    if not netId or not color or type(target) ~= 'string' or not TARGETS[target] then
        return false, 'error'
    end

    -- Couleur autorisée.
    if not allowedColors[color] then return false, 'invalid_color' end

    -- Véhicule et distance (position serveur).
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return false, 'no_vehicle'
    end
    if not Bridge.IsNear(src, GetEntityCoords(veh), ACTION_DISTANCE) then
        return false, 'too_far'
    end

    -- Job et pistolet revérifiés.
    if not hasRequiredJob(src) then return false, 'wrong_job' end
    if not Bridge.HasItem(src, Config.Item) then return false, 'missing_item', L('item_gun') end

    -- Pot de peinture consommé (tout ou rien, vérifié par le bridge).
    if Config.PaintItem and not Bridge.RemoveItem(src, Config.PaintItem, 1) then
        return false, 'missing_item', L('item_paint')
    end

    -- Application par le propriétaire réseau du véhicule (seul à pouvoir le modifier sans attente) ;
    -- repli sur le peintre si le véhicule n'a pas de propriétaire.
    local owner = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 or not GetPlayerName(owner) then owner = src end
    TriggerClientEvent('pop_paintgun:client:apply', owner, netId, color, target)

    Bridge.Notify(src, L('painted'), 'success')
    TriggerEvent('pop_paintgun:painted', src, netId, color, target, GetVehicleNumberPlateText(veh))
    log('painted src=%d (%s) netId=%d color=%d target=%s', src, Bridge.GetIdentifier(src) or '?', netId, color, target)
    return true
end

Callback.Register('pop_paintgun:paint', function(src, netId, color, target)
    src = tonumber(src)
    if not src then return false, 'error' end
    if busy[src] then return false, 'busy' end

    busy[src] = true
    local ok, res, reason, arg = pcall(paint, src, netId, color, target)
    busy[src] = nil -- libéré dans tous les cas

    if not ok then
        print(('[pop_paintgun] paint error: %s'):format(res))
        return false, 'error'
    end
    return res, reason, arg
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    sessions[src] = nil
    busy[src] = nil
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
