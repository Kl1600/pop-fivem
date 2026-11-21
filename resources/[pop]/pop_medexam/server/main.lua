-- pop_medexam : serveur. Sessions d'examen (borne auto et EMS), délivrance du certificat, exports.
-- Le client n'envoie qu'un index de lieu et, en fin d'examen auto, un booléen : tout le reste est décidé ici.

local ACTION_DISTANCE  = 3.0 -- joueur <-> lieu
local PATIENT_DISTANCE = 3.0 -- médecin <-> patient
local SHOW_DISTANCE    = 3.0 -- joueurs qui voient la carte
local SHOW_THROTTLE    = 2   -- secondes entre deux affichages de carte par joueur

local sessions    = {} -- [src] = { loc, startedAt }                      (auto)
local emsSessions = {} -- [doctorSrc] = { loc, patient, startedAt }
local patientOf   = {} -- [patientSrc] = doctorSrc
local cooldowns   = {} -- [identifier] = os.time() de fin
local busy        = {} -- [src] = true pendant un traitement
local lastShow    = {} -- [src] = os.time()

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function debug(msg, ...)
    if Config.Debug then print(('[pop_medexam] ' .. msg):format(...)) end
end

-- Entier >= 0 lu dans la config.
local function amount(n)
    n = tonumber(n) or 0
    if n ~= n or n < 0 then return 0 end
    return math.floor(math.min(n, 2147483647))
end

local PRICE = amount(Config.Price)

local function charge(src)
    if PRICE <= 0 then return true end
    return Bridge.RemoveMoney(src, Config.Account, PRICE, 'pop_medexam')
end

local function refund(src, identifier)
    if PRICE <= 0 or not src or Bridge.GetIdentifier(src) ~= identifier then return end
    if not Bridge.AddMoney(src, Config.Account, PRICE, 'pop_medexam') then
        debug('refund failed for %s (%s)', src, PRICE)
    end
end

local function location(loc)
    if math.type(loc) ~= 'integer' then return nil end
    local l = Config.Locations[loc]
    return l and l.coords or nil
end

local function inSession(src)
    return busy[src] or sessions[src] ~= nil or emsSessions[src] ~= nil or patientOf[src] ~= nil
end

local function onCooldown(id)
    local now = os.time()
    local untilAt = cooldowns[id]
    if untilAt and untilAt > now then return untilAt - now end
    cooldowns[id] = nil
    return nil
end

local function setCooldown(id)
    if id and amount(Config.Cooldown) > 0 then cooldowns[id] = os.time() + amount(Config.Cooldown) end
end

local function distance(a, b)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return math.huge end
    local pa, pb = Bridge.GetCoords(a), Bridge.GetCoords(b)
    if not pa or not pb then return math.huge end
    return #(pa - pb)
end

