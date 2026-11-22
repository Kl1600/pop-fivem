-- Réglages : validation et enregistrement des réglages de l'appareil, nom, widgets de l'accueil, musique en cours.
-- Le serveur ne croit que les clés de Tablet.SettingsSchema, avec type et bornes ; tout le reste est refusé en bloc.

Tablet = Tablet or {}
Tablet.Settings = {}
local S = Tablet.Settings

local APP_ID = '^[a-z0-9_]+$'
local MAX_NOTIF = 60

local function validNotif(v)
    if type(v) ~= 'table' then return nil end
    local out, n = {}, 0
    for app, on in pairs(v) do
        if type(app) ~= 'string' or #app < 3 or #app > 32 or not app:match(APP_ID) or type(on) ~= 'boolean' then return nil end
        n = n + 1
        if n > MAX_NOTIF then return nil end
        out[app] = on
    end
    return out
end

--- Contrôle un patch. Renvoie le patch propre, ou nil + clé d'erreur. Clé inconnue ou valeur hors bornes : tout est refusé.
function S.Validate(patch)
    if type(patch) ~= 'table' then return nil, 'err_payload' end
    local out = {}
    for key, value in pairs(patch) do
        local rule = type(key) == 'string' and Tablet.SettingsSchema[key] or nil
        if not rule then return nil, 'err_payload' end
        if rule == 'bool' then
            if type(value) ~= 'boolean' then return nil, 'err_payload' end
            out[key] = value
        elseif rule == 'lang' then
            if not Tablet.Limits.Enum(value, Tablet.LanguageSet) then return nil, 'err_lang_invalid' end
            out[key] = value
        elseif rule == 'wall' then
            local ok = value == 'auto'
            if type(value) == 'string' and value:match('^%d$') and tonumber(value) < Tablet.WallpaperCount then ok = true end
            -- Fond tiré d'une photo : 'photo:<id>' ; la propriété de la photo est vérifiée à l'enregistrement.
            if type(value) == 'string' and #value <= 17 and value:match('^photo:[1-9]%d*$') then ok = true end
            if not ok then return nil, 'err_payload' end
            out[key] = value
        elseif rule == 'notif' then
            local clean = validNotif(value)
            if not clean then return nil, 'err_payload' end
            out[key] = clean
        else
            local n = Tablet.Limits.Int(value, rule[1], rule[2])
            if not n then return nil, 'err_payload' end
            out[key] = n
        end
    end
    return out
end

--- Réseau coupé : Mode Avion ou Wi-Fi coupé.
function S.Offline(settings)
    return type(settings) == 'table' and (settings.air == true or settings.wifi == false)
end

--- pop_tablet:settings:save
function S.Save(src, patch)
    local s, err = Tablet.Guard(src, nil, { payload = patch, maxBytes = Tablet.MaxSettingsBytes, name = 'settings', rate = 5 })
    if not s then return Tablet.Fail(err) end
    local clean, verr = S.Validate(patch)
    if not clean then return Tablet.Fail(verr) end
    if type(clean.wall) == 'string' and clean.wall:sub(1, 6) == 'photo:' and not Tablet.DB.PhotoOwned(s.serial, tonumber(clean.wall:sub(7))) then
        return Tablet.Fail('err_not_found')
    end
    local merged = {}
    for k, v in pairs(s.settings or {}) do merged[k] = v end
    for k, v in pairs(clean) do merged[k] = v end
    Tablet.DB.SetSettings(s.serial, merged)
    s.settings = merged
    return { ok = true }
end

--- pop_tablet:settings:rename
function S.Rename(src, name)
    local s, err = Tablet.Guard(src, nil, { name = 'rename', rate = 2 })
    if not s then return Tablet.Fail(err) end
    if type(name) ~= 'string' then return Tablet.Fail('err_name_invalid') end
    name = Tablet.Limits.Trim(name)
    if not Tablet.Limits.Field('name', name, { min = 1 }) then return Tablet.Fail('err_name_invalid') end
    Tablet.DB.SetName(s.serial, name)
    return { ok = true, name = name }
end

------------------------------------------------------------------------
-- Musique en cours (affichée dans le centre de contrôle) : mémoire seulement, vidée au départ du joueur.
------------------------------------------------------------------------

local playing = {} -- [serial] = { title, artist, playing }

--- pop_tablet:music:state
function S.MusicState(src, data)
    local s, err = Tablet.Guard(src, nil, { payload = data, maxBytes = 512, name = 'musicState', rate = 3 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    if data.title == nil then
        playing[s.serial] = nil
        return { ok = true }
    end
    if type(data.title) ~= 'string' or #data.title > 120 or (data.artist ~= nil and (type(data.artist) ~= 'string' or #data.artist > 120)) then
        return Tablet.Fail('err_payload')
    end
    playing[s.serial] = { title = data.title, artist = data.artist or '', playing = data.playing == true }
    return { ok = true }
end

Bridge.OnPlayerDropped(function(src)
    local serial = Tablet.Device.SerialOf(src)
    if serial then playing[serial] = nil end
end)

------------------------------------------------------------------------
-- Données ajoutées à `boot` : réglages en cache de session, widgets de l'accueil, musique.
------------------------------------------------------------------------

local function hhmm(stamp) return type(stamp) == 'string' and stamp:sub(12, 16) or '' end

--- Widgets de l'accueil : { events = { { title, time, color } }, reminders = { { id, text, done } } }.
function S.Widgets(serial, gameNow)
    local events, reminders = {}, {}
    if gameNow then
        for _, e in ipairs(Tablet.DB.WidgetEvents(serial, gameNow)) do
            local time = ''
            if e.all_day ~= 1 and e.all_day ~= true then
                time = hhmm(e.start_game)
                if e.end_game and e.end_game:sub(1, 10) == (e.start_game or ''):sub(1, 10) then time = time .. ' – ' .. hhmm(e.end_game) end
            end
            events[#events + 1] = { title = e.title, time = time, color = (e.color ~= '' and e.color) or nil }
        end
    end
    for _, r in ipairs(Tablet.DB.WidgetReminders(serial)) do
        reminders[#reminders + 1] = { id = r.id, text = r.title, done = r.done == 1 or r.done == true }
    end
    return { events = events, reminders = reminders }
end

Tablet.BootHooks[#Tablet.BootHooks + 1] = function(serial, boot)
    local src = Tablet.Device.SrcOf(serial)
    local s = src and Tablet.Device.GetSession(src) or nil
    if s then s.settings = boot.settings end
    boot.widgets = S.Widgets(serial, s and s.gameNow or nil)
    boot.music = playing[serial]
end

Callback.Register('pop_tablet:settings:save', function(src, patch) return S.Save(src, patch) end)
Callback.Register('pop_tablet:settings:rename', function(src, name) return S.Rename(src, name) end)
Callback.Register('pop_tablet:music:state', function(src, data) return S.MusicState(src, data) end)
