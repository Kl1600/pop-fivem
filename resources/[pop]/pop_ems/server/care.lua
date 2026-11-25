-- pop_ems : soins sur un joueur. Chaque action = begin (contrôles, chrono serveur) → finish (re-contrôles, effet).

local ACTIONS = { diagnose = true, bandage = true, kit = true, revive = true, load = true }

-- Objet exigé par action (clé de Config.Items) ; consumed = retiré au finish.
local ITEMS = {
    bandage = { key = 'bandage', consumed = true },
    kit     = { key = 'kit', consumed = true },
    revive  = { key = 'defib', consumed = false },
}

local PARTS = { 'head', 'torso', 'leftArm', 'rightArm', 'leftLeg', 'rightLeg' }

local function duration(action)
    return math.floor(tonumber(Config.Durations[action]) or 0)
end

-- Action périmée (abandonnée par le client) : au-delà de durée + 30 s.
local function isStale(a)
    return GetGameTimer() - a.started > duration(a.action) + 30000
end

local function itemFor(action)
    local def = ITEMS[action]
    if not def then return nil, false end
    local name = Config.Items[def.key]
    if not name then return nil, false end -- false dans la config : aucun objet exigé
    return name, def.consumed
end

local function injury(target)
    local st = Player(target).state.popEmsInjury
    return type(st) == 'table' and st or {}
end

--- Contrôles communs à begin et finish (distance, état du patient, objet, véhicule).
--- Renvoie true, ou false + clé de locale (+ argument éventuel).
local function check(src, target, action, vehicleNetId)
    local tpos = Bridge.GetCoords(target)
    if not tpos or not Bridge.IsNear(src, tpos, Config.Distances.interact) then return false, 'too_far' end

    local dead = Ems.isDead(target)
    if action == 'kit' and dead then return false, 'patient_dead' end
    if (action == 'revive' or action == 'load') and not dead then return false, 'patient_not_dead' end
    if action == 'revive' and Config.Injuries.enabled and injury(target).bleeding == true then
        return false, 'patient_bleeding'
    end

    if action == 'load' then
        if Ems.transported[target] then return false, 'patient_busy' end
        local veh = Ems.getServiceEntity(vehicleNetId)
        if not veh or not Ems.isServiceVehicle(vehicleNetId) then return false, 'no_vehicle' end
        if not Bridge.IsNear(src, GetEntityCoords(veh), Config.Distances.vehicle) then return false, 'no_vehicle' end
        if Ems.patientInVehicle(vehicleNetId) or Entity(veh).state.popEmsPatient ~= nil then
            return false, 'patient_busy'
        end
    end

    local item = itemFor(action)
    if item and not Bridge.HasItem(src, item, 1) then return false, 'missing_item', item end
    return true
end

-- Vrai si un autre secouriste traite déjà cette cible.
local function targetBusy(src, target)
    for medic, a in pairs(Ems.actions) do
        if medic ~= src and a.target == target then
            if isStale(a) then
                Ems.actions[medic] = nil
            else
                return true
            end
        end
    end
    return false
end

-- Secondes restantes de cooldown (0 si libre).
local function cooldownLeft(src)
    local last = Ems.lastAction[src]
    if not last then return 0 end
    local left = Config.ActionCooldown * 1000 - (GetGameTimer() - last)
    return left > 0 and math.ceil(left / 1000) or 0
end

------------------------------------------------------------------------
-- Diagnostic (lu côté serveur)
------------------------------------------------------------------------

local function diagnose(target)
    local dead = Ems.isDead(target)
    local health = 0
    if not dead then
        local ped = GetPlayerPed(target)
        local hp = GetEntityHealth(ped)
        local ok, maxHp = pcall(GetEntityMaxHealth, ped)
        maxHp = ok and tonumber(maxHp) or 200
        if maxHp <= 100 then maxHp = 200 end
        health = math.floor((hp - 100) / (maxHp - 100) * 100 + 0.5)
        health = math.max(0, math.min(100, health))
    end

    local inj = injury(target)
    local result = { dead = dead, health = health, bleeding = inj.bleeding == true, limp = inj.limp == true }

    -- Zones de pop_medexam (statebag client) : nombres bornés, rien d'autre n'est renvoyé.
    if GetResourceState('pop_medexam') == 'started' then
        local med = Player(target).state.medInjuries
        if type(med) == 'table' then
            local parts = {}
            for _, p in ipairs(PARTS) do
                local v = tonumber(med[p]) or 100
                parts[p] = math.max(0, math.min(100, math.floor(v)))
            end
            result.parts = parts
        end
    end
    return result
