"""Contrôle hors ligne de sql/install.sql (aucun serveur MySQL requis).

Ce n'est PAS une exécution MariaDB : le script convertit le dialecte vers SQLite (types, index, ENGINE)
pour vérifier l'ordre de création, les clés étrangères, la cascade et le nombre de tables.
L'exécution réelle sur MariaDB reste à faire (voir PROGRESS.md).

Usage : python -I tests/check_sql.py   (depuis resources/[pop]/pop_tablet)
"""
import re
import sqlite3
import sys

EXPECTED = 23
src = open('sql/install.sql', encoding='utf-8').read()
src = re.sub(r'--[^\n]*', '', src)
statements = [s.strip() for s in src.split(';\n') if s.strip()]

conn = sqlite3.connect(':memory:')
conn.execute('PRAGMA foreign_keys = ON')
tables = []
indexes = []

for st in statements:
    m = re.match(r'CREATE TABLE IF NOT EXISTS `(\w+)` \((.*)\)\s*ENGINE=InnoDB[^;]*$', st, re.S)
    if not m:
        sys.exit('instruction non reconnue : ' + st[:80])
    name, body = m.group(1), m.group(2)
    lines = [l.strip().rstrip(',') for l in body.split('\n') if l.strip()]
    out = []
    for l in lines:
        km = re.match(r'(UNIQUE )?KEY `(\w+)` \((.*)\)$', l)
        if km:
            kind = 'UNIQUE INDEX' if km.group(1) else 'INDEX'
            indexes.append('CREATE %s `%s` ON `%s` (%s)' % (kind, km.group(2), name, km.group(3)))
            continue
        l = re.sub(r'ENUM\([^)]*\)', 'TEXT', l)
        l = re.sub(r'\bAUTO_INCREMENT\b', '', l)
        out.append(l)
    conn.execute('CREATE TABLE `%s` (%s)' % (name, ',\n'.join(out)))
    tables.append(name)

for ix in indexes:
    conn.execute(ix)

assert len(tables) == EXPECTED, 'attendu %d tables, trouvé %d' % (EXPECTED, len(tables))
assert len(set(tables)) == EXPECTED, 'table en double'

# Chaque table liée à une tablette porte `serial` et une clé étrangère CASCADE vers pop_tablet_devices.
no_serial = {'pop_tablet_devices', 'pop_tablet_messages', 'pop_tablet_calls', 'pop_tablet_market', 'pop_tablet_sites', 'pop_tablet_photo_albums', 'pop_tablet_msg_groups', 'pop_tablet_msg_members'}
for t in tables:
    cols = [r[1] for r in conn.execute('PRAGMA table_info(`%s`)' % t)]
    if t in no_serial:
        continue
    assert 'serial' in cols, t + ' sans serial'
    fks = [r for r in conn.execute('PRAGMA foreign_key_list(`%s`)' % t) if r[2] == 'pop_tablet_devices']
    assert fks and fks[0][6] == 'CASCADE', t + ' sans FK CASCADE vers devices'

# Cascade réelle : supprimer une tablette supprime ses lignes.
conn.execute("INSERT INTO pop_tablet_devices (serial, phone) VALUES ('PT-AAAAAAAAAA', '555-0001')")
conn.execute("INSERT INTO pop_tablet_notes (id, serial) VALUES (1, 'PT-AAAAAAAAAA')")
conn.execute("INSERT INTO pop_tablet_reminder_lists (id, serial) VALUES (1, 'PT-AAAAAAAAAA')")
conn.execute("INSERT INTO pop_tablet_reminders (id, serial, list_id) VALUES (1, 'PT-AAAAAAAAAA', 1)")
conn.execute("INSERT INTO pop_tablet_mailboxes (address, serial) VALUES ('a@pop.ls', 'PT-AAAAAAAAAA')")
try:
    conn.execute("INSERT INTO pop_tablet_notes (id, serial) VALUES (2, 'PT-INCONNU0000')")
    sys.exit('FK non appliquée : serial inconnu accepté')
except sqlite3.IntegrityError:
    pass
try:
    conn.execute("INSERT INTO pop_tablet_devices (serial, phone) VALUES ('PT-BBBBBBBBBB', '555-0001')")
    sys.exit('UNIQUE phone non appliqué')
except sqlite3.IntegrityError:
    pass
conn.execute("INSERT INTO pop_tablet_photos (id, serial) VALUES (1, 'PT-AAAAAAAAAA')")
conn.execute("INSERT INTO pop_tablet_albums (id, serial) VALUES (1, 'PT-AAAAAAAAAA')")
conn.execute("INSERT INTO pop_tablet_photo_albums (album_id, photo_id) VALUES (1, 1)")
conn.execute("INSERT INTO pop_tablet_note_folders (id, serial) VALUES (1, 'PT-AAAAAAAAAA')")
conn.execute("INSERT INTO pop_tablet_files (id, serial, parent_id) VALUES (1, 'PT-AAAAAAAAAA', NULL)")
conn.execute("INSERT INTO pop_tablet_files (id, serial, parent_id) VALUES (2, 'PT-AAAAAAAAAA', 1)")
conn.execute("DELETE FROM pop_tablet_devices WHERE serial = 'PT-AAAAAAAAAA'")
for t in ('pop_tablet_photo_albums', 'pop_tablet_photos', 'pop_tablet_albums', 'pop_tablet_note_folders', 'pop_tablet_files', 'pop_tablet_notes', 'pop_tablet_reminder_lists', 'pop_tablet_reminders', 'pop_tablet_mailboxes'):
    n = conn.execute('SELECT COUNT(*) FROM `%s`' % t).fetchone()[0]
    assert n == 0, t + ' non vidée par la cascade'

print('OK : %d tables, %d index, FK et cascade vérifiées (SQLite, pas MariaDB)' % (len(tables), len(indexes)))
