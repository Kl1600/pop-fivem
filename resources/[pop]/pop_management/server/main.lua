-- pop_management : callbacks, sessions de panneau, offres, sécurité et exports (SPEC §5, §7, §11, §13).
-- `Account` et `Jobs` (account.lua, framework.lua) ne sont utilisés que dans des handlers.

local RES = GetCurrentResourceName()

local POINT_DISTANCE = 5.0 -- tolérance serveur au point d'ouverture
local HISTORY_LIMIT = 30   -- lignes d'historique renvoyées (voir Account.History)
local HISTORY_DAYS = 30    -- purge de l'historique au démarrage
local NOTE_MAX = 50        -- motif de facture
local EXPORT_NOTE_MAX = 64 -- note des exports (colonne VARCHAR(64))
local MAX_EMPLOYEES = 100
local MAX_AMOUNT = 2147483647
local ready = false

local sessions = {}      -- [src] = { job, point, employees = { [id] = identifier } }
local busy = {}          -- [src] = true pendant un traitement
local societyLock = {}   -- [job] = true pendant une opération d'argent
local offers = {}        -- [offerId] = offre (SPEC §3)
local offerByTarget = {} -- [src cible] = offerId
local offerBySender = {} -- [src expéditeur] = offerId
local lastOfferId = 0

