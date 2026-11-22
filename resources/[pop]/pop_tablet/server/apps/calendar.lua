-- Calendrier : événements en dates du jeu ('AAAA-MM-JJ HH:MM'), alerte par échéance client (une seule minuterie).
-- Le serveur revérifie tout : propriété, formats, bornes, plage <= 90 jours, <= 500 événements.

Tablet = Tablet or {}
Tablet.Calendar = {}
local Cal = Tablet.Calendar
local P = Tablet.Productivity

------------------------------------------------------------------------
-- Dates du jeu (partagées avec Rappels et Horloge)
------------------------------------------------------------------------
Tablet.Dates = Tablet.Dates or {}
local Dates = Tablet.Dates

--- Jours depuis 1970-01-01 (calendrier grégorien, algorithme de Howard Hinnant).
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = (y >= 0 and y or y - 399) // 400
    local yoe = y - era * 400
    local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

local function monthDays(y, m)
    if m == 2 then return (y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)) and 29 or 28 end
    return (m == 4 or m == 6 or m == 9 or m == 11) and 30 or 31
end

--- Découpe 'AAAA-MM-JJ' (dateOnly) ou 'AAAA-MM-JJ HH:MM' validé. Renvoie y, m, d, h, mi ou nil.
function Dates.Parse(text, dateOnly)
    if type(text) ~= 'string' then return nil end
    local y, mo, d, h, mi
    if dateOnly then
        y, mo, d = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
        h, mi = '0', '0'
    else
        y, mo, d, h, mi = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$')
    end
    if not y then return nil end
    y, mo, d, h, mi = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi)
    if y < 1970 or y > 2200 or mo < 1 or mo > 12 or d < 1 or d > monthDays(y, mo) or h > 23 or mi > 59 then return nil end
    return y, mo, d, h, mi
end

--- Minutes depuis 1970 (fuseau neutre) d'un horodatage, ou nil.
function Dates.Minutes(text)
    local y, mo, d, h, mi = Dates.Parse(text)
    if not y then return nil end
    return daysFromCivil(y, mo, d) * 1440 + h * 60 + mi
end

