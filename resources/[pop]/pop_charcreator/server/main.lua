local sessions, profiles, loading, writing, owners = {}, {}, {}, {}, {}
local nextToken = 0
local ready = false

local function canEdit(src)
    return IsPlayerAceAllowed(src, 'pop.charcreator.edit') or (Config.AllowAdminEdit and Bridge.IsAdmin(src))
end

local function daysInMonth(year, month)
    local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 and year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then return 29 end
    return monthDays[month]
end

local function birthLimits()
    local today = os.date('!*t')
    local year = (Config.Birth.serverYear or today.year) - Config.Birth.minAge
    local day = math.min(today.day, daysInMonth(year, today.month))
    return { min = ('%04d-01-01'):format(Config.Birth.minYear), max = ('%04d-%02d-%02d'):format(year, today.month, day) }
end

local function validBirth(value)
    if type(value) ~= 'string' or #value ~= 10 then return false end
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or month < 1 or month > 12 or day < 1 or day > daysInMonth(year, month) then return false end
    local limits = birthLimits()
    return value >= limits.min and value <= limits.max
end

local function cleanName(value)
    if type(value) ~= 'string' or #value > 96 then return end
    value = value:match('^%s*(.-)%s*$'):gsub(' +', ' ')
    local length = utf8.len(value)
    if not length or length < 2 or length > 24 then return end
    local letters = 0
    for _, letter in utf8.codes(value) do
        local separator = letter == 32 or letter == 39 or letter == 45 or letter == 0x2019
        if not separator then
            local valid = (letter >= 65 and letter <= 90) or (letter >= 97 and letter <= 122)
                or (letter >= 0xC0 and letter <= 0x2FF)
                or (letter >= 0x370 and letter <= 0x52F)
                or (letter >= 0x590 and letter <= 0x6FF and not (letter >= 0x600 and letter <= 0x605))
                or (letter >= 0x900 and letter <= 0xD7F) or (letter >= 0x3040 and letter <= 0x9FFF)
            if not valid then return end
            letters = letters + 1
        end
    end
    if letters >= 2 then return value end
end

local function storedProfile(identifier)
    if profiles[identifier] ~= nil then return profiles[identifier] or nil end
    if loading[identifier] then return nil, 'busy' end
    loading[identifier] = true
    local ok, entry = pcall(MySQL.scalar.await, 'SELECT profile FROM pop_charcreator_profiles WHERE identifier = ?', { identifier })
    loading[identifier] = nil
    if not ok then return nil, 'error' end
    if not entry then
        profiles[identifier] = false
        return
    end
    local decoded, profile = pcall(json.decode, entry)
    local appearance = decoded and CharacterProfile.Appearance(profile)
    if not appearance or not cleanName(profile.firstName) or not cleanName(profile.lastName)
        or type(profile.dateOfBirth) ~= 'string' or not profile.dateOfBirth:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil, 'error'
    end
    appearance.firstName, appearance.lastName, appearance.dateOfBirth = profile.firstName, profile.lastName, profile.dateOfBirth
    profiles[identifier] = appearance
    return appearance
end

local function identifierFor(src)
    if ready and not Bridge.IsDead(src) then
        local identifier = Bridge.GetIdentifier(src)
        if type(identifier) == 'string' and #identifier <= 191 then
            owners[src] = identifier
            return identifier
        end
    end
end

local function spawnOptions()
    local result = {}
    for i, point in ipairs(Config.Spawns) do result[i] = { id = point.id, label = point.label } end
    return result
end

local function validSpawn(id)
    if type(id) ~= 'string' or #id > 32 then return false end
    for _, point in ipairs(Config.Spawns) do
        if point.id == id then return true end
    end
    return false
end

Callback.Register('pop_charcreator:load', function(src)
    local identifier = identifierFor(src)
    if not identifier then return nil, 'busy' end
    local profile, reason = storedProfile(identifier)
    if reason then return nil, reason end
    if owners[src] ~= identifier or Bridge.GetIdentifier(src) ~= identifier then
        profiles[identifier] = nil
        return nil, 'error'
    end
    return { profile = profile, canCreate = profile == nil }
end)

