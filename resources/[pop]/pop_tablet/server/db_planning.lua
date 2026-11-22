-- Requêtes oxmysql du calendrier, des rappels et de l'horloge (suite de db.lua, même table Tablet.DB).
-- Requêtes paramétrées (`?`) uniquement, aucune concaténation de valeurs.

Tablet = Tablet or {}
local DB = Tablet.DB

------------------------------------------------------------------------
-- Calendrier, Rappels, Horloge (requêtes préparées, index serial)
------------------------------------------------------------------------

--- Événements dont la plage recoupe [from, to] (dates réelles 'AAAA-MM-JJ HH:MM').
function DB.ListEvents(serial, from, to)
    return MySQL.query.await('SELECT id, title, place, notes, start_game, end_game, all_day, alert_min, color FROM pop_tablet_events'
        .. ' WHERE serial = ? AND start_game <= ? AND end_game >= ? ORDER BY start_game, id LIMIT 500', { serial, to, from }) or {}
end

function DB.CountEvents(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_events WHERE serial = ?', { serial })) or 0
end

function DB.GetEvent(serial, id)
    return MySQL.single.await('SELECT id, title, start_game, end_game, all_day, alert_min, notified FROM pop_tablet_events WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertEvent(serial, e)
    return MySQL.insert.await('INSERT INTO pop_tablet_events (serial, title, place, notes, start_game, end_game, all_day, alert_min, color, notified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
        { serial, e.title, e.place, e.notes, e.start, e.stop, e.allDay and 1 or 0, e.alert, e.color })
end

function DB.UpdateEvent(serial, id, e)
    local r = MySQL.update.await('UPDATE pop_tablet_events SET title = ?, place = ?, notes = ?, start_game = ?, end_game = ?, all_day = ?, alert_min = ?, color = ?, notified = 0 WHERE id = ? AND serial = ?',
        { e.title, e.place, e.notes, e.start, e.stop, e.allDay and 1 or 0, e.alert, e.color, id, serial })
    return (r or 0) > 0
end

function DB.DeleteEvent(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_events WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

function DB.SetEventNotified(serial, id)
    MySQL.update.await('UPDATE pop_tablet_events SET notified = 1 WHERE id = ? AND serial = ?', { id, serial })
end

--- Événements à alerte non encore notifiés (l'interface en tire les échéances du client).
function DB.PendingEventAlerts(serial)
    return MySQL.query.await('SELECT id, start_game, all_day, alert_min FROM pop_tablet_events WHERE serial = ? AND alert_min IS NOT NULL AND notified = 0 ORDER BY start_game LIMIT 500', { serial }) or {}
end

function DB.ListReminderLists(serial)
    return MySQL.query.await('SELECT id, name, color FROM pop_tablet_reminder_lists WHERE serial = ? ORDER BY id', { serial }) or {}
end

function DB.CountReminderLists(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_reminder_lists WHERE serial = ?', { serial })) or 0
end

function DB.ReminderListOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_reminder_lists WHERE id = ? AND serial = ?', { id, serial }) ~= nil
end

function DB.InsertReminderList(serial, name, color)
    return MySQL.insert.await('INSERT INTO pop_tablet_reminder_lists (serial, name, color) VALUES (?, ?, ?)', { serial, name, color })
end

function DB.UpdateReminderList(serial, id, name, color)
    return (MySQL.update.await('UPDATE pop_tablet_reminder_lists SET name = ?, color = ? WHERE id = ? AND serial = ?', { name, color, id, serial }) or 0) > 0
end

function DB.DeleteReminderList(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_reminder_lists WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

function DB.ListReminders(serial)
    return MySQL.query.await('SELECT id, list_id, title, done, due_game, flag FROM pop_tablet_reminders WHERE serial = ? ORDER BY done, due_game IS NULL, due_game, id LIMIT 200', { serial }) or {}
end

function DB.CountReminders(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_reminders WHERE serial = ?', { serial })) or 0
end

function DB.GetReminder(serial, id)
    return MySQL.single.await('SELECT id, list_id, title, done, due_game, flag FROM pop_tablet_reminders WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertReminder(serial, r)
    return MySQL.insert.await('INSERT INTO pop_tablet_reminders (serial, list_id, title, done, due_game, flag) VALUES (?, ?, ?, 0, ?, ?)',
        { serial, r.list, r.title, r.due, r.flag and 1 or 0 })
end

function DB.UpdateReminder(serial, id, r)
    return (MySQL.update.await('UPDATE pop_tablet_reminders SET list_id = ?, title = ?, due_game = ?, flag = ? WHERE id = ? AND serial = ?',
        { r.list, r.title, r.due, r.flag and 1 or 0, id, serial }) or 0) > 0
end

function DB.SetReminderDone(serial, id, done)
    return (MySQL.update.await('UPDATE pop_tablet_reminders SET done = ? WHERE id = ? AND serial = ?', { done and 1 or 0, id, serial }) or 0) > 0
end

function DB.DeleteReminder(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_reminders WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

function DB.ListAlarms(serial)
    return MySQL.query.await('SELECT id, kind, label, game_minute, repeat_mask, ends_at, enabled, sound FROM pop_tablet_alarms WHERE serial = ? ORDER BY kind, game_minute, id', { serial }) or {}
end

function DB.CountAlarms(serial, kind)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_alarms WHERE serial = ? AND kind = ?', { serial, kind })) or 0
end

function DB.GetAlarm(serial, id)
    return MySQL.single.await('SELECT id, kind, label, game_minute, repeat_mask, ends_at, enabled, sound FROM pop_tablet_alarms WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertAlarm(serial, a)
    return MySQL.insert.await('INSERT INTO pop_tablet_alarms (serial, kind, label, game_minute, repeat_mask, ends_at, enabled, sound) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { serial, a.kind, a.label, a.minute, a.mask or 0, a.ends, a.enabled and 1 or 0, a.sound or '' })
end

function DB.UpdateAlarm(serial, id, a)
    return (MySQL.update.await('UPDATE pop_tablet_alarms SET label = ?, game_minute = ?, repeat_mask = ?, enabled = ?, sound = ? WHERE id = ? AND serial = ? AND kind = \'alarm\'',
        { a.label, a.minute, a.mask, a.enabled and 1 or 0, a.sound or '', id, serial }) or 0) > 0
end

function DB.SetAlarmEnabled(serial, id, on)
    MySQL.update.await('UPDATE pop_tablet_alarms SET enabled = ? WHERE id = ? AND serial = ?', { on and 1 or 0, id, serial })
end

function DB.DeleteAlarm(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_alarms WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

--- Minuteurs en cours (relus au démarrage pour réarmer l'échéance serveur) ; les échus sont supprimés par l'appelant.
function DB.ListTimers()
    return MySQL.query.await('SELECT id, serial, label, ends_at FROM pop_tablet_alarms WHERE kind = \'timer\' AND ends_at IS NOT NULL ORDER BY ends_at LIMIT 5000', {}) or {}
end

------------------------------------------------------------------------
-- Messages, Téléphone, Contacts (requêtes préparées, index sur les numéros)
------------------------------------------------------------------------

--- Série de la tablette qui porte ce numéro, ou nil.
function DB.SerialOfPhone(phone)
    return MySQL.scalar.await('SELECT serial FROM pop_tablet_devices WHERE phone = ? LIMIT 1', { phone })
end

function DB.InsertMessage(from, to, body, kind, ref, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_messages (from_phone, to_phone, body, kind, ref, sent_at) VALUES (?, ?, ?, ?, ?, ?)',
        { from, to, body, kind, ref, now })
end

function DB.GetMessage(id)
    return MySQL.single.await('SELECT id, from_phone, to_phone, body, kind, ref, sent_at, read_at FROM pop_tablet_messages WHERE id = ?', { id })
end

--- Dernier message de chaque conversation à deux de `phone` (100 au plus).
function DB.LastDirect(phone)
    return MySQL.query.await('SELECT m.id, m.from_phone, m.to_phone, m.body, m.kind, m.sent_at, m.read_at FROM pop_tablet_messages m'
        .. ' JOIN (SELECT MAX(id) AS mid FROM pop_tablet_messages WHERE (from_phone = ? OR to_phone = ?) AND to_phone NOT LIKE \'g%\''
        .. ' GROUP BY IF(from_phone = ?, to_phone, from_phone)) x ON x.mid = m.id ORDER BY m.id DESC LIMIT 100', { phone, phone, phone }) or {}
end

--- Messages non lus reçus par `phone`, par expéditeur.
function DB.UnreadDirect(phone)
    return MySQL.query.await('SELECT from_phone, COUNT(*) AS n FROM pop_tablet_messages WHERE to_phone = ? AND read_at IS NULL GROUP BY from_phone', { phone }) or {}
end

--- 30 messages d'un fil à deux, du plus récent au plus ancien (`before` : id exclu).
function DB.DirectThread(a, b, before)
    return MySQL.query.await('SELECT id, from_phone, to_phone, body, kind, ref, sent_at, read_at FROM pop_tablet_messages'
        .. ' WHERE ((from_phone = ? AND to_phone = ?) OR (from_phone = ? AND to_phone = ?)) AND id < ? ORDER BY id DESC LIMIT 30',
        { a, b, b, a, before }) or {}
end

function DB.GroupThread(gid, before)
    return MySQL.query.await('SELECT id, from_phone, to_phone, body, kind, ref, sent_at, read_at FROM pop_tablet_messages'
        .. ' WHERE to_phone = ? AND id < ? ORDER BY id DESC LIMIT 30', { 'g' .. gid, before }) or {}
end

--- Marque lus les messages que `me` a reçus de `peer`. Renvoie le nombre de messages modifiés.
function DB.MarkRead(me, peer, now)
    return MySQL.update.await('UPDATE pop_tablet_messages SET read_at = ? WHERE to_phone = ? AND from_phone = ? AND read_at IS NULL', { now, me, peer }) or 0
end

function DB.Voicemails(phone)
    return MySQL.query.await('SELECT id, from_phone, body, sent_at, read_at FROM pop_tablet_messages WHERE to_phone = ? AND ref = \'vm\' ORDER BY id DESC LIMIT 30', { phone }) or {}
end

function DB.CreateGroup(name, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_msg_groups (name, created_at) VALUES (?, ?)', { name, now })
end

function DB.AddMember(gid, phone)
    MySQL.update.await('INSERT IGNORE INTO pop_tablet_msg_members (group_id, phone) VALUES (?, ?)', { gid, phone })
end

--- Retire `phone` du groupe. true si le numéro en faisait partie.
function DB.RemoveMember(gid, phone)
    return (MySQL.update.await('DELETE FROM pop_tablet_msg_members WHERE group_id = ? AND phone = ?', { gid, phone }) or 0) > 0
end

--- Supprime le groupe s'il n'a plus aucun membre.
function DB.DeleteGroupIfEmpty(gid)
    MySQL.update.await('DELETE FROM pop_tablet_msg_groups WHERE id = ? AND NOT EXISTS (SELECT 1 FROM pop_tablet_msg_members WHERE group_id = ? AND phone IS NOT NULL)', { gid, gid })
end

--- Groupes de `phone` avec leur nom et le nombre de non-lus.
function DB.GroupsOf(phone)
    return MySQL.query.await('SELECT g.id, g.name, mb.last_read, (SELECT COUNT(*) FROM pop_tablet_messages m WHERE m.to_phone = CONCAT(\'g\', g.id)'
        .. ' AND m.id > mb.last_read AND m.from_phone <> mb.phone) AS unread FROM pop_tablet_msg_members mb'
        .. ' JOIN pop_tablet_msg_groups g ON g.id = mb.group_id WHERE mb.phone = ? LIMIT 50', { phone }) or {}
end

function DB.GroupMembers(gid)
    return MySQL.query.await('SELECT phone FROM pop_tablet_msg_members WHERE group_id = ? LIMIT 20', { gid }) or {}
end

function DB.GroupLast(gid)
    return MySQL.single.await('SELECT id, from_phone, body, kind, sent_at FROM pop_tablet_messages WHERE to_phone = ? ORDER BY id DESC LIMIT 1', { 'g' .. gid })
end

function DB.GroupMarkRead(gid, phone)
    MySQL.update.await('UPDATE pop_tablet_msg_members SET last_read = (SELECT COALESCE(MAX(id), 0) FROM pop_tablet_messages WHERE to_phone = ?) WHERE group_id = ? AND phone = ?',
        { 'g' .. gid, gid, phone })
end

function DB.InsertCall(from, to, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_calls (from_phone, to_phone, started_at) VALUES (?, ?, ?)', { from, to, now })
end

function DB.UpdateCall(id, status, answeredAt, endedAt)
    MySQL.update.await('UPDATE pop_tablet_calls SET status = ?, answered_at = COALESCE(?, answered_at), ended_at = ? WHERE id = ?', { status, answeredAt, endedAt, id })
end

--- 50 derniers appels (émis ou reçus) d'un numéro.
function DB.CallHistory(phone)
    return MySQL.query.await('SELECT id, from_phone, to_phone, started_at, answered_at, ended_at, status FROM pop_tablet_calls'
        .. ' WHERE from_phone = ? OR to_phone = ? ORDER BY id DESC LIMIT 50', { phone, phone }) or {}
end

function DB.ListContacts(serial)
    return MySQL.query.await('SELECT id, name, phone, mail, note, favorite FROM pop_tablet_contacts WHERE serial = ? ORDER BY name LIMIT 300', { serial }) or {}
end

function DB.CountContacts(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_contacts WHERE serial = ?', { serial })) or 0
end

function DB.GetContact(serial, id)
    return MySQL.single.await('SELECT id, name, phone, mail, note, favorite FROM pop_tablet_contacts WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertContact(serial, c)
    return MySQL.insert.await('INSERT INTO pop_tablet_contacts (serial, name, phone, mail, note, favorite) VALUES (?, ?, ?, ?, ?, ?)',
        { serial, c.name, c.phone, c.mail, c.note, c.favorite and 1 or 0 })
end

function DB.UpdateContact(serial, id, c)
    return (MySQL.update.await('UPDATE pop_tablet_contacts SET name = ?, phone = ?, mail = ?, note = ?, favorite = ? WHERE id = ? AND serial = ?',
        { c.name, c.phone, c.mail, c.note, c.favorite and 1 or 0, id, serial }) or 0) > 0
end

function DB.DeleteContact(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_contacts WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

------------------------------------------------------------------------
-- Mail (index (serial, folder, id) ; 300 mails par tablette)
------------------------------------------------------------------------

--- Adresse mail de la tablette, ou nil.
function DB.MailAddress(serial)
    return MySQL.scalar.await('SELECT address FROM pop_tablet_mailboxes WHERE serial = ? LIMIT 1', { serial })
end

function DB.CountMails(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_mails WHERE serial = ?', { serial })) or 0
end

function DB.InsertMail(serial, folder, from, to, subject, body, now, readAt)
    return MySQL.insert.await('INSERT INTO pop_tablet_mails (serial, folder, from_addr, to_addr, subject, body, read_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { serial, folder, from, to, subject, body, readAt, now })
end

--- Nombre de mails et de non-lus par dossier, plus le nombre de mails avec drapeau.
function DB.MailCounts(serial)
    return MySQL.query.await('SELECT folder, COUNT(*) AS n, SUM(read_at IS NULL) AS unread, SUM(flagged) AS flagged FROM pop_tablet_mails WHERE serial = ? GROUP BY folder', { serial }) or {}
end

--- 30 mails d'un dossier (ou `flagged` : tous les mails avec drapeau hors corbeille), du plus récent au plus ancien ; `before` : id exclu.
function DB.ListMails(serial, folder, before)
    local cols = 'id, from_addr, to_addr, subject, SUBSTRING(body, 1, 80) AS preview, read_at, flagged, created_at, folder'
    if folder == 'flagged' then
        return MySQL.query.await('SELECT ' .. cols .. ' FROM pop_tablet_mails WHERE serial = ? AND flagged = 1 AND folder <> \'trash\' AND id < ? ORDER BY id DESC LIMIT 30', { serial, before }) or {}
    end
    return MySQL.query.await('SELECT ' .. cols .. ' FROM pop_tablet_mails WHERE serial = ? AND folder = ? AND id < ? ORDER BY id DESC LIMIT 30', { serial, folder, before }) or {}
end

function DB.GetMail(serial, id)
    return MySQL.single.await('SELECT id, folder, from_addr, to_addr, subject, body, read_at, flagged, created_at FROM pop_tablet_mails WHERE id = ? AND serial = ?', { id, serial })
end

function DB.MarkMailRead(serial, id, now)
    MySQL.update.await('UPDATE pop_tablet_mails SET read_at = ? WHERE id = ? AND serial = ? AND read_at IS NULL', { now, id, serial })
end

function DB.MoveMail(serial, id, folder)
    return (MySQL.update.await('UPDATE pop_tablet_mails SET folder = ? WHERE id = ? AND serial = ?', { folder, id, serial }) or 0) > 0
end

function DB.FlagMail(serial, id, on)
    return (MySQL.update.await('UPDATE pop_tablet_mails SET flagged = ? WHERE id = ? AND serial = ?', { on and 1 or 0, id, serial }) or 0) > 0
end

function DB.DeleteMail(serial, id)
    return (MySQL.update.await('DELETE FROM pop_tablet_mails WHERE id = ? AND serial = ?', { id, serial }) or 0) > 0
end

--- Mails d'un même expéditeur dans la Réception de `serial` (index (serial, folder, id), 300 lignes au plus).
function DB.CountInboxFrom(serial, fromAddr)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_mails WHERE serial = ? AND folder = \'inbox\' AND from_addr = ?', { serial, fromAddr })) or 0
end

--- Supprime le plus ancien mail reçu (Corbeille, Archive ou Réception ; sans drapeau d'abord). true si un mail a été retiré.
function DB.EvictOldestReceived(serial)
    return (MySQL.update.await('DELETE FROM pop_tablet_mails WHERE serial = ? AND folder IN (\'trash\', \'archive\', \'inbox\') ORDER BY flagged, id LIMIT 1', { serial }) or 0) > 0
end

function DB.UnreadMail(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_mails WHERE serial = ? AND folder = \'inbox\' AND read_at IS NULL', { serial })) or 0
end

--- Appels manqués reçus par `phone` depuis `since` (badge du Téléphone).
function DB.MissedCalls(phone, since)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_calls WHERE to_phone = ? AND status = \'missed\' AND started_at > ?', { phone, since })) or 0
end
