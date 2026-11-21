local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- ============================================================
-- OUTILS
-- ============================================================

local ValidPlates = {}
for _, car in ipairs(Cars) do ValidPlates[car.plate] = true end

local function Notify(src, message, duration)
    TriggerClientEvent('grandtheftauto:client:ShowNotify', src, { message = message, duration = duration or 7000 })
end

local function PedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function IsNear(src, pos, radius)
    local c = PedCoords(src)
    return c ~= nil and #(c - pos) <= radius
end

local function GetPolicePlayers()
    local policePlayers = {}
    if Config.Framework == 'esx' and ESX then
        for _, job in ipairs(Config.PoliceJobs) do
            for _, xPlayer in pairs(ESX.GetExtendedPlayers('job', job)) do
                table.insert(policePlayers, xPlayer.source)
            end
        end
    elseif Config.Framework == 'qbcore' and QBCore then
        local jobs = {}
        for _, job in ipairs(Config.PoliceJobs) do jobs[job] = true end
        for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
            if Player and jobs[Player.PlayerData.job.name] then
                table.insert(policePlayers, Player.PlayerData.source)
            end
        end
    end
    return policePlayers
end

local function ItemCount(src, item)
    if GetResourceState('pop_inventory') == 'started' then
        local ok, count = pcall(function() return exports['pop_inventory']:getItemCount(src, item) end)
        if ok then return tonumber(count) or 0 end
    end
    return 0
end

local function RemoveItem(src, item, qty)
    if GetResourceState('pop_inventory') ~= 'started' then return false end
    local ok, res = pcall(function() return exports['pop_inventory']:removeItem(src, item, qty or 1) end)
    return ok and res ~= false
end

local function GiveItem(src, item, qty)
    if GetResourceState('pop_inventory') ~= 'started' then return false end
    local ok, res = pcall(function() return exports['pop_inventory']:GiveItem(src, item, qty or 1) end)
    return ok and res == true
end

-- Paiement : cash d'abord (objet pop_inventory), sinon compte banque ESX.
local function PayPlayer(src, amount)
    if GiveItem(src, 'cash', amount) then return 'cash' end
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.addAccountMoney('bank', amount)
            return 'bank'
        end
    end
    return nil
end

-- ============================================================
-- ÉTAT DE LA MISSION
-- ============================================================

local Mission = {}
local HackLocks = {}
local HackCompleted = {}
local DeliverySlots = {}
local cooldownUntil = 0
local trackingToken = 0
local lastShowroomAlert, lastTrackingAlert = 0, 0

local function ResetState()
    Mission = {
        active = false,   -- casse lancé (au showroom)
        pending = false,  -- Svetlana a donné la mission, l'équipe se rend au showroom
        id = nil,
        owner = nil,
        members = {},     -- [src] = true
        entities = {},
        startedAt = 0,
        createdAt = 0,
        delivered = {},   -- [plate] = true
        deliveredCount = 0,
        endCheck = nil,
    }
    HackLocks = {}
    HackCompleted = {}
    DeliverySlots = {}
end
ResetState()

local function IsMember(src)
    return Mission.members[src] == true
end

local function MemberCount()
    local n = 0
    for _ in pairs(Mission.members) do n = n + 1 end
    return n
end

local function ToMembers(eventName, ...)
    for src in pairs(Mission.members) do
        TriggerClientEvent(eventName, src, ...)
    end
end

local function StopTracking()
    trackingToken = trackingToken + 1
    for _, src in pairs(GetPolicePlayers()) do
        TriggerClientEvent('mission:client:stopPoliceTracking', src)
    end
end

local function EndMission(reason)
    if not Mission.active and not Mission.pending then return end
    local wasActive = Mission.active

    -- Nettoyage des entités de la mission (sauf voitures déjà livrées, supprimées avant)
    for key, payload in pairs(Mission.entities) do
        local netId = type(payload) == 'table' and payload.netId or payload
        if type(netId) == 'number' then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                -- Une voiture volée conduite par un joueur n'est pas supprimée sous ses pieds
                local keep = false
                if GetEntityType(ent) == 2 then
                    local driver = GetPedInVehicleSeat(ent, -1)
                    keep = driver ~= 0 and IsPedAPlayer(driver)
                end
                if not keep then DeleteEntity(ent) end
            end
        end
    end

    ToMembers('mission:client:reset', reason or 'end')
    if wasActive then StopTracking() end

    cooldownUntil = os.time() + (wasActive and Config.Cooldown or 60)
    ResetState()
end

