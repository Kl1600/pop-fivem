-- pop_bank : serveur.
-- Le serveur ne fait jamais confiance au client : il borne les montants, vérifie le lieu,
-- lit les soldes lui-même et n'écrit l'historique qu'après un mouvement d'argent réussi.

local ACTION_DISTANCE = 3.0  -- m, distance max au guichet / à l'ATM
local ACTION_DELAY    = 1000 -- ms minimum entre deux opérations d'argent d'un joueur
local MAX_LIMIT       = 100  -- lignes max pour l'export GetHistory

local TYPES = { deposit = true, withdraw = true, transfer_out = true, transfer_in = true }

local busy = {}       -- [src] = true pendant une opération
local lastAction = {} -- [src] = GetGameTimer() de la dernière opération d'argent

local function log(msg, ...)
    if Config.Debug then print(('[pop_bank] ' .. msg):format(...)) end
end

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function isFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

--- Montant entier >= 1, sinon nil (refuse nil, NaN, inf, décimales, négatifs, chaînes non numériques).
local function toAmount(x)
    local n = tonumber(x)
    if not isFinite(n) or n ~= math.floor(n) or n < 1 then return nil end
    return math.tointeger(n)
end

local function clip(str, max)
    if type(str) ~= 'string' then return nil end
    return #str > max and str:sub(1, max) or str
end

local function nameOf(src)
    return Bridge.GetName(src) or GetPlayerName(src) or tostring(src)
end

------------------------------------------------------------------------
-- Historique (oxmysql)
------------------------------------------------------------------------

local function addRow(identifier, kind, amount, other, balance)
    MySQL.insert(
        'INSERT INTO pop_bank_transactions (identifier, type, amount, balance, other, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, kind, amount, math.tointeger(tonumber(balance) or 0) or 0, clip(other, 64), os.time() }
    )
end

local function fetchHistory(identifier, limit)
    local rows = MySQL.query.await(
        'SELECT type, amount, other, created_at FROM pop_bank_transactions WHERE identifier = ? ORDER BY id DESC LIMIT ?',
        { identifier, limit }
    )
    local out = {}
    for i, row in ipairs(rows or {}) do
        out[i] = { type = row.type, amount = row.amount, other = row.other, time = row.created_at }
    end
    return out
end

--- BankData : soldes, type de lieu, n° de compte affichable, historique.
local function buildData(src, place, identifier)
    local account
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then account = identifier end
    return {
        cash = math.floor(Bridge.GetMoney(src, 'cash') or 0),
        bank = math.floor(Bridge.GetMoney(src, 'bank') or 0),
        atm = type(place) == 'table' and place.type == 'atm',
        account = account,
        history = fetchHistory(identifier, Config.HistorySize),
    }
end

------------------------------------------------------------------------
-- Vérifications communes
------------------------------------------------------------------------

--- Le lieu existe et le joueur s'y trouve (position lue côté serveur).
local function validPlace(src, place)
    if type(place) ~= 'table' then return false end
    if place.type == 'bank' then
        local coords = math.type(place.index) == 'integer' and Config.Banks[place.index]
        return coords ~= nil and coords ~= false and Bridge.IsNear(src, coords, ACTION_DISTANCE)
    elseif place.type == 'atm' then
        local x, y, z = place.x, place.y, place.z
        if not (isFinite(x) and isFinite(y) and isFinite(z)) then return false end
        -- NOTE: les ATM sont des props de la carte, invisibles du serveur : on vérifie seulement
        -- la cohérence avec la position du joueur (le virement, seul flux vers un tiers, est réservé aux guichets).
        return Bridge.IsNear(src, { x = x, y = y, z = z }, ACTION_DISTANCE)
    end
    return false
end

--- Cherche un joueur en ligne par ID serveur (<= 5 chiffres) ou par identifiant exact.
local function findTarget(target)
    if type(target) ~= 'string' then return nil end
    target = target:match('^%s*(.-)%s*$')
    if #target < 1 or #target > 64 then return nil end

    local players = Bridge.GetPlayers()
    if #target <= 5 and target:match('^%d+$') then
        local id = tonumber(target)
        for _, p in ipairs(players) do
            if tonumber(p) == id then return id end
        end
        return nil
    end
    for _, p in ipairs(players) do
        if Bridge.GetIdentifier(p) == target then return tonumber(p) end
    end
    return nil
end

------------------------------------------------------------------------
-- Opérations
------------------------------------------------------------------------

local function deposit(src, identifier, place, amount)
    local n = toAmount(amount)
    if not n or n > Config.MaxAmount then return false, 'invalid_amount' end
    if not Bridge.RemoveMoney(src, 'cash', n, 'pop_bank_deposit') then return false, 'not_enough_money' end
    if not Bridge.AddMoney(src, 'bank', n, 'pop_bank_deposit') then
        Bridge.AddMoney(src, 'cash', n, 'pop_bank_refund')
        return false, 'error'
    end
    addRow(identifier, 'deposit', n, nil, Bridge.GetMoney(src, 'bank'))
    log('%s (%s) deposit %d', src, identifier, n)
    return true, 'deposited', n
end

local function withdraw(src, identifier, place, amount)
    local n = toAmount(amount)
    if not n then return false, 'invalid_amount' end
    if place.type == 'atm' and n > Config.AtmWithdraw then return false, 'atm_limit', Config.AtmWithdraw end
    if n > Config.MaxAmount then return false, 'invalid_amount' end
    if not Bridge.RemoveMoney(src, 'bank', n, 'pop_bank_withdraw') then return false, 'not_enough_money' end
    if not Bridge.AddMoney(src, 'cash', n, 'pop_bank_withdraw') then
        Bridge.AddMoney(src, 'bank', n, 'pop_bank_refund')
        return false, 'error'
    end
    addRow(identifier, 'withdraw', n, nil, Bridge.GetMoney(src, 'bank'))
    log('%s (%s) withdraw %d (%s)', src, identifier, n, place.type)
    return true, 'withdrawn', n
