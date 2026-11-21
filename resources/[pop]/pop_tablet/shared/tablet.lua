-- Constantes partagées client/serveur : langues, limites de taille, noms d'events et de callbacks.
-- Le serveur relit ces limites à chaque appel : ce que le client croit ne compte jamais.

Tablet = Tablet or {}

Tablet.Languages = { 'en', 'fr', 'es', 'de', 'it', 'pt', 'nl', 'pl', 'tr', 'ar' }

Tablet.LanguageSet = {}
for _, code in ipairs(Tablet.Languages) do Tablet.LanguageSet[code] = true end

-- Série d'une tablette : 'PT-' + 10 caractères parmi A-Z et 2-9.
Tablet.SerialPrefix = 'PT-'
Tablet.SerialChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ23456789'
Tablet.SerialLength = 10

-- Limites (section 7.4 de la SPEC). Longueurs en caractères, tailles en octets.
Tablet.Max = {
    name    = 32,    -- nom d'appareil
    title   = 80,
    note    = 10000,
    message = 1000,
    mail    = 5000,
    contact = 60,
    search  = 60,
    mailLocal = 32,  -- partie avant @ d'une adresse mail
    page    = 30,    -- éléments par page de liste
    payload = 16384, -- charge NUI -> serveur
    board   = 131072, -- charge NUI -> serveur pour un tableau
}

-- Events serveur -> client (push). Seuls ces noms sont acceptés par server/push.lua.
Tablet.PushNames = {
    notify = true, message = true, mail = true, call = true, market = true,
    share = true, open = true, forceClose = true, apps = true,
}

-- Taille maximale d'un paquet push, en octets.
Tablet.PushMaxBytes = 1024

-- Callbacks que l'interface a le droit d'appeler par le relais générique `tablet:call` (liste blanche,
-- noms relatifs à `pop_tablet:`). `device:open` et `device:close` passent par le client (animation, focus).
local relayed = {
    'device:setup', 'device:unlock', 'device:changeCode', 'device:lock',
    'settings:save', 'settings:rename',
    'store:list', 'store:install', 'store:remove',
    'notes:list', 'notes:get', 'notes:save', 'notes:delete',
    'calendar:list', 'calendar:save', 'calendar:delete',
    'reminders:list', 'reminders:save', 'reminders:delete', 'reminders:toggle', 'reminders:listSave',
    'files:list', 'files:save', 'files:delete', 'files:move', 'files:share', 'files:open',
    'board:list', 'board:get', 'board:save', 'board:delete',
    'clock:list', 'clock:saveAlarm', 'clock:deleteAlarm', 'clock:startTimer', 'clock:cancelTimer',
    'photos:capture', 'photos:list', 'photos:get', 'photos:delete', 'photos:favorite',
    'rec:save', 'rec:list', 'rec:delete',
    'messages:threads', 'messages:thread', 'messages:send', 'messages:read',
    'phone:call', 'phone:answer', 'phone:decline', 'phone:hangup', 'phone:history',
    'mail:folders', 'mail:list', 'mail:get', 'mail:send', 'mail:move', 'mail:flag', 'mail:delete',
    'contacts:list', 'contacts:save', 'contacts:delete',
    'browser:sites', 'music:stations', 'translate:run',
    'stocks:subscribe', 'stocks:unsubscribe', 'stocks:watch',
    'share:nearby', 'share:send', 'share:accept', 'share:refuse',
    'app:call',
}

Tablet.RelaySet = {}
for _, name in ipairs(relayed) do Tablet.RelaySet[name] = true end

-- Clé de locale renvoyée au client à la place d'un texte (réponse standard { ok = false, err = 'clé' }).
function Tablet.Fail(err, extra)
    local r = extra or {}
    r.ok = false
    r.err = err
    return r
end
