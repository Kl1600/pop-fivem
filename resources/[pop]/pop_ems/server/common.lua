-- pop_ems : état partagé du serveur et helpers communs.
-- Le serveur est seul juge : job, service, distance, objets, argent et durée des actions.

Ems = {}

Ems.duty        = {}  -- [src] = stationIndex
Ems.vehicles    = {}  -- [src] = netId
Ems.calls       = {}  -- [id] = { id, patient, coords, time, status, medic, medicName }
Ems.actions     = {}  -- [src] = { target, action, started, vehicle }
Ems.transported = {}  -- [patient] = { vehicle = netId, medic = src }
Ems.lastAction  = {}  -- [src] = GetGameTimer() du dernier finish réussi

local RES = GetCurrentResourceName()

--- Log console, seulement si Config.Debug.
function Ems.log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

--- Vrai si le joueur est connecté.
function Ems.isOnline(src)
    src = math.tointeger(tonumber(src))
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

------------------------------------------------------------------------
-- Véhicules de service
------------------------------------------------------------------------

-- Hashes des modèles de Config.Vehicles (normalisés en non signé : GetEntityModel et joaat
-- peuvent différer de signe).
local SERVICE_MODELS = {}
for _, v in ipairs(Config.Vehicles) do
    SERVICE_MODELS[joaat(v.model) & 0xFFFFFFFF] = true
end

--- Entité d'un véhicule de service à partir d'un netId client, ou nil (existence + modèle vérifiés).
function Ems.getServiceEntity(netId)
    if math.type(netId) ~= 'integer' or netId <= 0 then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if not SERVICE_MODELS[GetEntityModel(veh) & 0xFFFFFFFF] then return nil end
    return veh
end

--- Vrai si le netId a été créé par pop_ems pour un secouriste (n'importe lequel).
function Ems.isServiceVehicle(netId)
    for _, id in pairs(Ems.vehicles) do
        if id == netId then return true end
    end
    return false
end

--- Patient attaché à ce véhicule (netId), ou nil.
function Ems.patientInVehicle(netId)
    for patient, t in pairs(Ems.transported) do
        if t.vehicle == netId then return patient end
    end
    return nil
end

--- Libère le transport d'un patient : statebags remis à nil, détache côté client si demandé.
function Ems.releaseTransport(patient, sendDetach)
    local t = Ems.transported[patient]
    if not t then return end
    Ems.transported[patient] = nil
    local veh = NetworkGetEntityFromNetworkId(t.vehicle)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        Entity(veh).state:set('popEmsPatient', nil, true)
    end
    if GetPlayerName(patient) then
        Player(patient).state:set('popEmsTransport', nil, true)
        if sendDetach then TriggerClientEvent('pop_ems:client:detach', patient) end
    end
end

--- Supprime le véhicule de service d'un secouriste (le patient éventuel est détaché avant).
function Ems.deleteVehicle(src)
    local netId = Ems.vehicles[src]
    if not netId then return end
    Ems.vehicles[src] = nil
    local patient = Ems.patientInVehicle(netId)
    if patient then Ems.releaseTransport(patient, true) end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
    Ems.log('vehicle of %s deleted', src)
end

------------------------------------------------------------------------
-- Framework direct (autorisé ici seulement par la SPEC) : service QB et argent de société.
------------------------------------------------------------------------

local function started(name)
    return GetResourceState(name) == 'started'
end

--- Service QBCore / Qbox (job.onduty). Sans effet sur ESX et standalone.
function Ems.setFrameworkDuty(src, state)
    if Bridge.Framework ~= 'qbcore' and Bridge.Framework ~= 'qbox' then return end
    pcall(function()
        local player
        if Bridge.Framework == 'qbox' then
            player = exports.qbx_core:GetPlayer(src)
        else
            player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
        end
        if player and player.Functions and player.Functions.SetJobDuty then
            player.Functions.SetJobDuty(state == true)
        end
    end)
end

--- Crédite la société Config.Job.name. Renvoie true si un système de société a été crédité.
function Ems.addSocietyMoney(amount)
    local society = Config.Job.name
    if Bridge.Framework == 'esx' then
        if not started('esx_addonaccount') then return false end
        local credited = false
        pcall(function()
            -- Callback synchrone dans esx_addonaccount.
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. society, function(account)
                if account then
                    account.addMoney(amount)
                    credited = true
                end
            end)
        end)
        return credited
    elseif Bridge.Framework == 'qbcore' then
        if started('qb-banking') then
            local ok, res = pcall(function() return exports['qb-banking']:AddMoney(society, amount, 'pop_ems') end)
            if ok and res ~= false then return true end
        end
        if started('qb-management') then
            -- NOTE: qb-management:AddMoney ne renvoie rien ; aucune erreur = crédité.
            local ok, res = pcall(function() return exports['qb-management']:AddMoney(society, amount) end)
            if ok and res ~= false then return true end
        end
    elseif Bridge.Framework == 'qbox' then
        if started('Renewed-Banking') then
            local ok, res = pcall(function() return exports['Renewed-Banking']:addAccountMoney(society, amount) end)
            if ok and res ~= false then return true end
        end
        if started('qb-banking') then
            local ok, res = pcall(function() return exports['qb-banking']:AddMoney(society, amount, 'pop_ems') end)
            if ok and res ~= false then return true end
        end
    end
    return false
end

------------------------------------------------------------------------
-- Job, service, état du patient
------------------------------------------------------------------------

