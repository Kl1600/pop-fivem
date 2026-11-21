local sessions, cache, busy, owners = {}, {}, {}, {}
local token = 0
local ready = false

local function player(src)
    if not src or not ready or Bridge.IsDead(src) then return nil, 'busy' end
    local identifier = Bridge.GetIdentifier(src)
    local ped = GetPlayerPed(src)
    local model = ped ~= 0 and ClothesCatalog.Model(GetEntityModel(ped))
    if type(identifier) ~= 'string' or #identifier > 191 then return nil, 'error' end
    if not model then return nil, 'unsupported_model' end
    owners[src] = identifier
    return identifier, model
end

local function stored(identifier, model)
    local entry = cache[identifier]
    if entry and entry[model] then return entry[model] end
    local ok, raw = pcall(MySQL.scalar.await, 'SELECT selections FROM pop_clothes_outfits WHERE identifier = ? AND model = ?',
        { identifier, model })
    if not ok then return nil end
    local data = {}
    if raw then
        local decoded, parsed = pcall(json.decode, raw)
        if not decoded or type(parsed) ~= 'table' then return nil end
        for id, option in pairs(parsed) do
            if ClothesCatalog.Option(id, option, model) then data[id] = option end
        end
    end
    entry = cache[identifier] or {}
    cache[identifier] = entry
    if not entry[model] then entry[model] = data end
    return entry[model]
end

local function atShop(src, shop)
    if not Bridge.IsNear(src, shop.coords, Config.ShopDistance) then return false, 'too_far' end
    if shop.job and not Bridge.HasJob(src, shop.job) then return false, 'wrong_job' end
    if shop.onDuty then
        local job = Bridge.GetJob(src)
        if not job or not job.onDuty then return false, 'wrong_job' end
    end
    return true
end

local function free()
    return Config.Account == false or Bridge.Framework == 'standalone'
end

Callback.Register('pop_clothes:load', function(src)
    local identifier, model = player(src)
    if not identifier then return nil, model end
    local selections = stored(identifier, model)
    if not selections or owners[src] ~= identifier or Bridge.GetIdentifier(src) ~= identifier then
        if owners[src] ~= identifier then cache[identifier] = nil end
        return nil, 'error'
    end
    return { model = model, selections = selections }
end)

Callback.Register('pop_clothes:open', function(src, shopId)
    if math.type(shopId) ~= 'integer' or not Config.Shops[shopId] then return nil, 'error' end
    local identifier, model = player(src)
    if not identifier then return nil, model end
    local shop = Config.Shops[shopId]
    local valid, reason = atShop(src, shop)
    if not valid then return nil, reason end
    local bucket = GetPlayerRoutingBucket(src)
    local selections = stored(identifier, model)
    local latestId, latestModel = player(src)
    if not selections or latestId ~= identifier or latestModel ~= model or GetPlayerRoutingBucket(src) ~= bucket then
        return nil, 'error'
    end
    valid, reason = atShop(src, shop)
    if not valid then return nil, reason end
    token = token % 2147483647 + 1
    sessions[src] = {
        token = token, identifier = identifier, model = model, shop = shopId,
        bucket = bucket, expires = os.time() + Config.SessionSeconds,
    }
    return { token = token, model = model, kind = shop.kind, selections = selections, free = free() }
end)

Callback.Register('pop_clothes:cancel', function(src, match)
    if sessions[src] and sessions[src].token == match then sessions[src] = nil end
    return true
end)

local function purchase(src, state, raw)
    local identifier, model = state.identifier, state.model
    local shop = Config.Shops[state.shop]
    local previous = stored(identifier, model)
    if not previous then return false, 'error' end
    local desired = {}
    for id, option in pairs(previous) do desired[id] = option end
    local count, changes, total = 0, 0, 0
    for id, selection in pairs(raw) do
        count = count + 1
        if count > 32 then return false, 'invalid_option' end
        local option = ClothesCatalog.Option(id, selection, model, shop.kind)
        if not option then return false, 'invalid_option' end
        if previous[id] ~= selection then
            changes, total = changes + 1, total + option.price
            desired[id] = selection
        end
    end
    if changes == 0 then return true, previous end

    local currentIdentifier, currentModel = player(src)
    if currentIdentifier ~= identifier or currentModel ~= model or GetPlayerRoutingBucket(src) ~= state.bucket
        or state.expires <= os.time() or sessions[src] ~= state then
        return false, 'session_expired'
    end
    local valid, reason = atShop(src, shop)
    if not valid then return false, reason end

    local charge = (not free()) and total or 0
    local profile = json.encode(desired)
    if charge > 0 and not Bridge.RemoveMoney(src, Config.Account, charge, 'pop_clothes') then
        return false, 'not_enough_money'
    end
    local ok, affected = pcall(MySQL.update.await, [[
        INSERT INTO pop_clothes_outfits (identifier, model, selections) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE selections = VALUES(selections)
    ]], { identifier, model, profile })
    if not ok or type(affected) ~= 'number' then
        if charge > 0 then
            local refundedOK, refunded = pcall(function()
                return Bridge.GetIdentifier(src) == identifier
                    and Bridge.AddMoney(src, Config.Account, charge, 'pop_clothes')
            end)
            if not refundedOK or not refunded then
                print(('[pop_clothes] Purchase rollback could not refund %d to %s'):format(charge, identifier))
            end
        end
        return false, 'error'
    end
    cache[identifier] = cache[identifier] or {}
    cache[identifier][model] = desired
    return true, desired
end

Callback.Register('pop_clothes:buy', function(src, match, raw)
    local identifier, model = player(src)
    if not identifier then return false, model end
    local state = sessions[src]
    if not state or state.token ~= match or state.identifier ~= identifier or state.model ~= model
        or state.expires <= os.time() or GetPlayerRoutingBucket(src) ~= state.bucket then
        return false, 'session_expired'
    end
    if busy[identifier] then return false, 'busy' end
    if type(raw) ~= 'table' then return false, 'invalid_option' end
    busy[identifier] = true
    local ok, success, result = pcall(purchase, src, state, raw)
    busy[identifier] = nil
    if owners[src] ~= identifier then cache[identifier] = nil end
    if not ok then
        print('[pop_clothes] Purchase failed: ' .. tostring(success))
        return false, 'error'
    end
    return success, result
end)

exports('GetSelections', function(src)
    local identifier, model = player(tonumber(src))
    local entry = identifier and cache[identifier]
    if not entry or not entry[model] then return end
    local output = {}
    for key, value in pairs(entry[model]) do output[key] = value end
    return output
end)

local function leave(src)
    local identifier = owners[src]
    owners[src], sessions[src] = nil, nil
    if identifier and not busy[identifier] then cache[identifier] = nil end
end
Bridge.OnPlayerDropped(leave)
Bridge.OnPlayerUnloaded(function(src)
    leave(src)
    TriggerClientEvent('pop_clothes:client:unloaded', src)
end)

MySQL.ready(function()
    MySQL.query.await(assert(LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')))
    ready = true
end)