Callback.Register('pop_charcreator:begin', function(src)
    local identifier = identifierFor(src)
    if not identifier then return nil, 'busy' end
    local profile, reason = storedProfile(identifier)
    if reason then return nil, reason end
    if owners[src] ~= identifier or Bridge.GetIdentifier(src) ~= identifier then
        profiles[identifier] = nil
        return nil, 'error'
    end
    if profile and not canEdit(src) then return nil, 'no_permission' end
    nextToken = nextToken % 2147483647 + 1
    sessions[src] = { token = nextToken, identifier = identifier, expires = os.time() + Config.SessionSeconds }
    return { token = nextToken, profile = profile, birth = birthLimits(), spawns = not profile and spawnOptions() or {} }
end)

Callback.Register('pop_charcreator:cancel', function(src, token)
    if sessions[src] and sessions[src].token == token then sessions[src] = nil end
    return true
end)

Callback.Register('pop_charcreator:save', function(src, token, raw, spawn)
    local session = sessions[src]
    local identifier = identifierFor(src)
    if not session or session.token ~= token or session.identifier ~= identifier or session.expires <= os.time() then
        return false, 'session_expired'
    end
    if writing[identifier] then return false, 'busy' end
    local existing = profiles[identifier]
    if existing and not canEdit(src) then return false, 'no_permission' end
    local profile = CharacterProfile.Appearance(raw)
    if not profile then return false, 'invalid_appearance' end
    profile.firstName, profile.lastName = cleanName(raw.firstName), cleanName(raw.lastName)
    if not profile.firstName or not profile.lastName then return false, 'invalid_name' end
    if not validBirth(raw.dateOfBirth) then return false, 'invalid_birth' end
    profile.dateOfBirth = raw.dateOfBirth
    if not existing then
        spawn = spawn == nil and Config.DefaultSpawn or spawn
        if not validSpawn(spawn) then return false, 'invalid_spawn' end
    else
        spawn = nil
    end

    writing[identifier] = true
    sessions[src] = nil
    local ok, affected = pcall(function()
        return MySQL.update.await([[
            INSERT INTO pop_charcreator_profiles (identifier, profile) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE profile = VALUES(profile)
        ]], { identifier, json.encode(profile) })
    end)
    writing[identifier] = nil
    if not ok or type(affected) ~= 'number' then
        if not sessions[src] and owners[src] == identifier
            and Bridge.GetIdentifier(src) == identifier and session.expires > os.time() then
            sessions[src] = session
        end
        return false, 'error'
    end
    if owners[src] == identifier and Bridge.GetIdentifier(src) == identifier then
        profiles[identifier] = profile
        TriggerEvent('pop_charcreator:profileSaved', src)
    else
        profiles[identifier] = nil
    end
    return true, profile, spawn
end)

local function currentProfile(src)
    local identifier = Bridge.GetIdentifier(src)
    return identifier and profiles[identifier] or nil
end

exports('GetIdentity', function(src)
    local profile = currentProfile(src)
    if not profile then return end
    return {
        firstName = profile.firstName, lastName = profile.lastName,
        dateOfBirth = profile.dateOfBirth, model = profile.model,
    }
end)

exports('GetAppearance', function(src)
    local profile = currentProfile(src)
    if not profile then return end
    local out = {}
    for key, value in pairs(profile) do out[key] = value end
    return out
end)

local function onLeave(src)
    local identifier = owners[src]
    sessions[src], owners[src] = nil, nil
    if identifier and not writing[identifier] then profiles[identifier] = nil end
end

Bridge.OnPlayerDropped(onLeave)
Bridge.OnPlayerUnloaded(function(src)
    onLeave(src)
    TriggerClientEvent('pop_charcreator:client:unloaded', src)
end)

MySQL.ready(function()
    MySQL.query.await(assert(LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')))
    ready = true
end)
