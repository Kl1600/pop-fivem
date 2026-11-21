Police = Police or {}
local ready = false

MySQL.ready(function()
    local schema = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    for statement in schema:gmatch('(CREATE TABLE.-);') do MySQL.query.await(statement) end
    ready = true
end)

local function awaitDatabase()
    local timeout = GetGameTimer() + 10000
    while not ready and GetGameTimer() < timeout do Wait(100) end
    return ready
end

function Police.GetCitizenId(identifier, name)
    if not identifier or not awaitDatabase() then return end
    return MySQL.insert.await([[
        INSERT INTO pop_police_citizens (identifier, name) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), id = LAST_INSERT_ID(id)
    ]], { identifier, Police.Truncate(name, 100) })
end

local function playerInfo(src)
    local identifier = GetPlayerName(src) and Bridge.GetIdentifier(src)
    return identifier, identifier and (Bridge.GetName(src) or '#' .. src)
end

local function positiveInteger(value)
    return math.type(value) == 'integer' and value > 0 and value <= 4294967295
end

local function register(name, write, fn)
    Callback.Register('pop_police:' .. name, function(src, ...)
        local ok, reason = Police.CheckOfficer(src)
        if not ok then return false, reason end
        local identity = Bridge.GetIdentifier(src)
        if not identity or not awaitDatabase() or Bridge.GetIdentifier(src) ~= identity then return false, 'error' end
        ok, reason = Police.CheckOfficer(src)
        if not ok then return false, reason end
        local function run(actor, ...)
            local success, errorKey, result = fn(actor, identity, ...)
            if Bridge.GetIdentifier(actor) ~= identity then return false, 'error' end
            local authorized, denial = Police.CheckOfficer(actor)
            if not authorized then return false, denial end
            return success, errorKey, result
        end
        if write then return Police.WithLock(src, run, ...) end
        return run(src, ...)
    end)
end

register('mdtSearch', false, function(_, _, query)
    local clean, length = Police.CleanText(query, Police.QUERY_MAX)
    if not clean then return false, 'invalid_query' end
    local id = math.tointeger(tonumber(clean))
    if id then
        if not positiveInteger(id) then return true, nil, {} end
        local identifier, name = playerInfo(id)
        if not identifier then return true, nil, {} end
        local known = MySQL.scalar.await('SELECT id FROM pop_police_citizens WHERE identifier = ?', { identifier })
        return true, nil, { { citizenId = known, serverId = id, name = name } }
    end
    if length < 2 then return false, 'invalid_query' end
    local pattern = '%' .. clean:gsub('[!%%_]', '!%0') .. '%'
    local known = MySQL.query.await([[
        SELECT id, identifier, name FROM pop_police_citizens WHERE name LIKE ? ESCAPE '!'
        ORDER BY name, id LIMIT ?
    ]], { pattern, Police.RESULTS_MAX }) or {}
    local results, byIdentifier = {}, {}
    for _, row in ipairs(known) do
        local result = { citizenId = row.id, name = row.name }
        byIdentifier[row.identifier] = result
        results[#results + 1] = result
    end
    local lower = clean:lower()
    for _, player in ipairs(Bridge.GetPlayers()) do
        local identifier, name = playerInfo(player)
        if identifier then
            local previous = byIdentifier[identifier]
            if previous then
                previous.serverId, previous.name = player, name
            elseif name:lower():find(lower, 1, true) then
                local result = { serverId = player, name = name }
                byIdentifier[identifier] = result
                results[#results + 1] = result
            end
        end
    end
    table.sort(results, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return (a.citizenId or a.serverId) < (b.citizenId or b.serverId)
    end)
    for index = #results, Police.RESULTS_MAX + 1, -1 do results[index] = nil end
    return true, nil, results
end)

local function canDeleteAny(src)
    return Bridge.IsAdmin(src) or ((Bridge.GetJob(src) or {}).grade or 0) >= Config.BossGrade
end

local function getProfile(src, identity, citizenId)
    local row = MySQL.single.await('SELECT id, identifier, name FROM pop_police_citizens WHERE id = ?', { citizenId })
    if not row then return false, 'citizen_not_found' end
    local playerId
    for _, player in ipairs(Bridge.GetPlayers()) do
        if Bridge.GetIdentifier(player) == row.identifier then
            playerId = player
            break
        end
    end
    local notes = MySQL.query.await([[
        SELECT id, text, author, author_identifier, created_at AS createdAt FROM pop_police_notes
        WHERE citizen_id = ? ORDER BY created_at DESC, id DESC LIMIT ?
    ]], { citizenId, Police.HISTORY_MAX }) or {}
    local fines = MySQL.query.await([[
        SELECT id, amount, reason, status, officer, created_at AS createdAt FROM pop_police_fines
        WHERE citizen_id = ? ORDER BY created_at DESC, id DESC LIMIT ?
    ]], { citizenId, Police.HISTORY_MAX }) or {}
    local unpaid = MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0) FROM pop_police_fines WHERE citizen_id = ? AND status = ?
    ]], { citizenId, 'unpaid' })
    local deleteAny = canDeleteAny(src)
    for _, note in ipairs(notes) do
        note.canDelete = deleteAny or identity == note.author_identifier
        note.author_identifier = nil
    end
    return true, nil, {
        citizenId = row.id, name = row.name, online = playerId ~= nil, serverId = playerId,
        notes = notes, fines = fines, unpaid = tonumber(unpaid) or 0,
    }
