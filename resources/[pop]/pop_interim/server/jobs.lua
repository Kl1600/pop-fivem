-- Attribution de job par framework (local au script : le bridge commun ne gère pas setJob).
-- Tout appel framework est protégé par pcall : une erreur vaut false.

InterimJobs = {}

local ESX, QBCore

if Bridge.Framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        -- NOTE: ancien ESX (avant Legacy) : l'objet partagé n'est fourni que par cet event.
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end)
    end
elseif Bridge.Framework == 'qbcore' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = obj end
end

-- Grades indexés par chaîne ('0') ou par nombre (0) selon les versions.
local function hasGrade(grades, grade)
    if type(grades) ~= 'table' then return false end
    return grades[tostring(grade)] ~= nil or grades[tonumber(grade)] ~= nil
end

--- Le job (et ce grade) existe-t-il dans le framework ?
function InterimJobs.Exists(job, grade)
    local fw = Bridge.Framework
    if fw == 'esx' then
        if not ESX then return false end
        -- NOTE: ancien ESX sans DoesJobExist : on suppose que le job existe (setJob le refusera sinon).
        if type(ESX.DoesJobExist) ~= 'function' then return true end
        local ok, res = pcall(ESX.DoesJobExist, job, grade)
        return ok and res == true
    elseif fw == 'qbcore' then
        local ok, res = pcall(function()
            local j = QBCore.Shared.Jobs[job]
            return j ~= nil and hasGrade(j.grades, grade)
        end)
        return ok and res == true
    elseif fw == 'qbox' then
        local ok, res = pcall(function()
            local j = exports.qbx_core:GetJob(job)
            return j ~= nil and hasGrade(j.grades, grade)
        end)
        return ok and res == true
    end
    return false
end

--- Attribue le job au joueur. Renvoie true si le framework l'a accepté.
function InterimJobs.Set(src, job, grade)
    local fw = Bridge.Framework
    local ok, result
    if fw == 'esx' then
        ok, result = pcall(function()
            return Bridge.GetPlayer(src).setJob(job, grade)
        end)
    elseif fw == 'qbcore' then
        ok, result = pcall(function()
            return Bridge.GetPlayer(src).Functions.SetJob(job, grade)
        end)
    elseif fw == 'qbox' then
        ok, result = pcall(function()
            return exports.qbx_core:SetJob(src, job, grade)
        end)
    end
    if not ok or result == false then return false end

    -- Older ESX may return nil even after rejecting an unknown job or grade.
    local current = Bridge.GetJob(src)
    return current ~= nil and current.name == job and current.grade == grade
end