local function isDoctor(src)
    if Config.Mode == 'auto' then return false end
    if not Bridge.HasJob(src, Config.EmsJobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

local function emsOnDuty()
    for _, p in ipairs(Bridge.GetPlayers()) do
        if isDoctor(tonumber(p)) then return true end
    end
    return false
end

local function autoOpen()
    if Config.Mode == 'auto' then return true end
    return Config.Mode == 'mixed' and not emsOnDuty()
end

-- Verrou busy[src] pendant fn ; toujours libéré, même en cas d'erreur.
local function locked(src, starting, fn)
    if busy[src] or (starting and inSession(src)) then return false, 'busy' end
    busy[src] = true
    local res = table.pack(pcall(fn))
    busy[src] = nil
    if not res[1] then
        print(('[pop_medexam] error: %s'):format(tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

------------------------------------------------------------------------
-- Certificat
------------------------------------------------------------------------

local function isValid(expires)
    expires = tonumber(expires)
    if not expires then return false end
    return expires == 0 or expires > os.time()
end

local function formatDate(t)
    return os.date('%Y-%m-%d', t)
end

--- Remet un certificat au patient. Renvoie true si l'item a été ajouté.
local function issue(patient, doctorName)
    local metadata = nil
    if Bridge.SupportsMetadata() then
        local now = os.time()
        local days = math.min(36500, amount(Config.Validity))
        local expires = days > 0 and now + days * 86400 or 0
        local name = Bridge.GetName(patient) or GetPlayerName(patient) or ''
        metadata = {
            name = name,
            issued = now,
            expires = expires,
            doctor = doctorName or L('auto_doctor'),
            description = L('cert_description', name, expires > 0 and formatDate(expires) or L('card_no_expiry')),
        }
    end
    local ok = Bridge.AddItem(patient, Config.Item, 1, metadata)
    if ok then debug('certificate issued to %s by %s', patient, tostring(doctorName)) end
    return ok
end

------------------------------------------------------------------------
-- État
------------------------------------------------------------------------

Callback.Register('pop_medexam:getState', function(src, _loc)
    return autoOpen(), isDoctor(src)
end)

------------------------------------------------------------------------
-- Mode auto
------------------------------------------------------------------------

Callback.Register('pop_medexam:start', function(src, loc)
    return locked(src, true, function()
        local coords = location(loc)
        if not coords then return false, 'error' end
        if not Bridge.IsNear(src, coords, ACTION_DISTANCE) then return false, 'too_far' end
        local id = Bridge.GetIdentifier(src)
        if not id or Bridge.IsDead(src) then return false, 'error' end
        if not autoOpen() then return false, 'exam_closed' end
        local wait = onCooldown(id)
        if wait then return false, 'cooldown', wait end
        if not Bridge.CanCarry(src, Config.Item, 1) then return false, 'inventory_full' end
        if not charge(src) then return false, 'not_enough_money' end
        sessions[src] = { loc = loc, startedAt = os.time(), identifier = id }
        debug('auto exam started by %s at %d', src, loc)
        return true
    end)
end)

Callback.Register('pop_medexam:finish', function(src, passed)
    return locked(src, false, function()
        local s = sessions[src]
        if not s then return false, 'no_session' end
        local id = Bridge.GetIdentifier(src)
        if id ~= s.identifier or Bridge.IsDead(src) or type(passed) ~= 'boolean' then return false, 'error' end

        local minTime = math.floor(amount(Config.Durations.pressure) / 1000) + 2
        if os.time() - s.startedAt < minTime then
            sessions[src] = nil
            debug('auto exam too fast for %s', src)
            return false, 'exam_too_fast'
        end
        if not Bridge.IsNear(src, Config.Locations[s.loc].coords, ACTION_DISTANCE) then
            -- NOTE: SPEC muette sur ce cas : session close et visite remboursée (aucun gain possible pour le joueur).
            sessions[src] = nil
            refund(src, s.identifier)
            return false, 'too_far'
        end

        sessions[src] = nil
        setCooldown(id)
        if passed ~= true then return false, 'exam_failed' end

        if not issue(src, L('auto_doctor')) then
            refund(src, s.identifier)
            return false, 'inventory_full'
        end
        Bridge.Notify(src, L('exam_passed'), 'success')
        return true
    end)
end)

Callback.Register('pop_medexam:cancel', function(src)
    return locked(src, false, function()
        local s = sessions[src]
        if s then
            sessions[src] = nil
            refund(src, s.identifier)
        end
        return true
    end)
end)

------------------------------------------------------------------------
-- Mode EMS
------------------------------------------------------------------------

-- Joueur le plus proche du médecin, libre et vivant, à <= PATIENT_DISTANCE.
local function nearestPatient(doctor)
    local origin = Bridge.GetCoords(doctor)
    if not origin then return nil end
    local best, bestDist = nil, PATIENT_DISTANCE
    for _, p in ipairs(Bridge.GetPlayers()) do
        p = tonumber(p)
        if p and p ~= doctor and not inSession(p) and not Bridge.IsDead(p)
            and GetPlayerRoutingBucket(p) == GetPlayerRoutingBucket(doctor) then
            local pos = Bridge.GetCoords(p)
            if pos then
                local d = #(pos - origin)
                if d <= bestDist then best, bestDist = p, d end
            end
        end
    end
    return best
end

Callback.Register('pop_medexam:emsStart', function(src, loc)
    return locked(src, true, function()
        local coords = location(loc)
        if not coords then return false, 'error' end
        if not Bridge.IsNear(src, coords, ACTION_DISTANCE) then return false, 'too_far' end
        local doctorId = Bridge.GetIdentifier(src)
        if not doctorId or Bridge.IsDead(src) then return false, 'error' end
        if not isDoctor(src) then return false, 'wrong_job' end

        local patient = nearestPatient(src)
        if not patient then return false, 'no_patient' end
        local pid = Bridge.GetIdentifier(patient)
        if not pid then return false, 'no_patient' end
        local wait = onCooldown(pid)
        if wait then return false, 'cooldown', wait end
        if not Bridge.CanCarry(patient, Config.Item, 1) then return false, 'inventory_full' end

        return locked(patient, true, function()
            local accepted = Callback.Await('pop_medexam:consent', patient, PRICE,
                Bridge.GetName(src) or GetPlayerName(src) or '')
            if accepted ~= true then return false, 'patient_refused' end

            -- Le consentement peut être différé. Revérifier les deux personnages avant de débiter le patient.
            if Bridge.GetIdentifier(patient) ~= pid or Bridge.IsDead(patient) then
                return false, 'patient_gone'
            end
            if Bridge.GetIdentifier(src) ~= doctorId or Bridge.IsDead(src) then return false, 'error' end
            if not isDoctor(src) then return false, 'wrong_job' end
            if not Bridge.IsNear(src, coords, ACTION_DISTANCE) then return false, 'too_far' end
            if distance(src, patient) > PATIENT_DISTANCE then return false, 'patient_gone' end
            if not Bridge.CanCarry(patient, Config.Item, 1) then return false, 'inventory_full' end

            if not charge(patient) then
                Bridge.Notify(patient, L('not_enough_money'), 'error')
                return false, 'not_enough_money'
            end

            emsSessions[src] = {
                loc = loc, patient = patient, patientId = pid, doctorId = doctorId, startedAt = os.time(),
            }
            patientOf[patient] = src
            local patientName = Bridge.GetName(patient) or GetPlayerName(patient) or ''
            Bridge.Notify(src, L('exam_started', patientName), 'info')
            debug('ems exam started by %s for %s at %d', src, patient, loc)
            return true, nil, patientName
        end)
    end)
end)

local function closeEms(doctor)
    local s = emsSessions[doctor]
    if not s then return nil end
    emsSessions[doctor] = nil
    if patientOf[s.patient] == doctor then patientOf[s.patient] = nil end
    return s
end

Callback.Register('pop_medexam:emsFinish', function(src)
    return locked(src, false, function()
        local s = emsSessions[src]
        if not s then return false, 'no_session' end
        if Bridge.GetIdentifier(src) ~= s.doctorId or Bridge.IsDead(src) or not isDoctor(src) then
            closeEms(src)
            refund(s.patient, s.patientId)
            return false, 'wrong_job'
        end
        local d = Config.Durations
        local minTime = math.floor((amount(d.pressure) + amount(d.vision) + amount(d.reflex)) / 1000) - 1

        if os.time() - s.startedAt < minTime then
            closeEms(src)
            refund(s.patient, s.patientId)
            return false, 'exam_too_fast'
        end
        if not Bridge.IsNear(src, Config.Locations[s.loc].coords, ACTION_DISTANCE)
            or Bridge.GetIdentifier(s.patient) ~= s.patientId or Bridge.IsDead(s.patient)
            or distance(src, s.patient) > PATIENT_DISTANCE then
            closeEms(src)
            refund(s.patient, s.patientId)
            return false, 'patient_gone'
        end

        local doctorName = Bridge.GetName(src) or GetPlayerName(src) or ''
        busy[s.patient] = true
        closeEms(src)
        local ok, issued = pcall(issue, s.patient, doctorName)
        busy[s.patient] = nil
        if not ok or not issued then
            refund(s.patient, s.patientId)
            return false, 'inventory_full'
        end
        if PRICE > 0 then Bridge.AddMoney(src, Config.Account, PRICE, 'pop_medexam') end
        setCooldown(Bridge.GetIdentifier(s.patient))

        local patientName = Bridge.GetName(s.patient) or GetPlayerName(s.patient) or ''
        Bridge.Notify(s.patient, L('exam_passed'), 'success')
        Bridge.Notify(src, L('exam_done_doctor', patientName, PRICE), 'success')
        return true
    end)
end)

Callback.Register('pop_medexam:emsCancel', function(src)
    return locked(src, false, function()
        local s = closeEms(src)
        if s then refund(s.patient, s.patientId) end
        return true
    end)
end)

------------------------------------------------------------------------
-- Item utilisable : carte affichée au porteur et aux joueurs proches
------------------------------------------------------------------------

local function showCertificate(src, _item, metadata)
    src = tonumber(src)
    if not src then return end
    local now = os.time()
    if lastShow[src] and now - lastShow[src] < SHOW_THROTTLE then return end
    lastShow[src] = now

    if type(metadata) ~= 'table' or type(metadata.name) ~= 'string' then
        Bridge.Notify(src, L('cert_no_data'), 'error')
        return
    end
    local issued = tonumber(metadata.issued) or 0
    local expires = tonumber(metadata.expires) or 0
    local card = {
        name = metadata.name,
        issued = formatDate(issued),
        expires = expires > 0 and formatDate(expires) or nil,
        doctor = tostring(metadata.doctor or ''),
        valid = isValid(expires),
    }

    local origin = Bridge.GetCoords(src)
    TriggerClientEvent('pop_medexam:client:showCertificate', src, card)
    if not origin then return end
    for _, p in ipairs(Bridge.GetPlayers()) do
        p = tonumber(p)
        if p and p ~= src and GetPlayerRoutingBucket(p) == GetPlayerRoutingBucket(src)
            and Bridge.IsNear(p, origin, SHOW_DISTANCE) then
            TriggerClientEvent('pop_medexam:client:showCertificate', p, card)
        end
    end
end

CreateThread(function()
    Bridge.RegisterUsableItem(Config.Item, showCertificate)
    if not Bridge.SupportsMetadata() then
        print(('[pop_medexam] WARNING: inventory "%s" has no metadata support: certificates are given without data '
            .. '(no card, HasValidCertificate only checks the item).'):format(tostring(Bridge.Inventory)))
    end
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('HasValidCertificate', function(src)
    src = tonumber(src)
    if not src then return false end
    if not Bridge.SupportsMetadata() then return Bridge.HasItem(src, Config.Item, 1) end
    for _, stack in ipairs(Bridge.GetItems(src, Config.Item)) do
        if type(stack.metadata) == 'table' and isValid(stack.metadata.expires) then return true end
    end
    return false
end)

exports('GiveCertificate', function(src, doctorName)
    src = tonumber(src)
    if not src or not Bridge.GetPlayer(src) then return false end
    return issue(src, type(doctorName) == 'string' and doctorName ~= '' and doctorName or L('auto_doctor'))
end)

------------------------------------------------------------------------
-- Départs : sessions et verrous nettoyés
------------------------------------------------------------------------

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    lastShow[src] = nil
    sessions[src] = nil -- session auto : supprimée sans remboursement

    -- Patient parti : la session du médecin s'arrête, rien n'est remis ni remboursé.
    local doctor = patientOf[src]
    if doctor then
        patientOf[src] = nil
        emsSessions[doctor] = nil
        TriggerClientEvent('pop_medexam:client:sessionEnded', doctor, 'patient_gone')
    end

    -- Médecin parti : le patient est remboursé.
    local s = closeEms(src)
    if s then refund(s.patient, s.patientId) end
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