end

register('mdtProfile', false, function(src, identity, ref)
    if type(ref) ~= 'table' then return false, 'error' end
    if ref.serverId == nil and positiveInteger(ref.citizenId) then return getProfile(src, identity, ref.citizenId) end
    if ref.citizenId ~= nil or not positiveInteger(ref.serverId) then return false, 'error' end
    local identifier, name = playerInfo(ref.serverId)
    if not identifier then return false, 'citizen_not_found' end
    local citizenId = Police.GetCitizenId(identifier, name)
    if not citizenId then return false, 'error' end
    return getProfile(src, identity, citizenId)
end)

register('mdtAddNote', true, function(src, identity, citizenId, text)
    if not positiveInteger(citizenId) then return false, 'citizen_not_found' end
    local clean, length = Police.CleanText(text, Police.NOTE_MAX)
    if not clean or length < Police.NOTE_MIN then return false, 'invalid_note' end
    local name = Police.Truncate(Bridge.GetName(src) or '#' .. src, 100)
    local id = MySQL.insert.await([[
        INSERT INTO pop_police_notes (citizen_id, text, author, author_identifier, created_at)
        SELECT id, ?, ?, ?, ? FROM pop_police_citizens WHERE id = ?
    ]], { clean, name, identity, os.time(), citizenId })
    if not id or id == 0 then return false, 'citizen_not_found' end
    if Bridge.GetIdentifier(src) == identity then Bridge.Notify(src, L('note_added'), 'success') end
    return getProfile(src, identity, citizenId)
end)

register('mdtDeleteNote', true, function(src, identity, noteId)
    if not positiveInteger(noteId) then return false, 'note_not_found' end
    local note = MySQL.single.await('SELECT citizen_id, author_identifier FROM pop_police_notes WHERE id = ?', { noteId })
    if not note then return false, 'note_not_found' end
    if Bridge.GetIdentifier(src) ~= identity then return false, 'error' end
    local ok, reason = Police.CheckOfficer(src)
    if not ok then return false, reason end
    if note.author_identifier ~= identity and not canDeleteAny(src) then return false, 'no_permission' end
    local affected = MySQL.update.await('DELETE FROM pop_police_notes WHERE id = ? AND author_identifier = ?', { noteId, note.author_identifier })
    if affected ~= 1 then return false, 'note_not_found' end
    if Bridge.GetIdentifier(src) == identity then Bridge.Notify(src, L('note_deleted'), 'success') end
    return getProfile(src, identity, note.citizen_id)
end)
