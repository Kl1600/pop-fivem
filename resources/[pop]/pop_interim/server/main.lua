-- pop_interim : serveur. Le client n'envoie qu'un index de lieu et un id de Config.Jobs ;
-- job, grade et délai viennent uniquement de la config et du serveur.

local ACTION_DISTANCE = 3.0

local available = {} -- [id] = true si le job existe dans le framework
local cooldowns = {} -- [identifier] = os.time() de fin du délai
local busy = {}      -- [identifier] = true pendant un traitement

local jobById = {}
for _, entry in ipairs(Config.Jobs) do jobById[entry.id] = entry end

local function debug(msg, ...)
    if Config.Debug then print(('[pop_interim] ' .. msg):format(...)) end
end

-- Vérification des jobs au démarrage (après le chargement du framework).
CreateThread(function()
    Wait(2000)
    if Bridge.Framework == 'standalone' then
        print('[pop_interim] job center disabled in standalone (no framework detected)')
        return
    end
    for _, entry in ipairs(Config.Jobs) do
        available[entry.id] = InterimJobs.Exists(entry.job, entry.grade)
        if not available[entry.id] then
            print(('[pop_interim] job "%s" (grade %s) not found in the framework: offer "%s" hidden'):format(entry.job, entry.grade, entry.id))
        end
    end
end)

local function remaining(identifier)
    local untilTime = identifier and cooldowns[identifier]
    if not untilTime then return 0 end
    local left = untilTime - os.time()
    if left <= 0 then
        cooldowns[identifier] = nil
        return 0
    end
    return left
end

-- Contrôles communs (SPEC section 12, points 1 à 3). Renvoie identifier, job ou nil, reason.
local function check(src, loc)
    if math.type(loc) ~= 'integer' or not Config.Locations[loc] then return nil, nil, 'error' end
    if not Bridge.IsNear(src, Config.Locations[loc].coords.xyz, ACTION_DISTANCE) then return nil, nil, 'too_far' end
    if Bridge.Framework == 'standalone' then return nil, nil, 'not_available' end
    if Bridge.IsDead(src) then return nil, nil, 'error' end
    local identifier, job = Bridge.GetIdentifier(src), Bridge.GetJob(src)
    if not identifier or not job then return nil, nil, 'error' end
    return identifier, job
end

local function currentJob(job)
    local id
    for _, entry in ipairs(Config.Jobs) do
        if job.name == entry.job and job.grade == entry.grade then
            id = entry.id
            break
        end
    end
    return { id = id, label = job.label or job.name, unemployed = job.name == Config.Unemployed.job }
end

Callback.Register('pop_interim:getJobs', function(src, loc)
    local identifier, job, reason = check(src, loc)
    if not identifier then return false, reason end

    local jobs = {}
    for _, entry in ipairs(Config.Jobs) do
        if available[entry.id] then jobs[#jobs + 1] = { id = entry.id } end
    end
    return true, nil, nil, jobs, currentJob(job), remaining(identifier)
end)

local function startCooldown(identifier)
    if Config.Cooldown <= 0 then return end
    local expires = os.time() + Config.Cooldown
    cooldowns[identifier] = expires
    SetTimeout(Config.Cooldown * 1000, function()
        if cooldowns[identifier] == expires then cooldowns[identifier] = nil end
    end)
end

local function locked(src, loc, fn)
    local identifier, job, reason = check(src, loc)
    if not identifier then return false, reason end
    if busy[identifier] then return false, 'busy' end
    busy[identifier] = true
    local ok, res, errorKey, arg = pcall(fn, identifier, job)
    busy[identifier] = nil
    if not ok then
        print(('[pop_interim] error: %s'):format(res))
        return false, 'error'
    end
    return res, errorKey, arg
end

Callback.Register('pop_interim:selectJob', function(src, loc, id)
    return locked(src, loc, function(identifier, job)
        local left = remaining(identifier)
        if left > 0 then return false, 'cooldown', left end

        local entry = type(id) == 'string' and jobById[id]
        if not entry or not available[id] then return false, 'job_unknown' end
        if job.name == entry.job and job.grade == entry.grade then return false, 'already_job' end

        if not InterimJobs.Set(src, entry.job, entry.grade) then return false, 'error' end

        startCooldown(identifier)
        debug('%s (%s) took job %s %s', src, identifier, entry.job, entry.grade)
        Bridge.Notify(src, L('job_set', L('job_' .. id)), 'success')
        return true
    end)
end)

Callback.Register('pop_interim:resign', function(src, loc)
    return locked(src, loc, function(identifier, job)
        local left = remaining(identifier)
        if left > 0 then return false, 'cooldown', left end

        if job.name == Config.Unemployed.job then return false, 'already_unemployed' end

        if not InterimJobs.Set(src, Config.Unemployed.job, Config.Unemployed.grade) then return false, 'error' end

        startCooldown(identifier)
        debug('%s (%s) resigned from %s', src, identifier, job.name)
        Bridge.Notify(src, L('resigned'), 'success')
        return true
    end)
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('GetCooldown', function(src)
    return remaining(Bridge.GetIdentifier(src))
end)

exports('ResetCooldown', function(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false end
    cooldowns[identifier] = nil
    return true
end)
