-- Compte société (backends externes ou repli SQL) et historique des opérations.
-- Table globale `Account` (SPEC §11). Toutes les fonctions des backends sont appelées sous pcall.

Account = {}

local RES = GetCurrentResourceName()
local HISTORY_LIMIT = 30 -- identique à HISTORY_LIMIT de main.lua (SPEC §10)

local function started(name)
    return GetResourceState(name) == 'started'
end

local function debug(msg, ...)
    if Config.Debug then print(('[%s] account: ' .. msg):format(RES, ...)) end
end

-- Coupe une chaîne à `max` caractères UTF-8 (colonnes VARCHAR).
local function cut(s, max)
    if type(s) ~= 'string' then return nil end
    if not utf8.len(s) then s = s:gsub('[\128-\255]', '') end
    if utf8.len(s) > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

------------------------------------------------------------------------
-- Backends : get(job) -> number | nil, add(job, n, reason) -> bool, remove(job, n, reason) -> bool
------------------------------------------------------------------------

-- esx_addonaccount : le rappel de getSharedAccount est synchrone.
local function esxAccount(job)
    local acc
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. job, function(a) acc = a end)
    return acc
end

local BACKENDS = {
    esx_addonaccount = {
        resource = 'esx_addonaccount',
        get = function(job)
            local acc = esxAccount(job)
            return acc and acc.money
        end,
        add = function(job, n)
            local acc = esxAccount(job)
            if not acc then return false end
            acc.addMoney(n)
            return true
        end,
        remove = function(job, n)
            local acc = esxAccount(job)
            if not acc or (tonumber(acc.money) or 0) < n then return false end
            acc.removeMoney(n)
            return true
        end,
    },
    ['qb-banking'] = {
        resource = 'qb-banking',
        get = function(job) return exports['qb-banking']:GetAccountBalance(job) end,
        add = function(job, n, reason) return exports['qb-banking']:AddMoney(job, n, reason) end,
        remove = function(job, n, reason) return exports['qb-banking']:RemoveMoney(job, n, reason) end,
    },
    ['qb-management'] = {
        resource = 'qb-management',
        get = function(job) return exports['qb-management']:GetAccount(job) end,
        add = function(job, n) return exports['qb-management']:AddMoney(job, n) end,
        remove = function(job, n) return exports['qb-management']:RemoveMoney(job, n) end,
    },
    ['renewed-banking'] = {
        resource = 'Renewed-Banking',
        get = function(job) return exports['Renewed-Banking']:getAccountMoney(job) end,
        add = function(job, n) return exports['Renewed-Banking']:addAccountMoney(job, n) end,
        remove = function(job, n) return exports['Renewed-Banking']:removeAccountMoney(job, n) end,
    },
    -- Repli : table propre au script. Retrait atomique (une seule requête conditionnelle).
    pop = {
        get = function(job)
            local balance = MySQL.scalar.await('SELECT balance FROM pop_management_accounts WHERE society = ?', { job })
            if balance == nil then
                MySQL.insert.await('INSERT IGNORE INTO pop_management_accounts (society, balance) VALUES (?, 0)', { job })
                return 0
            end
            return balance
        end,
        add = function(job, n)
            local affected = MySQL.update.await(
                'INSERT INTO pop_management_accounts (society, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)',
                { job, n })
            return (tonumber(affected) or 0) >= 1
        end,
        remove = function(job, n)
            local affected = MySQL.update.await(
                'UPDATE pop_management_accounts SET balance = balance - ? WHERE society = ? AND balance >= ?',
                { n, job, n })
            return tonumber(affected) == 1
        end,
    },
}

local AUTO_ORDER = {
    esx        = { 'esx_addonaccount', 'pop' },
    qbcore     = { 'qb-banking', 'qb-management', 'renewed-banking', 'pop' },
    qbox       = { 'renewed-banking', 'qb-banking', 'pop' },
    standalone = { 'pop' },
}

local function chooseBackend()
    local forced = Config.SocietyAccount
    if forced and forced ~= 'auto' then
        if BACKENDS[forced] then return forced end
        print(('[%s] unknown Config.SocietyAccount "%s", using "pop"'):format(RES, tostring(forced)))
        return 'pop'
    end
    for _, name in ipairs(AUTO_ORDER[Bridge.Framework] or AUTO_ORDER.standalone) do
        local b = BACKENDS[name]
        if not b.resource or started(b.resource) then return name end
    end
    return 'pop'
end

Account.Backend = chooseBackend()
local backend = BACKENDS[Account.Backend]

if backend.resource and not started(backend.resource) then
    -- NOTE: backend forcé mais ressource non lancée : les appels échoueront proprement (pcall).
    print(('[%s] society account "%s" selected but resource "%s" is not started'):format(RES, Account.Backend, backend.resource))
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

local warned = {} -- [job] = true : avertissement "compte introuvable" déjà affiché

local function warnMissing(job)
    if warned[job] then return end
    warned[job] = true
    if Account.Backend == 'esx_addonaccount' then
        print(('[%s] society account not found: create the society account `society_%s` in addon_account'):format(RES, job))
    else
        print(('[%s] society account `%s` not found in %s'):format(RES, job, Account.Backend))
    end
end

--- Solde entier, ou nil si le compte est introuvable.
function Account.Get(job)
    if type(job) ~= 'string' then return nil end
    local ok, res = pcall(backend.get, job)
    local n = ok and tonumber(res) or nil
    if not n or n ~= n or n == math.huge or n == -math.huge then
        if not ok then debug('get error for %s: %s', job, tostring(res)) end
        if backend.resource and Config.Societies[job] then warnMissing(job) end
        return nil
    end
    return math.floor(n)
end

--- Ajoute `amount` (entier > 0 déjà validé). Un `false` explicite ou une erreur = échec.
function Account.Add(job, amount, reason)
    local ok, res = pcall(backend.add, job, amount, reason)
    if not ok then debug('add error for %s: %s', job, tostring(res)) end
    return ok and (res == true or (res == nil and Account.Backend == 'qb-management'))
end

--- Retire `amount` si le solde suffit (vérifié avant, sauf backend pop : requête atomique).
function Account.Remove(job, amount, reason)
    if Account.Backend ~= 'pop' then
        local balance = Account.Get(job)
        if not balance or balance < amount then return false end
    end
    local ok, res = pcall(backend.remove, job, amount, reason)
    if not ok then debug('remove error for %s: %s', job, tostring(res)) end
    return ok and (res == true or (res == nil and Account.Backend == 'qb-management'))
end

--- Ajoute une ligne d'historique (non bloquant).
function Account.Log(job, txType, amount, actor, target, note)
    MySQL.insert(
        'INSERT INTO pop_management_transactions (society, type, amount, actor, target, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { job, txType, amount, cut(actor, 100) or '-', cut(target, 100), cut(note, 64), os.time() })
end

--- 30 dernières opérations, plus récente en premier, au format `history` de PanelData.
function Account.History(job)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT type, amount, actor, target, note, created_at FROM pop_management_transactions WHERE society = ? ORDER BY id DESC LIMIT 30',
        { job })
    local out = {}
    if not ok or type(rows) ~= 'table' then return out end
    for i = 1, math.min(#rows, HISTORY_LIMIT) do
        local r = rows[i]
        out[i] = {
            type = r.type,
            amount = math.floor(tonumber(r.amount) or 0),
            actor = r.actor,
            target = r.target,
            note = r.note,
            at = math.floor(tonumber(r.created_at) or 0),
        }
    end
    return out
end