-- Kit (flipper + pcb) : une fois par joueur et par période de cooldown (anti-farm)
local KitGiven = {}
local function GiveKit(src)
    if not Config.GiveKit then return end
    local id = GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
    if KitGiven[id] and os.time() - KitGiven[id] < Config.Cooldown then return end
    KitGiven[id] = os.time()
    if ItemCount(src, 'flipper') < 1 then GiveItem(src, 'flipper', 1) end
    if ItemCount(src, 'pcb') < 1 then GiveItem(src, 'pcb', 1) end
end

local function NewHeistId(src)
    return string.format("%d_%d", os.time(), src or 0)
end

-- Svetlana : lancer, rejoindre ou refuser
local function CreatePending(src, ignoreCooldown)
    if Mission.active or Mission.pending then return false end
    if not ignoreCooldown and os.time() < cooldownUntil then
        local minutes = math.ceil((cooldownUntil - os.time()) / 60)
        Notify(src, ("Svetlana n'a rien pour vous. Revenez dans <span style='color:#ECA95D; font-weight:bold;'>%d min</span>."):format(minutes), 7000)
        return false
    end

    ResetState()
    Mission.pending = true
    Mission.owner = src
    Mission.id = NewHeistId(src)
    Mission.createdAt = os.time()
    Mission.members[src] = true

    -- Les joueurs proches de Svetlana font partie de l'équipe
    local origin = PedCoords(src)
    if origin then
        for _, id in ipairs(GetPlayers()) do
            local other = tonumber(id)
            if other ~= src and MemberCount() < Config.MaxMembers and IsNear(other, origin, Config.TeamRadius) then
                Mission.members[other] = true
            end
        end
    end

    for member in pairs(Mission.members) do
        GiveKit(member)
        TriggerClientEvent('mission:client:pending', member, Mission.id, member == src)
    end
    return true
end

RegisterNetEvent('mission:server:talkSvetlana')
AddEventHandler('mission:server:talkSvetlana', function()
    local src = source
    if not IsNear(src, Config.SvetlanaPos, 6.0) then return end

    if Mission.active or Mission.pending then
        if IsMember(src) then
            Notify(src, "Vous faites déjà partie de <span style='color:#ECA95D; font-weight:bold;'>l'équipe</span>.", 5000)
            if Mission.pending then TriggerClientEvent('mission:client:pending', src, Mission.id, src == Mission.owner) end
            return
        end
        if Mission.active then
            Notify(src, "Un casse est <span style='color:#E74C3C; font-weight:bold;'>déjà en cours</span>. Revenez plus tard.", 5000)
            return
        end
        if MemberCount() >= Config.MaxMembers then
            Notify(src, "L'équipe est <span style='color:#E74C3C; font-weight:bold;'>déjà complète</span>.", 5000)
            return
        end
        Mission.members[src] = true
        GiveKit(src)
        TriggerClientEvent('mission:client:pending', src, Mission.id, false)
        Notify(src, "Vous avez <span style='color:#2ecc71; font-weight:bold;'>rejoint l'équipe</span>.", 5000)
        return
    end

    CreatePending(src, false)
end)

-- Raccourci admin (/startheist) : même chemin que Svetlana, sans distance ni délai
RegisterNetEvent('mission:server:adminStart')
AddEventHandler('mission:server:adminStart', function()
    local src = source
    if not IsPlayerAceAllowed(src, 'command.startheist') and not IsPlayerAceAllowed(src, 'pop.admin') then return end
    if Mission.active or Mission.pending then EndMission('admin') end
    CreatePending(src, true)
end)

RegisterNetEvent('mission:server:startHeist')
AddEventHandler('mission:server:startHeist', function()
    local src = source
    if not Mission.pending or src ~= Mission.owner then return end
    if not IsNear(src, Config.ShowroomPos, 150.0) then return end

    Mission.pending = false
    Mission.active = true
    Mission.startedAt = os.time()
    ToMembers('mission:client:heistStart', Mission.owner, Mission.id)
end)

