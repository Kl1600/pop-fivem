-- Toutes les requêtes oxmysql du script. Requêtes paramétrées (`?`) uniquement, aucune concaténation de valeurs.

Tablet = Tablet or {}
Tablet.DB = {}
local DB = Tablet.DB

local COLUMNS = 'serial, phone, code_hash, code_salt, fails, locked_until, name, settings, apps, battery, battery_at, owner_hint, created_at, last_open_at'

--- Crée les tables manquantes (sql/install.sql, instructions séparées par « ;» en fin de ligne).
function DB.Install()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql then return false end
    sql = sql:gsub('%-%-[^\n]*', '')
    for statement in (sql .. '\n'):gmatch('(.-);%s*\n') do
        if statement:find('%S') then MySQL.query.await(statement) end
    end
    return true
end

function DB.GetDevice(serial)
    return MySQL.single.await('SELECT ' .. COLUMNS .. ' FROM pop_tablet_devices WHERE serial = ?', { serial })
end

function DB.SerialExists(serial)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_devices WHERE serial = ? LIMIT 1', { serial }) ~= nil
end

function DB.PhoneExists(phone)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_devices WHERE phone = ? LIMIT 1', { phone }) ~= nil
end

--- Crée la ligne d'une tablette ; false si le serial ou le numéro existe déjà.
function DB.CreateDevice(serial, phone, ownerHint, now, battery)
    local n = MySQL.update.await(
        'INSERT IGNORE INTO pop_tablet_devices (serial, phone, owner_hint, battery, battery_at, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { serial, phone, ownerHint, battery, now, now })
    return (n or 0) > 0
end

function DB.DeleteDevice(serial)
    MySQL.update.await('DELETE FROM pop_tablet_devices WHERE serial = ?', { serial })
end

--- Premier réglage : n'agit que si aucun code n'est défini. Renvoie true si la ligne a été modifiée.
function DB.ClaimSetup(serial, hash, salt, name, settingsJson, appsJson)
    local n = MySQL.update.await(
        'UPDATE pop_tablet_devices SET code_hash = ?, code_salt = ?, name = ?, settings = ?, apps = ?, fails = 0, locked_until = 0 WHERE serial = ? AND code_hash IS NULL',
        { hash, salt, name, settingsJson, appsJson, serial })
    return (n or 0) > 0
end

function DB.SetCode(serial, hash, salt)
    MySQL.update.await('UPDATE pop_tablet_devices SET code_hash = ?, code_salt = ?, fails = 0, locked_until = 0 WHERE serial = ?',
        { hash, salt, serial })
end

function DB.SetFails(serial, fails, lockedUntil)
    MySQL.update.await('UPDATE pop_tablet_devices SET fails = ?, locked_until = ? WHERE serial = ?', { fails, lockedUntil, serial })
end

function DB.SetBattery(serial, battery, at)
    MySQL.update.await('UPDATE pop_tablet_devices SET battery = ?, battery_at = ? WHERE serial = ?', { battery, at, serial })
end

function DB.TouchOpen(serial, battery, now)
    MySQL.update.await('UPDATE pop_tablet_devices SET battery = ?, battery_at = ?, last_open_at = ? WHERE serial = ?',
        { battery, now, now, serial })
end

--- Réglages (table Lua, encodée ici), nom et liste d'applis installées : une requête chacun.
function DB.SetSettings(serial, settings)
    MySQL.update.await('UPDATE pop_tablet_devices SET settings = ? WHERE serial = ?', { json.encode(settings), serial })
end

function DB.SetName(serial, name)
    MySQL.update.await('UPDATE pop_tablet_devices SET name = ? WHERE serial = ?', { name, serial })
end

function DB.SetApps(serial, apps)
    MySQL.update.await('UPDATE pop_tablet_devices SET apps = ? WHERE serial = ?', { json.encode(apps), serial })
end

--- Widgets de l'accueil : les 3 prochains événements (fin >= date du jeu) et 4 rappels, index (serial, ...).
function DB.WidgetEvents(serial, fromGame)
    return MySQL.query.await(
        'SELECT title, start_game, end_game, all_day, color FROM pop_tablet_events WHERE serial = ? AND end_game >= ? ORDER BY start_game LIMIT 3',
        { serial, fromGame }) or {}
end

function DB.WidgetReminders(serial)
    return MySQL.query.await(
        'SELECT id, title, done FROM pop_tablet_reminders WHERE serial = ? ORDER BY done, id LIMIT 4', { serial }) or {}
end

--- Photos : nombre de photos d'une tablette et insertion (le texte base64 de la capture va dans `data`).
function DB.CountPhotos(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_photos WHERE serial = ?', { serial })) or 0
end

function DB.InsertPhoto(serial, data, now, kind)
    return MySQL.insert.await('INSERT INTO pop_tablet_photos (serial, data, taken_at, kind) VALUES (?, ?, ?, ?)',
        { serial, data, now, kind or 'photo' })
end

--- Page de photos (30 au plus) : portée 'all' (hors corbeille), 'fav', 'trash' ou 'album' (albumId). Récentes d'abord.
function DB.ListPhotos(serial, scope, albumId, offset, limit)
    local cols = 'p.id, p.kind, p.rating, p.favorite, p.fx, p.taken_at, p.thumb'
    local order = ' ORDER BY p.taken_at DESC, p.id DESC LIMIT ? OFFSET ?'
    if scope == 'album' then
        return MySQL.query.await('SELECT ' .. cols .. ' FROM pop_tablet_photo_albums pa JOIN pop_tablet_photos p ON p.id = pa.photo_id'
            .. ' WHERE pa.album_id = ? AND p.serial = ? AND p.deleted_at IS NULL' .. order, { albumId, serial, limit, offset }) or {}
    end
    local where = scope == 'trash' and 'p.deleted_at IS NOT NULL' or scope == 'fav' and 'p.deleted_at IS NULL AND p.favorite = 1' or 'p.deleted_at IS NULL'
    return MySQL.query.await('SELECT ' .. cols .. ' FROM pop_tablet_photos p WHERE p.serial = ? AND ' .. where .. order, { serial, limit, offset }) or {}
end

--- Compteurs de la barre latérale : photos (hors corbeille), favoris, corbeille. Une requête.
function DB.PhotoCounts(serial)
    local r = MySQL.single.await('SELECT SUM(deleted_at IS NULL) AS total, SUM(deleted_at IS NULL AND favorite = 1) AS fav,'
        .. ' SUM(deleted_at IS NOT NULL) AS trash FROM pop_tablet_photos WHERE serial = ?', { serial }) or {}
    return { total = tonumber(r.total) or 0, fav = tonumber(r.fav) or 0, trash = tonumber(r.trash) or 0 }
end

function DB.GetPhoto(serial, id)
    return MySQL.single.await('SELECT id, data, kind, rating, favorite, fx, taken_at, deleted_at FROM pop_tablet_photos WHERE id = ? AND serial = ?', { id, serial })
end

function DB.PhotoOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_photos WHERE id = ? AND serial = ? LIMIT 1', { id, serial }) ~= nil
end

--- Modifie un champ d'une photo (liste blanche de colonnes ; la valeur reste un paramètre).
local PHOTO_FIELDS = { favorite = true, rating = true, fx = true, thumb = true }
function DB.SetPhotoField(serial, id, field, value)
    if not PHOTO_FIELDS[field] then return false end
    local n = MySQL.update.await('UPDATE pop_tablet_photos SET ' .. field .. ' = ? WHERE id = ? AND serial = ?', { value, id, serial })
    return (n or 0) > 0
end

--- Corbeille : deleted_at posé (now) ou retiré (nil).
function DB.SetPhotoDeleted(serial, id, now)
    local n = MySQL.update.await('UPDATE pop_tablet_photos SET deleted_at = ? WHERE id = ? AND serial = ?', { now, id, serial })
    return (n or 0) > 0
end

function DB.DeletePhoto(serial, id)
    local n = MySQL.update.await('DELETE FROM pop_tablet_photos WHERE id = ? AND serial = ?', { id, serial })
    return (n or 0) > 0
end

--- Vide la corbeille des photos supprimées avant `cutoff`.
function DB.PurgePhotoTrash(serial, cutoff)
    return MySQL.update.await('DELETE FROM pop_tablet_photos WHERE serial = ? AND deleted_at IS NOT NULL AND deleted_at < ?', { serial, cutoff }) or 0
end

--- Albums : liste avec nombre de photos, création, suppression, appartenance.
function DB.ListAlbums(serial)
    return MySQL.query.await('SELECT a.id, a.name, (SELECT COUNT(*) FROM pop_tablet_photo_albums pa JOIN pop_tablet_photos p ON p.id = pa.photo_id'
        .. ' WHERE pa.album_id = a.id AND p.deleted_at IS NULL) AS n FROM pop_tablet_albums a WHERE a.serial = ? ORDER BY a.id', { serial }) or {}
end

function DB.CountAlbums(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_albums WHERE serial = ?', { serial })) or 0
end

function DB.InsertAlbum(serial, name, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_albums (serial, name, created_at) VALUES (?, ?, ?)', { serial, name, now })
end

function DB.RenameAlbum(serial, id, name)
    local n = MySQL.update.await('UPDATE pop_tablet_albums SET name = ? WHERE id = ? AND serial = ?', { name, id, serial })
    return (n or 0) > 0
end

function DB.DeleteAlbum(serial, id)
    local n = MySQL.update.await('DELETE FROM pop_tablet_albums WHERE id = ? AND serial = ?', { id, serial })
    return (n or 0) > 0
end

function DB.AlbumOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_albums WHERE id = ? AND serial = ? LIMIT 1', { id, serial }) ~= nil
end

function DB.AlbumLink(albumId, photoId, on)
    if on then
        MySQL.update.await('INSERT IGNORE INTO pop_tablet_photo_albums (album_id, photo_id) VALUES (?, ?)', { albumId, photoId })
    else
        MySQL.update.await('DELETE FROM pop_tablet_photo_albums WHERE album_id = ? AND photo_id = ?', { albumId, photoId })
    end
end

function DB.PhotoAlbums(photoId)
    local rows = MySQL.query.await('SELECT album_id FROM pop_tablet_photo_albums WHERE photo_id = ?', { photoId }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = r.album_id end
    return out
end

--- Notes : liste sans corps (titre, extrait, épinglée, dossier, corbeille), lecture, écriture, dossiers.
function DB.ListNotes(serial)
    return MySQL.query.await('SELECT id, folder_id, title, excerpt, hint, pinned, deleted_at, updated_at FROM pop_tablet_notes WHERE serial = ?'
        .. ' ORDER BY pinned DESC, updated_at DESC, id DESC LIMIT 200', { serial }) or {}
end

function DB.CountNotes(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_notes WHERE serial = ?', { serial })) or 0
end

function DB.GetNote(serial, id)
    return MySQL.single.await('SELECT id, folder_id, title, body, pinned, deleted_at, updated_at FROM pop_tablet_notes WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertNote(serial, n, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_notes (serial, folder_id, title, excerpt, hint, body, pinned, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { serial, n.folder, n.title, n.excerpt, n.hint, n.body, n.pinned and 1 or 0, now })
end

function DB.UpdateNote(serial, id, n, now)
    local r = MySQL.update.await('UPDATE pop_tablet_notes SET folder_id = ?, title = ?, excerpt = ?, hint = ?, body = ?, pinned = ?, updated_at = ? WHERE id = ? AND serial = ?',
        { n.folder, n.title, n.excerpt, n.hint, n.body, n.pinned and 1 or 0, now, id, serial })
    return (r or 0) > 0
end

--- Corbeille des notes : deleted_at posé (now) ou retiré (nil).
function DB.SetNoteDeleted(serial, id, now)
    local r = MySQL.update.await('UPDATE pop_tablet_notes SET deleted_at = ?, pinned = 0 WHERE id = ? AND serial = ?', { now, id, serial })
    return (r or 0) > 0
end

function DB.DeleteNote(serial, id)
    local r = MySQL.update.await('DELETE FROM pop_tablet_notes WHERE id = ? AND serial = ?', { id, serial })
    return (r or 0) > 0
end

function DB.PurgeNoteTrash(serial, cutoff)
    return MySQL.update.await('DELETE FROM pop_tablet_notes WHERE serial = ? AND deleted_at IS NOT NULL AND deleted_at < ?', { serial, cutoff }) or 0
end

function DB.ListNoteFolders(serial)
    return MySQL.query.await('SELECT id, name FROM pop_tablet_note_folders WHERE serial = ? ORDER BY id', { serial }) or {}
end

function DB.NoteFolderOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_note_folders WHERE id = ? AND serial = ? LIMIT 1', { id, serial }) ~= nil
end

function DB.InsertNoteFolder(serial, name, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_note_folders (serial, name, created_at) VALUES (?, ?, ?)', { serial, name, now })
end

function DB.RenameNoteFolder(serial, id, name)
    local r = MySQL.update.await('UPDATE pop_tablet_note_folders SET name = ? WHERE id = ? AND serial = ?', { name, id, serial })
    return (r or 0) > 0
end

function DB.DeleteNoteFolder(serial, id)
    local r = MySQL.update.await('DELETE FROM pop_tablet_note_folders WHERE id = ? AND serial = ?', { id, serial })
    return (r or 0) > 0
end

--- Fichiers : toutes les entrées d'une tablette (500 au plus, sans corps), lecture, écriture, partage par jeton.
function DB.ListFiles(serial)
    return MySQL.query.await('SELECT id, parent_id, kind, name, ref_id, size, share_token, tag, fav, updated_at FROM pop_tablet_files WHERE serial = ? LIMIT 501', { serial }) or {}
end

function DB.GetFile(serial, id)
    return MySQL.single.await('SELECT id, parent_id, kind, name, body, ref_id, size, share_token, tag, fav, updated_at FROM pop_tablet_files WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertFile(serial, f, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_files (serial, parent_id, kind, name, body, ref_id, size, tag, fav, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { serial, f.parent, f.kind, f.name, f.body, f.ref, f.size or 0, f.tag, f.fav and 1 or 0, now })
end

function DB.UpdateFile(serial, id, f, now)
    local r = MySQL.update.await('UPDATE pop_tablet_files SET name = ?, body = ?, size = ?, tag = ?, fav = ?, updated_at = ? WHERE id = ? AND serial = ?',
        { f.name, f.body, f.size or 0, f.tag, f.fav and 1 or 0, now, id, serial })
    return (r or 0) > 0
end

function DB.MoveFile(serial, id, parent, now)
    local r = MySQL.update.await('UPDATE pop_tablet_files SET parent_id = ?, updated_at = ? WHERE id = ? AND serial = ?', { parent, now, id, serial })
    return (r or 0) > 0
end

function DB.DeleteFile(serial, id)
    local r = MySQL.update.await('DELETE FROM pop_tablet_files WHERE id = ? AND serial = ?', { id, serial })
    return (r or 0) > 0
end

--- Pose un jeton de partage unique ; false si le jeton existe déjà (le serveur retire alors un autre jeton).
function DB.SetShareToken(serial, id, token)
    local r = MySQL.update.await('UPDATE IGNORE pop_tablet_files SET share_token = ? WHERE id = ? AND serial = ?', { token, id, serial })
    return (r or 0) > 0
end

function DB.FileByToken(token)
    return MySQL.single.await('SELECT id, serial, kind, name, body, ref_id, size, updated_at FROM pop_tablet_files WHERE share_token = ?', { token })
end

function DB.PhotoData(id)
    return MySQL.scalar.await('SELECT data FROM pop_tablet_photos WHERE id = ? AND deleted_at IS NULL', { id })
end

--- Tableaux : liste sans contenu, lecture, écriture. La suppression emporte les raccourcis de Fichiers.
function DB.ListBoards(serial)
    return MySQL.query.await('SELECT id, title, updated_at FROM pop_tablet_boards WHERE serial = ? ORDER BY updated_at DESC, id DESC LIMIT 30', { serial }) or {}
end

function DB.CountBoards(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_boards WHERE serial = ?', { serial })) or 0
end

function DB.GetBoard(serial, id)
    return MySQL.single.await('SELECT id, title, strokes, updated_at FROM pop_tablet_boards WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertBoard(serial, title, strokes, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_boards (serial, title, strokes, updated_at) VALUES (?, ?, ?, ?)', { serial, title, strokes, now })
end

function DB.UpdateBoard(serial, id, title, strokes, now)
    local r = MySQL.update.await('UPDATE pop_tablet_boards SET title = ?, strokes = ?, updated_at = ? WHERE id = ? AND serial = ?', { title, strokes, now, id, serial })
    return (r or 0) > 0
end

function DB.DeleteBoard(serial, id)
    local r = MySQL.update.await('DELETE FROM pop_tablet_boards WHERE id = ? AND serial = ?', { id, serial })
    if (r or 0) > 0 then MySQL.update.await("DELETE FROM pop_tablet_files WHERE serial = ? AND kind = 'board' AND ref_id = ?", { serial, id }) end
    return (r or 0) > 0
end

--- Enregistrements : liste sans contenu (memo = 1 pour un mémo dicté), lecture, écriture.
function DB.ListRecs(serial)
    return MySQL.query.await("SELECT id, title, seconds, created_at, (LEFT(data, 5) = 'memo:') AS memo FROM pop_tablet_recordings WHERE serial = ? ORDER BY created_at DESC, id DESC LIMIT 30", { serial }) or {}
end

function DB.CountRecs(serial)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pop_tablet_recordings WHERE serial = ?', { serial })) or 0
end

function DB.GetRec(serial, id)
    return MySQL.single.await('SELECT id, title, seconds, data, created_at FROM pop_tablet_recordings WHERE id = ? AND serial = ?', { id, serial })
end

function DB.InsertRec(serial, title, seconds, data, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_recordings (serial, title, seconds, data, created_at) VALUES (?, ?, ?, ?, ?)', { serial, title, seconds, data, now })
end

function DB.RenameRec(serial, id, title)
    local r = MySQL.update.await('UPDATE pop_tablet_recordings SET title = ? WHERE id = ? AND serial = ?', { title, id, serial })
    return (r or 0) > 0
end

function DB.DeleteRec(serial, id)
    local r = MySQL.update.await('DELETE FROM pop_tablet_recordings WHERE id = ? AND serial = ?', { id, serial })
    if (r or 0) > 0 then MySQL.update.await("DELETE FROM pop_tablet_files WHERE serial = ? AND kind = 'audio' AND ref_id = ?", { serial, id }) end
    return (r or 0) > 0
end

function DB.BoardOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_boards WHERE id = ? AND serial = ? LIMIT 1', { id, serial }) ~= nil
end

function DB.RecordingOwned(serial, id)
    return MySQL.scalar.await('SELECT 1 FROM pop_tablet_recordings WHERE id = ? AND serial = ? LIMIT 1', { id, serial }) ~= nil
end

--- Réserve une adresse mail (unique, une par tablette) ; false si prise ou si la tablette en a déjà une.
function DB.ClaimMailbox(address, serial)
    local n = MySQL.update.await('INSERT IGNORE INTO pop_tablet_mailboxes (address, serial) VALUES (?, ?)', { address, serial })
    return (n or 0) > 0
end

function DB.MailboxOwner(address)
    return MySQL.scalar.await('SELECT serial FROM pop_tablet_mailboxes WHERE address = ? LIMIT 1', { address })
end

function DB.DeleteMailbox(address, serial)
    MySQL.update.await('DELETE FROM pop_tablet_mailboxes WHERE address = ? AND serial = ?', { address, serial })
end

--- Données d'appli par tablette (Plans, Traduire, Bourse) : texte JSON, nil si rien d'enregistré.
function DB.GetAppData(serial, app)
    return MySQL.scalar.await('SELECT data FROM pop_tablet_appdata WHERE serial = ? AND app = ?', { serial, app })
end

function DB.SetAppData(serial, app, data)
    MySQL.update.await('INSERT INTO pop_tablet_appdata (serial, app, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { serial, app, data })
end

--- Marché simulé : lecture de tous les symboles, écriture d'un lot (état persisté rarement).
function DB.LoadMarket()
    return MySQL.query.await('SELECT symbol, price, prev_close, trend, updated_at FROM pop_tablet_market', {}) or {}
end

function DB.SaveMarket(rows, now)
    for _, r in ipairs(rows) do
        MySQL.update.await('INSERT INTO pop_tablet_market (symbol, price, prev_close, trend, updated_at) VALUES (?, ?, ?, ?, ?)'
            .. ' ON DUPLICATE KEY UPDATE price = VALUES(price), prev_close = VALUES(prev_close), trend = VALUES(trend), updated_at = VALUES(updated_at)',
            { r.sym, r.price, r.prev, r.trend, now })
    end
end

--- Supprime messages et appels plus vieux que `days` jours. Appelée au démarrage seulement.
function DB.Purge(days, now)
    local cutoff = now - days * 86400
    local messages = MySQL.update.await('DELETE FROM pop_tablet_messages WHERE sent_at < ?', { cutoff })
    local calls = MySQL.update.await('DELETE FROM pop_tablet_calls WHERE started_at < ?', { cutoff })
    return messages or 0, calls or 0
end

------------------------------------------------------------------------
-- Calendrier, Rappels, Horloge (requêtes préparées, index serial)
------------------------------------------------------------------------

--- Événements dont la plage recoupe [from, to] (dates jeu 'AAAA-MM-JJ HH:MM').
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
