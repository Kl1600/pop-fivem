-- Svetlana, départ du casse, équipe, entités et relais coop.

-- Svetlana : lancer, rejoindre ou refuser
local function CreatePending(src, ignoreCooldown)
    if GTA.Mission.active or GTA.Mission.pending then return false end
    if not ignoreCooldown and os.time() < GTA.cooldownUntil then
        local minutes = math.ceil((GTA.cooldownUntil - os.time()) / 60)
        GTA.Notify(src, L('svetlana_cooldown', minutes), 7000)
        return false
    end

    GTA.ResetState()
    GTA.Mission.pending = true
    GTA.Mission.owner = src
    GTA.Mission.id = GTA.NewHeistId(src)
    GTA.Mission.createdAt = os.time()
    GTA.Mission.members[src] = true

    -- Les joueurs proches de Svetlana font partie de l'équipe
    local origin = Bridge.GetCoords(src)
    if origin then
        for _, id in ipairs(GetPlayers()) do
            local other = tonumber(id)
            if other ~= src and GTA.MemberCount() < Config.MaxMembers and Bridge.IsNear(other, origin, Config.TeamRadius) then
                GTA.Mission.members[other] = true
            end
        end
    end

    for member in pairs(GTA.Mission.members) do
        GTA.GiveKit(member)
        TriggerClientEvent('mission:client:pending', member, GTA.Mission.id, member == src)
    end
    return true
end

RegisterNetEvent('mission:server:talkSvetlana')
AddEventHandler('mission:server:talkSvetlana', function()
    local src = source
    if not Bridge.IsNear(src, Config.SvetlanaPos, 6.0) then return end

    if GTA.Mission.active or GTA.Mission.pending then
        if GTA.IsMember(src) then
            GTA.Notify(src, L('already_member'), 5000)
            if GTA.Mission.pending then TriggerClientEvent('mission:client:pending', src, GTA.Mission.id, src == GTA.Mission.owner) end
            return
        end
        if GTA.Mission.active then
            GTA.Notify(src, L('heist_running'), 5000)
            return
        end
        if GTA.MemberCount() >= Config.MaxMembers then
            GTA.Notify(src, L('team_full'), 5000)
            return
        end
        GTA.Mission.members[src] = true
        GTA.GiveKit(src)
        TriggerClientEvent('mission:client:pending', src, GTA.Mission.id, false)
        GTA.Notify(src, L('team_joined'), 5000)
        return
    end

    CreatePending(src, false)
end)

-- Raccourci admin (/startheist) : même chemin que Svetlana, sans distance ni délai
RegisterNetEvent('mission:server:adminStart')
AddEventHandler('mission:server:adminStart', function()
    local src = source
    if not IsPlayerAceAllowed(src, 'command.startheist') and not IsPlayerAceAllowed(src, 'pop.admin') then return end
    if GTA.Mission.active or GTA.Mission.pending then GTA.EndMission('admin') end
    CreatePending(src, true)
end)

RegisterNetEvent('mission:server:startHeist')
AddEventHandler('mission:server:startHeist', function()
    local src = source
    if not GTA.Mission.pending or src ~= GTA.Mission.owner then return end
    if not Bridge.IsNear(src, Config.ShowroomPos, 150.0) then return end

    GTA.Mission.pending = false
    GTA.Mission.active = true
    GTA.Mission.startedAt = os.time()
    GTA.ToMembers('mission:client:heistStart', GTA.Mission.owner, GTA.Mission.id)
end)

RegisterNetEvent('mission:server:registerEntity')
AddEventHandler('mission:server:registerEntity', function(key, payload)
    local src = source
    if not GTA.Mission.active or src ~= GTA.Mission.owner then return end
    if type(key) ~= 'string' then return end
    if not (key == 'thornton' or key == 'thornton_vehicle' or key == 'heist_demo_feltzer2' or key:match('^showroom_car_%d$')) then return end

    if GTA.Mission.entities[key] then return end -- une clé ne s'enregistre qu'une fois

    local netId = type(payload) == 'table' and tonumber(payload.netId) or tonumber(payload)
    if not netId then return end

    -- Modèles attendus pour chaque clé (le chef ne peut pas faire supprimer l'entité d'un autre)
    local expected
    if key == 'thornton' then
        expected = { 'ig_thornton', 'csb_thornton', 'a_m_m_business_01' }
    elseif key == 'thornton_vehicle' then
        expected = { 'turismo3', 'turismor' }
    elseif key == 'heist_demo_feltzer2' then
        expected = { 'feltzer2' }
    else
        local car = Cars[tonumber(key:match('%d$'))]
        if not car then return end
        expected = { car.model, car.fallback }
    end

    local id = GTA.Mission.id
    CreateThread(function()
        -- L'entité peut mettre un instant à exister côté serveur
        local ent = 0
        for _ = 1, 20 do
            ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then break end
            Wait(250)
        end
        if not GTA.Mission.active or GTA.Mission.id ~= id or GTA.Mission.entities[key] then return end
        if ent == 0 or not DoesEntityExist(ent) then
            GTA.Debug(('entité %s refusée : introuvable côté serveur (netId %s)'):format(key, netId))
            return
        end
        if #(GetEntityCoords(ent) - Config.ShowroomPos) > 80.0 then
            GTA.Debug(('entité %s refusée : trop loin du showroom'):format(key))
            return
        end
        local model, ok = GetEntityModel(ent), false
        for _, m in ipairs(expected) do
            if m and GetHashKey(m) == model then ok = true break end
        end
        if not ok then
            GTA.Debug(('entité %s refusée : modèle inattendu'):format(key))
            return
        end

        local clean = { netId = netId }
        GTA.Debug(('entité %s enregistrée (netId %s)'):format(key, netId))
        if key:match('^showroom_car_%d$') then clean.idx = tonumber(key:match('%d$')) end
        GTA.Mission.entities[key] = (key == 'thornton') and netId or clean
        GTA.ToMembers('mission:client:entity', key, GTA.Mission.entities[key], GTA.Mission.id)
    end)
end)


