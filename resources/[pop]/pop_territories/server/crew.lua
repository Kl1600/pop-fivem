-- Résolution du crew d'un joueur, évaluée à chaque appel (pop_crew peut démarrer après pop_territories).
--   1. pop_crew lancé  -> exports.pop_crew:GetPlayerCrew(src) (pcall) ; nil = pas de crew (pas de repli sur les jobs)
--   2. sinon Config.UseJobsAsCrews (hors standalone, qui n'a pas de jobs) -> job présent dans Config.JobCrews
--   3. sinon mode désactivé
-- Objet crew interne : { key = 'crew:12' | 'job:ballas', label, color = '#rrggbb' }.

Crew = {}

local RES = GetCurrentResourceName()
local LABEL_MAX = 32

local function popCrewStarted()
    return GetResourceState('pop_crew') == 'started'
end

-- NOTE: en standalone il n'y a pas de job : sans pop_crew, le mode est 'disabled'.
local function jobsEnabled()
    return Config.UseJobsAsCrews == true and type(Config.JobCrews) == 'table' and Bridge.Framework ~= 'standalone'
end

--- Couleur '#rrggbb' en minuscules, sinon '#ffffff'.
function Crew.Color(color)
    if type(color) == 'string' and color:match('^#%x%x%x%x%x%x$') then return color:lower() end
    return '#ffffff'
end

--- Label sûr : sans caractères de contrôle, UTF-8 valide, 32 caractères max ; vide -> L('crew_unknown').
function Crew.Label(label)
    if type(label) ~= 'string' and type(label) ~= 'number' then return L('crew_unknown') end
    label = tostring(label):gsub('%c', ''):match('^%s*(.-)%s*$')
    local len = utf8.len(label)
    if not len or len == 0 then return L('crew_unknown') end
    if len > LABEL_MAX then label = label:sub(1, utf8.offset(label, LABEL_MAX + 1) - 1) end
    return label
end

--- Construit un objet crew interne validé.
function Crew.Make(key, label, color)
    return { key = key, label = Crew.Label(label), color = Crew.Color(color) }
end

--- 'pop_crew' | 'jobs' | 'disabled'
function Crew.Mode()
    if popCrewStarted() then return 'pop_crew' end
    if jobsEnabled() then return 'jobs' end
    return 'disabled'
end

--- Crew interne du joueur (lecture fraîche) ou nil.
function Crew.Get(src)
    src = tonumber(src)
    if not src then return nil end

    if popCrewStarted() then
        local ok, data = pcall(function() return exports.pop_crew:GetPlayerCrew(src) end)
        if not ok or type(data) ~= 'table' then return nil end
        local n = tonumber(data.id)
        local id = n and math.tointeger(n)
        if not id then return nil end
        return Crew.Make('crew:' .. id, data.name, data.color)
    end

    if jobsEnabled() then
        local job = Bridge.GetJob(src)
        local name = job and job.name
        if type(name) ~= 'string' or Config.JobCrews[name] == nil then return nil end
        if #name > 60 then return nil end -- clé SQL limitée à 64 caractères
        return Crew.Make('job:' .. name, job.label or name, Config.JobCrews[name])
    end

    return nil
end

-- Un seul message au démarrage si aucun système de crew n'est disponible.
-- NOTE: vérifié après quelques secondes pour laisser pop_crew démarrer s'il est ensuré après nous.
CreateThread(function()
    Wait(5000)
    if Crew.Mode() == 'disabled' then
        print(('[%s] %s'):format(RES, L('crews_disabled')))
    end
end)
