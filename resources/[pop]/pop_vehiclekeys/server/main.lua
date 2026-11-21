-- pop_vehiclekeys : serveur.
-- Une clé = item Config.KeyItem avec la métadonnée { plate, description }.
-- Aucun event ni callback ne crée de clé à partir d'une plaque client sans preuve de possession :
-- seules sources de clés = export GiveKey, ou double chez le serrurier d'une clé déjà possédée.

local RES = GetCurrentResourceName()
local SUPPORTED = Bridge.SupportsMetadata()

local lastLock = {}   -- [src] = GetGameTimer() du dernier verrouillage
local busy = {}       -- [src] = true pendant un double
local pendingDup = {} -- [src] = { plate, t } : double lancé chez le serrurier (attente de la barre)

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

-- Lu par le client : sans métadonnées, il ne lance pas la boucle moteur.
GlobalState:set('pop_vehiclekeys_supported', SUPPORTED, true)

if not SUPPORTED then
    print(('[%s] WARNING: inventory "%s" (%s) has no item metadata: vehicle keys cannot work. Use ox_inventory, qs-inventory, qb-inventory or pop_inventory.')
        :format(RES, Bridge.Inventory, Bridge.Framework))
end

-- Source de joueur valide et chargé, sinon nil.
local function validPlayer(src)
    src = tonumber(src)
    if not src or math.type(src) ~= 'integer' or src <= 0 then return nil end
    if not GetPlayerName(src) or not Bridge.GetPlayer(src) then return nil end
    return src
end

-- Véhicule serveur valide à partir d'un netId entier, sinon nil.
local function vehicleFromNet(netId)
    if math.type(netId) ~= 'integer' then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function nearLocksmith(src)
    local ls = Config.Locksmith
    if type(ls) ~= 'table' or type(ls.locations) ~= 'table' then return false end
    for _, loc in ipairs(ls.locations) do
        if Bridge.IsNear(src, loc, Keys.ACTION_DISTANCE) then return true end
    end
    return false
end

-- Prix d'un double, relu dans la config (entier >= 0).
local function locksmithPrice()
    local p = tonumber(Config.Locksmith and Config.Locksmith.price) or 0
    return p > 0 and math.floor(p) or 0
end

------------------------------------------------------------------------
-- Clés (inventaire lu côté serveur)
------------------------------------------------------------------------

--- Première pile de clés de cette plaque : slot, metadata (slot nil possible), ou nil.
local function findKey(src, plate)
    if not SUPPORTED or not plate then return nil end
    for _, s in ipairs(Bridge.GetItems(src, Config.KeyItem)) do
        if Keys.Normalize(s.metadata.plate) == plate then return s.slot, s.metadata end
    end
    return nil
end

local function hasKey(src, plate)
    local _, meta = findKey(src, plate)
    return meta ~= nil
end

local function giveKey(src, plate)
    if not SUPPORTED or not plate then return false end
    return Bridge.AddItem(src, Config.KeyItem, 1, { plate = plate, description = L('key_description', plate) })
end

------------------------------------------------------------------------
-- Verrouillage
------------------------------------------------------------------------

--- Logique commune (callback et item). Renvoie ok, reason, locked|arg.
local function toggleLock(src, veh)
    if not SUPPORTED then return false, 'not_supported' end
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return false, 'no_vehicle'
    end

    local now = GetGameTimer()
    if lastLock[src] and now - lastLock[src] < Keys.LOCK_COOLDOWN then return false, 'cooldown', 1 end
    -- NOTE: le cooldown démarre à chaque tentative (même refusée) pour limiter le sondage des plaques.
    lastLock[src] = now

    local coords = GetEntityCoords(veh)
    if not Bridge.IsNear(src, coords, Config.LockDistance + Keys.LOCK_TOLERANCE) then return false, 'too_far' end

    -- Plaque lue côté serveur, jamais celle du client.
    local plate = Keys.Normalize(GetVehicleNumberPlateText(veh))
    if not plate or not hasKey(src, plate) then return false, 'no_key' end

    local locked = GetVehicleDoorLockStatus(veh) < 2
    SetVehicleDoorsLocked(veh, locked and 2 or 1)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    for _, p in ipairs(Bridge.GetPlayers()) do
        if Bridge.IsNear(p, coords, Keys.FX_RADIUS) then
            TriggerClientEvent('pop_vehiclekeys:client:lockFx', p, netId, locked, src)
        end
    end

    Bridge.Notify(src, L(locked and 'locked' or 'unlocked'), 'success')
    log('%s %s vehicle %s', src, locked and 'locked' or 'unlocked', plate)
    return true, nil, locked
end

Callback.Register('pop_vehiclekeys:toggleLock', function(src, netId)
    if not validPlayer(src) then return false, 'error' end
    if not SUPPORTED then return false, 'not_supported' end
    local veh = vehicleFromNet(netId)
    if not veh then return false, 'no_vehicle' end
    return toggleLock(src, veh)
end)

-- Moteur : le joueur doit être dans ce véhicule.
-- Retour : true / false, ou nil si le serveur ne voit pas encore le joueur dans ce véhicule
-- (synchro réseau en retard) : le client redemande 500 ms plus tard sans couper le moteur.
Callback.Register('pop_vehiclekeys:hasKey', function(src, netId)
    -- NOTE: sans métadonnées, aucune clé ne peut exister ; plutôt que de bloquer tous les moteurs du serveur,
    -- le blocage moteur est désactivé (GlobalState + avertissement console au démarrage).
    if not SUPPORTED then return true end
    if not validPlayer(src) then return false end
    local veh = vehicleFromNet(netId)
    if not veh then return false end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return nil end
    return hasKey(src, Keys.Normalize(GetVehicleNumberPlateText(veh)))
end)