-- ============================================================
-- RELAIS COOP (liste blanche, équipe uniquement)
-- ============================================================

local RelayCommands = { opencapot = true, removeblip1 = true, open1 = true, blc = true, laseroff = true }
local RelayEvents = {
    ['mission:forceThorntonExit'] = true,
    ['mission:keysBlipOn'] = true,
    ['mission:setKeysTaken'] = true,
    ['mission:setDoorOpened'] = true,
    ['mission:client:lockShowroomDoors'] = true,
    ['mission:client:openShowroomDoors'] = true,
    ['mission:setupBlips'] = true,
    ['StartMissionTimer'] = true,
    ['mission:client:syncTruckDoor'] = true,
}

local function CleanString(s, max)
    if type(s) ~= 'string' then return nil end
    return s:sub(1, max or 64)
end

RegisterNetEvent('mission:server:relay')
AddEventHandler('mission:server:relay', function(action, data, includeSender)
    local src = source
    if not GTA.Mission.active or not GTA.IsMember(src) then return end
    if type(data) ~= 'table' then data = {} end

    local clean
    if action == 'subtitle' then
        clean = { text = CleanString(data.text, 200) or '', duration = math.min(tonumber(data.duration) or 5000, 15000) }
    elseif action == 'hypersound' then
        clean = {
            sound = CleanString(data.sound, 32),
            netId = tonumber(data.netId),
            coords = type(data.coords) == 'vector3' and data.coords or nil,
            looped = false,
            distance = math.min(tonumber(data.distance) or 15.0, 50.0),
        }
        if not clean.sound then return end
    elseif action == 'interactsound_one' then
        clean = { sound = CleanString(data.sound, 32), volume = math.min(tonumber(data.volume) or 0.6, 1.0) }
        if not clean.sound then return end
    elseif action == 'command' then
        if not RelayCommands[data.cmd] then return end
        clean = { cmd = data.cmd }
    elseif action == 'event' then
        if not RelayEvents[data.name] then return end
        local args = {}
        if data.name == 'mission:client:syncTruckDoor' and type(data.args) == 'table' then
            args = { tonumber(data.args[1]), data.args[2] == 'open' and 'open' or 'close' }
        end
        clean = { name = data.name, args = args }
    else
        return
    end

    for member in pairs(GTA.Mission.members) do
        if includeSender == true or member ~= src then
            TriggerClientEvent('mission:client:relay', member, action, clean, src, includeSender == true, GTA.Mission.id)
        end
    end
end)

RegisterNetEvent('mission:server:syncMissionToPlayer')
AddEventHandler('mission:server:syncMissionToPlayer', function()
    local src = source
    if not GTA.Mission.active or not GTA.IsMember(src) then return end
    TriggerClientEvent('mission:client:heistStart', src, GTA.Mission.owner, GTA.Mission.id)
    for key, payload in pairs(GTA.Mission.entities) do
        TriggerClientEvent('mission:client:entity', src, key, payload, GTA.Mission.id)
    end
end)


-- ============================================================
-- FIN DE MISSION : départ du chef, délai dépassé
-- ============================================================

AddEventHandler('playerDropped', function()
    local src = source
    for plate, lock in pairs(GTA.HackLocks) do
        if lock and lock.holder == src then
            GTA.HackLocks[plate] = nil
            GTA.ToMembers('mission:client:hackState', plate, false, nil)
        end
    end
    for i, slot in pairs(GTA.DeliverySlots) do
        if slot.src == src then GTA.DeliverySlots[i] = nil end
    end
    if GTA.Mission.members[src] then
        GTA.Mission.members[src] = nil
        if GTA.Mission.owner == src then
            GTA.EndMission('owner_left')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        if GTA.Mission.active and os.time() - GTA.Mission.startedAt > Config.MissionDuration then
            GTA.EndMission('timeout')
        elseif GTA.Mission.pending and os.time() - GTA.Mission.createdAt > Config.PendingDuration then
            GTA.EndMission('timeout')
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if GTA.Mission.active or GTA.Mission.pending then GTA.EndMission('stop') end
end)
