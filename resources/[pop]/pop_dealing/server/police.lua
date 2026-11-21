-- Police : comptage des policiers en service, témoins d'une vente, alertes (dispatch ou fallback).
-- Table globale Police utilisée par server/main.lua (appels à l'exécution uniquement).

Police = {}

local RES = GetCurrentResourceName()
local DISPATCHERS = { 'ps-dispatch', 'cd_dispatch', 'qs-dispatch' }
local OFFSET = 20.0 -- imprécision volontaire de la position (m)

local function log(msg, ...)
    if Config.Debug then print(('[%s] police: ' .. msg):format(RES, ...)) end
end

--- Policier en service : bon job ET en service (partagé avec server/main.lua).
function Police.IsOnDuty(src)
    if not Bridge.HasJob(src, Config.Police.jobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

--- Nombre de policiers en service.
function Police.Count()
    local n = 0
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Police.IsOnDuty(src) then n = n + 1 end
    end
    return n
end

--- PNJ vivants (non joueurs) autour de coords, plafonné à Config.Witnesses.max.
--- Appelé seulement au moment d'une vente conclue (GetAllPeds est coûteux).
function Police.CountWitnesses(coords, ignoreEntity)
    local radius, max = Config.Witnesses.radius, Config.Witnesses.max
    local n = 0
    for _, ped in ipairs(GetAllPeds()) do
        if ped ~= ignoreEntity and DoesEntityExist(ped) and not IsPedAPlayer(ped) and GetEntityHealth(ped) > 0
            and #(GetEntityCoords(ped) - coords) <= radius then
            n = n + 1
            if n >= max then break end
        end
    end
    return n
end

-- Système de dispatch à utiliser (résolu à chaque alerte : une ressource peut démarrer après nous).
local function dispatchSystem()
    local wanted = Config.Police.dispatch
    if wanted ~= 'auto' then return wanted end
    for _, name in ipairs(DISPATCHERS) do
        if GetResourceState(name) == 'started' then return name end
    end
    return 'notify'
end

-- NOTE: formats valables pour les versions courantes de ces ressources ; à ajuster dans ce seul fichier si besoin.
local SENDERS = {
    ['ps-dispatch'] = function(coords, kind, _, message)
        TriggerEvent('ps-dispatch:server:notify', {
            message = message, codeName = 'drugsell', code = '10-31', icon = 'fas fa-cannabis',
            priority = kind == 'bust' and 1 or 2, coords = coords, street = '',
            jobs = { 'leo', table.unpack(Config.Police.jobs) },
        })
    end,
    cd_dispatch = function(coords, kind, title, message)
        TriggerEvent('cd_dispatch:AddNotification', {
            job_table = Config.Police.jobs, coords = coords, title = title, message = message,
            flash = 0, unique_id = ('pop_dealing_%d'):format(os.time()), sound = 1,
            blip = { sprite = 51, scale = 1.0, colour = 1, flashes = kind == 'bust', text = title, time = 5, radius = 0 },
        })
    end,
    ['qs-dispatch'] = function(coords, kind, title, message)
        TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
            job = Config.Police.jobs, callLocation = coords,
            callCode = { code = '10-31', snippet = title }, message = message, flashes = kind == 'bust', image = nil,
            blip = { sprite = 51, scale = 1.0, colour = 1, flashes = kind == 'bust', text = title, time = Config.Police.blipTime * 1000 },
        })
    end,
}

-- Fallback : notification + blip côté client, uniquement aux policiers en service.
local function notifyCops(coords, kind)
    for _, src in ipairs(Bridge.GetPlayers()) do
        if Police.IsOnDuty(src) then
            TriggerClientEvent('pop_dealing:client:policeAlert', src, coords, kind)
        end
    end
end

--- kind = 'deal' | 'bust'. Position décalée de ± 20 m puis envoyée au dispatch.
function Police.Alert(coords, kind)
    if not coords then return end
    kind = kind == 'bust' and 'bust' or 'deal'
    local pos = vector3(
        coords.x + (math.random() * 2.0 - 1.0) * OFFSET,
        coords.y + (math.random() * 2.0 - 1.0) * OFFSET,
        coords.z
    )
    local title = L('dispatch_title')
    local message = L(kind == 'bust' and 'dispatch_bust' or 'dispatch_deal')
    local system = dispatchSystem()
    local send = SENDERS[system]

    if send then
        local ok, err = pcall(send, pos, kind, title, message)
        if ok then
            log('alert %s via %s', kind, system)
            return
        end
        -- NOTE: si le dispatch échoue (format changé, ressource arrêtée), on retombe sur le fallback.
        log('dispatch %s failed (%s), using notify', system, tostring(err))
    end
    notifyCops(pos, kind)
    log('alert %s via notify', kind)
end
