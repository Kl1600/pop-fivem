-- Échéances côté client (alarmes, rappels, événements) : UNE SetTimeout vers la prochaine, sur l'heure réelle.
-- À l'échéance on relit l'heure réelle, on prévient le serveur (qui revérifie tout) puis on re-planifie.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client
C.Scheduler = {}
local S = C.Scheduler

local MAX_ITEMS = 100
local MAX_RETRIES = 3
local KINDS = { alarm = true, event = true, reminder = true }

local items = {}
local generation = 0

--- Garde les éléments valides : { id = entier, kind = 'alarm'|'event'|'reminder', minute = 0..1439 }.
function S.Sanitize(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, it in ipairs(list) do
        if #out >= MAX_ITEMS then break end
        if type(it) == 'table' and math.type(it.id) == 'integer' and KINDS[it.kind] then
            local minute = math.tointeger(it.minute)
            if minute and minute >= 0 and minute <= 1439 then
                out[#out + 1] = { id = it.id, kind = it.kind, minute = minute }
            end
        end
    end
    return out
end

--- Prochaine échéance : renvoie l'élément et le délai en millisecondes réelles (heure réelle h:m:s, msPerMin par minute).
--- Un élément dont la minute est déjà entamée est reporté au lendemain.
function S.Next(list, h, m, sec, msPerMin)
    local nowMinute = h * 60 + m
    local best, bestDelta
    for _, it in ipairs(list) do
        local delta = ((it.minute - nowMinute) % 1440) * 60 - sec -- secondes
        if delta <= 0 then delta = delta + 86400 end
        if not bestDelta or delta < bestDelta then best, bestDelta = it, delta end
    end
    if not best then return nil end
    return best, bestDelta * msPerMin / 60
end

local function plan(retries)
    generation = generation + 1
    local mine = generation
    if #items == 0 then return end
    local now = C.ClockSnapshot()
    local best, delay = S.Next(items, now.h, now.m, now.s, now.msPerMin)
    if not best then return end
    SetTimeout(math.max(50, math.floor(delay)), function()
        if mine ~= generation then return end
        local at = C.ClockSnapshot()
        local nowMinute = at.h * 60 + at.m
        local fired = false
        local stamp = C.GameStamp()
        for _, it in ipairs(items) do
            if it.minute == nowMinute then
                fired = true
                TriggerServerEvent('pop_tablet:server:due', it.id, it.kind, stamp)
            end
        end
        if fired then
            plan(0)
        elseif retries < MAX_RETRIES then
            plan(retries + 1) -- minuterie arrivée trop tôt ou heure système modifiée : on recale
        else
            plan(0)
        end
    end)
end

--- Remplace les échéances (envoyées par l'interface après chaque modification) et re-planifie.
function S.Set(list)
    items = S.Sanitize(list)
    plan(0)
end

function S.Count()
    return #items
end