------------------------------------------------------------------------
-- Serrurier
------------------------------------------------------------------------

local function doDuplicate(src, plate)
    -- NOTE: le double n'est accepté qu'après un startDuplicate envoyé par le serveur pour cette plaque,
    -- et pas avant la fin de la barre (marge réseau 500 ms) : impossible de sauter la fabrication.
    local p = pendingDup[src]
    pendingDup[src] = nil
    local duration = tonumber(Config.Locksmith.duration) or 0
    local elapsed = p and (GetGameTimer() - p.t) or -1
    if not p or p.plate ~= plate or elapsed < duration - 500 or elapsed > duration + 30000 then
        return false, 'error'
    end

    if not nearLocksmith(src) then return false, 'too_far' end
    if not hasKey(src, plate) then return false, 'no_key' end
    if not Bridge.CanCarry(src, Config.KeyItem, 1) then return false, 'inventory_full' end

    local price = locksmithPrice()
    local account = Config.Locksmith.account or 'cash'
    if price > 0 and not Bridge.RemoveMoney(src, account, price, RES) then
        return false, 'not_enough_money'
    end

    if not giveKey(src, plate) then
        if price > 0 then Bridge.AddMoney(src, account, price, RES) end
        return false, 'inventory_full'
    end

    Bridge.Notify(src, L('duplicated', plate), 'success')
    log('key created (locksmith duplicate) src=%s plate=%s price=%s', src, plate, price)
    return true
end

Callback.Register('pop_vehiclekeys:duplicate', function(src, plate)
    if not validPlayer(src) then return false, 'error' end
    if not SUPPORTED then return false, 'not_supported' end
    plate = Keys.Normalize(plate)
    if not plate then return false, 'error' end
    if busy[src] then return false, 'busy' end

    busy[src] = true
    local pok, ok, reason, arg = pcall(doDuplicate, src, plate)
    busy[src] = nil
    if not pok then
        print(('[%s] duplicate error: %s'):format(RES, tostring(ok)))
        return false, 'error'
    end
    return ok, reason, arg
end)

------------------------------------------------------------------------
-- Item utilisable
------------------------------------------------------------------------

Bridge.RegisterUsableItem(Config.KeyItem, function(playerId, _, metadata)
    local src = validPlayer(playerId)
    if not src then return end
    if not SUPPORTED then return Bridge.Notify(src, L('not_supported'), 'error') end

    local plate = Keys.Normalize(type(metadata) == 'table' and metadata.plate or nil)
    if not plate then return Bridge.Notify(src, L('key_invalid'), 'error') end

    -- Chez le serrurier : lancer la fabrication d'un double (possession revérifiée à la fin).
    if nearLocksmith(src) then
        if busy[src] then return Bridge.Notify(src, L('busy'), 'error') end
        pendingDup[src] = { plate = plate, t = GetGameTimer() }
        TriggerClientEvent('pop_vehiclekeys:client:startDuplicate', src, plate, locksmithPrice())
        return
    end

    -- Sinon : véhicule de cette plaque à portée (possession revérifiée dans toggleLock).
    local maxDist = Config.LockDistance + Keys.LOCK_TOLERANCE
    for _, veh in ipairs(GetAllVehicles()) do
        if Keys.Normalize(GetVehicleNumberPlateText(veh)) == plate and Bridge.IsNear(src, GetEntityCoords(veh), maxDist) then
            local ok, reason, arg = toggleLock(src, veh)
            if not ok then Bridge.Notify(src, L(reason or 'error', arg), 'error') end
            return
        end
    end
    Bridge.Notify(src, L('vehicle_not_here', plate), 'error')
end)

------------------------------------------------------------------------
-- Exports (seules portes d'entrée pour créer une clé depuis un autre script)
------------------------------------------------------------------------

exports('GiveKey', function(src, plate)
    src = validPlayer(src)
    plate = Keys.Normalize(plate)
    if not src or not plate or not SUPPORTED then return false end
    if not giveKey(src, plate) then return false end
    Bridge.Notify(src, L('key_received', plate), 'success')
    log('key created (export GiveKey from %s) src=%s plate=%s', GetInvokingResource() or RES, src, plate)
    return true
end)

exports('RemoveKey', function(src, plate, all)
    src = validPlayer(src)
    plate = Keys.Normalize(plate)
    if not src or not plate or not SUPPORTED then return false end

    local removed = 0
    -- Limite de sécurité : évite une boucle infinie si un inventaire ne retire rien en renvoyant true.
    for _ = 1, 100 do
        local slot, meta = findKey(src, plate)
        if not meta or not Bridge.RemoveItem(src, Config.KeyItem, 1, meta, slot) then break end
        removed = removed + 1
        if all ~= true then break end
    end

    if removed == 0 then return false end
    Bridge.Notify(src, L('key_removed', plate), 'info')
    log('key removed (export RemoveKey from %s) src=%s plate=%s count=%d', GetInvokingResource() or RES, src, plate, removed)
    return true
end)

exports('HasKey', function(src, plate)
    src = validPlayer(src)
    if not src then return false end
    return hasKey(src, Keys.Normalize(plate))
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

local function cleanup(src)
    lastLock[src] = nil
    busy[src] = nil
    pendingDup[src] = nil
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
