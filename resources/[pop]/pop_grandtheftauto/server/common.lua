-- Fonctions et état communs du serveur (mission, équipe, outils).
-- Tout passe par le bridge (Bridge.*) : argent, objets, job, distance.

GTA = {}

GTA.ValidPlates = {}
for _, car in ipairs(Cars) do GTA.ValidPlates[car.plate] = true end

-- ============================================================
-- OUTILS
-- ============================================================

function GTA.Notify(src, message, duration)
    Bridge.Notify(src, { message = message, icon = Config.NotifyIcon, duration = duration or 7000 })
end

function GTA.GetPolicePlayers()
    local list = {}
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Bridge.HasJob(src, Config.PoliceJobs) then list[#list + 1] = src end
    end
    return list
end

-- Paiement : cash d'abord (objet cash de pop_inventory), sinon compte banque.
function GTA.PayPlayer(src, amount)
    if Bridge.AddMoney(src, 'cash', amount, 'pop_grandtheftauto') then return 'cash' end
    if Bridge.AddMoney(src, 'bank', amount, 'pop_grandtheftauto') then return 'bank' end
    return nil
end

-- ============================================================
-- ÉTAT DE LA MISSION
-- ============================================================

GTA.cooldownUntil = 0
GTA.trackingToken = 0
GTA.lastShowroomAlert, GTA.lastTrackingAlert = 0, 0

function GTA.ResetState()
    GTA.Mission = {
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
    GTA.HackLocks = {}
    GTA.HackCompleted = {}
    GTA.DeliverySlots = {}
end
GTA.ResetState()

function GTA.IsMember(src)
    return GTA.Mission.members[src] == true
end

function GTA.MemberCount()
    local n = 0
    for _ in pairs(GTA.Mission.members) do n = n + 1 end
    return n
end

function GTA.ToMembers(eventName, ...)
    for src in pairs(GTA.Mission.members) do
        TriggerClientEvent(eventName, src, ...)
    end
end

function GTA.StopTracking()
    GTA.trackingToken = GTA.trackingToken + 1
    for _, src in pairs(GTA.GetPolicePlayers()) do
        TriggerClientEvent('mission:client:stopPoliceTracking', src)
    end
end

function GTA.EndMission(reason)
    local Mission = GTA.Mission
    if not Mission.active and not Mission.pending then return end
    local wasActive = Mission.active

    -- Nettoyage des entités de la mission (sauf voitures déjà livrées, supprimées avant)
    for _, payload in pairs(Mission.entities) do
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

    GTA.ToMembers('mission:client:reset', reason or 'end')
    if wasActive then GTA.StopTracking() end

    GTA.cooldownUntil = os.time() + (wasActive and Config.Cooldown or 60)
    GTA.ResetState()
end

-- Kit (flipper + pcb) : une fois par joueur et par période de cooldown (anti-farm)
local KitGiven = {}
function GTA.GiveKit(src)
    if not Config.GiveKit then return end
    local id = GetPlayerIdentifierByType(src, 'license') or Bridge.GetIdentifier(src) or ('src:' .. src)
    if KitGiven[id] and os.time() - KitGiven[id] < Config.Cooldown then return end
    KitGiven[id] = os.time()
    if Bridge.GetItemCount(src, 'flipper') < 1 then Bridge.AddItem(src, 'flipper', 1) end
    if Bridge.GetItemCount(src, 'pcb') < 1 then Bridge.AddItem(src, 'pcb', 1) end
end

function GTA.NewHeistId(src)
    return string.format("%d_%d", os.time(), src or 0)
end

-- netId enregistré pour une plaque du showroom
function GTA.CarNetIdForPlate(plate)
    for i, car in ipairs(Cars) do
        if car.plate == plate then
            local e = GTA.Mission.entities['showroom_car_' .. i]
            return e and e.netId
        end
    end
    return nil
end

function GTA.IsLockExpired(lock)
    if not lock then return true end
    return (os.time() - (lock.t or 0)) > 300
end
