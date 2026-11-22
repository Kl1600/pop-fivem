-- pop_vehiclepersistence — serveur : évènements réseau et commande de debug.

local P = Persist
local allVehicles, spawnedPlates, lastSnapshots = P.allVehicles, P.spawnedPlates, P.lastSnapshots
local originalOwner, lastSeen, current, requested = P.originalOwner, P.lastSeen, P.current, P.requested
local normalPlate, num, gridUpdate = P.normalPlate, P.num, P.gridUpdate
local isForgotten, sanitize, isNearPlayer, maxDays = P.isForgotten, P.sanitize, P.isNearPlayer, P.maxDays
local snapshot, needsSave, saveVehicle, saveAllFor = P.snapshot, P.needsSave, P.saveVehicle, P.saveAllFor
local findEntityByPlate = P.findEntityByPlate
local getIdentifier, hasKey = P.getIdentifier, P.hasKey
local CULL_RADIUS, DAY = P.CULL_RADIUS, P.DAY
local floor = math.floor

-- ── Événements ───────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local pid = source
    local claimed = {}
    for plate, claimer in pairs(spawnedPlates) do
        if claimer == pid then claimed[#claimed + 1] = plate end
    end
    -- Anti-doublon : si l'entité a migré vers un autre joueur, il devient le détenteur ;
    -- sinon la plaque est libérée et la boucle spatiale la refera apparaître.
    if #claimed > 0 then
        SetTimeout(3000, function()
            for _, plate in ipairs(claimed) do
                if spawnedPlates[plate] == pid then
                    local ent = findEntityByPlate(plate)
                    local owner = ent and NetworkGetEntityOwner(ent) or nil
                    if owner and owner > 0 and GetPlayerName(owner) then
                        spawnedPlates[plate] = owner
                    else
                        spawnedPlates[plate] = nil
                    end
                end
            end
        end)
    end
    local entry = current[pid]
    if entry then
        saveAllFor(entry, false)
        current[pid] = nil
    end
    requested[pid] = nil
end)

local function track(pid, plate, v)
    if isForgotten(plate) then return end
    spawnedPlates[plate] = pid
    allVehicles[plate] = v
    gridUpdate(plate, v)
end

RegisterNetEvent('saveVehicleToDatabase', function(v)
    local pid = source
    v = sanitize(v)
    if not v or not isNearPlayer(pid, v) then return end
    local plate = normalPlate(v.plate)
    if isForgotten(plate) or not hasKey(pid, plate) then return end
    local id = getIdentifier(pid)
    if not id then return end

    saveVehicle(id, v)
    local entry = current[pid]
    if not entry then
        entry = { identifier = id, vehicles = {} }
        current[pid] = entry
    end
    entry.vehicles[plate] = v
    entry.active = plate
    spawnedPlates[plate] = pid
end)

RegisterNetEvent('CurrentVehicle', function(v)
    local pid = source
    local entry = current[pid]

    if v == nil then
        if entry and entry.active then
            local data = entry.vehicles[entry.active]
            if data then saveVehicle(entry.identifier, data) end
            entry.active = nil
        end
        return
    end

    v = sanitize(v)
    if not v or not isNearPlayer(pid, v) then return end
    local plate = normalPlate(v.plate)
    if isForgotten(plate) then return end

    if entry then
        local old = entry.active
        if old == plate then
            entry.vehicles[plate] = v
            allVehicles[plate] = v
            gridUpdate(plate, v)
            -- Écriture SQL seulement si l'état a réellement changé.
            if needsSave(v) then saveVehicle(entry.identifier, v) end
            return
        end
        if old and entry.vehicles[old] then saveVehicle(entry.identifier, entry.vehicles[old]) end
        if entry.vehicles[plate] or hasKey(pid, plate) then
            entry.vehicles[plate] = v
            entry.active = plate
            track(pid, plate, v)
        else
            entry.active = nil
        end
    elseif hasKey(pid, plate) then
        local id = getIdentifier(pid)
        if id then
            current[pid] = { identifier = id, vehicles = { [plate] = v }, active = plate }
            track(pid, plate, v)
        end
    end
end)

-- Le joueur doit être près du véhicule connu, et ne pas voler la plaque d'un autre détenteur en ligne.
local function canClaim(src, plate)
    local v = allVehicles[plate]
    if not v or isForgotten(plate) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local dist = #(GetEntityCoords(ped) - vector3(num(v.x), num(v.y), num(v.z)))
    if dist > CULL_RADIUS + 100.0 then return false end
    local claimer = spawnedPlates[plate]
    return not claimer or claimer == src or not GetPlayerName(claimer)
end

RegisterNetEvent('pop_vehiclepersistence:vehicleSpawned', function(plate)
    local src = source
    plate = normalPlate(plate)
    if canClaim(src, plate) then spawnedPlates[plate] = src end
end)

RegisterNetEvent('pop_vehiclepersistence:despawnFailed', function(plate)
    local src = source
    plate = normalPlate(plate)
    if canClaim(src, plate) then spawnedPlates[plate] = src end
end)