RegisterNetEvent('mission:server:registerEntity')
AddEventHandler('mission:server:registerEntity', function(key, payload)
    local src = source
    if not Mission.active or src ~= Mission.owner then return end
    if type(key) ~= 'string' then return end
    if not (key == 'thornton' or key == 'thornton_vehicle' or key == 'heist_demo_feltzer2' or key:match('^showroom_car_%d$')) then return end

    if Mission.entities[key] then return end -- une clé ne s'enregistre qu'une fois

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

    local id = Mission.id
    CreateThread(function()
        -- L'entité peut mettre un instant à exister côté serveur
        local ent = 0
        for _ = 1, 20 do
            ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then break end
            Wait(250)
        end
        if not Mission.active or Mission.id ~= id or Mission.entities[key] then return end
        if ent == 0 or not DoesEntityExist(ent) then return end
        if #(GetEntityCoords(ent) - Config.ShowroomPos) > 80.0 then return end
        local model, ok = GetEntityModel(ent), false
        for _, m in ipairs(expected) do
            if m and GetHashKey(m) == model then ok = true break end
        end
        if not ok then return end

        local clean = { netId = netId }
        if key:match('^showroom_car_%d$') then clean.idx = tonumber(key:match('%d$')) end
        Mission.entities[key] = (key == 'thornton') and netId or clean
        ToMembers('mission:client:entity', key, Mission.entities[key], Mission.id)
    end)
end)

-- netId enregistré pour une plaque du showroom
local function CarNetIdForPlate(plate)
    for i, car in ipairs(Cars) do
        if car.plate == plate then
            local e = Mission.entities['showroom_car_' .. i]
            return e and e.netId
        end
    end
    return nil
end

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
    if not Mission.active or not IsMember(src) then return end
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

    for member in pairs(Mission.members) do
        if includeSender == true or member ~= src then
            TriggerClientEvent('mission:client:relay', member, action, clean, src, includeSender == true, Mission.id)
        end
    end
end)

RegisterNetEvent('mission:server:syncMissionToPlayer')
AddEventHandler('mission:server:syncMissionToPlayer', function()
    local src = source
    if not Mission.active or not IsMember(src) then return end
    TriggerClientEvent('mission:client:heistStart', src, Mission.owner, Mission.id)
    for key, payload in pairs(Mission.entities) do
        TriggerClientEvent('mission:client:entity', src, key, payload, Mission.id)
    end
end)

-- ============================================================
-- ALERTES POLICE (cooldown, équipe uniquement)
-- ============================================================

RegisterNetEvent('mission:server:alertPoliceLocation')
AddEventHandler('mission:server:alertPoliceLocation', function()
    local src = source
    if not Mission.active or not IsMember(src) then return end
    if os.time() - lastShowroomAlert < Config.PoliceAlertCooldown then return end
    lastShowroomAlert = os.time()

    local coords = Config.ShowroomPos
    local policePlayers = GetPolicePlayers()
    for _, p in pairs(policePlayers) do
        TriggerClientEvent('grandtheftauto:client:ShowNotify', p, {
            title = "Braquage en cours",
            message = "Showroom Benefactor<br><span style='color:#2ecc71; font-weight:bold;'>[Y] Prendre l'appel</span>",
            duration = 20000
        })
        TriggerClientEvent('mission:client:policeShowroomBlip', p, coords)
    end

    SetTimeout(100000, function()
        for _, p in pairs(policePlayers) do
            TriggerClientEvent('mission:client:removeShowroomBlip', p)
        end
    end)
end)

RegisterNetEvent('mission:server:alertPolice')
AddEventHandler('mission:server:alertPolice', function()
    local src = source
    if not Mission.active or not IsMember(src) then return end
    if os.time() - lastTrackingAlert < Config.PoliceAlertCooldown then return end
    lastTrackingAlert = os.time()

    -- Les véhicules suivis viennent du serveur, pas du client
    local vehicleNetIds = {}
    for key, payload in pairs(Mission.entities) do
        if key:match('^showroom_car_%d$') and type(payload) == 'table' and payload.netId then
            table.insert(vehicleNetIds, payload.netId)
        end
    end

    local policePlayers = GetPolicePlayers()
    for _, p in pairs(policePlayers) do
        TriggerClientEvent('grandtheftauto:client:ShowNotify', p, {
            message = "Un <span style='color:#ECA95D; font-weight:bold;'>vol de véhicule</span> a été signalé dans la zone par un citoyen suspect, restez un moment pour plus d'informations.",
            duration = 10000
        })
    end

    trackingToken = trackingToken + 1
    local myToken = trackingToken
    CreateThread(function()
        local dureeEnSecondes = 100 -- durée du suivi GPS
        for _ = 1, dureeEnSecondes do
            if myToken ~= trackingToken then return end
            local trackingData = {}
            for _, netId in ipairs(vehicleNetIds) do
                local entity = NetworkGetEntityFromNetworkId(netId)
                if entity ~= 0 and DoesEntityExist(entity) then
                    table.insert(trackingData, { netId = netId, coords = GetEntityCoords(entity) })
                end
            end
            for _, p in pairs(GetPolicePlayers()) do
                TriggerClientEvent('mission:client:startPoliceTracking', p, trackingData)
            end
            Wait(1000)
        end
        if myToken == trackingToken then StopTracking() end
    end)
end)

