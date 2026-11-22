-- Ouverture et fermeture de la tablette. Aucune boucle : tout est déclenché par la touche, l'objet ou un event.
-- Le focus NUI bloque déjà les contrôles du jeu : pas de DisableControlAction en boucle.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

local state = 'closed' -- 'closed' | 'opening' | 'open'
local lastOpen = nil   -- dernier message tablet:open, renvoyé si l'interface signale tablet:ready après coup
local deathHandler = nil

--- Envoie un message à l'interface : SendNUIMessage({ action = 'tablet:<nom>', data }).
function C.Post(action, data)
    SendNUIMessage({ action = action, data = data })
end

function C.IsOpen()
    return state == 'open'
end

function C.LastOpen()
    return lastOpen
end

-- La mort ferme la tablette. Le handler n'existe que pendant l'ouverture : 0,00 ms fermée.
local function watchDeath(enable)
    if enable and not deathHandler then
        deathHandler = AddEventHandler('gameEventTriggered', function(name, args)
            if name ~= 'CEventNetworkEntityDamage' then return end
            local ped = PlayerPedId()
            if args[1] == ped and IsPedDeadOrDying(ped, true) then C.Close('dead') end
        end)
    elseif not enable and deathHandler then
        RemoveEventHandler(deathHandler)
        deathHandler = nil
    end
end

--- Ferme la tablette : focus rendu, animation et objet supprimés, serveur prévenu. Sans effet si déjà fermée.
function C.Close(reason)
    if state == 'closed' then return end
    state = 'closed'
    lastOpen = nil
    watchDeath(false)
    C.StopResync()
    if C.Camera then C.Camera.Stop() end
    SetNuiFocus(false, false)
    C.Post('tablet:close', { reason = reason })
    C.Anim.Stop()
    Callback.Trigger('pop_tablet:device:close', function() end)
end

--- Ouvre la tablette. `hint` : série de la pile utilisée (revérifiée par le serveur) ; `openApp` : { app, data } ;
--- `silent` : pas de message si le joueur n'a pas de tablette (touche).
function C.Open(hint, openApp, silent)
    if state == 'open' then
        if openApp then C.Post('tablet:openApp', openApp) end
        return
    end
    if state == 'opening' then return end
    state = 'opening'
    Callback.Trigger('pop_tablet:device:open', function(res)
        if state ~= 'opening' then return end
        if type(res) ~= 'table' or not res.ok then
            state = 'closed'
            local err = type(res) == 'table' and res.err or 'err_timeout'
            if not (silent and err == 'err_no_tablet') then Bridge.Notify(L(err), 'error') end
            return
        end
        state = 'open'
        SetNuiFocus(true, true)
        CreateThread(C.Anim.Start)
        watchDeath(true)
        local lang = res.boot and res.boot.settings and res.boot.settings.lang or Config.Locale
        local texts = C.LocaleTable(lang)
        lastOpen = {
            serial = res.serial, needSetup = res.needSetup, locked = res.locked, boot = res.boot,
            locale = texts, rtl = texts._rtl, accent = Config.AccentColor,
            lang = Tablet.LanguageSet[lang] and lang or Config.Locale,
            shell = Config.Shell == true or nil, -- absent = pas de coque en jeu
            clock = C.ClockSnapshot(), weather = C.WeatherSnapshot(), app = openApp,
        }
        C.Post('tablet:open', lastOpen)
    end, hint, C.GameStamp())
end

-- Touche réglable (F5 par défaut) : sans objet, le serveur refuse et la touche ne fait rien.
RegisterCommand('pop_tablet_toggle', function()
    if state == 'open' then
        C.Close('key')
    elseif state == 'closed' then
        C.Open(nil, nil, true)
    end
end, false)
RegisterKeyMapping('pop_tablet_toggle', L('tablet_key'), 'keyboard', Config.Key)

-- Utilisation de l'objet : le serveur envoie la série de la pile utilisée.
RegisterNetEvent('pop_tablet:client:use', function(serial)
    C.Open(type(serial) == 'string' and serial or nil)
end)

-- Fermeture forcée : objet perdu, mort, tablette volée.
RegisterNetEvent('pop_tablet:client:forceClose', function(data)
    C.Close(type(data) == 'table' and data.reason or 'server')
end)

-- OpenApp de l'API : ouvre la tablette (le code reste exigé) puis l'appli.
RegisterNetEvent('pop_tablet:client:open', function(data)
    if type(data) ~= 'table' or type(data.app) ~= 'string' then return end
    C.Open(nil, { app = data.app, data = data.data })
end)

-- Relais des push vers l'interface, seulement tablette ouverte (fermée : rien à afficher, 0,00 ms).
for _, name in ipairs({ 'notify', 'message', 'mail', 'call', 'market', 'share', 'apps', 'appEvent' }) do
    RegisterNetEvent('pop_tablet:client:' .. name, function(data)
        if state == 'open' then C.Post('tablet:' .. name, data) end
    end)
end

-- Nettoyage à l'arrêt : jamais d'objet, d'animation ni de focus qui traîne.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    watchDeath(false)
    SetNuiFocus(false, false)
    C.Anim.Stop()
end)
