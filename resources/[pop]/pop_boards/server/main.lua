local name = GetCurrentResourceName()
local entries, ownerCount, lastWrite = {}, {}, {}
local total, ready, busy = 0, false, false
local tableName = 'pop_boards_surfaces'

local function number(value)
    return type(value) == 'number' and value == value and math.abs(value) <= 10000
end

local function point(value)
    if type(value) ~= 'table' or not (number(value.x) and number(value.y) and number(value.z)) then return end
    return vec3(value.x, value.y, value.z)
end

local function canWrite(src)
    return Bridge.IsAdmin(src) or not Config.WriteAce or IsPlayerAceAllowed(src, Config.WriteAce)
end

local function editor(src)
    if not ready then return nil, 'busy' end
    if Bridge.IsDead(src) then return nil, 'error' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier or #identifier > 96 then return nil, 'error' end
    return identifier
end

local function getEntry(src, id)
    local identifier, reason = editor(src)
    if not identifier then return nil, reason end
    local entry = math.type(id) == 'integer' and entries[id]
    if not entry or not Bridge.IsNear(src, entry.position, Config.ActionDistance) then return nil, 'too_far' end
    if not Bridge.IsAdmin(src) and (entry.owner ~= identifier or not canWrite(src)) then
        return nil, 'no_permission'
    end
    return entry
end

local function mutate(src, fn)
    local now = GetGameTimer()
    if busy or lastWrite[src] and now - lastWrite[src] < Config.WriteDelay then return false, 'busy' end
    lastWrite[src], busy = now, true
    local ran, ok, reason = pcall(fn)
    busy = false
    if ran then return ok, reason end
    print(('[%s] Write failed: %s'):format(name, tostring(ok)))
    return false, 'error'
end

local function array(value, max)
    if type(value) ~= 'table' or #value > max then return false end
    local count = 0
    for index in pairs(value) do
        if math.type(index) ~= 'integer' or index < 1 or index > #value then return false end
        count = count + 1
    end
    return count == #value
end

