-- Employés et grades selon le framework (ESX Legacy / ancien ESX, QBCore, Qbox).
-- Table globale `Jobs` (SPEC §11). Toutes les fonctions publiques sont protégées (pcall).
-- Un employé = { identifier, name, grade, src? } ; `src` présent seulement s'il est en ligne.

Jobs = {}

local RES = GetCurrentResourceName()
local FWK = Bridge.Framework
local MAX_EMPLOYEES = 100
local CACHE_TTL = 300 -- secondes (cache des grades)

local ESX, QBCore

if FWK == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end) -- ancien ESX
    end
elseif FWK == 'qbcore' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    QBCore = ok and obj or nil
end

Jobs.Supported = (FWK == 'esx' and ESX ~= nil) or (FWK == 'qbcore' and QBCore ~= nil) or FWK == 'qbox'

local function debug(msg, ...)
    if Config.Debug then print(('[%s] jobs: ' .. msg):format(RES, ...)) end
end

-- Appel protégé : renvoie le résultat, ou `fallback` en cas d'erreur.
local function safe(fallback, fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        debug('error: %s', tostring(res))
        return fallback
    end
    return res
end

local function decode(s)
    if type(s) == 'table' then return s end
    if type(s) ~= 'string' then return nil end
    local ok, t = pcall(json.decode, s)
    return ok and type(t) == 'table' and t or nil
end

-- Nom depuis le charinfo QBCore / Qbox (JSON ou table).
local function charName(charinfo)
    local c = decode(charinfo)
    if not c then return '-' end
    local n = (('%s %s'):format(c.firstname or '', c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or '-'
end

------------------------------------------------------------------------
-- Définition des jobs (label + grades), en cache
------------------------------------------------------------------------

local cache = {} -- [job] = { t, label, grades = { { grade, label }, ... } }

local function readJob(job)
    local label, grades = nil, {}
    if FWK == 'esx' then
        local def = ESX.GetJobs and ESX.GetJobs()[job]
        if def then
            label = def.label
            for k, g in pairs(def.grades or {}) do
                local level = tonumber(g.grade) or tonumber(k)
                if level then grades[#grades + 1] = { grade = level, label = g.label or tostring(level) } end
            end
        else
            -- NOTE: ancien ESX sans ESX.GetJobs : lecture directe des tables du framework.
            label = MySQL.scalar.await('SELECT label FROM jobs WHERE name = ?', { job })
            for _, r in ipairs(MySQL.query.await('SELECT grade, label FROM job_grades WHERE job_name = ?', { job }) or {}) do
                local level = tonumber(r.grade)
                if level then grades[#grades + 1] = { grade = level, label = r.label or tostring(level) } end
            end
        end
    elseif FWK == 'qbcore' then
        local def = QBCore.Shared.Jobs[job]
        if def then
            label = def.label
            for k, g in pairs(def.grades or {}) do
                local level = tonumber(k)
                if level then grades[#grades + 1] = { grade = level, label = g.name or tostring(level) } end
            end
        end
    elseif FWK == 'qbox' then
        local def = exports.qbx_core:GetJob(job)
        if def then
            label = def.label
            for k, g in pairs(def.grades or {}) do
                local level = tonumber(k)
                if level then grades[#grades + 1] = { grade = level, label = g.name or tostring(level) } end
            end
        end
    end
    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return { t = os.time(), label = label, grades = grades }
end

local function getJob(job)
    local c = cache[job]
    if c and os.time() - c.t < CACHE_TTL then return c end
    if not Jobs.Supported or type(job) ~= 'string' then return { t = 0, grades = {} } end
    c = safe(nil, readJob, job)
    if not c then return { t = 0, grades = {} } end
    if #c.grades > 0 then cache[job] = c end -- un job vide n'est pas mis en cache (framework pas encore prêt)
    return c
end

--- Grades triés par ordre croissant : { { grade, label }, ... }.
function Jobs.GetGrades(job)
    local out = {}
    for i, g in ipairs(getJob(job).grades) do out[i] = { grade = g.grade, label = g.label } end
    return out
end

--- Label du job, sinon son nom.
function Jobs.GetLabel(job)
    return getJob(job).label or job
end

------------------------------------------------------------------------
-- Joueurs en ligne
------------------------------------------------------------------------

local function onlinePlayer(identifier)
    if FWK == 'esx' then
        return ESX.GetPlayerFromIdentifier(identifier)
    elseif FWK == 'qbcore' then
        return QBCore.Functions.GetPlayerByCitizenId(identifier)
    elseif FWK == 'qbox' then
        return exports.qbx_core:GetPlayerByCitizenId(identifier)
    end
end

--- Source du joueur en ligne ayant cet identifiant, sinon nil.
function Jobs.FindOnline(identifier)
    if not Jobs.Supported or type(identifier) ~= 'string' then return nil end
    return safe(nil, function()
        local p = onlinePlayer(identifier)
        if not p then return nil end
        return tonumber(p.source or (p.PlayerData and p.PlayerData.source))
    end)
end

-- Grade d'un joueur en ligne dans `job`, ou nil s'il n'y appartient pas.
-- Qbox : un joueur peut appartenir au job sans que ce soit son job principal (PlayerData.jobs).
local function onlineGrade(src, job)
    local j = Bridge.GetJob(src)
    if j and j.name == job then return j.grade end
    if FWK == 'qbox' then
        return safe(nil, function()
            local p = exports.qbx_core:GetPlayer(src)
            local jobs = p and p.PlayerData.jobs
            return jobs and tonumber(jobs[job]) or nil
        end)
    end
    return nil
end

local function onlineEmployee(src, job, identifier)
    local grade = onlineGrade(src, job)
    if not grade then return nil end
    return { identifier = identifier, name = Bridge.GetName(src) or '-', grade = grade, src = src }
end

------------------------------------------------------------------------
-- Lecture des employés en base (hors ligne compris)
------------------------------------------------------------------------

-- ESX : requêtes avec users.firstname / lastname (Legacy), sinon users.name (ancien ESX).
local ESX_QUERIES = {
    byJob = {
        'SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ? LIMIT 100',
        'SELECT identifier, name, job_grade FROM users WHERE job = ? LIMIT 100',
    },
    byId = {
        'SELECT identifier, firstname, lastname, job_grade FROM users WHERE identifier = ? AND job = ?',
        'SELECT identifier, name, job_grade FROM users WHERE identifier = ? AND job = ?',
    },
}

local function esxRows(queries, params)
    local ok, rows = pcall(MySQL.query.await, queries[1], params)
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            local n = (('%s %s'):format(r.firstname or '', r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            r.name = n ~= '' and n or '-'
        end
        return rows
    end
    -- NOTE: ancien ESX sans colonnes firstname / lastname.
    rows = MySQL.query.await(queries[2], params)
    return type(rows) == 'table' and rows or {}
end

-- Qbox : membres du groupe, liste { citizenid, grade } ou table citizenid -> grade.
local function qboxMembers(job)
    local res = exports.qbx_core:GetGroupMembers(job, 'job')
    local out = {}
    if type(res) ~= 'table' then return out end
    for k, v in pairs(res) do
        if type(v) == 'table' and v.citizenid then
            out[#out + 1] = { identifier = v.citizenid, grade = tonumber(v.grade) or 0 }
        elseif type(k) == 'string' then
            out[#out + 1] = { identifier = k, grade = tonumber(v) or 0 }
        end
    end
    return out
end

local function qboxNames(cids)
    local names = {}
    if #cids == 0 then return names end
    local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { cids })
    for _, r in ipairs(rows or {}) do names[r.citizenid] = charName(r.charinfo) end
    return names
end

-- Employés en base : { { identifier, name, grade }, ... } (100 max).
local function storedEmployees(job)
    local list = {}
    if FWK == 'esx' then
        for _, r in ipairs(esxRows(ESX_QUERIES.byJob, { job })) do
            list[#list + 1] = { identifier = r.identifier, name = r.name or '-', grade = tonumber(r.job_grade) or 0 }
        end
    elseif FWK == 'qbcore' then
        local rows = MySQL.query.await(
            "SELECT citizenid, charinfo, job FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ? LIMIT 100", { job })
        for _, r in ipairs(rows or {}) do
            local j = decode(r.job)
            local level = j and (type(j.grade) == 'table' and j.grade.level or j.grade)
            list[#list + 1] = { identifier = r.citizenid, name = charName(r.charinfo), grade = tonumber(level) or 0 }
        end
    elseif FWK == 'qbox' then
        local members = qboxMembers(job)
        local cids = {}
        for i = 1, math.min(#members, MAX_EMPLOYEES) do cids[i] = members[i].identifier end
        local names = qboxNames(cids)
        for i = 1, #cids do
            local m = members[i]
            list[i] = { identifier = m.identifier, name = names[m.identifier] or '-', grade = m.grade }
        end
    end
    return list
end

local function storedEmployee(job, identifier)
    if FWK == 'esx' then
        local r = esxRows(ESX_QUERIES.byId, { identifier, job })[1]
        return r and { identifier = r.identifier, name = r.name or '-', grade = tonumber(r.job_grade) or 0 }
    elseif FWK == 'qbcore' then
        local r = (MySQL.query.await('SELECT citizenid, charinfo, job FROM players WHERE citizenid = ?', { identifier }) or {})[1]
        local j = r and decode(r.job)
        if not j or j.name ~= job then return nil end
        local level = type(j.grade) == 'table' and j.grade.level or j.grade
        return { identifier = identifier, name = charName(r.charinfo), grade = tonumber(level) or 0 }
    elseif FWK == 'qbox' then
        for _, m in ipairs(qboxMembers(job)) do
            if m.identifier == identifier then
                return { identifier = identifier, name = qboxNames({ identifier })[identifier] or '-', grade = m.grade }
            end
        end
    end
    return nil
end

--- Employés du job (hors ligne compris, 100 max). Les joueurs en ligne passent en premier (nom et grade en direct).
function Jobs.GetEmployees(job)
    if not Jobs.Supported or type(job) ~= 'string' then return {} end
    return safe({}, function()
        local list, online = {}, {}
        for _, src in ipairs(Bridge.GetPlayers()) do
            local id = Bridge.GetIdentifier(src)
            if id and not online[id] then
                online[id] = true
                local emp = onlineEmployee(src, job, id)
                if emp and #list < MAX_EMPLOYEES then list[#list + 1] = emp end
            end
        end
        for _, emp in ipairs(storedEmployees(job)) do
            if #list >= MAX_EMPLOYEES then break end
            -- Un joueur en ligne est déjà traité (données en direct) : sa ligne en base est ignorée.
            if emp.identifier and not online[emp.identifier] then
                online[emp.identifier] = true
                list[#list + 1] = emp
            end
        end
        return list
    end)
end

--- Employé relu au moment de l'appel, ou nil s'il n'appartient plus au job.
function Jobs.GetEmployee(job, identifier)
    if not Jobs.Supported or type(job) ~= 'string' or type(identifier) ~= 'string' then return nil end
    return safe(nil, function()
        local src = Jobs.FindOnline(identifier)
        if src then return onlineEmployee(src, job, identifier) end
        return storedEmployee(job, identifier)
    end)
end

------------------------------------------------------------------------
-- Écritures
------------------------------------------------------------------------

-- QBCore : JSON du job tel que l'écrit Player.Functions.SetJob (joueur hors ligne).
local function qbJobJson(job, grade)
    local def = QBCore.Shared.Jobs[job]
    local g = def and def.grades and def.grades[tostring(grade)]
    if not g then return nil end
    return json.encode({
        name = job,
        label = def.label,
        payment = g.payment or 0,
        type = def.type or 'none',
        onduty = false,
        isboss = g.isboss or false,
        grade = { name = g.name, level = grade },
    })
end

-- Applique job / grade à un joueur en ligne (ESX, QBCore). Vérifie le résultat.
local function setOnlineJob(src, job, grade)
    if FWK == 'esx' then
        if ESX.DoesJobExist and not ESX.DoesJobExist(job, grade) then return false end
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.setJob(job, grade)
        xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer ~= nil and xPlayer.job.name == job and tonumber(xPlayer.job.grade) == grade
    elseif FWK == 'qbcore' then
        local p = QBCore.Functions.GetPlayer(src)
        if not p or p.Functions.SetJob(job, grade) == false then return false end
        p = QBCore.Functions.GetPlayer(src)
        return p ~= nil and p.PlayerData.job.name == job
    end
    return false
end

--- Recrute un joueur en ligne au grade donné.
function Jobs.Hire(src, job, grade)
    if not Jobs.Supported then return false end
    return safe(false, function()
        if FWK == 'qbox' then
            local cid = Bridge.GetIdentifier(src)
            if not cid or exports.qbx_core:AddPlayerToJob(cid, job, grade) == false then return false end
            return exports.qbx_core:SetPlayerPrimaryJob(cid, job) ~= false
        end
        return setOnlineJob(src, job, grade)
    end) == true
end

--- Change le grade d'un employé (en ligne ou hors ligne).
function Jobs.SetGrade(job, identifier, grade)
    if not Jobs.Supported then return false end
    return safe(false, function()
        if FWK == 'qbox' then
            return exports.qbx_core:AddPlayerToJob(identifier, job, grade) ~= false
        end
        local src = Jobs.FindOnline(identifier)
        if src then
            local j = Bridge.GetJob(src)
            if not j or j.name ~= job then return false end
            return setOnlineJob(src, job, grade)
        end
        if FWK == 'esx' then
            if ESX.DoesJobExist and not ESX.DoesJobExist(job, grade) then return false end
            local n = MySQL.update.await('UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?', { grade, identifier, job })
            return (tonumber(n) or 0) > 0
        end
        local data = qbJobJson(job, grade)
        if not data then return false end
        local n = MySQL.update.await(
            "UPDATE players SET job = ? WHERE citizenid = ? AND JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?",
            { data, identifier, job })
        return (tonumber(n) or 0) > 0
    end) == true
end

--- Renvoie un employé (en ligne ou hors ligne) : il repasse sans emploi.
function Jobs.Fire(job, identifier)
    if not Jobs.Supported then return false end
    return safe(false, function()
        if FWK == 'qbox' then
            return exports.qbx_core:RemovePlayerFromJob(identifier, job) ~= false
        end
        local src = Jobs.FindOnline(identifier)
        if src then
            local j = Bridge.GetJob(src)
            if not j or j.name ~= job then return false end
            return setOnlineJob(src, 'unemployed', 0)
        end
        if FWK == 'esx' then
            local n = MySQL.update.await(
                "UPDATE users SET job = 'unemployed', job_grade = 0 WHERE identifier = ? AND job = ?", { identifier, job })
            return (tonumber(n) or 0) > 0
        end
        local data = qbJobJson('unemployed', 0)
        if not data then return false end
        local n = MySQL.update.await(
            "UPDATE players SET job = ? WHERE citizenid = ? AND JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?",
            { data, identifier, job })
        return (tonumber(n) or 0) > 0
    end) == true
end
