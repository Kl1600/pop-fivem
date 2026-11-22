-- Horloge : alarmes (heure réelle du joueur, déclenchées par UNE échéance côté client, tablette fermée comprise) et minuteurs
-- (secondes réelles, UNE échéance serveur via Tablet.Scheduler). Le chronomètre et les horloges du monde sont 100 % interface.
-- Aucune boucle : rien ne tourne tant qu'aucun minuteur ou alarme n'est armé.

Tablet = Tablet or {}
Tablet.Clock = {}
local C = Tablet.Clock
local P = Tablet.Productivity

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local function alarmRow(a)
    return { id = a.id, label = a.label, minute = a.game_minute, mask = a.repeat_mask, enabled = a.enabled == 1 or a.enabled == true, sound = a.sound }
end


--- Minuteur échu : supprimé de la base puis notifié (tablette ouverte ou notification du jeu).
local function fireTimer(serial, tid, label)
    Tablet.DB.DeleteAlarm(serial, tid)
    local src = Tablet.Device.SrcOf(serial)
    local session = src and Tablet.Device.GetSession(src)
    local title = label ~= '' and label or Tablet.TextFor(session, 'clock_timer')
    Tablet.DueNotify(src, serial, 'horloge', title, Tablet.TextFor(session, 'clock_timer_done'))
    if src then Tablet.Push.To(src, 'appEvent', { appId = 'horloge', name = 'timerDone', data = { id = tid } }) end
end

local function armTimer(serial, tid, label, ends)
    Tablet.Scheduler.Add('timer:' .. tid, ends, function() fireTimer(serial, tid, label) end)
end

--- Réarme les minuteurs enregistrés (démarrage de la ressource). Les minuteurs échus pendant l'arrêt sont supprimés.
function C.Rearm()
    local now = Tablet.Now()
    for _, t in ipairs(Tablet.DB.ListTimers()) do
        if t.ends_at <= now then Tablet.DB.DeleteAlarm(t.serial, t.id) else armTimer(t.serial, t.id, t.label, t.ends_at) end
    end
end