end

------------------------------------------------------------------------
-- Réanimation (partagée avec l'export)
------------------------------------------------------------------------

local function revive(target, medic)
    if Ems.transported[target] then Ems.releaseTransport(target, false) end -- le client se détache seul
    TriggerClientEvent('pop_ems:client:revived', target, Config.ReviveHealth)
    if Ems.closeCallOf(target) then Ems.broadcastCalls(nil) end
    TriggerEvent('pop_ems:revived', target, medic)
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_ems:begin', function(src, targetId, action, vehicleNetId)
    if type(action) ~= 'string' or not ACTIONS[action] then return false, 'error' end
    if math.type(targetId) ~= 'integer' or not GetPlayerName(targetId) then return false, 'error' end
    if action == 'load' and math.type(vehicleNetId) ~= 'integer' then return false, 'no_vehicle' end
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    if targetId == src then return false, 'patient_self' end

    local current = Ems.actions[src]
    if current then
        if isStale(current) then Ems.actions[src] = nil else return false, 'busy' end
    end
    local left = cooldownLeft(src)
    if left > 0 then return false, 'cooldown', left end -- NOTE: 3e valeur = secondes pour L('cooldown', s)
    if targetBusy(src, targetId) then return false, 'patient_busy' end

    local ok, err, arg = check(src, targetId, action, vehicleNetId)
    if not ok then return false, err, arg end

    Ems.actions[src] = {
        target = targetId, action = action, started = GetGameTimer(),
        vehicle = action == 'load' and vehicleNetId or nil,
    }
    return true, duration(action)
end)

Callback.Register('pop_ems:finish', function(src, targetId, action)
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    local a = Ems.actions[src]
    if not a or a.target ~= targetId or a.action ~= action then return false, 'error' end

    -- Une seule tentative par begin : l'action est effacée quoi qu'il arrive.
    Ems.actions[src] = nil
    local elapsed = GetGameTimer() - a.started
    local dur = duration(action)
    if elapsed < dur - 500 or elapsed > dur + 30000 then
        Ems.log('finish %s refused for %s (elapsed %d ms)', action, src, elapsed)
        return false, 'error'
    end
    if not GetPlayerName(targetId) then return false, 'error' end
    if cooldownLeft(src) > 0 then return false, 'cooldown', cooldownLeft(src) end

    local ok, err, arg = check(src, targetId, action, a.vehicle)
    if not ok then return false, err, arg end

    -- Objet consommé : l'action échoue si le retrait échoue.
    local item, consumed = itemFor(action)
    if item and consumed and not Bridge.RemoveItem(src, item, 1) then return false, 'missing_item', item end

    local result
    if action == 'diagnose' then
        result = diagnose(targetId)
    elseif action == 'bandage' then
        TriggerClientEvent('pop_ems:client:treated', targetId, 'bandage')
        Ems.bill(targetId, src, 'bandage')
    elseif action == 'kit' then
        TriggerClientEvent('pop_ems:client:treated', targetId, 'kit')
        if GetResourceState('pop_medexam') == 'started' then
            TriggerClientEvent('pop_medexam:treated', targetId)
        end
        Ems.bill(targetId, src, 'kit')
    elseif action == 'revive' then
        revive(targetId, src)
        Ems.bill(targetId, src, 'revive')
    elseif action == 'load' then
        local netId = a.vehicle
        local veh = Ems.getServiceEntity(netId)
        Ems.transported[targetId] = { vehicle = netId, medic = src }
        Entity(veh).state:set('popEmsPatient', targetId, true)
        Player(targetId).state:set('popEmsTransport', netId, true)
        TriggerClientEvent('pop_ems:client:attach', targetId, netId)
        Ems.ensureLoop()
    end

    Ems.lastAction[src] = GetGameTimer()
    Ems.log('%s did %s on %s', src, action, targetId)
    return true, result
end)

------------------------------------------------------------------------
-- Export : réanimation forcée (scripts serveur uniquement, ex. admin)
------------------------------------------------------------------------

exports('revive', function(src)
    src = math.tointeger(tonumber(src))
    if not src or not GetPlayerName(src) then return false end
    revive(src, nil)
    Ems.log('%s revived by export', src)
    return true
end)