--- Job EMS (grade minimum) ou ACE pop.ems (standalone ou serveur qui le souhaite).
function Ems.isMedic(src)
    if not Ems.isOnline(src) then return false end
    if Bridge.HasJob(src, { [Config.Job.name] = Config.Job.minGrade }) then return true end
    return IsPlayerAceAllowed(tostring(src), 'pop.ems') == true
end

--- Nombre d'EMS en service.
function Ems.dutyCount()
    local n = 0
    for _ in pairs(Ems.duty) do n = n + 1 end
    return n
end

--- Libère les appels pris par ce secouriste (repassent en attente). Renvoie true si changement.
function Ems.releaseCallsOf(src)
    local changed = false
    for _, c in pairs(Ems.calls) do
        if c.medic == src then
            c.status, c.medic, c.medicName = 'pending', nil, nil
            changed = true
        end
    end
    return changed
end

--- Ferme l'appel ouvert d'un patient. Renvoie true si un appel a été fermé.
function Ems.closeCallOf(patient)
    for id, c in pairs(Ems.calls) do
        if c.patient == patient then
            Ems.calls[id] = nil
            return true
        end
    end
    return false
end

--- Fin de service : véhicule supprimé, appels libérés, action annulée.
--- forced = true : le client est prévenu (pop_ems:client:dutyOff).
function Ems.endDuty(src, forced)
    if not Ems.duty[src] then
        Ems.deleteVehicle(src)
        return
    end
    Ems.duty[src] = nil
    Ems.actions[src] = nil
    Ems.deleteVehicle(src)
    -- Patients chargés par ce secouriste dans une autre ambulance : détachés.
    for patient, t in pairs(Ems.transported) do
        if t.medic == src then Ems.releaseTransport(patient, true) end
    end
    if GetPlayerName(src) then
        Player(src).state:set('popEmsDuty', false, true)
        Ems.setFrameworkDuty(src, false)
        if forced then TriggerClientEvent('pop_ems:client:dutyOff', src) end
    end
    if Ems.releaseCallsOf(src) then Ems.broadcastCalls(nil) end
    Ems.log('%s off duty%s', src, forced and ' (forced)' or '')
end

--- En service et toujours EMS. Perte du job : fin de service forcée.
function Ems.isOnDuty(src)
    if not Ems.duty[src] then return false end
    if not Ems.isMedic(src) then
        Ems.endDuty(src, true)
        return false
    end
    return true
end

--- Mort ou à terre : pop_death s'il est lancé, ou état du framework / santé du ped.
function Ems.isDead(src)
    if not Ems.isOnline(src) then return false end
    if started('pop_death') then
        local ok, dead = pcall(function() return exports.pop_death:isDead(src) end)
        if ok and dead == true then return true end
    end
    return Bridge.IsDead(src)
end

------------------------------------------------------------------------
-- Facture
------------------------------------------------------------------------

--- Facture un soin réussi au patient (banque, sinon liquide) et crédite la société ou le secouriste.
function Ems.bill(patient, medic, kind)
    local price = tonumber(Config.Prices[kind]) or 0
    if price <= 0 or Bridge.Framework == 'standalone' then return end
    price = math.floor(price)
    local paid = Bridge.RemoveMoney(patient, 'bank', price, 'pop_ems')
        or Bridge.RemoveMoney(patient, 'cash', price, 'pop_ems')
    if not paid then
        Bridge.Notify(medic, L('bill_unpaid'), 'warning')
        Ems.log('bill %s: %s could not pay %d', kind, patient, price)
        return
    end
    if not Ems.addSocietyMoney(price) then
        Bridge.AddMoney(medic, 'bank', price, 'pop_ems')
    end
    Bridge.Notify(patient, L('billed_you', price), 'info')
    Bridge.Notify(medic, L('bill_paid', price), 'success')
    Ems.log('bill %s: %s paid %d (medic %s)', kind, patient, price, medic)
end

------------------------------------------------------------------------
-- Diffusion des appels
------------------------------------------------------------------------

-- Liste triée du plus récent au plus ancien, personnalisée pour `src`.
local function callsFor(src, sorted)
    local list = {}
    for i, c in ipairs(sorted) do
        list[i] = {
            id = c.id, coords = c.coords, time = c.time, status = c.status,
            medic = c.medicName, mine = c.medic == src,
        }
    end
    return list
end

local function sortedCalls()
    local sorted = {}
    for _, c in pairs(Ems.calls) do sorted[#sorted + 1] = c end
    table.sort(sorted, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return a.id > b.id
    end)
    return sorted
end

--- Envoie la liste des appels à un EMS (ou à tous ceux en service si src est nil).
function Ems.sendCalls(src, newId)
    local sorted = sortedCalls()
    if src then
        TriggerClientEvent('pop_ems:client:calls', src, callsFor(src, sorted), newId)
        return
    end
    for medic in pairs(Ems.duty) do
        TriggerClientEvent('pop_ems:client:calls', medic, callsFor(medic, sorted), newId)
    end
end

--- Rediffuse les appels à tous les EMS en service.
function Ems.broadcastCalls(newId)
    Ems.sendCalls(nil, newId)
end

------------------------------------------------------------------------
-- Exports d'état
------------------------------------------------------------------------

exports('isOnDuty', function(src)
    src = tonumber(src)
    return src ~= nil and Ems.isOnDuty(math.tointeger(src) or -1) or false
end)

exports('getOnDutyCount', function()
    return Ems.dutyCount()
end)