end

local function transfer(src, identifier, place, target, amount)
    if place.type ~= 'bank' then return false, 'transfer_atm' end
    local n = toAmount(amount)
    if not n then return false, 'invalid_amount' end
    if n > Config.MaxTransfer then return false, 'transfer_limit', Config.MaxTransfer end

    local dest = findTarget(target)
    if not dest then return false, 'target_not_found' end
    local destId = Bridge.GetIdentifier(dest)
    if not destId then return false, 'target_not_found' end
    if dest == src or destId == identifier then return false, 'target_self' end

    if not Bridge.RemoveMoney(src, 'bank', n, 'pop_bank_transfer') then return false, 'not_enough_money' end
    if not Bridge.AddMoney(dest, 'bank', n, 'pop_bank_transfer') then
        Bridge.AddMoney(src, 'bank', n, 'pop_bank_refund')
        return false, 'error'
    end

    -- Les noms ne sont révélés qu'après un virement réussi (pas de sonde des joueurs).
    local fromName, toName = nameOf(src), nameOf(dest)
    addRow(identifier, 'transfer_out', n, toName, Bridge.GetMoney(src, 'bank'))
    addRow(destId, 'transfer_in', n, fromName, Bridge.GetMoney(dest, 'bank'))
    Bridge.Notify(dest, L('transfer_received', n, fromName), 'success')
    log('%s (%s) transfer %d to %s (%s)', src, identifier, n, dest, destId)
    return true, 'transferred', { n, toName }
end

------------------------------------------------------------------------
-- Callbacks : ok, reason, arg, data
------------------------------------------------------------------------

local function register(name, handler, moneyAction)
    Callback.Register('pop_bank:' .. name, function(src, place, ...)
        if Bridge.Framework == 'standalone' then return false, 'not_available' end
        local identifier = Bridge.GetIdentifier(src)
        if not identifier then return false, 'error' end

        if busy[src] then return false, 'busy', nil, buildData(src, place, identifier) end
        if not validPlace(src, place) then return false, 'too_far', nil, buildData(src, place, identifier) end
        if Bridge.IsDead(src) then return false, 'error', nil, buildData(src, place, identifier) end

        if moneyAction then
            local now = GetGameTimer()
            if lastAction[src] and now - lastAction[src] < ACTION_DELAY then
                return false, 'busy', nil, buildData(src, place, identifier)
            end
            lastAction[src] = now
        end

        busy[src] = true
        local okCall, ok, reason, arg = pcall(handler, src, identifier, place, ...)
        if not okCall then
            print(('[pop_bank] %s error: %s'):format(name, tostring(ok)))
            ok, reason, arg = false, 'error', nil
        end
        local okData, data = pcall(buildData, src, place, identifier)
        busy[src] = nil
        return ok, reason, arg, okData and data or nil
    end)
end

register('getData', function() return true end, false)
register('deposit', deposit, true)
register('withdraw', withdraw, true)
register('transfer', transfer, true)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

--- Ajoute une ligne d'historique (salaires, factures d'autres scripts).
exports('AddTransaction', function(identifier, kind, amount, other)
    if type(identifier) ~= 'string' or identifier == '' or #identifier > 64 then return false end
    if not TYPES[kind] then return false end
    local n = toAmount(amount)
    if not n then return false end
    if other ~= nil and type(other) ~= 'string' then other = tostring(other) end

    local balance = 0
    for _, p in ipairs(Bridge.GetPlayers()) do
        if Bridge.GetIdentifier(p) == identifier then
            balance = Bridge.GetMoney(p, 'bank') or 0
            break
        end
    end
    addRow(identifier, kind, n, other, balance)
    return true
end)

--- Historique d'un personnage, du plus récent au plus ancien.
exports('GetHistory', function(identifier, limit)
    if type(identifier) ~= 'string' or identifier == '' then return {} end
    limit = math.tointeger(tonumber(limit)) or Config.HistorySize
    limit = math.max(1, math.min(limit, MAX_LIMIT))
    return fetchHistory(identifier, limit)
end)

------------------------------------------------------------------------
-- Démarrage et nettoyage
------------------------------------------------------------------------

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pop_bank_transactions` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64)  NOT NULL,
            `type`       VARCHAR(16)  NOT NULL,
            `amount`     INT UNSIGNED NOT NULL,
            `balance`    BIGINT       NOT NULL DEFAULT 0,
            `other`      VARCHAR(64)  NULL DEFAULT NULL,
            `created_at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_identifier_time` (`identifier`, `created_at`)
        )
    ]])
    local purged = MySQL.update.await('DELETE FROM pop_bank_transactions WHERE created_at < ?',
        { os.time() - Config.HistoryDays * 86400 })
    log('history purged: %s rows', tostring(purged))
end)

CreateThread(function()
    if Bridge.Framework == 'standalone' then
        print('^3[pop_bank] No framework detected: banking is disabled (every operation returns not_available).^0')
    end
end)

local function cleanup(src)
    busy[src] = nil
    lastAction[src] = nil
end

Bridge.OnPlayerDropped(cleanup)
Bridge.OnPlayerUnloaded(cleanup)