--- Jours depuis 1970 d'une date seule (10 caractères) ou d'un horodatage, ou nil.
function Dates.Days(text)
    if type(text) ~= 'string' then return nil end
    local y, mo, d = Dates.Parse(text, #text == 10)
    if not y then return nil end
    return daysFromCivil(y, mo, d)
end

--- Jour de la semaine d'un horodatage : 0 = lundi ... 6 = dimanche.
function Dates.Weekday(text)
    local days = Dates.Days(text)
    if not days then return nil end
    return (days + 3) % 7 -- 1970-01-01 était un jeudi
end

--- Texte d'une clé dans la langue de la tablette (repli : langue du serveur).
function Tablet.TextFor(session, key)
    local lang = session and session.settings and session.settings.lang
    local t = Locales[lang] and Locales[lang][key]
    if type(t) == 'string' then return t end
    return L(key)
end

--- Coupe un texte à `n` caractères (titre de notification <= 60).
function Tablet.Cut(s, n)
    local len = utf8.len(s)
    if len and len > n then return s:sub(1, utf8.offset(s, n + 1) - 1) end
    return s
end

--- Notification d'échéance : dans la tablette si elle est ouverte, sinon notification du jeu (aucun affichage possible sinon).
function Tablet.DueNotify(src, serial, app, title, body)
    if not src or not Bridge.GetPlayer(src) then return false end
    local s = Tablet.Device.GetSession(src)
    title, body = Tablet.Cut(title, 60), body or ''
    if s and s.openedAt then
        return Tablet.Api.Notify(serial, { app = app, title = title, body = body, sound = true }, GetCurrentResourceName())
    end
    Bridge.Notify(src, body ~= '' and (title .. ' : ' .. body) or title, 'info')
    return true
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

local COLOR = '^#%x%x%x%x%x%x$'

local function text(field, v, opts)
    if v == nil then v = '' end
    local ok, err = Tablet.Limits.Field(field, v, opts)
    if not ok then return nil, err end
    return v
end

local function row(r)
    return { id = r.id, title = r.title, place = r.place, notes = r.notes, start = r.start_game, stop = r.end_game,
        allDay = r.all_day == 1 or r.all_day == true, alert = r.alert_min, color = r.color }
end

--- pop_tablet:calendar:list  { from, to } (dates 'AAAA-MM-JJ', plage <= 90 jours)
function Cal.List(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'calList', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.from) ~= 'string' or type(data.to) ~= 'string' then return Tablet.Fail('err_payload') end
    local a, b = Dates.Days(data.from), Dates.Days(data.to)
    if not a or not b or #data.from ~= 10 or #data.to ~= 10 or b < a or b - a > P.rangeDays then return Tablet.Fail('err_payload') end
    local out = {}
    for i, r in ipairs(Tablet.DB.ListEvents(s.serial, data.from .. ' 00:00', data.to .. ' 23:59')) do out[i] = row(r) end
    -- Alertes en attente : l'interface en tire les échéances du client (minute de la journée).
    local alerts = {}
    for i, r in ipairs(Tablet.DB.PendingEventAlerts(s.serial)) do
        alerts[i] = { id = r.id, start = r.start_game, allDay = r.all_day == 1 or r.all_day == true, alert = r.alert_min }
    end
    return { ok = true, events = out, alerts = alerts }
end

--- pop_tablet:calendar:save  { id?, title, place?, notes?, start, stop, allDay?, alert?, color? }
function Cal.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'calSave', rate = 4, payload = data, maxBytes = 2048 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local e = { allDay = data.allDay == true }
    local ferr
    e.title, ferr = text('title', data.title, { min = 1 })
    if not e.title then return Tablet.Fail(ferr) end
    e.place, ferr = text('place', data.place)
    if not e.place then return Tablet.Fail(ferr) end
    e.notes, ferr = text('evNotes', data.notes, { multiline = true })
    if not e.notes then return Tablet.Fail(ferr) end
    local a, b = Dates.Minutes(data.start), Dates.Minutes(data.stop)
    if not a or not b or b < a then return Tablet.Fail('err_payload') end
    e.start, e.stop = data.start, data.stop
    if data.alert ~= nil then
        e.alert = Tablet.Limits.Int(data.alert, 0, 2880)
        if e.alert == nil or not P.alerts[e.alert] then return Tablet.Fail('err_payload') end
    end
    e.color = data.color or ''
    if e.color ~= '' and (type(e.color) ~= 'string' or not e.color:match(COLOR)) then return Tablet.Fail('err_payload') end
    if data.id ~= nil then
        local id = Tablet.Limits.Int(data.id, 1, 4294967295)
        if not id or not Tablet.DB.UpdateEvent(s.serial, id, e) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = id }
    end
    if Tablet.DB.CountEvents(s.serial) >= P.events then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertEvent(s.serial, e) }
end

--- pop_tablet:calendar:delete  id
function Cal.Delete(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'calSave', rate = 4, payload = id, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    id = Tablet.Limits.Int(id, 1, 4294967295)
    if not id or not Tablet.DB.DeleteEvent(s.serial, id) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- Échéance signalée par le client : l'alerte de l'événement `id` est due si la date du jeu annoncée est l'heure de l'alerte.
function Cal.Due(src, serial, id, kind, stamp)
    if kind ~= 'event' then return end
    local e = Tablet.DB.GetEvent(serial, id)
    if not e or e.alert_min == nil or e.notified == 1 or e.notified == true then return end
    local now = Dates.Minutes(stamp)
    local start = Dates.Minutes((e.all_day == 1 or e.all_day == true) and (e.start_game:sub(1, 10) .. ' 00:00') or e.start_game)
    if not now or not start then return end
    local at = start - e.alert_min
    if now < at or now > at + 2 then return end
    Tablet.DB.SetEventNotified(serial, id)
    local body = e.alert_min == 0 and Tablet.TextFor(Tablet.Device.GetSession(src), 'cal_now') or e.start_game:sub(12, 16)
    Tablet.DueNotify(src, serial, 'calendrier', e.title, body)
end

Tablet.DueHandlers[#Tablet.DueHandlers + 1] = function(...) return Cal.Due(...) end

Callback.Register('pop_tablet:calendar:list', function(src, data) return Cal.List(src, data) end)
Callback.Register('pop_tablet:calendar:save', function(src, data) return Cal.Save(src, data) end)
Callback.Register('pop_tablet:calendar:delete', function(src, id) return Cal.Delete(src, id) end)
