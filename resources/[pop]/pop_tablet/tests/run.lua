-- Tests Lua autonomes de pop_tablet (sans FiveM) : lua tests/run.lua, depuis resources/[pop]/pop_tablet.
-- Les natives, Bridge, la base et l'inventaire sont remplacés par de petits faux ; la logique testée est le vrai code.

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print('ECHEC ' .. name .. (detail and (' : ' .. tostring(detail)) or ''))
    end
end
local function section(name) print('-- ' .. name) end

local function def(k, v) rawset(_G, k, v) end

------------------------------------------------------------------------
-- Faux environnement FiveM
------------------------------------------------------------------------

local function jsonEncode(v)
    local t = type(v)
    if t == 'table' then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = '"' .. tostring(k) .. '":' .. jsonEncode(x) end
        table.sort(parts)
        return '{' .. table.concat(parts, ',') .. '}'
    elseif t == 'string' then
        return '"' .. v .. '"'
    end
    return tostring(v)
end
def('json', { encode = jsonEncode, decode = function() return {} end })
def('vec3', function(x, y, z) return { x = x, y = y, z = z } end)
def('GetCurrentResourceName', function() return 'pop_tablet' end)
local kvp = {}
def('GetConvar', function(_, default) return default end)
def('GetResourceKvpString', function(k) return kvp[k] end)
def('SetResourceKvp', function(k, v) kvp[k] = v end)

