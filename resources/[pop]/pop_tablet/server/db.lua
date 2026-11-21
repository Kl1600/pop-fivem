-- Toutes les requêtes oxmysql du script. Requêtes paramétrées (`?`) uniquement, aucune concaténation de valeurs.

Tablet = Tablet or {}
Tablet.DB = {}
local DB = Tablet.DB

local COLUMNS = 'serial, phone, code_hash, code_salt, fails, locked_until, name, settings, apps, battery, battery_at, owner_hint'

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