local function debug(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- Entier strict. NOTE: un flottant entier (ex. 500.0, possible après un passage JSON) est converti ;
-- décimaux, NaN et infinis sont refusés comme l'exige SPEC §13.
local function toInt(x)
    if math.type(x) == 'integer' then return x end
    if math.type(x) == 'float' then return math.tointeger(x) end
    return nil
end

--- Montant entier dans [1, max] → n, ou nil, reason, arg.
local function validAmount(n, max)
    max = math.min(max, MAX_AMOUNT)
    n = toInt(n)
    if not n or n < 1 then return nil, 'invalid_amount' end
    if n > max then return nil, 'amount_too_high', L('money', max) end
    return n
end

local function presetAmount(kind, preset)
    if type(preset) ~= 'string' or #preset > 32 then return nil, 'invalid_amount' end
    local values = Config.AmountPresets[kind]
    local max = kind == 'invoice' and Config.MaxInvoice or Config.MaxAmount
    return validAmount(values and values[preset], max)
end

local function presets(kind)
    local options = {}
    for id in pairs(Config.AmountPresets[kind] or {}) do
        local amount = presetAmount(kind, id)
        if amount then options[#options + 1] = { id = id, amount = amount } end
    end
    table.sort(options, function(a, b)
        if a.amount == b.amount then return a.id < b.id end
        return a.amount < b.amount
    end)
    return options
end

--- Texte libre nettoyé : sans caractères de contrôle ni <>, rogné, `max` caractères ; vide → nil.
local function cleanNote(s, max)
    if type(s) ~= 'string' then return nil end
    if #s > 1024 then s = s:sub(1, 1024) end -- borne avant traitement
    if not utf8.len(s) then
        -- Séquence UTF-8 coupée en fin de chaîne, sinon octets invalides retirés.
        for _ = 1, 3 do
            s = s:sub(1, -2)
            if utf8.len(s) then break end
        end
        if not utf8.len(s) then s = s:gsub('[\128-\255]', '') end
    end
    s = s:gsub('%c', ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(s) > (max or NOTE_MAX) then
        s = s:sub(1, utf8.offset(s, (max or NOTE_MAX) + 1) - 1):gsub('%s+$', '')
    end
    return s ~= '' and s or nil
end

local function nameOf(src)
    return Bridge.GetName(src) or '-'
end

--- Joueur patron d'une société listée → cfg, job ; sinon nil, reason.
local function isBoss(src)
    local job = src and Bridge.GetJob(src)
    if not job or not Bridge.GetIdentifier(src) then return nil, 'error' end
    local cfg = type(job.name) == 'string' and Config.Societies[job.name]
    if not cfg then return nil, 'wrong_job' end
    if (tonumber(job.grade) or 0) < cfg.bossGrade then return nil, 'no_permission' end
    return cfg, job
end

--- Contrôle patron pour une action du panneau → session, job, cfg ; sinon nil, reason.
local function checkSession(src)
    if not Jobs.Supported then return nil, 'error' end
    local cfg, job = isBoss(src)
    if not cfg then
        if job ~= 'error' then sessions[src] = nil end
        return nil, job
    end
    local s = sessions[src]
    if not s or s.job ~= job.name or s.owner ~= Bridge.GetIdentifier(src) then
        sessions[src] = nil
        return nil, 'no_permission'
    end
    if s.point and not Bridge.IsNear(src, cfg.points[s.point], POINT_DISTANCE) then return nil, 'too_far' end
    return s, job, cfg
end

--- Exécute fn sous le verrou de la société (toute opération d'argent). Libéré dans tous les cas.
local function withSocietyLock(job, fn)
    if societyLock[job] then return false, 'busy' end
    societyLock[job] = true
    local res = table.pack(pcall(fn))
    societyLock[job] = nil
    if not res[1] then
        print(('[%s] society operation error: %s'):format(RES, tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

--- Cible d'une offre : autre joueur, connecté, chargé, vivant, proche → nil ; sinon reason.
local function checkTarget(src, targetId)
    if targetId == src or targetId < 1 or not GetPlayerName(targetId) or not Bridge.GetIdentifier(targetId)
        or Bridge.IsDead(targetId) or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId) then
        return 'target_not_found'
    end
    local coords = Bridge.GetCoords(targetId)
    if not coords or not Bridge.IsNear(src, coords, Config.InteractDistance) then return 'too_far' end
    return nil
end

--- Contrôle de facturation → cfg, job ; sinon nil, reason.
local function checkInvoicer(src)
    if not Jobs.Supported then return nil, 'error' end
    local job = Bridge.GetJob(src)
    if not job or not Bridge.GetIdentifier(src) then return nil, 'error' end
    local cfg = type(job.name) == 'string' and Config.Societies[job.name]
    if not cfg then return nil, 'wrong_job' end
    -- NOTE: invoiceGrade absent (nil) traité comme false : factures désactivées.
    if type(Config.InvoiceCommand) ~= 'string' or type(cfg.invoiceGrade) ~= 'number' then return nil, 'invoice_disabled' end
    if (tonumber(job.grade) or 0) < cfg.invoiceGrade then return nil, 'no_permission' end
    if not job.onDuty then return nil, 'off_duty' end
    return cfg, job
end

------------------------------------------------------------------------
-- Offres
------------------------------------------------------------------------

local function removeOffer(o)
    if offers[o.id] == o then offers[o.id] = nil end
    if offerByTarget[o.to] == o.id then offerByTarget[o.to] = nil end
    if offerBySender[o.from] == o.id then offerBySender[o.from] = nil end
end

--- Enregistre l'offre, l'envoie à la cible (sans source ni identifiant) et programme son expiration.
local function createOffer(o, payload)
    lastOfferId = lastOfferId < 2147483647 and lastOfferId + 1 or 1
    o.fromId = Bridge.GetIdentifier(o.from)
    o.toId = Bridge.GetIdentifier(o.to)
    o.id = lastOfferId
    o.expires = os.time() + Config.OfferTimeout
    offers[o.id] = o
    offerByTarget[o.to] = o.id
    offerBySender[o.from] = o.id

    payload.id = o.id
    payload.kind = o.kind
    payload.timeout = Config.OfferTimeout
    TriggerClientEvent('pop_management:client:offer', o.to, payload)

    SetTimeout(Config.OfferTimeout * 1000, function()
        if offers[o.id] ~= o then return end
        removeOffer(o)
        TriggerClientEvent('pop_management:client:offerClosed', o.to, o.id)
        Bridge.Notify(o.from, L('offer_expired'), 'error')
    end)
end

--- Supprime sessions, verrou et offres d'un joueur qui part ou change de personnage.
local function cleanup(src)
    sessions[src] = nil
    local id = offerByTarget[src]
    if id and offers[id] then removeOffer(offers[id]) end
    id = offerBySender[src]
    local o = id and offers[id]
    if o then
        removeOffer(o)
        TriggerClientEvent('pop_management:client:offerClosed', o.to, o.id)
    end
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)

RegisterNetEvent('pop_management:server:closePanel', function()
    sessions[source] = nil
end)

------------------------------------------------------------------------
-- Enregistrement des callbacks : verrou par joueur, erreurs capturées
------------------------------------------------------------------------

-- fail : première valeur renvoyée en cas d'échec (nil pour getPanel / canInvoice, false pour les actions).
local function register(name, fail, fn)
    Callback.Register('pop_management:' .. name, function(src, ...)
        if not ready or not Bridge.GetIdentifier(src) or Bridge.IsDead(src) then return fail, 'error' end
        if busy[src] then return fail, 'busy' end
        busy[src] = true
        local res = table.pack(pcall(fn, src, ...))
        busy[src] = nil
        if not res[1] then
            print(('[%s] "%s" error: %s'):format(RES, name, tostring(res[2])))
            return fail, 'error'
        end
        return table.unpack(res, 2, res.n)
    end)
end

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function buildPanel(src, job)
    local name = job.name
    local grades = Jobs.GetGrades(name)
    local labels = {}
    for _, g in ipairs(grades) do labels[g.grade] = g.label end

    local myId = Bridge.GetIdentifier(src)
    local list = Jobs.GetEmployees(name)
    table.sort(list, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.name or '') < (b.name or '')
    end)

    local employees, ids = {}, {}
    for i = 1, math.min(#list, MAX_EMPLOYEES) do
        local e = list[i]
        ids[i] = e.identifier
        employees[i] = {
            id = i,
            name = e.name or '-',
            grade = e.grade,
            gradeLabel = labels[e.grade] or tostring(e.grade),
            online = e.src ~= nil,
            me = e.identifier == myId,
        }
    end

    local history = Account.History(name)
    for i = #history, HISTORY_LIMIT + 1, -1 do history[i] = nil end

    -- NOTE: compte introuvable → solde affiché 0 ; les opérations renverront society_no_account.
    local data = {
        society = { name = name, label = Jobs.GetLabel(name) },
        me = { grade = job.grade, gradeLabel = labels[job.grade] or job.gradeLabel or tostring(job.grade) },
        balance = Account.Get(name) or 0,
        presets = { transfer = presets('transfer'), bonus = presets('bonus') },
        now = os.time(),
        grades = grades,
        employees = employees,
        history = history,
    }
    return data, ids
end

register('getPanel', nil, function(src, point)
    if point ~= nil then
        point = toInt(point)
        if not point then return nil, 'error' end
    end
    if not Jobs.Supported then return nil, 'error' end

    local cfg, job = isBoss(src)
    if not cfg then
        sessions[src] = nil
        return nil, job
    end

    if point then
        local coords = cfg.points and cfg.points[point]
        if not coords or not Bridge.IsNear(src, coords, POINT_DISTANCE) then return nil, 'too_far' end
    elseif type(Config.Command) ~= 'string' then
        return nil, 'too_far'
    end

    local owner = Bridge.GetIdentifier(src)
    local data, ids = buildPanel(src, job)
    local _, latest = isBoss(src)
    if Bridge.GetIdentifier(src) ~= owner or type(latest) ~= 'table' or latest.name ~= job.name then
        return nil, 'no_permission'
    end
    sessions[src] = { owner = owner, job = job.name, point = point, employees = ids }
    return data
end)

------------------------------------------------------------------------
-- Employés
------------------------------------------------------------------------

--- Employé visé par une action → emp, identifier ; sinon nil, reason (SPEC §13 « Employé visé »).
local function targetEmployee(src, session, job, employeeId)
    employeeId = toInt(employeeId)
    if not employeeId then return nil, 'error' end
    local identifier = session.employees[employeeId]
    if not identifier then return nil, 'employee_not_found' end
    local emp = Jobs.GetEmployee(job.name, identifier)
    if not emp then return nil, 'employee_not_found' end
    if identifier == Bridge.GetIdentifier(src) then return nil, 'cannot_self' end
    if emp.grade >= job.grade then return nil, 'rank_too_high' end
    return emp, identifier
end

register('fire', false, function(src, employeeId)
    local s, job = checkSession(src)
    if not s then return false, job end
    local emp, identifier = targetEmployee(src, s, job, employeeId)
    if not emp then return false, identifier end

    if not Jobs.Fire(job.name, identifier) then return false, 'error' end
    s.employees[toInt(employeeId)] = nil

    debug('%s fired %s from %s', src, emp.name, job.name)
    Bridge.Notify(src, L('fired', emp.name), 'success')
    -- NOTE: notification de la personne renvoyée en 'info' (message neutre, pas un succès pour elle).
    if emp.src then Bridge.Notify(emp.src, L('fired_target', Jobs.GetLabel(job.name)), 'info') end
    return true
end)

--- Promotion (dir = 1) ou rétrogradation (dir = -1) d'un grade existant.
local function changeGrade(src, employeeId, dir)
    local s, job = checkSession(src)
    if not s then return false, job end
    local emp, identifier = targetEmployee(src, s, job, employeeId)
    if not emp then return false, identifier end

    local target
    for _, g in ipairs(Jobs.GetGrades(job.name)) do
        if dir > 0 and g.grade > emp.grade and (not target or g.grade < target.grade) then target = g end
        if dir < 0 and g.grade < emp.grade and (not target or g.grade > target.grade) then target = g end
    end
    if not target then return false, dir > 0 and 'grade_max' or 'grade_min' end
    if dir > 0 and target.grade >= job.grade then return false, 'rank_too_high' end

    if not Jobs.SetGrade(job.name, identifier, target.grade) then return false, 'error' end

    debug('%s set %s to grade %s in %s', src, emp.name, target.grade, job.name)
    Bridge.Notify(src, L('grade_set', emp.name, target.label), 'success')
    if emp.src then Bridge.Notify(emp.src, L('grade_changed', Jobs.GetLabel(job.name), target.label), 'info') end
    return true
end

register('promote', false, function(src, employeeId) return changeGrade(src, employeeId, 1) end)
register('demote', false, function(src, employeeId) return changeGrade(src, employeeId, -1) end)

register('pay', false, function(src, employeeId, preset)
    local s, job = checkSession(src)
    if not s then return false, job end
    local n, reason, arg = presetAmount('bonus', preset)
    if not n then return false, reason, arg end
    local emp, identifier = targetEmployee(src, s, job, employeeId)
    if not emp then return false, identifier end
    if not emp.src then return false, 'employee_offline' end

    local society = job.name
    local actor = nameOf(src)
    local ok, err = withSocietyLock(society, function()
        local balance = Account.Get(society)
        if not balance then return false, 'society_no_account' end
        if balance < n or not Account.Remove(society, n, L('tx_bonus')) then return false, 'society_no_money' end
        if Bridge.GetIdentifier(emp.src) ~= identifier
            or not Bridge.AddMoney(emp.src, Config.Accounts.bonus, n, L('tx_bonus')) then
            Account.Add(society, n, L('tx_bonus')) -- remboursement de la société
            return false, 'error'
        end
        Account.Log(society, 'bonus', n, actor, emp.name, nil)
        return true
    end)
    if not ok then return false, err end

    debug('%s paid a bonus of %d to %s (%s)', src, n, emp.name, society)
    Bridge.Notify(src, L('paid', L('money', n), emp.name), 'success')
    Bridge.Notify(emp.src, L('bonus_received', L('money', n), Jobs.GetLabel(society)), 'success')
    return true
end)

register('recruit', false, function(src, targetId)
    local s, job = checkSession(src)
    if not s then return false, job end
    targetId = toInt(targetId)
    if not targetId then return false, 'error' end

    local reason = checkTarget(src, targetId)
    if reason then return false, reason end
    if Jobs.GetEmployee(job.name, Bridge.GetIdentifier(targetId)) then return false, 'already_employee' end
    if offerByTarget[targetId] then return false, 'target_busy' end
    if offerBySender[src] then return false, 'busy' end

    local grades = Jobs.GetGrades(job.name)
    if not grades[1] then return false, 'error' end

    createOffer({ kind = 'recruit', from = src, to = targetId, job = job.name }, {
        society = Jobs.GetLabel(job.name),
        gradeLabel = grades[1].label,
    })
    debug('%s sent a job offer (%s) to %s', src, job.name, targetId)
    Bridge.Notify(src, L('offer_sent'), 'success')
    return true
end)

------------------------------------------------------------------------
-- Compte
------------------------------------------------------------------------

register('deposit', false, function(src, preset)
    local s, job = checkSession(src)
    if not s then return false, job end
    local n, reason, arg = presetAmount('transfer', preset)
    if not n then return false, reason, arg end

    local society, account = job.name, Config.Accounts.transfer
    local actor = nameOf(src)
    local ok, err = withSocietyLock(society, function()
        if not Bridge.RemoveMoney(src, account, n, L('tx_deposit')) then return false, 'not_enough_money' end
        if not Account.Add(society, n, L('tx_deposit')) then
            Bridge.AddMoney(src, account, n, L('tx_deposit')) -- remboursement du joueur
            return false, 'society_no_account'
        end
        Account.Log(society, 'deposit', n, actor, nil, nil)
        return true
    end)
    if not ok then return false, err end

    debug('%s deposited %d into %s', src, n, society)
    Bridge.Notify(src, L('deposited', L('money', n)), 'success')
    return true
end)

register('withdraw', false, function(src, preset)
    local s, job = checkSession(src)
    if not s then return false, job end
    local n, reason, arg = presetAmount('transfer', preset)
    if not n then return false, reason, arg end

    local society, account = job.name, Config.Accounts.transfer
    local actor = nameOf(src)
    local ok, err = withSocietyLock(society, function()
        if not Account.Get(society) then return false, 'society_no_account' end
        if not Account.Remove(society, n, L('tx_withdraw')) then return false, 'society_no_money' end
        if not Bridge.AddMoney(src, account, n, L('tx_withdraw')) then
            Account.Add(society, n, L('tx_withdraw')) -- remboursement de la société
            return false, 'error'
        end
        Account.Log(society, 'withdraw', n, actor, nil, nil)
        return true
    end)
    if not ok then return false, err end

    debug('%s withdrew %d from %s', src, n, society)
    Bridge.Notify(src, L('withdrawn', L('money', n)), 'success')
    return true
end)

------------------------------------------------------------------------
-- Factures
------------------------------------------------------------------------

register('canInvoice', nil, function(src)
    local cfg, job = checkInvoicer(src)
    if not cfg then return nil, job end
    return { society = Jobs.GetLabel(job.name), presets = presets('invoice') }
end)

register('sendInvoice', false, function(src, targetId, preset, note)
    local cfg, job = checkInvoicer(src)
    if not cfg then return false, job end
    targetId = toInt(targetId)
    if not targetId then return false, 'error' end
    local n, reason, arg = presetAmount('invoice', preset)
    if not n then return false, reason, arg end
    if note ~= nil and type(note) ~= 'string' then return false, 'error' end
    note = cleanNote(note, NOTE_MAX)

    reason = checkTarget(src, targetId)
    if reason then return false, reason end
    if offerByTarget[targetId] then return false, 'target_busy' end
    if offerBySender[src] then return false, 'busy' end

    createOffer({ kind = 'invoice', from = src, to = targetId, job = job.name, amount = n, note = note }, {
        society = Jobs.GetLabel(job.name),
        amount = n,
        note = note,
    })
    debug('%s sent an invoice of %d (%s) to %s', src, n, job.name, targetId)
    Bridge.Notify(src, L('offer_sent'), 'success')
    return true
end)

------------------------------------------------------------------------
-- Réponse à une offre
------------------------------------------------------------------------

local function acceptRecruit(src, o)
    local cfg = Config.Societies[o.job]
    local from = Bridge.GetJob(o.from)
    if not cfg or not from or from.name ~= o.job or (tonumber(from.grade) or 0) < cfg.bossGrade then
        return false, 'offer_not_found'
    end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false, 'error' end
    if Jobs.GetEmployee(o.job, identifier) then return false, 'already_employee' end
    local grades = Jobs.GetGrades(o.job)
    if not grades[1] or not Jobs.Hire(src, o.job, grades[1].grade) then return false, 'error' end

    debug('%s joined %s', src, o.job)
    Bridge.Notify(o.from, L('recruited', nameOf(src)), 'success')
    Bridge.Notify(src, L('hired', Jobs.GetLabel(o.job)), 'success')
    return true
end

local function acceptInvoice(src, o)
    local cfg, from = checkInvoicer(o.from)
    if not cfg or from.name ~= o.job then return false, 'offer_not_found' end

    local account = Config.Accounts.invoice
    local actor, customer = nameOf(o.from), nameOf(src)
    -- NOTE: si la société est verrouillée à cet instant (« busy »), l'offre est déjà consommée :
    -- l'expéditeur devra renvoyer la facture (aucun argent n'a bougé).
    local ok, err = withSocietyLock(o.job, function()
        if not Bridge.RemoveMoney(src, account, o.amount, L('tx_invoice')) then
            Bridge.Notify(o.from, L('invoice_unpaid'), 'error')
            return false, 'not_enough_money'
        end
        if not Account.Add(o.job, o.amount, L('tx_invoice')) then
            Bridge.AddMoney(src, account, o.amount, L('tx_invoice')) -- remboursement du client
            return false, 'society_no_account'
        end
        Account.Log(o.job, 'invoice', o.amount, actor, customer, o.note)
        return true
    end)
    if not ok then return false, err end

    debug('%s paid an invoice of %d to %s', src, o.amount, o.job)
    Bridge.Notify(o.from, L('invoice_paid', L('money', o.amount)), 'success')
    Bridge.Notify(src, L('invoice_paid_target', L('money', o.amount), Jobs.GetLabel(o.job)), 'success')
    return true
end

register('answerOffer', false, function(src, offerId, accept)
    offerId = toInt(offerId)
    if not offerId or type(accept) ~= 'boolean' then return false, 'error' end

    local o = offers[offerId]
    if not o or o.to ~= src or Bridge.GetIdentifier(src) ~= o.toId or os.time() > o.expires then
        return false, 'offer_not_found'
    end
    removeOffer(o) -- avant tout traitement : empêche une double acceptation

    if not accept then
        Bridge.Notify(o.from, L('offer_refused'), 'error')
        return true
    end

    if Bridge.GetIdentifier(o.from) ~= o.fromId or Bridge.IsDead(o.from) then return false, 'offer_not_found' end
    if GetPlayerRoutingBucket(o.from) ~= GetPlayerRoutingBucket(src) then return false, 'too_far' end
    local coords = Bridge.GetCoords(o.from)
    if not coords or not Bridge.IsNear(src, coords, Config.InteractDistance + 2.0) then return false, 'too_far' end

    if o.kind == 'recruit' then return acceptRecruit(src, o) end
    return acceptInvoice(src, o)
end)

------------------------------------------------------------------------
-- Exports serveur (SPEC §7) : même verrou de société, acteur '-'
------------------------------------------------------------------------

local function validJob(job)
    return type(job) == 'string' and job ~= '' and #job <= 50
end

exports('GetSocietyMoney', function(job)
    if not ready or not validJob(job) then return nil end
    return Account.Get(job)
end)

exports('AddSocietyMoney', function(job, amount, note)
    amount = toInt(amount)
    if not ready or not validJob(job) or not amount or amount < 1 or amount > MAX_AMOUNT then return false end
    note = cleanNote(note, EXPORT_NOTE_MAX)
    local ok = withSocietyLock(job, function()
        if not Account.Add(job, amount, note or L('tx_add')) then return false end
        Account.Log(job, 'add', amount, '-', nil, note)
        return true
    end)
    debug('export AddSocietyMoney %s %s -> %s', job, amount, tostring(ok))
    return ok == true
end)

exports('RemoveSocietyMoney', function(job, amount, note)
    amount = toInt(amount)
    if not ready or not validJob(job) or not amount or amount < 1 or amount > MAX_AMOUNT then return false end
    note = cleanNote(note, EXPORT_NOTE_MAX)
    local ok = withSocietyLock(job, function()
        if not Account.Remove(job, amount, note or L('tx_remove')) then return false end
        Account.Log(job, 'remove', amount, '-', nil, note)
        return true
    end)
    debug('export RemoveSocietyMoney %s %s -> %s', job, amount, tostring(ok))
    return ok == true
end)

exports('IsBoss', function(src)
    src = tonumber(src)
    return src ~= nil and (isBoss(src)) ~= nil
end)

------------------------------------------------------------------------
-- Démarrage : tables, purge, avertissements (console en anglais)
------------------------------------------------------------------------

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `pop_management_accounts` (
                `society` VARCHAR(50)     NOT NULL,
                `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
                PRIMARY KEY (`society`)
            )
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `pop_management_transactions` (
                `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `society`    VARCHAR(50)  NOT NULL,
                `type`       VARCHAR(16)  NOT NULL,
                `amount`     INT UNSIGNED NOT NULL,
                `actor`      VARCHAR(100) NOT NULL,
                `target`     VARCHAR(100) NULL DEFAULT NULL,
                `note`       VARCHAR(64)  NULL DEFAULT NULL,
                `created_at` INT UNSIGNED NOT NULL,
                PRIMARY KEY (`id`),
                KEY `idx_society_time` (`society`, `created_at`)
            )
        ]])
        MySQL.update.await('DELETE FROM pop_management_transactions WHERE created_at < ?', { os.time() - HISTORY_DAYS * 86400 })
    end)
    if not ok then
        print(('[%s] database setup failed: %s'):format(RES, tostring(err)))
        return
    end
    ready = true

    print(('[%s] society account backend: %s'):format(RES, Account.Backend))
    if not Jobs.Supported then
        print(('[%s] no supported framework (%s): the management panel is disabled'):format(RES, Bridge.Framework))
        return
    end
    for job in pairs(Config.Societies) do
        if #Jobs.GetGrades(job) == 0 then
            print(('[%s] job "%s" from Config.Societies does not exist in %s'):format(RES, job, Bridge.Framework))
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    -- Les offres en cours disparaissent avec la ressource : on prévient les cibles.
    for id, o in pairs(offers) do
        TriggerClientEvent('pop_management:client:offerClosed', o.to, id)
    end
end)
