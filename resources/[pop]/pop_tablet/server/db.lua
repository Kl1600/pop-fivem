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

--- Supprime messages et appels plus vieux que `days` jours. Appelée au démarrage seulement.
function DB.Purge(days, now)
    local cutoff = now - days * 86400
    local messages = MySQL.update.await('DELETE FROM pop_tablet_messages WHERE sent_at < ?', { cutoff })
    local calls = MySQL.update.await('DELETE FROM pop_tablet_calls WHERE started_at < ?', { cutoff })
    return messages or 0, calls or 0
end