local function validateContent(strokes)
    if not array(strokes, Config.MaxStrokes) then return end
    local clean, pointsTotal = {}, 0
    for _, stroke in ipairs(strokes) do
        if type(stroke) ~= 'table' then return end
        local color, width, points = stroke.color, math.tointeger(stroke.width), stroke.points
        if type(color) ~= 'string' or #color ~= 7 or not color:match('^#%x+$') or not width or width < 1 or width > 32
            or not array(points, 2 * Config.MaxPoints) or #points < 2 or #points % 2 ~= 0 then return end
        pointsTotal = pointsTotal + #points / 2
        if pointsTotal > Config.MaxPoints then return end
        local coords = {}
        for i, value in ipairs(points) do
            local coordinate = type(value) == 'number' and math.tointeger(value)
            if not coordinate or coordinate < 0 or coordinate > 511 then return end
            coords[i] = coordinate
        end
        clean[#clean + 1] = { color = color:lower(), width = width, points = coords }
    end
    return clean
end

local function encodeContent(content) return json.encode(content) end
local function decodeContent(content) return validateContent(json.decode(content)) end

local function packed(value)
    return { x = value.x, y = value.y, z = value.z }
end

MySQL.ready(function()
    local schema = LoadResourceFile(name, 'sql/install.sql')
    MySQL.query.await(schema)
    local rows = MySQL.query.await(('SELECT * FROM %s ORDER BY id LIMIT ?'):format(tableName), { Config.MaxSurfaces })
    for _, row in ipairs(rows or {}) do
        local position = point({ x = row.x, y = row.y, z = row.z })
        local normal = point({ x = row.nx, y = row.ny, z = row.nz })
        local ok, content = pcall(decodeContent, row.content)
        if position and normal and #normal > 0.5 and ok and content ~= nil then
            entries[row.id] = { position = position, normal = normal / #normal,
                owner = row.owner, revision = row.revision, content = content }
            ownerCount[row.owner] = (ownerCount[row.owner] or 0) + 1
            total = total + 1
        end
    end
    ready = true
end)

Callback.Register(name .. ':nearby', function(src)
    local identifier = Bridge.GetIdentifier(src)
    if not ready or not identifier then return {} end
    local admin = Bridge.IsAdmin(src)
    local allowed = admin or canWrite(src)
    local coords = Bridge.GetCoords(src)
    if not coords then return {} end

    local rows = {}
    for id, entry in pairs(entries) do
        local distance = #(coords - entry.position)
        if distance <= Config.RenderDistance + 5 then
            rows[#rows + 1] = { id = id, position = packed(entry.position), normal = packed(entry.normal),
                revision = entry.revision, distance = distance,
                editable = admin or (allowed and entry.owner == identifier) }
        end
    end
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    for i = #rows, Config.MaxVisible + 1, -1 do rows[i] = nil end
    return rows
end)

Callback.Register(name .. ':content', function(src, id)
    local entry = math.type(id) == 'integer' and entries[id]
    if not entry or not Bridge.GetIdentifier(src)
        or not Bridge.IsNear(src, entry.position, Config.RenderDistance + 5) then return nil end
    return entry.content, entry.revision
end)

Callback.Register(name .. ':edit', function(src, id)
    local entry, reason = getEntry(src, id)
    if not entry then return false, reason end
    return true, entry.content, entry.revision
end)

Callback.Register(name .. ':access', function(src)
    local identifier, reason = editor(src)
    if not identifier then return false, reason end
    if not canWrite(src) then return false, 'no_permission' end
    if total >= Config.MaxSurfaces or (ownerCount[identifier] or 0) >= Config.MaxPerOwner then return false, 'limit' end
    return true
end)

Callback.Register(name .. ':save', function(src, id, revision, position, normal, value)
    return mutate(src, function()
        local identifier, reason = editor(src)
        if not identifier then return false, reason end
        if not canWrite(src) then return false, 'no_permission' end
        local content = validateContent(value)
        if content == nil then return false, 'bad_content' end

        if id ~= nil then
            local entry, editReason = getEntry(src, id)
            if not entry then return false, editReason end
            if revision ~= entry.revision then return false, 'changed' end
            local updated = MySQL.update.await(
                ('UPDATE %s SET content = ?, revision = revision + 1 WHERE id = ? AND revision = ?'):format(tableName),
                { encodeContent(content), id, revision })
            if updated ~= 1 then return false, 'changed' end
            entry.content, entry.revision = content, entry.revision + 1
            return true, 'saved'
        end

        local coordinates, direction = point(position), point(normal)
        if not coordinates or not direction or math.abs(#direction - 1.0) > 0.1 or math.abs(direction.z) > 0.25 then
            return false, 'find_wall'
        end
        if not Bridge.IsNear(src, coordinates, Config.ActionDistance) then return false, 'too_far' end
        if total >= Config.MaxSurfaces or (ownerCount[identifier] or 0) >= Config.MaxPerOwner then
            return false, 'limit'
        end
        for _, entry in pairs(entries) do
            if #(entry.position - coordinates) < 0.6 then return false, 'busy' end
        end

        direction = direction / #direction
        local newId = MySQL.insert.await(
            ('INSERT INTO %s (owner,x,y,z,nx,ny,nz,content) VALUES (?,?,?,?,?,?,?,?)'):format(tableName),
            { identifier, coordinates.x, coordinates.y, coordinates.z, direction.x, direction.y, direction.z,
                encodeContent(content) })
        if not newId or newId <= 0 then return false, 'error' end
        entries[newId] = { owner = identifier, position = coordinates, normal = direction,
            revision = 1, content = content }
        ownerCount[identifier] = (ownerCount[identifier] or 0) + 1
        total = total + 1
        return true, 'saved'
    end)
end)

Callback.Register(name .. ':remove', function(src, id, revision)
    return mutate(src, function()
        local entry, reason = getEntry(src, id)
        if not entry then return false, reason end
        if revision ~= entry.revision then return false, 'changed' end
        local removed = MySQL.update.await(('DELETE FROM %s WHERE id = ? AND revision = ?'):format(tableName),
            { id, revision })
        if removed ~= 1 then return false, 'changed' end
        entries[id] = nil
        ownerCount[entry.owner] = ownerCount[entry.owner] - 1
        if ownerCount[entry.owner] == 0 then ownerCount[entry.owner] = nil end
        total = total - 1
        return true, 'removed'
    end)
end)

local function clearTimer(src) lastWrite[src] = nil end
Bridge.OnPlayerDropped(clearTimer)
Bridge.OnPlayerUnloaded(function(src)
    clearTimer(src)
    TriggerClientEvent(name .. ':client:unloaded', src)
end)
