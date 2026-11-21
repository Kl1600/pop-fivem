Police = Police or {}
local fines, pendingByTarget, lastFine, resolving = {}, {}, {}, {}
local nextId = 0

local function remove(fine)
    fines[fine.id], pendingByTarget[fine.target] = nil, nil
end

local function notifyPlayer(src, identifier, key, level, ...)
    if GetPlayerName(src) and Bridge.GetIdentifier(src) == identifier then
        Bridge.Notify(src, L(key, ...), level)
    end
end

local function save(fine, status)
    local citizen = Police.GetCitizenId(fine.targetIdentifier, fine.targetName)
    if not citizen then return end
    return MySQL.insert.await([[
        INSERT INTO pop_police_fines (citizen_id, amount, reason, status, officer, officer_identifier, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { citizen, fine.amount, fine.reason, status, Police.Truncate(fine.officerName, 100), fine.officerIdentifier, os.time() })
end

local function markPaid(id)
    for attempt = 1, 3 do
        local ok, count = pcall(MySQL.update.await, 'UPDATE pop_police_fines SET status = ? WHERE id = ?', { 'paid', id })
        if ok and count == 1 then return true end
        -- An earlier attempt may have committed without returning its result.
        local read, status = pcall(MySQL.scalar.await, 'SELECT status FROM pop_police_fines WHERE id = ?', { id })
        if read and status == 'paid' then return true end
        if attempt < 3 then Wait(attempt * 250) end
    end
    return false
end

local function expire(id)
    local fine = fines[id]
    if not fine then return end
    remove(fine)
    CreateThread(function()
        local ok, recordId = pcall(save, fine, 'expired')
        if not ok or not recordId or recordId == 0 then print(('[pop_police] Could not save expired fine %s'):format(fine.id)) end
    end)
    if GetPlayerName(fine.target) and Bridge.GetIdentifier(fine.target) == fine.targetIdentifier then
        TriggerClientEvent('pop_police:client:fineClosed', fine.target, id)
    end
    notifyPlayer(fine.officer, fine.officerIdentifier, 'fine_expired_officer', 'warning')
end

Callback.Register('pop_police:fine', function(src, target, option, reason)
    local officer, failure = Police.CheckOfficer(src)
    if not officer then return false, failure end
    if not Police.Cooldown(src) then return false, 'busy' end
    return Police.WithLock(src, function()
        local valid, errorKey = Police.CheckTarget(src, target)
        if not valid then return false, errorKey end
        local amount = math.type(option) == 'integer' and Police.fineAmounts[option]
        if not amount then return false, 'invalid_amount' end
        local clean, length = Police.CleanText(reason, Police.REASON_MAX)
        if not clean or length < Police.REASON_MIN then return false, 'invalid_reason' end
        if pendingByTarget[target] or resolving[target] then return false, 'fine_pending' end
        local now = os.time()
        local remaining = Police.FINE_COOLDOWN - (now - (lastFine[src] or 0))
        if remaining > 0 then return false, 'cooldown', remaining end
        local targetId, officerId = Bridge.GetIdentifier(target), Bridge.GetIdentifier(src)
        if not targetId or not officerId then return false, 'error' end
        lastFine[src] = now
        nextId = nextId + 1
        local fine = {
            id = nextId, target = target, officer = src,
            targetIdentifier = targetId, targetName = Bridge.GetName(target) or '#' .. target,
            officerIdentifier = officerId, officerName = Bridge.GetName(src) or '#' .. src,
            amount = amount, reason = clean, expires = now + Config.Fines.timeout,
        }
        fines[fine.id], pendingByTarget[target] = fine, fine.id
        SetTimeout(Config.Fines.timeout * 1000, function() expire(fine.id) end)
        TriggerClientEvent('pop_police:client:fineRequest', target, {
            id = fine.id, amount = amount, reason = clean, officer = fine.officerName,
        })
        Bridge.Notify(src, L('fine_sent'), 'success')
        return true
    end)
end)

Callback.Register('pop_police:respondFine', function(src, id, accept)
    local fine = math.type(id) == 'integer' and fines[id]
    if not fine or fine.target ~= src or fine.targetIdentifier ~= Bridge.GetIdentifier(src) then
        return false, 'fine_not_found'
    end
    if type(accept) ~= 'boolean' then return false, 'error' end
    if os.time() >= fine.expires then
        expire(id)
        return false, 'fine_not_found'
    end

    remove(fine)
    resolving[src] = fine
    -- Establish the fine record before attempting any external economy change.
    local status = accept and 'unpaid' or 'refused'
    local saved, recordId = pcall(save, fine, status)
    if not saved or not recordId or recordId == 0 then
        if resolving[src] == fine then resolving[src] = nil end
        print(('[pop_police] Could not save fine %s'):format(fine.id))
        notifyPlayer(fine.officer, fine.officerIdentifier, 'error', 'error')
        return false, 'error'
    end

    if accept and resolving[src] == fine and Bridge.GetIdentifier(src) == fine.targetIdentifier then
        local debited, paid = pcall(Bridge.RemoveMoney, src, Config.Fines.account, fine.amount, 'pop_police_fine')
        if debited and paid then
            if markPaid(recordId) then
                status = 'paid'
            else
                local refunded = false
                if resolving[src] == fine and Bridge.GetIdentifier(src) == fine.targetIdentifier then
                    local called, result = pcall(Bridge.AddMoney, src, Config.Fines.account, fine.amount, 'pop_police_fine_refund')
                    refunded = called and result == true
                end
                print(('[pop_police] Could not mark fine record %s paid; refunded=%s'):format(recordId, refunded))
                notifyPlayer(fine.officer, fine.officerIdentifier, 'error', 'error')
                if resolving[src] == fine then resolving[src] = nil end
                return false, 'error'
            end
        end
    end
    if resolving[src] == fine then resolving[src] = nil end
    local money = L('money', fine.amount)
    local targetLevel = status == 'paid' and 'success' or (status == 'unpaid' and 'error' or 'info')
    notifyPlayer(src, fine.targetIdentifier, 'fine_' .. status .. '_target', targetLevel, money)
    notifyPlayer(fine.officer, fine.officerIdentifier, 'fine_' .. status .. '_officer',
        status == 'paid' and 'success' or 'warning', money)
    if status == 'paid' then TriggerEvent('pop_police:finePaid', src, fine.officer, fine.amount, fine.reason) end
    return true, nil, status
end)

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    local id = pendingByTarget[src]
    if id then expire(id) end
    lastFine[src], resolving[src] = nil, nil
end
Bridge.OnPlayerUnloaded(cleanup)
Bridge.OnPlayerDropped(cleanup)
