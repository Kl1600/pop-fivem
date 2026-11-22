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

function DB.InsertPhoto(serial, data, now)
    return MySQL.insert.await('INSERT INTO pop_tablet_photos (serial, data, taken_at) VALUES (?, ?, ?)', { serial, data, now })
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