-- Liste complète / stats : outil de debug (/showvehicles), réservé aux admins (ace 'command').
RegisterNetEvent('pop_vehiclepersistence:requestAllVehicles', function()
    local pid = source
    if not IsPlayerAceAllowed(pid, 'command') then return end
    local list, days, now = {}, maxDays(), os.time()
    for plate, v in pairs(allVehicles) do
        local expiresIn = nil
        if days > 0 then
            local ls = lastSeen[plate] or now
            expiresIn = math.max(0, floor((ls + days * DAY - now) / DAY))
        end
        list[#list + 1] = {
            plate = plate, x = num(v.x), y = num(v.y), z = num(v.z),
            model = tonumber(v.model) or 0, active = spawnedPlates[plate] ~= nil, expiresIn = expiresIn,
        }
    end
    TriggerClientEvent('pop_vehiclepersistence:receiveAllVehicles', pid, list)
end)

RegisterNetEvent('pop_vehiclepersistence:requestStats', function()
    local pid = source
    if not IsPlayerAceAllowed(pid, 'command') then return end
    local total, driven, seen, spawned = 0, 0, {}, 0
    for _ in pairs(allVehicles) do total = total + 1 end
    for _ in pairs(spawnedPlates) do spawned = spawned + 1 end
    for _, e in pairs(current) do
        if e.active and not seen[e.active] then seen[e.active] = true; driven = driven + 1 end
    end
    local owned, id = 0, getIdentifier(pid)
    if id then
        for _, o in pairs(originalOwner) do if o == id then owned = owned + 1 end end
    end
    TriggerClientEvent('pop_vehiclepersistence:receiveStats', pid, {
        total = total, driven = driven, spawnedServer = spawned, placeholders = 0,
        owned = owned, onlinePlayers = #GetPlayers(), cullRadius = CULL_RADIUS,
        promoteRadius = 30.0, autoSave = 1, maxPersistenceDays = maxDays(),
    })
end)

RegisterNetEvent('requestSavedVehicle', function()
    local pid = source
    if requested[pid] then return end
    requested[pid] = true
    local id = getIdentifier(pid)
    if not id then return end

    MySQL.query('SELECT vehicle_data, last_seen FROM persistent_vehicles WHERE owner_id = ?', { id }, function(rows)
        if not rows or #rows == 0 then return end
        current[pid] = current[pid] or { identifier = id, vehicles = {} }
        local days, now = maxDays(), os.time()
        local ped = GetPlayerPed(pid)
        local ppos = ped ~= 0 and GetEntityCoords(ped) or nil
        local cutoff = days > 0 and (now - days * DAY) or 0

        -- Spawn séquentiel (500 ms entre chaque) pour ne pas inonder le client.
        CreateThread(function()
            for i, row in ipairs(rows) do
                if not GetPlayerName(pid) or not current[pid] then return end
                local ok, v = pcall(json.decode, row.vehicle_data or '')
                if ok and type(v) == 'table' and v.plate then
                    local plate = normalPlate(v.plate)
                    local seen = tonumber(row.last_seen) or 0
                    if seen == 0 then seen = now end
                    if (days <= 0 or seen >= cutoff) and not isForgotten(plate) then
                        lastSeen[plate] = seen
                        allVehicles[plate] = v
                        originalOwner[plate] = id
                        current[pid].vehicles[plate] = v
                        gridUpdate(plate, v)
                        -- La connexion n'est pas une interaction : pas de sauvegarde (ni last_seen) ensuite.
                        lastSnapshots[plate] = snapshot(v)

                        -- Seulement les véhicules proches ; les autres apparaîtront via la boucle
                        -- spatiale quand un joueur s'en approchera (plus de véhicules partout).
                        local near = ppos and #(ppos - vector3(num(v.x), num(v.y), num(v.z))) < CULL_RADIUS
                        local claimer = spawnedPlates[plate]
                        if near and not (claimer and GetPlayerName(claimer)) then
                            spawnedPlates[plate] = pid
                            TriggerClientEvent('respawnPlayerInVehicle', pid, v, i == #rows)
                        end
                    end
                end
                Wait(500)
            end
        end)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(current) do saveAllFor(e, false) end
end)

-- Redémarrage / arrêt par txAdmin : sauvegarde avant l'arrêt, quand la base répond encore.
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for _, e in pairs(current) do saveAllFor(e, false) end
end)

-- Commande console (debug) : état de la persistance.
RegisterCommand('debug_persistence', function(src)
    if src ~= 0 then
        local e = current[src]
        local msg = L('debug_none_tracked')
        if e then
            local n = 0
            for _ in pairs(e.vehicles) do n = n + 1 end
            msg = L('debug_tracked', n, e.active or L('debug_none'))
        end
        TriggerClientEvent('pop_vehiclepersistence:notify', src, msg)
        return
    end
    local total, spawned = 0, 0
    for _ in pairs(allVehicles) do total = total + 1 end
    for _ in pairs(spawnedPlates) do spawned = spawned + 1 end
    print(('[Persistence] DB:%d  RealSpawned:%d'):format(total, spawned)) -- sortie de la commande console
end, true)
