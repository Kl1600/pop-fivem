-- Appli tierce minimale pour pop_tablet. Aucune boucle, aucun polling : tout part d'un evenement.
-- Montre les 4 exports : RegisterApp, Notify, OpenApp, AppEvent.

local RES = GetCurrentResourceName()
local APP_ID = 'example_hello' -- [a-z0-9_]{3,32}, unique

-- Textes de l'appli : la tablette les traduit dans sa propre langue (repli sur l'anglais).
local TEXTS = {
    en = { name = 'Hello', alert_title = 'Hello', alert_body = 'Greetings from %s' },
    fr = { name = 'Bonjour', alert_title = 'Bonjour', alert_body = 'Salutations de %s' },
}

local pings = {} -- [serial] = nombre d'appels : memoire serveur seulement, jamais ecrite en base

local function register()
    local ok, reason = exports.pop_tablet:RegisterApp({
        id = APP_ID,
        nameKey = 'name',
        texts = TEXTS,
        page = ('nui://%s/web/index.html'):format(RES),
        color = '#30d158',
        category = 'tools',
        -- Appel venu de la page (window.parent.postMessage). POP a deja verifie l'objet porte, le code et la taille ;
        -- l'identite (src, serial) vient du serveur, jamais de la page.
        onCall = function(src, serial, action, data)
            if action ~= 'ping' then return { ok = false } end
            pings[serial] = (pings[serial] or 0) + 1
            -- Poussee vers la page ouverte (<= 1 Ko, seulement si l'appli est au premier plan).
            exports.pop_tablet:AppEvent(src, APP_ID, 'pong', { count = pings[serial] })
            return { count = pings[serial] }
        end,
    })
    if not ok then print(('[%s] RegisterApp refuse : %s'):format(RES, tostring(reason))) end
end

-- pop_tablet peut demarrer avant ou apres cette ressource : on gere les deux cas par evenements.
if GetResourceState('pop_tablet') == 'started' then register() end
AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'pop_tablet' then register() end
end)

-- Les applis sont retirees automatiquement a l'arret de cette ressource (onResourceStop cote pop_tablet).
AddEventHandler('onResourceStop', function(resource)
    if resource == RES then pings = {} end
end)

-- /example_hello [id] : notifie puis ouvre l'appli. Reserve a la console et aux admins (ACE command).
RegisterCommand('example_hello', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target = tonumber(args[1]) or (src ~= 0 and src or nil)
    if not target then return print(('[%s] usage : example_hello <id joueur>'):format(RES)) end
    -- true si une tablette a ete notifiee ; false si le joueur n'en porte pas.
    local sent = exports.pop_tablet:Notify(target, {
        app = APP_ID,
        titleKey = 'alert_title',
        bodyKey = 'alert_body',
        texts = TEXTS,
        args = { RES },
    })
    if sent then exports.pop_tablet:OpenApp(target, APP_ID, { from = RES }) end
end, false)
