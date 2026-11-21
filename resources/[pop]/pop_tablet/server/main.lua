-- Démarrage, joueurs, nettoyage. Aucune boucle : tout est déclenché par des events.

Tablet = Tablet or {}
local RES = GetCurrentResourceName()

local function log(key, ...)
    print(('[%s] %s'):format(RES, L(key, ...)))
end

local function start()
    Tablet.DB.Install()
    local purged, purgedCalls = Tablet.DB.Purge(Config.Retention.Days, Tablet.Now())
    if purged > 0 or purgedCalls > 0 then log('log_purged', purged, purgedCalls) end
    log(Tablet.Device.Mode() == 'item' and 'log_mode_item' or 'log_mode_owner')
    if GetConvar('pop_tablet_pepper', '') == '' then log('log_pepper_missing') end
    -- Utiliser l'objet ouvre la tablette (le serial de la pile utilisée sert d'indice, revérifié à l'ouverture).
    Bridge.RegisterUsableItem(Config.Item, function(src, _, metadata)
        TriggerClientEvent('pop_tablet:client:use', src, type(metadata) == 'table' and metadata.serial or nil)
    end)
end

if MySQL and MySQL.ready then
    MySQL.ready(start)
else
    CreateThread(start)
end

-- Nettoyage : drop, retour au choix du personnage, arrêt de la ressource.
Bridge.OnPlayerDropped(function(src) Tablet.Device.DropSession(src) end)
Bridge.OnPlayerUnloaded(function(src) Tablet.Device.DropSession(src) end)

AddEventHandler('onResourceStop', function(resource)
    if resource == RES then Tablet.Device.StopAll() end
end)

-- Échéance signalée par le client (alarme, rappel, événement) : le serveur revérifie l'objet porté.
RegisterNetEvent('pop_tablet:server:due', function(id, kind)
    local src = source
    if not Tablet.Limits.Rate(src, 'due', 5) then return end
    if math.type(id) ~= 'integer' or type(kind) ~= 'string' or #kind > 16 then return end
    local s = Tablet.Device.GetSession(src)
    if not s or not Bridge.GetPlayer(src) or not Tablet.Device.Carries(src, s.serial) then return end
    for _, handler in ipairs(Tablet.DueHandlers) do
        local ok, err = pcall(handler, src, s.serial, id, kind)
        if not ok and Config.Debug then print(('[%s] due handler: %s'):format(RES, tostring(err))) end
    end
end)

-- /pop_tablet_give [id] : réservé aux administrateurs (ACE pop.admin) et à la console.
RegisterCommand('pop_tablet_give', function(src, args)
    local function say(text)
        if src == 0 then print(text) else Bridge.Notify(src, text, 'info') end
    end
    if src ~= 0 and not Bridge.IsAdmin(src) then return say(L('no_permission')) end
    local target = tonumber(args[1]) or (src ~= 0 and src or nil)
    if not target or not Bridge.GetPlayer(target) then return say(L('give_target')) end
    local ok, serial, err = Tablet.Device.Give(target)
    if not ok then return say(L(err or 'error')) end
    say(serial and L('give_ok', target, serial) or L('give_owner_mode'))
end, false)

-- Diagnostic : nombre de sessions (aucune session résiduelle après un drop). Actif seulement avec Config.Debug.
if Config.Debug then
    RegisterCommand('pop_tablet_sessions', function(src)
        if src ~= 0 and not Bridge.IsAdmin(src) then return end
        print(('[%s] sessions: %d, scheduler: %d'):format(RES, Tablet.Device.SessionCount(), Tablet.Scheduler.Count()))
    end, false)
end