RegisterNetEvent('mission:server:stopPoliceTracking')
AddEventHandler('mission:server:stopPoliceTracking', function()
    local src = source
    if not IsMember(src) or not IsNear(src, Config.DeliveryPos, 80.0) then return end
    StopTracking()
end)

-- ============================================================
-- VERROUS DE PIRATAGE (PCB)
-- ============================================================

local function IsLockExpired(lock)
    if not lock then return true end
    return (os.time() - (lock.t or 0)) > 300
end

RegisterNetEvent('mission:server:tryLockHack')
AddEventHandler('mission:server:tryLockHack', function(plate)
    local src = source
    if type(plate) ~= 'string' or not ValidPlates[plate] then return end
    if not Mission.active or not IsMember(src) then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "nomission")
        return
    end
    if HackCompleted[plate] then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "completed")
        return
    end
    local lock = HackLocks[plate]
    if lock and not IsLockExpired(lock) and lock.holder ~= src then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "locked")
        return
    end
    HackLocks[plate] = { holder = src, t = os.time() }
    TriggerClientEvent('mission:client:hackLockResult', src, plate, true, "ok")
    ToMembers('mission:client:hackState', plate, false, src)
end)

RegisterNetEvent('mission:server:releaseHackLock')
AddEventHandler('mission:server:releaseHackLock', function(plate)
    local src = source
    local lock = HackLocks[plate]
    if lock and (lock.holder == src or IsLockExpired(lock)) then
        HackLocks[plate] = nil
        ToMembers('mission:client:hackState', plate, false, nil)
    end
end)

-- Fin du piratage : le module pirate (pcb) est consommé ici, seulement en cas de réussite.
RegisterNetEvent('mission:server:finalizeHack')
AddEventHandler('mission:server:finalizeHack', function(plate, netId)
    local src = source
    if type(plate) ~= 'string' or not ValidPlates[plate] then return end
    local function reply(ok, reason) TriggerClientEvent('mission:client:finalizeResult', src, plate, ok, reason) end

    if not Mission.active or not IsMember(src) then return reply(false, 'nomission') end
    if HackCompleted[plate] then return reply(false, 'completed') end
    local lock = HackLocks[plate]
    if not lock or lock.holder ~= src then return reply(false, 'locked') end
    if not IsNear(src, Config.ShowroomPos, 60.0) then return reply(false, 'far') end

    -- La voiture doit être celle du showroom (pas un clone avec la même plaque), à côté du joueur
    local expectedNet = CarNetIdForPlate(plate)
    if not expectedNet or tonumber(netId) ~= expectedNet then return reply(false, 'badveh') end
    local veh = NetworkGetEntityFromNetworkId(expectedNet)
    if veh == 0 or not DoesEntityExist(veh) then return reply(false, 'badveh') end
    local pc = PedCoords(src)
    if not pc or #(pc - GetEntityCoords(veh)) > 8.0 then return reply(false, 'far') end

    if not RemoveItem(src, 'pcb', 1) then return reply(false, 'nopcb') end

    SetVehicleDoorsLocked(veh, 1) -- déverrouillée pour toute l'équipe, quel que soit le propriétaire réseau
    HackCompleted[plate] = true
    HackLocks[plate] = nil
    ToMembers('mission:client:hackState', plate, true, nil)
    reply(true, 'ok')
end)

RegisterNetEvent('mission:server:requestHackState')
AddEventHandler('mission:server:requestHackState', function()
    local src = source
    if not IsMember(src) then return end
    for plate in pairs(HackCompleted) do
        TriggerClientEvent('mission:client:hackState', src, plate, true, nil)
    end
    for plate, lock in pairs(HackLocks) do
        if lock and not IsLockExpired(lock) then
            TriggerClientEvent('mission:client:hackState', src, plate, false, lock.holder)
        end
    end
end)

-- ============================================================
-- LIVRAISON
-- ============================================================

