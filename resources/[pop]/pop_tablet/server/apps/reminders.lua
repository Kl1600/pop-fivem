-- Rappels : listes colorées, rappels avec échéance en date du jeu, drapeau, case à cocher. Alerte par échéance client.
-- <= 20 listes, <= 200 rappels. Une liste supprimée emporte ses rappels (clé étrangère).

Tablet = Tablet or {}
Tablet.Reminders = {}
local R = Tablet.Reminders
local P = Tablet.Productivity

local COLOR = '^#%x%x%x%x%x%x$'

local function id(v) return Tablet.Limits.Int(v, 1, 4294967295) end

local function color(v)
    if v == nil or v == '' then return '' end
    if type(v) ~= 'string' or not v:match(COLOR) then return nil end
    return v
end

local function rrow(r)
    return { id = r.id, list = r.list_id, title = r.title, done = r.done == 1 or r.done == true, due = r.due_game, flag = r.flag == 1 or r.flag == true }
end

--- pop_tablet:reminders:list : listes et rappels (<= 200)
function R.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'remList', rate = 6 })
    if not s then return Tablet.Fail(err) end
    local lists, items = {}, {}
    for i, l in ipairs(Tablet.DB.ListReminderLists(s.serial)) do lists[i] = { id = l.id, name = l.name, color = l.color } end
    for i, r in ipairs(Tablet.DB.ListReminders(s.serial)) do items[i] = rrow(r) end
    return { ok = true, lists = lists, items = items }
end

--- pop_tablet:reminders:save  { id?, list, title, due?, flag? }
function R.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'remSave', rate = 6, payload = data, maxBytes = 1024 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('remTitle', data.title, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    local r = { title = data.title, flag = data.flag == true, list = id(data.list) }
    if not r.list or not Tablet.DB.ReminderListOwned(s.serial, r.list) then return Tablet.Fail('err_not_found') end
    if data.due ~= nil and data.due ~= '' then
        if not Tablet.Dates.Minutes(data.due) then return Tablet.Fail('err_payload') end
        r.due = data.due
    end
    if data.id ~= nil then
        local rid = id(data.id)
        if not rid or not Tablet.DB.UpdateReminder(s.serial, rid, r) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = rid }
    end
    if Tablet.DB.CountReminders(s.serial) >= P.reminders then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertReminder(s.serial, r) }
end

--- pop_tablet:reminders:delete  id
function R.Delete(src, rid)
    local s, err = Tablet.Guard(src, nil, { name = 'remSave', rate = 6, payload = rid, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    rid = id(rid)
    if not rid or not Tablet.DB.DeleteReminder(s.serial, rid) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:reminders:toggle  { id, done }
function R.Toggle(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'remSave', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.done) ~= 'boolean' then return Tablet.Fail('err_payload') end
    local rid = id(data.id)
    if not rid or not Tablet.DB.SetReminderDone(s.serial, rid, data.done) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:reminders:listSave  { id?, name, color?, delete? } : création, renommage ou suppression d'une liste
function R.ListSave(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'remList', rate = 3, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    if data.delete == true then
        local lid = id(data.id)
        if not lid or not Tablet.DB.DeleteReminderList(s.serial, lid) then return Tablet.Fail('err_not_found') end
        return { ok = true, deleted = true }
    end
    if type(data.name) ~= 'string' then return Tablet.Fail('err_payload') end
    local name = Tablet.Limits.Trim(data.name)
    if not Tablet.Limits.Field('listName', name, { min = 1 }) then return Tablet.Fail('err_payload') end
    local col = color(data.color)
    if col == nil then return Tablet.Fail('err_payload') end
    if data.id ~= nil then
        local lid = id(data.id)
        if not lid or not Tablet.DB.UpdateReminderList(s.serial, lid, name, col) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = lid, name = name, color = col }
    end
    if Tablet.DB.CountReminderLists(s.serial) >= P.reminderLists then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertReminderList(s.serial, name, col), name = name, color = col }
end

--- Échéance signalée par le client : le rappel `rid` est dû si la date du jeu annoncée est son échéance (à 2 minutes près).
function R.Due(src, serial, rid, kind, stamp)
    if kind ~= 'reminder' then return end
    local r = Tablet.DB.GetReminder(serial, rid)
    if not r or r.due_game == nil or r.done == 1 or r.done == true then return end
    local now, at = Tablet.Dates.Minutes(stamp), Tablet.Dates.Minutes(r.due_game)
    if not now or not at or now < at or now > at + 2 then return end
    Tablet.DueNotify(src, serial, 'rappels', r.title, Tablet.TextFor(Tablet.Device.GetSession(src), 'rem_due'))
end

Tablet.DueHandlers[#Tablet.DueHandlers + 1] = function(...) return R.Due(...) end

Callback.Register('pop_tablet:reminders:list', function(src) return R.List(src) end)
Callback.Register('pop_tablet:reminders:save', function(src, data) return R.Save(src, data) end)
Callback.Register('pop_tablet:reminders:delete', function(src, rid) return R.Delete(src, rid) end)
Callback.Register('pop_tablet:reminders:toggle', function(src, data) return R.Toggle(src, data) end)
Callback.Register('pop_tablet:reminders:listSave', function(src, data) return R.ListSave(src, data) end)