local timers = {}
def('SetTimeout', function(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end)
local sent = {}
def('TriggerClientEvent', function(name, src, data) sent[#sent + 1] = { name = name, src = src, data = data } end)

local handlers = {}
Callback = { Register = function(name, fn) handlers[name] = fn end }

dofile('config.lua')
dofile('shared/tablet.lua')
dofile('shared/locale.lua')
for _, lang in ipairs({ 'en', 'fr', 'es', 'de', 'it', 'pt', 'nl', 'pl', 'tr', 'ar' }) do
    dofile('locales/' .. lang .. '.lua')
end
for _, f in ipairs({ 'hash', 'limits', 'db', 'device', 'push', 'scheduler', 'api' }) do
    def('exports', function() end)
    dofile('server/' .. f .. '.lua')
end

local Hash, Limits, D = Tablet.Hash, Tablet.Limits, Tablet.Device

------------------------------------------------------------------------
section('socle-03 : SHA-256 et HMAC')
------------------------------------------------------------------------
check('sha256 vide', Hash.sha256('') == 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
check('sha256 abc', Hash.sha256('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
check('sha256 448 bits', Hash.sha256('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')
    == '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1')
check('sha256 million a', Hash.sha256(string.rep('a', 1000000))
    == 'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0')
check('hmac rfc4231 #1', Hash.hmac(string.rep('\x0b', 20), 'Hi There')
    == 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7')
check('hmac rfc4231 #2', Hash.hmac('Jefe', 'what do ya want for nothing?')
    == '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843')
check('hmac rfc4231 #6 (clé > 64 octets)', Hash.hmac(string.rep('\xaa', 131), 'Test Using Larger Than Block-Size Key - Hash Key First')
    == '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54')
check('equals vrai', Hash.equals('abcd', 'abcd'))
check('equals faux', not Hash.equals('abcd', 'abce') and not Hash.equals('abc', 'abcd') and not Hash.equals('a', nil))
local c1 = Hash.code('pep', 'sel', '1234', 3)
check('code 64 hex', #c1 == 64 and c1:match('^%x+$') ~= nil)
check('code stable', c1 == Hash.code('pep', 'sel', '1234', 3))
check('code dépend du code, du sel, du poivre, des itérations',
    c1 ~= Hash.code('pep', 'sel', '1235', 3) and c1 ~= Hash.code('pep', 'sol', '1234', 3)
    and c1 ~= Hash.code('per', 'sel', '1234', 3) and c1 ~= Hash.code('pep', 'sel', '1234', 4))
local t0 = os.clock()
Hash.code('pep', 'sel', '1234', 2000)
print(('   (2000 itérations : %.0f ms)'):format((os.clock() - t0) * 1000))

------------------------------------------------------------------------
section('socle-04 : série et numéro')
------------------------------------------------------------------------
do
    local seen, dup, badFormat = {}, 0, 0
    for _ = 1, 10000 do
        local s = D.NewSerial(function(x) return seen[x] end)
        if seen[s] then dup = dup + 1 end
        seen[s] = true
        if not (#s == 13 and s:match('^PT%-[A-Z2-9]+$')) then badFormat = badFormat + 1 end
    end
    check('10 000 séries sans doublon', dup == 0, dup)
    check('format série', badFormat == 0, badFormat)
    local tries = 0
    local s = D.NewSerial(function() tries = tries + 1 return tries <= 3 end)
    check('collision forcée : nouvelle série tirée', s ~= nil and tries == 4)
    check('collisions permanentes : nil', D.NewSerial(function() return true end) == nil)

    local phones, pdup, pbad = {}, 0, 0
    for _ = 1, 3000 do
        local p = D.NewPhone('###-####', function(x) return phones[x] end)
        if p then
            if phones[p] then pdup = pdup + 1 end
            phones[p] = true
            if not (p:match('^%d%d%d%-%d%d%d%d$') and D.PhoneValid(p)) then pbad = pbad + 1 end
        end
    end
    check('numéros sans doublon', pdup == 0)
    check('format numéro ###-####', pbad == 0)
    local n = 0
    check('numéro : 5 essais puis nil', D.NewPhone('###-####', function() n = n + 1 return true end) == nil and n == 5)
    check('PhoneValid refuse', not D.PhoneValid('12-34567') and not D.PhoneValid('abc-defg') and not D.PhoneValid(5))
    check('SerialValid', D.SerialValid('PT-ABCDEFGH23') and not D.SerialValid('PT-ABCDEFGH01') and not D.SerialValid('XX-ABCDEFGH23'))
    check('série du propriétaire stable', D.OwnerSerial('char1:abc') == D.OwnerSerial('char1:abc')
        and D.OwnerSerial('char1:abc') ~= D.OwnerSerial('char2:abc') and D.SerialValid(D.OwnerSerial('x')))
end

------------------------------------------------------------------------
section('socle-12 : batterie')
------------------------------------------------------------------------
do
    local cfg = { Enabled = true, MinToOpen = 5, DrainMinutes = 6, ChargeMinutes = 1 }
    local b = Tablet.Battery
    check('recharge 10 min fermée : 50 -> 60', (b.OnOpen(50, 1000, 1000 + 600, cfg)) == 60)
    check('recharge plafonnée à 100', (b.OnOpen(95, 0 + 1, 1 + 3600, cfg)) == 100)
    check('pas de recharge si at inconnu', (b.OnOpen(40, 0, 5000, cfg)) == 40)
    check('décharge 12 min ouverte : 50 -> 48', b.OnClose(50, 1000, 1000 + 720, cfg) == 48)
    check('décharge 5 min : aucun pourcent', b.OnClose(50, 1000, 1300, cfg) == 50)
    check('décharge plancher 0', b.OnClose(1, 0, 36000, cfg) == 0)
    check('batterie désactivée : 100', (b.OnOpen(3, 1, 99999, { Enabled = false })) == 100)
end

------------------------------------------------------------------------
section('socle-13 : limites')
------------------------------------------------------------------------
for _, field in ipairs({ 'name', 'title', 'note', 'message', 'mail', 'contact', 'search' }) do
    local max = Tablet.Max[field]
    check(field .. ' = N accepté', Limits.Field(field, string.rep('a', max), { multiline = true }))
    local ok, err = Limits.Field(field, string.rep('a', max + 1), { multiline = true })
    check(field .. ' = N+1 rejeté', not ok and err == 'err_too_large', err)
    check(field .. ' accents N accepté, N+1 rejeté', Limits.Field(field, string.rep('é', max))
        and not Limits.Field(field, string.rep('é', max + 1)))
end
check('type non chaîne rejeté', not Limits.Field('name', 42) and not Limits.Field('name', nil))
check('caractère de contrôle rejeté', not Limits.Field('title', 'a\0b') and not Limits.Field('title', 'a\nb'))
check('retour à la ligne autorisé en multiligne', Limits.Field('note', 'a\nb', { multiline = true }))
check('UTF-8 invalide rejeté', not Limits.Field('name', '\xff\xfe'))
check('min respecté', not Limits.Field('name', '', { min = 1 }) and Limits.Field('name', 'a', { min = 1 }))
check('Int', Limits.Int(5, 1, 10) == 5 and Limits.Int(11, 1, 10) == nil and Limits.Int(5.5, 1, 10) == nil and Limits.Int('5', 1, 10) == nil)
check('Enum', Limits.Enum('fr', Tablet.LanguageSet) and not Limits.Enum('xx', Tablet.LanguageSet) and not Limits.Enum(1, Tablet.LanguageSet))
check('charge 16 Ko : N ok, N+1 rejeté', Limits.Payload({ s = string.rep('a', 100) }, 16384)
    and not Limits.Payload({ s = string.rep('a', 17000) }, 16384))
check('tableau 128 Ko', Limits.Payload({ s = string.rep('a', 130000) }, Tablet.Max.board)
    and not Limits.Payload({ s = string.rep('a', 132000) }, Tablet.Max.board))
local deep = {}
local cursor = deep
for _ = 1, 20 do cursor.x = {} cursor = cursor.x end
check('charge trop profonde rejetée', not Limits.Payload(deep, 16384))
check('fonction rejetée', not Limits.Payload({ f = print }, 16384))

------------------------------------------------------------------------
section('socle-15 : scheduler serveur')
------------------------------------------------------------------------
do
    local S = Tablet.Scheduler
    local now = 100
    S.SetClock(function() return now end)
    timers = {}
    local fired = {}
    S.Add('a', 110, function(k) fired[#fired + 1] = k end)
    check('une seule minuterie armée', #timers == 1 and timers[1].ms == 10000)
    S.Add('b', 105, function(k) fired[#fired + 1] = k end)
    check('échéance plus proche : nouvelle minuterie', #timers == 2 and timers[2].ms == 5000)
    timers[1].fn() -- ancienne minuterie : ne fait rien
    check('minuterie périmée sans effet', #fired == 0 and #timers == 2)
    now = 105
    timers[2].fn()
    check('b déclenchée, a ré-armée', fired[1] == 'b' and #timers == 3 and timers[3].ms == 5000)
    now = 110
    timers[3].fn()
    check('a déclenchée, plus aucune minuterie', fired[2] == 'a' and #timers == 3 and S.Count() == 0)
    S.Add('c', 120, function() end)
    S.Cancel('c')
    timers[#timers].fn()
    check('annulation : rien ne se déclenche', S.Count() == 0 and #fired == 2)
    S.SetClock(os.time)
end

------------------------------------------------------------------------
section('langues : mêmes clés dans les 10 fichiers')
------------------------------------------------------------------------
do
    local en = Locales.en
    for lang, tbl in pairs(Locales) do
        local missing = {}
        for k in pairs(en) do if tbl[k] == nil then missing[#missing + 1] = k end end
        for k in pairs(tbl) do if k ~= '_rtl' and en[k] == nil then missing[#missing + 1] = 'extra:' .. k end end
        check('clés de ' .. lang, #missing == 0, table.concat(missing, ','))
    end
    check('ar est RTL', Locales.ar._rtl == true and not Locales.en._rtl)
end

------------------------------------------------------------------------
-- Faux Bridge, inventaire et base pour la garde, la session et le code
------------------------------------------------------------------------
local clock = 1000000
Tablet.Now = function() return clock end

local players, dead, inv, admin = {}, {}, {}, {}
local failAdd = 0
Bridge = {
    GetPlayer = function(src) return players[src] and {} or nil end,
    IsDead = function(src) return dead[src] == true end,
    GetIdentifier = function(src) return players[src] end,
    SupportsMetadata = function() return true end,
    IsAdmin = function(src) return admin[src] == true end,
    HasItem = function(src, item)
        for _, it in ipairs(inv[src] or {}) do if it.name == item then return true end end
        return false
    end,
    GetItems = function(src, item)
        local out = {}
        for _, it in ipairs(inv[src] or {}) do if it.name == item then out[#out + 1] = it end end
        return out
    end,
    AddItem = function(src, item, count, metadata)
        if failAdd > 0 then failAdd = failAdd - 1 return false end
        inv[src] = inv[src] or {}
        table.insert(inv[src], { name = item, count = count, slot = #inv[src] + 1, metadata = metadata or {} })
        return true
    end,
    RemoveItem = function(src, item, _, metadata, slot)
        for i, it in ipairs(inv[src] or {}) do
            local match = it.name == item and (slot == nil or it.slot == slot)
            if match and metadata then
                for k, v in pairs(metadata) do if it.metadata[k] ~= v then match = false end end
            end
            if match then table.remove(inv[src], i) return true end
        end
        return false
    end,
}

local rows, mailboxes = {}, {}
local DB = Tablet.DB
DB.GetDevice = function(serial)
    local r = rows[serial]
    if not r then return nil end
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    return c
end
DB.SerialExists = function(s) return rows[s] ~= nil end
DB.PhoneExists = function(p) for _, r in pairs(rows) do if r.phone == p then return true end end return false end
DB.CreateDevice = function(serial, phone, hint, now, battery)
    if rows[serial] then return false end
    rows[serial] = { serial = serial, phone = phone, owner_hint = hint, battery = battery, battery_at = now,
        fails = 0, locked_until = 0, code_salt = '', name = '' }
    return true
end
DB.DeleteDevice = function(s) rows[s] = nil end
DB.ClaimSetup = function(serial, hash, salt, name, settings, apps)
    local r = rows[serial]
    if r.code_hash ~= nil then return false end
    r.code_hash, r.code_salt, r.name, r.settings, r.apps = hash, salt, name, settings, apps
    return true
end
DB.SetCode = function(serial, hash, salt) rows[serial].code_hash, rows[serial].code_salt = hash, salt end
DB.SetFails = function(serial, fails, until_) rows[serial].fails, rows[serial].locked_until = fails, until_ end
DB.SetBattery = function(serial, b, at) rows[serial].battery, rows[serial].battery_at = b, at end
DB.TouchOpen = function(serial, b, now) rows[serial].battery, rows[serial].battery_at = b, now end
DB.ClaimMailbox = function(addr, serial)
    if mailboxes[addr] then return false end
    for _, s in pairs(mailboxes) do if s == serial then return false end end
    mailboxes[addr] = serial
    return true
end
DB.MailboxOwner = function(addr) return mailboxes[addr] end
DB.DeleteMailbox = function(addr) mailboxes[addr] = nil end

local function countRows() local n = 0 for _ in pairs(rows) do n = n + 1 end return n end
local function lastPush() return sent[#sent] end

------------------------------------------------------------------------
section('socle-05 : conversion d\'un objet sans serial (logique, faux inventaire)')
------------------------------------------------------------------------
players[1] = 'char1'
inv[1] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = { color = 'noir' } } }
local open = handlers['pop_tablet:device:open'](1)
check('ouverture ok, setup requis', open.ok and open.needSetup and open.locked, open.err)
check('objet converti : un seul objet avec serial', #inv[1] == 1 and D.SerialValid(inv[1][1].metadata.serial)
    and inv[1][1].metadata.color == 'noir')
check('une seule ligne en base', countRows() == 1 and rows[open.serial] ~= nil and open.serial == inv[1][1].metadata.serial)
local serial1 = open.serial
local again = handlers['pop_tablet:device:open'](1)
check('réouverture : même série, pas de nouvelle ligne', again.serial == serial1 and countRows() == 1)

players[2] = 'char2'
inv[2] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
failAdd = 1
local r2 = handlers['pop_tablet:device:open'](2)
check('échec de l\'ajout : objet d\'origine restitué, rien en base',
    not r2.ok and #inv[2] == 1 and inv[2][1].metadata.serial == nil and countRows() == 1, r2.err)
players[3] = 'char3'
check('sans objet : refusé', handlers['pop_tablet:device:open'](3).err == 'err_no_tablet')

------------------------------------------------------------------------
section('socle-07 : garde')
------------------------------------------------------------------------
do
    local s, err = Tablet.Guard(9, nil, {})
    check('joueur inconnu refusé', s == nil and err == 'err_no_player')
    players[4] = 'char4'
    inv[4] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    s, err = Tablet.Guard(4, nil, { public = true })
    check('sans session refusé', s == nil and err == 'err_session')

    s, err = Tablet.Guard(1, nil, { public = true })
    check('session ouverte : accepté (public)', s ~= nil, err)
    s, err = Tablet.Guard(1, nil, {})
    check('tablette verrouillée refusée', s == nil and err == 'err_locked')
    s, err = Tablet.Guard(1, 'PT-FORGEDXXXX', { public = true })
    check('serial forgé refusé', s == nil and err == 'err_session')
    s, err = Tablet.Guard(1, nil, { public = true, payload = { s = string.rep('a', 20000) } })
    check('charge trop grande refusée', s == nil and err == 'err_too_large')

    -- Configuration puis déverrouillage
    local rawSetup = handlers['pop_tablet:device:setup']
    local function setup(src, d) clock = clock + 1 return rawSetup(src, d) end
    check('code de 3 chiffres refusé', setup(1, { code = '123', name = 'T', lang = 'fr', mail = 'alex' }).err == 'err_code_format')
    check('langue inconnue refusée', setup(1, { code = '1234', name = 'T', lang = 'xx', mail = 'alex' }).err == 'err_lang_invalid')
    check('adresse invalide refusée', setup(1, { code = '1234', name = 'T', lang = 'fr', mail = 'a b' }).err == 'err_mail_invalid')
    check('nom vide refusé', setup(1, { code = '1234', name = '  ', lang = 'fr', mail = 'alex' }).err == 'err_name_invalid')
    clock = clock + 1
    local ok = setup(1, { code = '1234', name = 'Alex Tab', lang = 'fr', mail = 'Alex.Martin@pop.ls' })
    check('premier allumage accepté', ok.ok and ok.boot ~= nil and ok.boot.name == 'Alex Tab', ok.err)
    local row = rows[serial1]
    check('code stocké haché, jamais en clair', row.code_hash ~= '1234' and #row.code_hash == 64 and row.code_salt ~= '1234'
        and not tostring(row.code_hash):find('1234', 1, true))
    check('adresse mail enregistrée', mailboxes['alex.martin@pop.ls'] == serial1)
    clock = clock + 1
    check('seconde configuration refusée', setup(1, { code = '9999', name = 'X', lang = 'fr', mail = 'autre' }).err == 'err_setup_done')
    check('mail déjà pris', (function()
        -- autre tablette tentant la même adresse
        inv[4][1].metadata = {}
        local o = handlers['pop_tablet:device:open'](4)
        clock = clock + 1
        return o.ok and setup(4, { code = '1111', name = 'B', lang = 'en', mail = 'alex.martin' }).err == 'err_mail_taken'
    end)())

    -- Session expirée
    s = Tablet.Guard(1, nil, {})
    check('session déverrouillée acceptée', s ~= nil)
    clock = clock + Config.Session.IdleLockSeconds + 1
    s, err = Tablet.Guard(1, nil, {})
    check('session expirée refusée', s == nil and err == 'err_locked')
    s = Tablet.Guard(1, nil, { public = true })
    check('expirée mais publique : ok', s ~= nil)

    -- Objet retiré en cours d'usage
    local before = #sent
    inv[1] = {}
    s, err = Tablet.Guard(1, nil, { public = true })
    check('objet perdu : refusé + session supprimée', s == nil and err == 'err_no_tablet' and not D.HasSession(1))
    check('objet perdu : fermeture forcée poussée', #sent == before + 1 and lastPush().name == 'pop_tablet:client:forceClose'
        and lastPush().data.reason == 'lost')
    dead[4] = true
    s, err = Tablet.Guard(4, nil, { public = true })
    check('joueur mort refusé', s == nil and err == 'err_dead')
    dead[4] = nil
end

------------------------------------------------------------------------
section('socle-10 / 11 : déverrouillage, blocage progressif, changement de code')
------------------------------------------------------------------------
do
    inv[1] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = { serial = serial1 } } }
    clock = clock + 1
    local o = handlers['pop_tablet:device:open'](1)
    check('réouverture après perte : verrouillée', o.ok and o.locked)
    local unlock = handlers['pop_tablet:device:unlock']
    local function try(code) clock = clock + 1 return unlock(1, code) end

    check('code mal formé : pas compté', try('12') .err == 'err_code_format' and rows[serial1].fails == 0)
    local r
    for i = 1, 4 do
        r = try('0000')
        check('échec ' .. i, r.err == 'err_code_wrong' and r.left == 5 - i, r.err)
    end
    r = try('0000')
    check('5e échec : blocage 60 s', r.err == 'err_code_blocked' and r.wait == 60, r.wait)
    r = try('1234')
    check('bon code pendant le blocage : refusé', r.err == 'err_code_blocked' and r.wait > 0 and r.wait <= 60)
    clock = clock + 61
    r = try('0000')
    check('échec suivant : blocage doublé (120 s)', r.err == 'err_code_blocked' and r.wait == 120, r.wait)
    clock = clock + 121
    r = try('0000')
    check('puis 240 s', r.err == 'err_code_blocked' and r.wait == 240, r.wait)
    check('Lockout.Wait plafonné à 3600', Tablet.Lockout.Wait(30, Config.Security) == 3600
        and Tablet.Lockout.Wait(4, Config.Security) == 0 and Tablet.Lockout.Wait(5, Config.Security) == 60)
    clock = clock + 241
    r = try('1234')
    check('bon code après blocage : déverrouillé, compteur remis à 0', r.ok and r.boot and rows[serial1].fails == 0, r.err)

    -- Changement de code
    local change = handlers['pop_tablet:device:changeCode']
    clock = clock + 1
    check('mauvais ancien code refusé', change(1, '0000', '4321').err == 'err_code_wrong')
    clock = clock + 1
    check('nouveau code mal formé refusé', change(1, '1234', 'abcd').err == 'err_code_format')
    clock = clock + 1
    check('bon ancien code accepté', change(1, '1234', '4321').ok)
    handlers['pop_tablet:device:lock'](1)
    check('verrouillage', Tablet.Guard(1, nil, {}) == nil)
    check('ancien code inactif', try('1234').err == 'err_code_wrong')
    check('nouveau code actif', try('4321').ok)
    -- Limite de débit
    clock = clock + 10
    local limited = 0
    for _ = 1, 5 do if unlock(1, '0000').err == 'err_rate' then limited = limited + 1 end end
    check('limite de tentatives par seconde', limited >= 3, limited)
end

------------------------------------------------------------------------
section('socle-08 : nettoyage des sessions')
------------------------------------------------------------------------
do
    local before = D.SessionCount()
    check('session présente', before >= 1 and D.SrcOf(serial1) == 1)
    D.DropSession(1)
    check('drop : session et association supprimées', not D.HasSession(1) and D.SrcOf(serial1) == nil)
    D.StopAll()
    check('arrêt : aucune session résiduelle', D.SessionCount() == 0)
end

------------------------------------------------------------------------
section('socle-14 : push < 1 Ko')
------------------------------------------------------------------------
do
    local Push = Tablet.Push
    inv[1] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = { serial = serial1 } } }
    clock = clock + 1
    handlers['pop_tablet:device:open'](1)
    local n = #sent
    local ok, bytes = Push.To(1, 'notify', { app = 'messages', titleKey = 'k', args = { 'a' } })
    check('petit paquet envoyé', ok and bytes < 1024 and #sent == n + 1)
    check('paquet > 1 Ko refusé', not Push.To(1, 'notify', { text = string.rep('x', 1100) }) and #sent == n + 1)
    check('nom hors liste refusé', not Push.To(1, 'autre', {}))
    check('joueur sans session : rien envoyé', not Push.To(77, 'notify', {}) and #sent == n + 1)
    check('ToSerial atteint le porteur', Push.ToSerial(serial1, 'message', { msg = 1 }))
    check('ToSerial inconnu', not Push.ToSerial('PT-ZZZZZZZZZZ', 'message', {}))
    D.StopAll()
end

------------------------------------------------------------------------
section('socle-16 : give (logique)')
------------------------------------------------------------------------
do
    players[5] = 'char5'
    inv[5] = {}
    local ok, serial = D.Give(5)
    check('give : objet avec serial + ligne en base', ok and D.SerialValid(serial) and inv[5][1].metadata.serial == serial and rows[serial] ~= nil)
end

------------------------------------------------------------------------
-- Client : faux natives, vrai code de client/*.lua
------------------------------------------------------------------------
section('client : ouverture, focus, animation, relais, mort, arrêt')
do
    local cmds, keymaps, netEvents, gameHandlers, nuiCb, nuiMsgs, focus = {}, {}, {}, {}, {}, {}, {}
    local triggers, notifs, deleted, created, removedHandlers, serverEvents, exportsReg = {}, {}, {}, 0, 0, {}, {}
    local serverReply, threadsAtLoad, loading = {}, 0, true
    local deadPed, hour, minute, second = false, 8, 30, 0
    local clientTimers = {}
    def('RegisterCommand', function(n, fn) cmds[n] = fn end)
    def('RegisterKeyMapping', function(...) keymaps[#keymaps + 1] = { ... } end)
    def('RegisterNetEvent', function(n, fn) if fn then netEvents[n] = fn end end)
    def('AddEventHandler', function(n, fn)
        if n == 'gameEventTriggered' then gameHandlers[#gameHandlers + 1] = fn return #gameHandlers end
        netEvents[n] = fn
    end)
    def('RemoveEventHandler', function() removedHandlers = removedHandlers + 1 end)
    def('RegisterNUICallback', function(n, fn) nuiCb[n] = fn end)
    def('SendNUIMessage', function(m) nuiMsgs[#nuiMsgs + 1] = m end)
    def('SetNuiFocus', function(a, b) focus[#focus + 1] = { a, b } end)
    def('SetTimeout', function(ms, fn) clientTimers[#clientTimers + 1] = { ms = ms, fn = fn } end)
    def('TriggerServerEvent', function(n, ...) serverEvents[#serverEvents + 1] = { n, ... } end)
    def('exports', function(n, fn) exportsReg[n] = fn end)
    def('CreateThread', function(fn) if loading then threadsAtLoad = threadsAtLoad + 1 end fn() end)
    def('Wait', function() end)
    def('PlayerPedId', function() return 77 end)
    def('RequestAnimDict', function() end)
    def('HasAnimDictLoaded', function() return true end)
    def('TaskPlayAnim', function() end)
    def('joaat', function() return 1 end)
    def('RequestModel', function() end)
    def('HasModelLoaded', function() return true end)
    def('GetEntityCoords', function() return { x = 0, y = 0, z = 0 } end)
    def('CreateObject', function() created = created + 1 return 555 end)
    def('GetPedBoneIndex', function() return 1 end)
    def('AttachEntityToEntity', function() end)
    def('SetModelAsNoLongerNeeded', function() end)
    def('DoesEntityExist', function() return true end)
    def('DeleteEntity', function(e) deleted[#deleted + 1] = e end)
    def('StopAnimTask', function() end)
    def('RemoveAnimDict', function() end)
    def('IsPedDeadOrDying', function() return deadPed end)
    def('GetClockHours', function() return hour end)
    def('GetClockMinutes', function() return minute end)
    def('GetClockSeconds', function() return second end)
    def('GetClockDayOfMonth', function() return 14 end)
    def('GetClockMonth', function() return 5 end)
    def('GetClockYear', function() return 2026 end)
    def('GetMillisecondsPerGameMinute', function() return 2000 end)
    Bridge.OnUiClose = function(fn) nuiCb['__uiclose'] = fn end
    Bridge.Notify = function(msg) notifs[#notifs + 1] = msg end
    Callback = {
        Register = function() end,
        Trigger = function(name, cb, ...)
            triggers[#triggers + 1] = { name = name, args = { ... } }
            local reply = serverReply[name]
            cb(type(reply) == 'function' and reply(...) or reply)
        end,
    }
    Config.Locale = 'en'
    for _, f in ipairs({ 'locale', 'anim', 'device', 'scheduler', 'main', 'nui', 'api' }) do dofile('client/' .. f .. '.lua') end
    loading = false
    local C = Tablet.Client
    local function triggered(name) for i = #triggers, 1, -1 do if triggers[i].name == name then return triggers[i] end end end
    local function lastMsg() return nuiMsgs[#nuiMsgs] end
    local function reset() triggers, nuiMsgs, notifs, focus, deleted = {}, {}, {}, {}, {} end

    check('aucune boucle ni thread au chargement (0,00 ms fermée)', threadsAtLoad == 0, threadsAtLoad)
    check('touche : RegisterKeyMapping(commande, texte traduit, keyboard, F5)',
        keymaps[1] and keymaps[1][1] == 'pop_tablet_toggle' and keymaps[1][2] == 'Open the tablet'
        and keymaps[1][3] == 'keyboard' and keymaps[1][4] == 'F5')
    check('exports IsOpen/Close/OpenApp', exportsReg.IsOpen and exportsReg.Close and exportsReg.OpenApp)

    -- Textes
    local ar = C.LocaleTable('ar')
    check('locale ar : RTL + clés en arabe', ar._rtl == true and ar.tablet_key == Locales.ar.tablet_key and ar.cancel ~= nil)
    check('locale fr : repli anglais pour une clé absente', C.LocaleTable('fr').tablet_key == Locales.fr.tablet_key and not C.LocaleTable('fr')._rtl)
    check('locale inconnue : langue du serveur', C.LocaleTable('zz').tablet_key == Locales.en.tablet_key)
    local snap = C.ClockSnapshot()
    check('horloge : heure, mois 1-12, ms par minute', snap.h == 8 and snap.m == 30 and snap.mo == 6 and snap.y == 2026 and snap.msPerMin == 2000)

    -- Ouverture par la touche
    serverReply['pop_tablet:device:open'] = { ok = false, err = 'err_no_tablet' }
    cmds.pop_tablet_toggle()
    check('touche sans objet : aucune notification, rien d\'ouvert', #notifs == 0 and not C.IsOpen() and #focus == 0)
    netEvents['pop_tablet:client:use']('PT-ABCDEFGH23')
    check('objet utilisé sans tablette valide : message d\'erreur', #notifs == 1 and not C.IsOpen())
    check('série de l\'objet transmise comme indice', triggered('pop_tablet:device:open').args[1] == 'PT-ABCDEFGH23')

    reset()
    serverReply['pop_tablet:device:open'] = { ok = true, serial = 'PT-ABCDEFGH23', needSetup = false, locked = true,
        boot = { settings = { lang = 'ar' } } }
    cmds.pop_tablet_toggle()
    check('ouverture : focus NUI (true, true)', C.IsOpen() and focus[1] and focus[1][1] == true and focus[1][2] == true)
    check('ouverture : message tablet:open (locale, rtl, accent, horloge)', lastMsg().action == 'tablet:open'
        and lastMsg().data.rtl == true and lastMsg().data.accent == Config.AccentColor and lastMsg().data.clock.h == 8
        and lastMsg().data.locale.tablet_key == Locales.ar.tablet_key)
    check('animation : objet créé et gestionnaire de mort posé', created == 1 and C.Anim.HasProp() and #gameHandlers == 1)

    local replies = {}
    nuiCb['tablet:ready']({}, function(r) replies[#replies + 1] = r end)
    check('tablet:ready renvoie tablet:open', lastMsg().action == 'tablet:open' and replies[1].ok)

    -- Relais NUI
    serverReply['pop_tablet:notes:list'] = { ok = true, notes = {} }
    local got
    nuiCb['tablet:call']({ name = 'notes:list', data = { a = 1 } }, function(r) got = r end)
    check('relais : nom autorisé transmis au serveur', got and got.ok and triggered('pop_tablet:notes:list') ~= nil)
    for _, bad in ipairs({ 'device:open', 'device:close', 'evil:thing', '../x', '' }) do
        local before = #triggers
        got = nil
        nuiCb['tablet:call']({ name = bad }, function(r) got = r end)
        check('relais : « ' .. bad .. ' » rejeté', got and got.ok == false and got.err == 'err_unknown_call' and #triggers == before)
    end
    nuiCb['tablet:call']({ name = 42 }, function(r) got = r end)
    check('relais : nom non texte rejeté', got.ok == false)
    nuiCb['tablet:call']({ name = 'notes:save', data = { body = string.rep('x', 140000) } }, function(r) got = r end)
    check('relais : charge > 128 Ko rejetée', got.err == 'err_too_large')
    serverReply['pop_tablet:notes:save'] = nil
    nuiCb['tablet:call']({ name = 'notes:save', data = {} }, function(r) got = r end)
    check('relais : pas de réponse serveur -> err_timeout', got.err == 'err_timeout')
    nuiCb['tablet:camera']({}, function(r) got = r end)
    check('caméra/carte/micro : réponse propre en attendant les applis', got.ok == false and got.err == 'err_unavailable')

    -- Horloge et resynchronisation
    clientTimers = {}
    reset()
    nuiCb['tablet:resync']({ active = true }, function(r) got = r end)
    check('resync : instantané + une minuterie de 60 s', got.ok and lastMsg().action == 'tablet:clock'
        and #clientTimers == 1 and clientTimers[1].ms == 60000)
    clientTimers[1].fn()
    check('resync : se ré-arme tant que l\'appli est active', #clientTimers == 2 and clientTimers[2].ms == 60000)
    nuiCb['tablet:resync']({ active = false }, function() end)
    local n = #nuiMsgs
    clientTimers[2].fn()
    check('resync coupée : plus aucun message ni minuterie', #nuiMsgs == n)

    -- Fermeture par l'interface
    reset()
    nuiCb['tablet:close']({}, function() end)
    check('fermeture : focus rendu, objet supprimé, serveur prévenu',
        not C.IsOpen() and focus[1][1] == false and deleted[1] == 555 and triggered('pop_tablet:device:close') ~= nil
        and removedHandlers == 1 and lastMsg().action == 'tablet:close')
    nuiCb['tablet:call']({ name = 'notes:list' }, function(r) got = r end)
    check('tablette fermée : relais refusé', got.err == 'err_session')
    local f = #focus
    nuiCb['__uiclose']()
    check('fermer deux fois : sans effet', #focus == f)

    -- Mort, objet perdu, arrêt
    cmds.pop_tablet_toggle()
    check('réouverture', C.IsOpen())
    gameHandlers[#gameHandlers]('CEventNetworkEntityDamage', { 12 })
    check('dégât sur un autre : reste ouverte', C.IsOpen())
    deadPed = true
    gameHandlers[#gameHandlers]('CEventNetworkEntityDamage', { 77 })
    check('mort du joueur : fermeture + focus rendu', not C.IsOpen() and focus[#focus][1] == false)
    deadPed = false
    cmds.pop_tablet_toggle()
    netEvents['pop_tablet:client:forceClose']({ reason = 'lost' })
    check('forceClose (objet perdu) : fermée', not C.IsOpen())
    cmds.pop_tablet_toggle()
    reset()
    netEvents.onResourceStop('autre')
    check('arrêt d\'une autre ressource : ignoré', C.IsOpen())
    netEvents.onResourceStop('pop_tablet')
    check('arrêt de la ressource : focus rendu, objet supprimé', focus[#focus][1] == false and deleted[1] == 555)
    C.Close('test')

    -- OpenApp
    exportsReg.OpenApp('settings', { a = 1 })
    check('export OpenApp : passe par le serveur', triggered('pop_tablet:app:open') ~= nil)
    serverReply['pop_tablet:device:open'].boot = nil
    netEvents['pop_tablet:client:open']({ app = 'notes' })
    check('push open : ouvre la tablette avec l\'appli demandée', C.IsOpen() and lastMsg().data.app.app == 'notes')
    netEvents['pop_tablet:client:open']({ app = 'clock' })
    check('déjà ouverte : tablet:openApp', lastMsg().action == 'tablet:openApp' and lastMsg().data.app == 'clock')
    check('push notify relayé seulement ouverte', (function()
        netEvents['pop_tablet:client:notify']({ app = 'x' })
        local ok1 = lastMsg().action == 'tablet:notify'
        C.Close('t')
        local n2 = #nuiMsgs
        netEvents['pop_tablet:client:notify']({ app = 'x' })
        return ok1 and #nuiMsgs == n2
    end)())

    -- Scheduler client
    local S = C.Scheduler
    check('Sanitize garde les éléments valides seulement', #S.Sanitize({ { id = 1, kind = 'alarm', minute = 480 }, { id = 2, kind = 'bad', minute = 1 },
        { id = 3, kind = 'alarm', minute = 1440 }, { id = 'x', kind = 'alarm', minute = 5 }, 'x' }) == 1)
    local it, ms = S.Next({ { id = 1, kind = 'alarm', minute = 8 * 60 + 32 }, { id = 2, kind = 'alarm', minute = 9 * 60 } }, 8, 30, 0, 2000)
    check('délai : alarme dans 2 minutes de jeu = 4000 ms', it.id == 1 and ms == 4000, ms)
    ms = select(2, S.Next({ { id = 1, kind = 'alarm', minute = 8 * 60 + 32 } }, 8, 30, 30, 2000))
    check('délai : secondes de jeu déduites (1 min 30 = 3000 ms)', ms == 3000, ms)
    ms = select(2, S.Next({ { id = 1, kind = 'alarm', minute = 8 * 60 + 30 } }, 8, 30, 10, 2000))
    check('minute déjà entamée : reportée au lendemain de jeu', ms == (86400 - 10) * 2000 / 60, ms)
    ms = select(2, S.Next({ { id = 1, kind = 'alarm', minute = 5 } }, 23, 59, 0, 2000))
    check('passage de minuit', ms == 6 * 60 * 2000 / 60 * 1.0, ms)
    check('liste vide : nil', S.Next({}, 1, 1, 1, 2000) == nil)

    clientTimers, serverEvents = {}, {}
    S.Set({ { id = 7, kind = 'alarm', minute = 8 * 60 + 32 } })
    check('une seule minuterie planifiée', #clientTimers == 1 and clientTimers[1].ms == 4000)
    S.Set({ { id = 7, kind = 'alarm', minute = 8 * 60 + 32 }, { id = 8, kind = 'event', minute = 8 * 60 + 31 } })
    check('re-planification : nouvelle minuterie, l\'ancienne est périmée', #clientTimers == 2 and clientTimers[2].ms == 2000)
    clientTimers[1].fn()
    check('minuterie périmée sans effet', #serverEvents == 0 and #clientTimers == 2)
    minute = 31
    clientTimers[2].fn()
    check('à l\'échéance : pop_tablet:server:due(id, kind) puis re-planification',
        serverEvents[1] and serverEvents[1][1] == 'pop_tablet:server:due' and serverEvents[1][2] == 8 and serverEvents[1][3] == 'event'
        and #clientTimers == 3)
    minute = 30
    clientTimers[3].fn()
    check('arrivée trop tôt : pas d\'alerte, nouvelle tentative', #serverEvents == 1 and #clientTimers == 4)
    S.Set({})
    local nt = #clientTimers
    clientTimers[#clientTimers].fn()
    check('liste vidée : plus aucune minuterie', #clientTimers == nt)
end

print(('\n%d réussis, %d échecs'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
