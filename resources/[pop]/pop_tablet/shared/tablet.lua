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
    doc     = 20000, -- document texte de Fichiers
    folder  = 40,    -- nom de dossier de notes, d'album
}

-- Limites des applis Notes, Photos et Fichiers (comptes et formats).
Tablet.Media = {
    notes = 200, noteFolders = 10, albums = 20, files = 500, depth = 6,
    trashDays = 30, thumbBytes = 24576,
    noteBlocks = 40, todoItems = 50, todoText = 120, tableRows = 12, tableCols = 6, cellText = 60, textBlock = 10000,
    photoKinds = { photo = true, square = true, portrait = true, pano = true },
    photoFx = { none = true, vivid = true, mono = true, drama = true, sepia = true },
    fileTags = { red = true, orange = true, yellow = true, green = true, blue = true },
    fileKinds = { folder = true, doc = true, photo = true, audio = true, board = true },
}

-- Limites des applis Calendrier, Rappels et Horloge. Dates du jeu : 'AAAA-MM-JJ HH:MM' (CHAR(16)).
Tablet.Productivity = {
    events = 500, reminderLists = 20, reminders = 200, alarms = 20, timers = 5,
    rangeDays = 90, timerMaxSeconds = 86400,
    alerts = { [0] = true, [5] = true, [10] = true, [15] = true, [30] = true, [60] = true, [120] = true, [1440] = true, [2880] = true },
    -- Texte (caractères) : lieu, notes d'événement, titre de rappel, nom de liste, libellé d'alarme.
    place = 80, evNotes = 500, remTitle = 120, listName = 40, alarmLabel = 40,
}
Tablet.Max.place, Tablet.Max.evNotes, Tablet.Max.remTitle = 80, 500, 120
Tablet.Max.listName, Tablet.Max.alarmLabel = 40, 40

-- Version du système et modèle affichés dans Réglages > Général > Informations.
Tablet.OsVersion = '1.0'
Tablet.Model = 'POP Tab'

-- Applis natives. Les identifiants sont ceux de l'interface (ui/pop-os/src/apps/*). `system` : non retirable.
-- `cat` : catégorie de la Boutique ; `online` : coupée par Mode Avion et Wi-Fi coupé (SPEC section 0).
Tablet.NativeApps = {
    { id = 'reglages', cat = 'system', system = true },
    { id = 'boutique', cat = 'system', system = true, online = true },
    { id = 'camera', cat = 'media' },
    { id = 'photos', cat = 'media' },
    { id = 'musique', cat = 'media' },
    { id = 'dictaphone', cat = 'media', option = 'dictaphone' },
    { id = 'notes', cat = 'personal' },
    { id = 'calendrier', cat = 'personal' },
    { id = 'rappels', cat = 'personal' },
    { id = 'fichiers', cat = 'personal' },
    { id = 'tableau', cat = 'personal' },
    { id = 'horloge', cat = 'tools' },
    { id = 'calculette', cat = 'tools' },
    { id = 'meteo', cat = 'tools' },
    { id = 'plans', cat = 'tools' },
    { id = 'traduire', cat = 'tools', option = 'translate' },
    { id = 'bourse', cat = 'tools' },
    { id = 'messages', cat = 'communication', online = true },
    { id = 'telephone', cat = 'communication', online = true },
    { id = 'mail', cat = 'communication', online = true },
    { id = 'contacts', cat = 'communication' },
    { id = 'navigateur', cat = 'communication', online = true },
}

Tablet.NativeById = {}
for _, app in ipairs(Tablet.NativeApps) do Tablet.NativeById[app.id] = app end

-- Réglages acceptés par `settings:save` (liste blanche). 'bool', ou { min, max } pour un entier, ou 'lang', 'wall', 'notif'.
Tablet.SettingsSchema = {
    lang = 'lang', dark = 'bool', glass = { 0, 100 }, bright = { 15, 100 }, wall = 'wall', blur = 'bool',
    air = 'bool', wifi = 'bool', bt = 'bool', rot = 'bool', mirror = 'bool', share = 'bool', focus = 'bool',
    bold = 'bool', vol = { 0, 100 }, ring = { 1, 5 }, notif = 'notif',
}
Tablet.WallpaperCount = 8 -- fonds 0 à 7, ou 'auto'
Tablet.MaxSettingsBytes = 4096

-- Events serveur -> client (push). Seuls ces noms sont acceptés par server/push.lua.
Tablet.PushNames = {
    notify = true, message = true, mail = true, call = true, market = true,
    share = true, open = true, forceClose = true, apps = true, appEvent = true,
}

-- Taille maximale d'un paquet push, en octets.
Tablet.PushMaxBytes = 1024

-- Callbacks que l'interface a le droit d'appeler par le relais générique `tablet:call` (liste blanche,
-- noms relatifs à `pop_tablet:`). `device:open` et `device:close` passent par le client (animation, focus).
local relayed = {
    'device:setup', 'device:unlock', 'device:changeCode', 'device:lock',
    'settings:save', 'settings:rename',
    'store:list', 'store:install', 'store:remove',
    'notes:list', 'notes:get', 'notes:save', 'notes:delete', 'notes:restore', 'notes:folderSave', 'notes:folderDelete',
    'calendar:list', 'calendar:save', 'calendar:delete',
    'reminders:list', 'reminders:save', 'reminders:delete', 'reminders:toggle', 'reminders:listSave',
    'files:list', 'files:get', 'files:save', 'files:delete', 'files:move', 'files:share', 'files:unshare', 'files:open',
    'board:list', 'board:get', 'board:save', 'board:delete',
    'clock:list', 'clock:saveAlarm', 'clock:deleteAlarm', 'clock:startTimer', 'clock:cancelTimer',
    'photos:capture', 'photos:list', 'photos:get', 'photos:delete', 'photos:favorite', 'photos:restore', 'photos:rate', 'photos:filter',
    'photos:thumb', 'photos:albums', 'photos:albumSave', 'photos:albumDelete', 'photos:albumLink',
    'rec:save', 'rec:list', 'rec:delete',
    'messages:threads', 'messages:thread', 'messages:send', 'messages:read',
    'phone:call', 'phone:answer', 'phone:decline', 'phone:hangup', 'phone:history',
    'mail:folders', 'mail:list', 'mail:get', 'mail:send', 'mail:move', 'mail:flag', 'mail:delete',
    'contacts:list', 'contacts:save', 'contacts:delete',
    'browser:sites', 'music:stations', 'translate:run',
    'stocks:subscribe', 'stocks:unsubscribe', 'stocks:watch',
    'share:nearby', 'share:send', 'share:accept', 'share:refuse',
    'app:call', 'app:focus', 'music:state',
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
