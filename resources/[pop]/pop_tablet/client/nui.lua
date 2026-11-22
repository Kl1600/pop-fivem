-- Callbacks NUI -> Lua (contrat de la section 8 de la SPEC). Réponse `cb({ ok, ... })`.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

local MAX_RELAY_BYTES = 131072

RegisterNUICallback('tablet:ready', function(_, cb)
    local last = C.LastOpen()
    if C.IsOpen() and last then C.Post('tablet:open', last) end
    cb({ ok = true })
end)

RegisterNUICallback('tablet:close', function(_, cb)
    C.Close('ui')
    cb({ ok = true })
end)

-- Échap ou `Pop.post('close')` du bridge : le focus est déjà rendu, on termine le nettoyage.
Bridge.OnUiClose(function()
    C.Close('ui')
end)

-- Relais générique vers `pop_tablet:<name>` : liste blanche des noms, tablette ouverte, charge bornée.
-- Le serveur refait tous les contrôles (objet porté, code, taille, propriété).
RegisterNUICallback('tablet:call', function(data, cb)
    if not C.IsOpen() then return cb({ ok = false, err = 'err_session' }) end
    if type(data) ~= 'table' or type(data.name) ~= 'string' or not Tablet.RelaySet[data.name] then
        return cb({ ok = false, err = 'err_unknown_call' })
    end
    if type(data.data) == 'table' and #json.encode(data.data) > MAX_RELAY_BYTES then
        return cb({ ok = false, err = 'err_too_large' })
    end
    Callback.Trigger('pop_tablet:' .. data.name, function(res)
        if type(res) ~= 'table' then res = { ok = false, err = 'err_timeout' } end
        cb(res)
    end, data.data)
end)

-- Horloge : l'interface demande une resynchronisation en ouvrant Horloge/Météo, et la coupe en les quittant.
RegisterNUICallback('tablet:resync', function(data, cb)
    if not C.IsOpen() then return cb({ ok = false, err = 'err_session' }) end
    C.SetResync(type(data) == 'table' and data.active ~= false)
    cb({ ok = true, clock = C.ClockSnapshot() })
end)

-- Échéances (alarmes, rappels, événements) : une seule minuterie côté client.
RegisterNUICallback('tablet:schedule', function(data, cb)
    if not C.IsOpen() then return cb({ ok = false, err = 'err_session' }) end
    C.Scheduler.Set(type(data) == 'table' and data.items or nil)
    cb({ ok = true })
end)

-- Textes d'une autre langue (changement de langue de la tablette).
RegisterNUICallback('tablet:locale', function(data, cb)
    local lang = type(data) == 'table' and data.lang or nil
    local texts = C.LocaleTable(lang)
    cb({ ok = true, locale = texts, rtl = texts._rtl })
end)

-- Appareil photo : start | stop | selfie | zoom | look. La capture passe par le relais `photos:capture` (serveur).
RegisterNUICallback('tablet:camera', function(data, cb)
    if not C.IsOpen() then return cb({ ok = false, err = 'err_session' }) end
    local action = type(data) == 'table' and data.action or nil
    if action == 'start' then return cb(C.Camera.Start()) end
    if action == 'stop' then C.Camera.Stop() return cb({ ok = true }) end
    if action == 'selfie' then return cb({ ok = C.Camera.Selfie(data.on) }) end
    if action == 'zoom' then return cb({ ok = C.Camera.Zoom(data.level) }) end
    if action == 'look' then return cb({ ok = C.Camera.Look(data.dx, data.dy) }) end
    cb({ ok = false, err = 'err_payload' })
end)

-- Micro du Dictaphone : l'interface teste getUserMedia et annonce `granted` ou `denied` (aucun audio ne transite par Lua).
C.MicroState = 'unknown'
RegisterNUICallback('tablet:micro', function(data, cb)
    local state = type(data) == 'table' and data.state or nil
    if state ~= 'granted' and state ~= 'denied' then return cb({ ok = false, err = 'err_payload' }) end
    C.MicroState = state
    cb({ ok = true })
end)

-- Carte de Plans : voir client/map.lua.
