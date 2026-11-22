-- Verrous de piratage et fin du piratage (PCB).

-- ============================================================
-- VERROUS DE PIRATAGE (PCB)
-- ============================================================

RegisterNetEvent('mission:server:tryLockHack')
AddEventHandler('mission:server:tryLockHack', function(plate)
    local src = source
    if type(plate) ~= 'string' or not GTA.ValidPlates[plate] then return end
    if not GTA.Mission.active or not GTA.IsMember(src) then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "nomission")
        return
    end
    if GTA.HackCompleted[plate] then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "completed")
        return
    end
    local lock = GTA.HackLocks[plate]
    if lock and not GTA.IsLockExpired(lock) and lock.holder ~= src then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "locked")
        return
    end
    GTA.HackLocks[plate] = { holder = src, t = os.time() }
    TriggerClientEvent('mission:client:hackLockResult', src, plate, true, "ok")
    GTA.ToMembers('mission:client:hackState', plate, false, src)
end)

RegisterNetEvent('mission:server:releaseHackLock')
AddEventHandler('mission:server:releaseHackLock', function(plate)
    local src = source
    local lock = GTA.HackLocks[plate]
    if lock and (lock.holder == src or GTA.IsLockExpired(lock)) then
        GTA.HackLocks[plate] = nil
        GTA.ToMembers('mission:client:hackState', plate, false, nil)
    end
end)

-- Fin du piratage : le module pirate (pcb) est consommé ici, seulement en cas de réussite.
RegisterNetEvent('mission:server:finalizeHack')
AddEventHandler('mission:server:finalizeHack', function(plate, netId)
    local src = source
    if type(plate) ~= 'string' or not GTA.ValidPlates[plate] then return end
    local function reply(ok, reason) TriggerClientEvent('mission:client:finalizeResult', src, plate, ok, reason) end

    if not GTA.Mission.active or not GTA.IsMember(src) then return reply(false, 'nomission') end
    if GTA.HackCompleted[plate] then return reply(false, 'completed') end
    local lock = GTA.HackLocks[plate]
    if not lock or lock.holder ~= src then return reply(false, 'locked') end
    if not Bridge.IsNear(src, Config.ShowroomPos, 60.0) then return reply(false, 'far') end

    -- La voiture doit être celle du showroom (pas un clone avec la même plaque), à côté du joueur
    local expectedNet = GTA.CarNetIdForPlate(plate)
    if not expectedNet or tonumber(netId) ~= expectedNet then return reply(false, 'badveh') end
    local veh = NetworkGetEntityFromNetworkId(expectedNet)
    if veh == 0 or not DoesEntityExist(veh) then return reply(false, 'badveh') end
    local pc = Bridge.GetCoords(src)
    if not pc or #(pc - GetEntityCoords(veh)) > 8.0 then return reply(false, 'far') end

    if not Bridge.RemoveItem(src, 'pcb', 1) then return reply(false, 'nopcb') end

    SetVehicleDoorsLocked(veh, 1) -- déverrouillée pour toute l'équipe, quel que soit le propriétaire réseau
    GTA.HackCompleted[plate] = true
    GTA.HackLocks[plate] = nil
    GTA.ToMembers('mission:client:hackState', plate, true, nil)
    reply(true, 'ok')
end)

RegisterNetEvent('mission:server:requestHackState')
AddEventHandler('mission:server:requestHackState', function()
    local src = source
    if not GTA.IsMember(src) then return end
    for plate in pairs(GTA.HackCompleted) do
        TriggerClientEvent('mission:client:hackState', src, plate, true, nil)
    end
    for plate, lock in pairs(GTA.HackLocks) do
        if lock and not GTA.IsLockExpired(lock) then
            TriggerClientEvent('mission:client:hackState', src, plate, false, lock.holder)
        end
    end
end)
