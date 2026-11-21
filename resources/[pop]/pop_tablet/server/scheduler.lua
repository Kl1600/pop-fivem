-- Échéances serveur en secondes réelles (minuteurs). Aucune boucle : une seule SetTimeout vers la prochaine échéance.
-- SetTimeout n'est pas annulable : chaque minuterie porte un numéro de génération, les anciennes ne font rien.

Tablet = Tablet or {}
Tablet.Scheduler = {}
local S = Tablet.Scheduler

local MAX_DELAY_MS = 86400000

local items = {}      -- [clé] = { at = epoch secondes, fn = function(clé) }
local generation = 0
local armedFor = nil  -- échéance visée par la minuterie active
local clock = os.time

--- Remplace l'horloge (tests).
function S.SetClock(fn)
    clock = fn
end

local function nextAt()
    local best
    for _, it in pairs(items) do
        if not best or it.at < best then best = it.at end
    end
    return best
end

local function arm()
    local at = nextAt()
    if not at then
        generation = generation + 1
        armedFor = nil
        return
    end
    if armedFor == at then return end
    generation = generation + 1
    local mine = generation
    armedFor = at
    local delay = math.min(math.max(0, at - clock()) * 1000, MAX_DELAY_MS)
    SetTimeout(delay, function()
        if mine ~= generation then return end
        armedFor = nil
        S.Run()
    end)
end

--- Exécute les échéances dépassées puis arme la suivante.
function S.Run()
    local t = clock()
    local due = {}
    for key, it in pairs(items) do
        if it.at <= t then due[#due + 1] = key end
    end
    table.sort(due, function(a, b) return items[a].at < items[b].at end)
    for _, key in ipairs(due) do
        local it = items[key]
        items[key] = nil
        local ok, err = pcall(it.fn, key)
        if not ok then print(('[pop_tablet] scheduler "%s": %s'):format(tostring(key), tostring(err))) end
    end
    arm()
end

--- Programme (ou remplace) l'échéance `key` à l'instant epoch `at`.
function S.Add(key, at, fn)
    items[key] = { at = at, fn = fn }
    arm()
end

function S.Cancel(key)
    if items[key] == nil then return end
    items[key] = nil
    arm()
end

function S.Count()
    local n = 0
    for _ in pairs(items) do n = n + 1 end
    return n
end