RegisterNetEvent('mission:server:requestDeliverySlot')
AddEventHandler('mission:server:requestDeliverySlot', function()
    local src = source
    if not Mission.active or not IsMember(src) then return end

    -- Libère les emplacements oubliés (plus de 15 min)
    for i, slot in pairs(DeliverySlots) do
        if os.time() - slot.t > 900 then DeliverySlots[i] = nil end
    end

    -- Un seul camion à la fois par joueur
    for i, slot in pairs(DeliverySlots) do
        if slot.src == src then
            TriggerClientEvent('mission:client:receiveDeliverySlot', src, nil)
            return
        end
    end

    local slotIndex = nil
    for i = 1, #Config.DeliverySlots do
        if not DeliverySlots[i] then
            DeliverySlots[i] = { src = src, t = os.time() }
            slotIndex = i
            break
        end
    end
    TriggerClientEvent('mission:client:receiveDeliverySlot', src, slotIndex)
end)

local function CheckEnd()
    if not Mission.active then return end
    local completed = 0
    for _ in pairs(HackCompleted) do completed = completed + 1 end
    if Mission.deliveredCount >= #Cars then
        EndMission('done')
        return
    end
    -- Toutes les voitures piratées sont livrées : 5 min pour en voler une autre, sinon fin.
    if completed > 0 and Mission.deliveredCount >= completed then
        local id = Mission.id
        Mission.endCheck = id
        for member in pairs(Mission.members) do
            Notify(member, "Plus de voiture en route : le casse se termine dans <span style='color:#ECA95D; font-weight:bold;'>5 min</span> si vous n'en volez pas une autre.", 9000)
        end
        SetTimeout(5 * 60 * 1000, function()
            if Mission.active and Mission.id == id and Mission.endCheck == id then
                local c = 0
                for _ in pairs(HackCompleted) do c = c + 1 end
                if Mission.deliveredCount >= c then EndMission('done') end
            end
        end)
    end
end

RegisterNetEvent('mission:server:delivered')
AddEventHandler('mission:server:delivered', function(netId, slotIndex)
    local src = source
    netId = tonumber(netId)
    slotIndex = tonumber(slotIndex)
    local function reply(ok) TriggerClientEvent('mission:client:deliveredResult', src, slotIndex, ok) end

    if not Mission.active or not IsMember(src) or not netId or not slotIndex then return reply(false) end
    local slotCfg = Config.DeliverySlots[slotIndex]
    if not slotCfg then return reply(false) end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return reply(false) end

    local plate = (GetVehicleNumberPlateText(veh) or ''):match("^%s*(.-)%s*$")
    if not ValidPlates[plate] or not HackCompleted[plate] or Mission.delivered[plate] then return reply(false) end
    if CarNetIdForPlate(plate) ~= netId then return reply(false) end
    if #(GetEntityCoords(veh) - slotCfg.pos) > 15.0 then return reply(false) end
    if not IsNear(src, slotCfg.pos, 40.0) then return reply(false) end

    Mission.delivered[plate] = true
    Mission.deliveredCount = Mission.deliveredCount + 1
    DeliverySlots[slotIndex] = nil

    -- Le joueur sort du véhicule avant la suppression
    for seat = -1, 6 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 then TaskLeaveVehicle(p, veh, 16) end
    end
    SetTimeout(1500, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end)

    local paid = PayPlayer(src, Config.RewardPerCar)
    if paid then
        Notify(src, ("Svetlana vous a payé <span style='color:#2ecc71; font-weight:bold;'>%d $</span>%s."):format(Config.RewardPerCar, paid == 'bank' and " (sur votre compte en banque)" or ""), 8000)
    end
    for member in pairs(Mission.members) do
        if member ~= src then
            Notify(member, "Une <span style='color:#ECA95D; font-weight:bold;'>sportive</span> a été livrée par l'équipe.", 6000)
        end
    end
    reply(true)
    CheckEnd()
end)

-- ============================================================
-- FIN DE MISSION : départ du chef, délai dépassé
-- ============================================================

AddEventHandler('playerDropped', function()
    local src = source
    for plate, lock in pairs(HackLocks) do
        if lock and lock.holder == src then
            HackLocks[plate] = nil
            ToMembers('mission:client:hackState', plate, false, nil)
        end
    end
    for i, slot in pairs(DeliverySlots) do
        if slot.src == src then DeliverySlots[i] = nil end
    end
    if Mission.members[src] then
        Mission.members[src] = nil
        if Mission.owner == src then
            EndMission('owner_left')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        if Mission.active and os.time() - Mission.startedAt > Config.MissionDuration then
            EndMission('timeout')
        elseif Mission.pending and os.time() - Mission.createdAt > Config.PendingDuration then
            EndMission('timeout')
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if Mission.active or Mission.pending then EndMission('stop') end
end)