--- pop_tablet:clock:list : alarmes et minuteurs (reste en secondes réelles)
function C.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'clockList', rate = 4 })
    if not s then return Tablet.Fail(err) end
    local alarms, timers, now = {}, {}, Tablet.Now()
    for _, a in ipairs(Tablet.DB.ListAlarms(s.serial)) do
        if a.kind == 'timer' then
            timers[#timers + 1] = { id = a.id, label = a.label, remaining = math.max(0, (a.ends_at or now) - now) }
        else
            alarms[#alarms + 1] = alarmRow(a)
        end
    end
    return { ok = true, alarms = alarms, timers = timers }
end

--- pop_tablet:clock:saveAlarm  { id?, label?, minute, mask?, enabled?, sound? }
function C.SaveAlarm(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'clockSave', rate = 4, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local a = { kind = 'alarm', label = data.label == nil and '' or data.label, enabled = data.enabled ~= false }
    local ok, ferr = Tablet.Limits.Field('alarmLabel', a.label)
    if not ok then return Tablet.Fail(ferr) end
    a.minute = Tablet.Limits.Int(data.minute, 0, 1439)
    a.mask = data.mask == nil and 0 or Tablet.Limits.Int(data.mask, 0, 127)
    if not a.minute or not a.mask then return Tablet.Fail('err_payload') end
    a.sound = data.sound == nil and '' or data.sound
    if type(a.sound) ~= 'string' or #a.sound > 32 or (a.sound ~= '' and not a.sound:match('^[%w_]+$')) then return Tablet.Fail('err_payload') end
    if data.id ~= nil then
        local aid = id(data.id)
        if not aid or not Tablet.DB.UpdateAlarm(s.serial, aid, a) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = aid }
    end
    if Tablet.DB.CountAlarms(s.serial, 'alarm') >= P.alarms then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertAlarm(s.serial, a) }
end

--- pop_tablet:clock:deleteAlarm  id (alarme ou minuteur)
function C.DeleteAlarm(src, aid)
    local s, err = Tablet.Guard(src, nil, { name = 'clockSave', rate = 4, payload = aid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    aid = id(aid)
    if not aid or not Tablet.DB.DeleteAlarm(s.serial, aid) then return Tablet.Fail('err_not_found') end
    Tablet.Scheduler.Cancel('timer:' .. aid)
    return { ok = true }
end

--- pop_tablet:clock:startTimer  { seconds, label? } : <= 5 minuteurs, <= 24 h
function C.StartTimer(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'clockSave', rate = 4, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local seconds = Tablet.Limits.Int(data.seconds, 1, P.timerMaxSeconds)
    local label = data.label == nil and '' or data.label
    if not seconds or not Tablet.Limits.Field('alarmLabel', label) then return Tablet.Fail('err_payload') end
    if Tablet.DB.CountAlarms(s.serial, 'timer') >= P.timers then return Tablet.Fail('err_limit') end
    local ends = Tablet.Now() + seconds
    local tid = Tablet.DB.InsertAlarm(s.serial, { kind = 'timer', label = label, ends = ends, enabled = true })
    armTimer(s.serial, tid, label, ends)
    return { ok = true, id = tid, remaining = seconds }
end

--- pop_tablet:clock:cancelTimer  id
function C.CancelTimer(src, tid)
    local s, err = Tablet.Guard(src, nil, { name = 'clockSave', rate = 4, payload = tid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    tid = id(tid)
    local a = tid and Tablet.DB.GetAlarm(s.serial, tid)
    if not a or a.kind ~= 'timer' then return Tablet.Fail('err_not_found') end
    Tablet.DB.DeleteAlarm(s.serial, tid)
    Tablet.Scheduler.Cancel('timer:' .. tid)
    return { ok = true }
end

--- Échéance signalée par le client : l'alarme `aid` sonne si c'est son heure (jour de répétition compris).
--- Sans répétition, elle s'éteint après avoir sonné.
function C.Due(src, serial, aid, kind, stamp)
    if kind ~= 'alarm' then return end
    local a = Tablet.DB.GetAlarm(serial, aid)
    if not a or a.kind ~= 'alarm' or not (a.enabled == 1 or a.enabled == true) or a.game_minute == nil then return end
    local h, m = stamp:match(' (%d%d):(%d%d)$')
    if not h or not Tablet.Dates.Minutes(stamp) then return end
    local now = tonumber(h) * 60 + tonumber(m)
    local delta = (now - a.game_minute) % 1440
    if delta > 2 then return end
    if a.repeat_mask ~= 0 then
        local day = Tablet.Dates.Weekday(stamp)
        if not day or (a.repeat_mask >> day) & 1 == 0 then return end
    else
        Tablet.DB.SetAlarmEnabled(serial, aid, false)
    end
    local session = Tablet.Device.GetSession(src)
    local title = a.label ~= '' and a.label or Tablet.TextFor(session, 'clock_alarm')
    Tablet.DueNotify(src, serial, 'horloge', title, ('%02d:%02d'):format(a.game_minute // 60, a.game_minute % 60))
    Tablet.Push.To(src, 'appEvent', { appId = 'horloge', name = 'alarmRang', data = { id = aid } })
end

Tablet.DueHandlers[#Tablet.DueHandlers + 1] = function(...) return C.Due(...) end

Callback.Register('pop_tablet:clock:list', function(src) return C.List(src) end)
Callback.Register('pop_tablet:clock:saveAlarm', function(src, data) return C.SaveAlarm(src, data) end)
Callback.Register('pop_tablet:clock:deleteAlarm', function(src, aid) return C.DeleteAlarm(src, aid) end)
Callback.Register('pop_tablet:clock:startTimer', function(src, data) return C.StartTimer(src, data) end)
Callback.Register('pop_tablet:clock:cancelTimer', function(src, tid) return C.CancelTimer(src, tid) end)
