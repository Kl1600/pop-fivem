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
local evHandlers, invoking, exportsApi = {}, 'pop_police', {}
def('AddEventHandler', function(n, fn) evHandlers[n] = fn end)
def('GetInvokingResource', function() return invoking end)
for _, f in ipairs({ 'hash', 'limits', 'db', 'device', 'push', 'scheduler', 'api' }) do
    def('exports', function(n, fn) exportsApi[n] = fn end)
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
section('Système : réglages, widgets, Boutique, API, photos (app-set, app-sto, api, arb)')
------------------------------------------------------------------------
do
    -- Faux supplémentaires : base (réglages, applis, widgets, photos), métier, captures.
    local hasJob, widgetEvents, widgetReminders, photos, setSettingsCalls = {}, {}, {}, 0, 0
    local playerDropped = {}
    Bridge.OnPlayerDropped = function(fn) playerDropped[#playerDropped + 1] = fn end
    Bridge.HasJob = function(src) return hasJob[src] == true end
    local notifiedGame = {}
    Bridge.Notify = function(src, msg) notifiedGame[#notifiedGame + 1] = { src = src, msg = msg } end
    DB.SetSettings = function(serial, t) setSettingsCalls = setSettingsCalls + 1 rows[serial].settings = t end
    DB.SetName = function(serial, n) rows[serial].name = n end
    DB.SetApps = function(serial, a) rows[serial].apps = a end
    DB.WidgetEvents = function() return widgetEvents end
    DB.WidgetReminders = function() return widgetReminders end
    DB.CountPhotos = function() return photos end
    DB.InsertPhoto = function() photos = photos + 1 return photos end
    for _, f in ipairs({ 'settings', 'store', 'photos' }) do dofile('server/apps/' .. f .. '.lua') end
    local Settings, Store, Api = Tablet.Settings, Tablet.Store, Tablet.Api
    local function tick() clock = clock + 5 end

    -- Joueur 20 : tablette configurée, session déverrouillée, date du jeu transmise.
    players[20] = 'char20'
    inv[20] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    tick()
    local o = handlers['pop_tablet:device:open'](20, nil, '2026-06-14 08:30')
    tick()
    local st = handlers['pop_tablet:device:setup'](20, { code = '4321', name = 'Bob Tab', lang = 'fr', mail = 'bob.test' })
    local serial20 = o.serial
    check('setup : applis par défaut = natives disponibles', st.ok and #st.boot.apps == #Store.DefaultApps() and #Store.DefaultApps() == 22, st.err)
    check('boot : widgets et musique fournis', st.boot.widgets ~= nil and st.boot.widgets.events ~= nil and st.boot.widgets.reminders ~= nil and st.boot.music == nil)
    check('boot : informations (modèle, système, créée)', st.boot.model == 'POP Tab' and st.boot.os == '1.0')

    -- app-set : validation des réglages
    local V = function(p) return Settings.Validate(p) end
    local good = { lang = 'ar', dark = true, glass = 70, bright = 40, wall = '3', blur = false, air = false, wifi = true, bt = true,
        rot = true, mirror = false, share = true, focus = true, bold = true, vol = 30, ring = 2, notif = { messages = false, police_mdt = true } }
    check('réglages : patch complet valide accepté', V(good) ~= nil and V(good).glass == 70 and V(good).wall == '3')
    check('réglages : wall auto accepté', V({ wall = 'auto' }).wall == 'auto')
    for name, bad in pairs({
        unknown = { evil = true }, langue = { lang = 'xx' }, type = { dark = 'oui' }, verre = { glass = 101 }, lum = { bright = 14 },
        fond = { wall = '8' }, fond2 = { wall = '-1' }, vol = { vol = -1 }, ring = { ring = 6 }, notif = { notif = { ['A b'] = false } },
        notif2 = { notif = { messages = 'x' } }, flottant = { glass = 50.5 }, nonTable = 'x',
    }) do
        check('réglages : refusé (' .. name .. ')', V(bad) == nil)
    end
    rows[serial20].settings = { lang = 'fr', dark = false }
    Tablet.Device.GetSession(20).settings = { lang = 'fr', dark = false }
    tick()
    local r = handlers['pop_tablet:settings:save'](20, { glass = 80, dark = true })
    check('settings:save : accepté et stocké fusionné', r.ok and rows[serial20].settings.glass == 80 and rows[serial20].settings.dark == true
        and rows[serial20].settings.lang == 'fr')
    local calls = setSettingsCalls
    check('settings:save : clé inconnue refusée, rien écrit', handlers['pop_tablet:settings:save'](20, { evil = 1 }).err == 'err_payload' and setSettingsCalls == calls)
    check('settings:save : charge > 4 Ko refusée', handlers['pop_tablet:settings:save'](20, { notif = (function()
        local t = {} for i = 1, 700 do t['app_' .. i] = true end return t end)() }).err == 'err_too_large')
    check('settings:save sans session refusé', handlers['pop_tablet:settings:save'](3, { dark = true }).err ~= nil)
    tick()
    check('rename : nom vide refusé', handlers['pop_tablet:settings:rename'](20, '  ').err == 'err_name_invalid')
    tick()
    check('rename : trop long refusé', handlers['pop_tablet:settings:rename'](20, string.rep('x', 33)).err == 'err_name_invalid')
    tick()
    r = handlers['pop_tablet:settings:rename'](20, ' Tablette de Bob ')
    check('rename : accepté et rogné', r.ok and rows[serial20].name == 'Tablette de Bob')

    -- widgets (événements et rappels du serveur)
    widgetEvents = { { title = 'Patrouille', start_game = '2026-06-14 15:00', end_game = '2026-06-14 17:00', all_day = 0, color = '#0088ff' },
        { title = 'Fête', start_game = '2026-06-15 00:00', end_game = '2026-06-15 23:59', all_day = 1, color = '' } }
    widgetReminders = { { id = 1, title = 'Plein', done = 0 }, { id = 2, title = 'Rapport', done = 1 } }
    local w = Settings.Widgets(serial20, '2026-06-14 08:30')
    check('widgets : horaire, journée entière, rappels', w.events[1].time == '15:00 – 17:00' and w.events[1].color == '#0088ff'
        and w.events[2].time == '' and w.events[2].color == nil and w.reminders[1].text == 'Plein' and w.reminders[2].done == true)
    check('widgets : sans date du jeu, pas d\'événements', #Settings.Widgets(serial20, nil).events == 0)
    tick()
    local m = handlers['pop_tablet:music:state'](20, { title = 'Radio LS', artist = 'FM', playing = true })
    check('music:state accepté', m.ok)
    check('music:state titre trop long refusé', handlers['pop_tablet:music:state'](20, { title = string.rep('a', 200) }).err == 'err_payload')

    -- arb-01 : Mode Avion et Wi-Fi coupé refusent les services en ligne
    tick()
    check('en ligne : Boutique accessible', handlers['pop_tablet:store:list'](20).ok)
    tick()
    handlers['pop_tablet:settings:save'](20, { air = true })
    tick()
    check('Mode Avion : Boutique refusée (err_offline)', handlers['pop_tablet:store:list'](20).err == 'err_offline')
    check('Mode Avion : Réglages encore possibles', handlers['pop_tablet:settings:save'](20, { air = false, wifi = false }).ok)
    tick()
    check('Wi-Fi coupé : installation refusée', handlers['pop_tablet:store:install'](20, 'notes').err == 'err_offline')
    check('Wi-Fi coupé : garde en ligne refusée, hors ligne acceptée',
        select(2, Tablet.Guard(20, nil, { online = true })) == 'err_offline' and Tablet.Guard(20, nil, {}) ~= nil)
    handlers['pop_tablet:settings:save'](20, { wifi = true })
    tick()

    -- app-sto : retirer et installer
    r = handlers['pop_tablet:store:remove'](20, 'notes')
    check('Boutique : retrait de Notes', r.ok and #r.apps == 21 and rows[serial20].apps ~= nil)
    tick()
    check('Boutique : appli système non retirable', handlers['pop_tablet:store:remove'](20, 'reglages').err == 'err_app_system')
    check('Boutique : appli inconnue refusée', handlers['pop_tablet:store:remove'](20, 'zzzzzz').err == 'err_app_unknown')
    check('Boutique : id invalide refusé', handlers['pop_tablet:store:install'](20, 'A b').err == 'err_payload')
    tick()
    local list = handlers['pop_tablet:store:list'](20)
    local notesEntry
    for _, it in ipairs(list.items) do if it.id == 'notes' then notesEntry = it end end
    check('Boutique : catalogue marque Notes non installée', list.ok and notesEntry and notesEntry.installed == false)
    tick()
    r = handlers['pop_tablet:store:install'](20, 'notes')
    check('Boutique : réinstallation de Notes', r.ok and #r.apps == 22)
    tick()
    local before = #r.apps
    check('Boutique : installer deux fois ne duplique pas', #handlers['pop_tablet:store:install'](20, 'notes').apps == before)
    Config.Apps.dictaphone = 'off'
    check('Config.Apps off : Dictaphone retiré du catalogue', #Store.DefaultApps() == 21)
    Config.Apps.dictaphone = 'on'

    -- api-01 : RegisterApp
    local reg = function(d, res) invoking = res or 'pop_police' return exportsApi.RegisterApp(d) end
    local appDef = { id = 'police_mdt', nameKey = 'mdt_name', texts = { en = { mdt_name = 'Police MDT' }, fr = { mdt_name = 'MDT Police' } },
        page = 'nui://pop_police/web/mdt.html', jobs = { 'police', sheriff = 2 }, color = '#0a84ff', category = 'work',
        onCall = function(src, serial, action, data) if action == 'big' then return { s = string.rep('x', 20000) } end return { echo = data, serial = serial } end }
    check('RegisterApp : valide', reg(appDef) == true)
    check('RegisterApp : doublon d\'une autre ressource refusé', select(2, reg(appDef, 'autre')) == 'id_taken')
    check('RegisterApp : id d\'une appli native refusé', select(2, reg({ id = 'notes', name = 'x', page = 'nui://pop_police/a.html' })) == 'id_taken')
    check('RegisterApp : id invalide refusé', select(2, reg({ id = 'Ab', name = 'x', page = 'nui://pop_police/a.html' })) == 'bad_id')
    check('RegisterApp : page d\'une autre ressource refusée', select(2, reg({ id = 'abc', name = 'x', page = 'nui://autre/a.html' })) == 'bad_page')
    check('RegisterApp : page https hors liste refusée', select(2, reg({ id = 'abc', name = 'x', page = 'https://evil.example/a' })) == 'bad_page')
    Config.Browser.AllowedHosts = { 'ok.example' }
    check('RegisterApp : page https listée acceptée', reg({ id = 'web_app', name = 'Web', page = 'https://ok.example/a' }) == true)
    Config.Browser.AllowedHosts = {}
    check('RegisterApp : nom manquant refusé', select(2, reg({ id = 'abc', page = 'nui://pop_police/a.html' })) == 'bad_name')
    check('RegisterApp : couleur invalide refusée', select(2, reg({ id = 'abc', name = 'x', page = 'nui://pop_police/a.html', color = 'red' })) == 'bad_color')
    check('RegisterApp : jobs invalides refusés', select(2, reg({ id = 'abc', name = 'x', page = 'nui://pop_police/a.html', jobs = { 5 } })) == 'bad_jobs')
    check('RegisterApp : nom résolu dans la langue de la tablette', Api.NameOf(Api.Get('police_mdt'), 'fr') == 'MDT Police'
        and Api.NameOf(Api.Get('police_mdt'), 'de') == 'Police MDT')

    -- api-02 : filtre par métier à l'installation, au catalogue, à l'appel
    tick()
    check('métier refusé à l\'installation', handlers['pop_tablet:store:install'](20, 'police_mdt').err == 'wrong_job')
    tick()
    local visible = false
    for _, it in ipairs(handlers['pop_tablet:store:list'](20).items) do if it.id == 'police_mdt' then visible = true end end
    check('métier refusé : appli absente du catalogue', not visible)
    hasJob[20] = true
    tick()
    r = handlers['pop_tablet:store:install'](20, 'police_mdt')
    check('bon métier : installation', r.ok)
    tick()
    local entryOk
    for _, it in ipairs(handlers['pop_tablet:store:list'](20).items) do if it.id == 'police_mdt' then entryOk = it end end
    check('catalogue : fiche API avec nom traduit et page', entryOk and entryOk.api and entryOk.installed and entryOk.name == 'MDT Police' and entryOk.page == 'nui://pop_police/web/mdt.html')

    -- api-05 : app:call, focus, événements
    tick()
    local c = handlers['pop_tablet:app:call'](20, { appId = 'police_mdt', action = 'search', data = { q = 'x' } })
    check('app:call : routé vers onCall avec le serial', c.ok and c.data.serial == serial20 and c.data.echo.q == 'x', c.err)
    check('app:call : résultat > 16 Ko refusé', handlers['pop_tablet:app:call'](20, { appId = 'police_mdt', action = 'big' }).err == 'err_too_large')
    check('app:call : action invalide refusée', handlers['pop_tablet:app:call'](20, { appId = 'police_mdt', action = 'a b' }).err == 'err_payload')
    check('app:call : appli sans onCall / inconnue refusée', handlers['pop_tablet:app:call'](20, { appId = 'web_app', action = 'x' }).err == 'err_app_unknown')
    check('app:call : charge > 4 Ko refusée', handlers['pop_tablet:app:call'](20, { appId = 'police_mdt', action = 'x', data = { s = string.rep('a', 5000) } }).err == 'err_too_large')
    hasJob[20] = false
    tick()
    check('app:call : métier revérifié à chaque appel', handlers['pop_tablet:app:call'](20, { appId = 'police_mdt', action = 'x' }).err == 'wrong_job')
    hasJob[20] = true
    tick()
    sent = {}
    invoking = 'pop_police'
    check('AppEvent : refusé si l\'appli n\'est pas au premier plan', exportsApi.AppEvent(20, 'police_mdt', 'alert', { a = 1 }) == false)
    check('app:focus : accepté', handlers['pop_tablet:app:focus'](20, 'police_mdt').ok)
    check('AppEvent : poussé à la page ouverte', exportsApi.AppEvent(20, 'police_mdt', 'alert', { a = 1 }) == true and lastPush().name == 'pop_tablet:client:appEvent')
    invoking = 'autre'
    check('AppEvent : refusé pour une autre ressource', exportsApi.AppEvent(20, 'police_mdt', 'alert', {}) == false)
    invoking = 'pop_police'

    -- api-03 : Notify
    tick()
    handlers['pop_tablet:settings:save'](20, { lang = 'fr' })
    sent = {}
    local ok1 = exportsApi.Notify(20, { app = 'police_mdt', titleKey = 'a', bodyKey = 'b', args = { 'Mission Row' },
        texts = { fr = { a = 'Alerte', b = 'Vol à %s' }, en = { a = 'Alert', b = 'Theft at %s' } } })
    check('Notify : texte traduit dans la langue de la tablette', ok1 == true and lastPush().data.title == 'Alerte' and lastPush().data.text == 'Vol à Mission Row'
        and lastPush().src == 20)
    check('Notify par serial', exportsApi.Notify(serial20, { app = 'police_mdt', title = 'T', body = 'B' }) == true)
    check('Notify : serial inconnu refusé', exportsApi.Notify('PT-ZZZZZZZZZZ', { app = 'police_mdt', title = 'T' }) == false)
    check('Notify : titre > 60 car. refusé', exportsApi.Notify(20, { app = 'police_mdt', title = string.rep('t', 61) }) == false)
    check('Notify : corps > 200 car. refusé', exportsApi.Notify(20, { app = 'police_mdt', title = 't', body = string.rep('b', 201) }) == false)
    invoking = 'autre'
    check('Notify : appli d\'une autre ressource refusée', exportsApi.Notify(20, { app = 'police_mdt', title = 't' }) == false)
    invoking = 'pop_police'
    tick()
    local passedN = 0
    for _ = 1, 6 do if exportsApi.Notify(20, { app = 'police_mdt', title = 't', body = 'b' }) then passedN = passedN + 1 end end
    check('Notify : 6 notifications dans la seconde, la 6e rejetée', passedN == 5, passedN)
    tick()
    handlers['pop_tablet:settings:save'](20, { notif = { police_mdt = false } })
    check('Notify : appli désactivée dans Réglages > Notifications', exportsApi.Notify(20, { app = 'police_mdt', title = 't' }) == false)
    handlers['pop_tablet:settings:save'](20, { notif = { police_mdt = true } })
    players[21] = 'char21'
    inv[21] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = { serial = 'PT-ABCDEFGH24' } } }
    tick()
    check('Notify : tablette fermée = notification du jeu', exportsApi.Notify(21, { app = 'police_mdt', title = 'Alerte', body = 'Vol' }) == true
        and notifiedGame[#notifiedGame].msg == 'Alerte : Vol')

    -- api-04 : OpenApp
    sent = {}
    check('OpenApp : appli du bon métier', exportsApi.OpenApp(20, 'police_mdt', { a = 1 }) == true and lastPush().name == 'pop_tablet:client:open')
    hasJob[20] = false
    check('OpenApp : mauvais métier refusé', exportsApi.OpenApp(20, 'police_mdt') == false)
    check('OpenApp : appli inconnue refusée', exportsApi.OpenApp(20, 'inconnue_xx') == false)
    check('OpenApp : native acceptée', exportsApi.OpenApp(20, 'notes') == true)
    check('OpenApp : données > 2 Ko refusées', exportsApi.OpenApp(20, 'notes', { s = string.rep('x', 3000) }) == false)
    check('GetSerial et GetApiVersion', exportsApi.GetSerial(20) == serial20 and exportsApi.GetApiVersion() == 1)

    -- api-01 : arrêt de la ressource
    sent = {}
    evHandlers.onResourceStop('pop_police')
    check('arrêt de la ressource : applis retirées, tablettes prévenues', Api.Get('police_mdt') == nil and lastPush().name == 'pop_tablet:client:apps')
    tick()
    check('applis retirées : absentes du démarrage', (function()
        for _, id in ipairs(Store.Resolve(20, { 'police_mdt', 'notes' })) do if id == 'police_mdt' then return false end end
        return true
    end)())

    -- arb-02 : capture de l'écran vers Photos
    local shots, shotData = 0, 'data:image/webp;base64,AAAA'
    Config.Photos.Max = 3
    def('GetResourceState', function() return 'started' end)
    def('promise', { new = function() local p = { v = nil } function p:resolve(x) if self.v == nil then self.v = x end end return p end })
    def('Citizen', { Await = function(p) return p.v end })
    def('exports', setmetatable({ screencapture = { serverCapture = function(_, _, opts, cb)
        shots = shots + 1
        check('capture : webp réduite (960)', opts.encoding == 'webp' and opts.maxWidth == 960)
        cb(shotData)
    end } }, { __call = function() end }))
    tick()
    r = handlers['pop_tablet:photos:capture'](20)
    check('photos:capture : photo enregistrée', r.ok and photos == 1 and shots == 1, r.err)
    check('photos:capture : 1 prise / 3 s', handlers['pop_tablet:photos:capture'](20).err == 'err_rate' and shots == 1)
    clock = clock + 4
    shotData = 'data:' .. string.rep('x', 160000)
    check('photos:capture : > 150 Ko rejetée', handlers['pop_tablet:photos:capture'](20).err == 'err_too_large' and photos == 1)
    clock = clock + 4
    shotData = 'data:ok'
    photos = 3
    check('photos:capture : plafond Config.Photos.Max', handlers['pop_tablet:photos:capture'](20).err == 'err_photos_full')
    photos = 0
    clock = clock + 4
    handlers['pop_tablet:settings:save'](20, { air = true })
    check('photos:capture : hors ligne autorisée (capture locale)', handlers['pop_tablet:photos:capture'](20).ok)
    handlers['pop_tablet:settings:save'](20, { air = false })
    tick()
    check('photos:capture sans session refusée', handlers['pop_tablet:photos:capture'](3).err ~= nil)
    for _, fn in ipairs(playerDropped) do fn(20) end
end

------------------------------------------------------------------------
section('Médias : Photos, Notes, Fichiers (app-pho, app-not, app-fil)')
------------------------------------------------------------------------
do
    -- Base fictive en mémoire (même contrat que server/db.lua).
    local P, A, PA, NO, NF, FI = {}, {}, {}, {}, {}, {}
    Config.Photos.Max = 200
    Config.Session.IdleLockSeconds = 1000000 -- le temps simulé avance de 5 s par appel
    local seq = 0
    local function nid() seq = seq + 1 return seq end
    local store = {}
    local realJson = json
    def('json', { encode = function(v) local k = 'J' .. nid() store[k] = v return k end, decode = function(k) return store[k] end })
    DB.ListPhotos = function(serial, scope, albumId, offset, limit)
        local out = {}
        for _, p in pairs(P) do
            local inAlbum = scope ~= 'album' or PA[albumId .. ':' .. p.id]
            local live = p.deleted_at == nil
            if p.serial == serial and inAlbum and ((scope == 'trash') ~= live) and (scope ~= 'fav' or p.favorite == 1) then out[#out + 1] = p end
        end
        table.sort(out, function(a, b) return a.id > b.id end)
        local page = {}
        for i = offset + 1, math.min(#out, offset + limit) do page[#page + 1] = out[i] end
        return page
    end
    DB.PhotoCounts = function(serial)
        local c = { total = 0, fav = 0, trash = 0 }
        for _, p in pairs(P) do
            if p.serial == serial then
                if p.deleted_at then c.trash = c.trash + 1 else c.total = c.total + 1 if p.favorite == 1 then c.fav = c.fav + 1 end end
            end
        end
        return c
    end
    DB.GetPhoto = function(serial, id) local p = P[id] return p and p.serial == serial and p or nil end
    DB.PhotoOwned = function(serial, id) return P[id] ~= nil and P[id].serial == serial end
    DB.SetPhotoField = function(serial, id, f, v) if not DB.PhotoOwned(serial, id) then return false end P[id][f] = v return true end
    DB.SetPhotoDeleted = function(serial, id, now) if not DB.PhotoOwned(serial, id) then return false end P[id].deleted_at = now return true end
    DB.DeletePhoto = function(serial, id) if not DB.PhotoOwned(serial, id) then return false end P[id] = nil return true end
    DB.PurgePhotoTrash = function() return 0 end
    DB.ListAlbums = function(serial) local o = {} for _, a in pairs(A) do if a.serial == serial then o[#o + 1] = { id = a.id, name = a.name, n = 0 } end end return o end
    DB.CountAlbums = function(serial) return #DB.ListAlbums(serial) end
    DB.InsertAlbum = function(serial, name) local id = nid() A[id] = { id = id, serial = serial, name = name } return id end
    DB.RenameAlbum = function(serial, id, name) if not A[id] or A[id].serial ~= serial then return false end A[id].name = name return true end
    DB.DeleteAlbum = function(serial, id) if not A[id] or A[id].serial ~= serial then return false end A[id] = nil return true end
    DB.AlbumOwned = function(serial, id) return A[id] ~= nil and A[id].serial == serial end
    DB.AlbumLink = function(a, p, on) PA[a .. ':' .. p] = on or nil end
    DB.PhotoAlbums = function() return {} end
    DB.InsertPhoto = function(serial, data, now, kind) local id = nid() P[id] = { id = id, serial = serial, data = data, kind = kind, rating = 0, favorite = 0, fx = 'none', taken_at = now } return id end
    DB.CountPhotos = function(serial) local n = 0 for _, p in pairs(P) do if p.serial == serial then n = n + 1 end end return n end

    DB.ListNotes = function(serial) local o = {} for _, n in pairs(NO) do if n.serial == serial then o[#o + 1] = { id = n.id, folder_id = n.folder, title = n.title, excerpt = n.excerpt, hint = n.hint, pinned = n.pinned and 1 or 0, deleted_at = n.deleted_at, updated_at = n.updated } end end return o end
    DB.CountNotes = function(serial) return #DB.ListNotes(serial) end
    DB.GetNote = function(serial, id) local n = NO[id] if not n or n.serial ~= serial then return nil end return { id = id, folder_id = n.folder, title = n.title, body = n.body, pinned = n.pinned and 1 or 0, deleted_at = n.deleted_at, updated_at = n.updated } end
    DB.InsertNote = function(serial, n, now) local id = nid() NO[id] = { id = id, serial = serial, folder = n.folder, title = n.title, excerpt = n.excerpt, hint = n.hint, body = n.body, pinned = n.pinned, updated = now } return id end
    DB.UpdateNote = function(serial, id, n, now) local o = NO[id] if not o or o.serial ~= serial then return false end o.folder, o.title, o.excerpt, o.hint, o.body, o.pinned, o.updated = n.folder, n.title, n.excerpt, n.hint, n.body, n.pinned, now return true end
    DB.SetNoteDeleted = function(serial, id, now) local o = NO[id] if not o or o.serial ~= serial then return false end o.deleted_at = now return true end
    DB.DeleteNote = function(serial, id) if not NO[id] or NO[id].serial ~= serial then return false end NO[id] = nil return true end
    DB.PurgeNoteTrash = function() return 0 end
    DB.ListNoteFolders = function(serial) local o = {} for _, f in pairs(NF) do if f.serial == serial then o[#o + 1] = f end end return o end
    DB.NoteFolderOwned = function(serial, id) return NF[id] ~= nil and NF[id].serial == serial end
    DB.InsertNoteFolder = function(serial, name) local id = nid() NF[id] = { id = id, serial = serial, name = name } return id end
    DB.RenameNoteFolder = function(serial, id, name) if not DB.NoteFolderOwned(serial, id) then return false end NF[id].name = name return true end
    DB.DeleteNoteFolder = function(serial, id) if not DB.NoteFolderOwned(serial, id) then return false end NF[id] = nil for _, n in pairs(NO) do if n.folder == id then n.folder = nil end end return true end

    DB.ListFiles = function(serial) local o = {} for _, f in pairs(FI) do if f.serial == serial then o[#o + 1] = f end end return o end
    DB.GetFile = function(serial, id) local f = FI[id] return f and f.serial == serial and f or nil end
    DB.InsertFile = function(serial, f, now) local id = nid() FI[id] = { id = id, serial = serial, parent_id = f.parent, kind = f.kind, name = f.name, body = f.body, ref_id = f.ref, size = f.size, tag = f.tag, fav = f.fav and 1 or 0, updated_at = now } return id end
    DB.UpdateFile = function(_, id, f, now) local o = FI[id] if not o then return false end o.name, o.body, o.size, o.tag, o.fav, o.updated_at = f.name, f.body, f.size, f.tag, f.fav and 1 or 0, now return true end
    DB.MoveFile = function(_, id, parent) FI[id].parent_id = parent return true end
    DB.DeleteFile = function(serial, id)
        if not FI[id] or FI[id].serial ~= serial then return false end
        local function rm(i) for k, f in pairs(FI) do if f.parent_id == i then rm(k) end end FI[i] = nil end
        rm(id)
        return true
    end
    DB.SetShareToken = function(_, id, token) for _, f in pairs(FI) do if token and f.share_token == token then return false end end FI[id].share_token = token return true end
    DB.FileByToken = function(token) for _, f in pairs(FI) do if f.share_token == token then return f end end end
    DB.PhotoData = function(id) return P[id] and P[id].data end
    DB.BoardOwned = function() return false end
    DB.RecordingOwned = function() return false end
    for _, f in ipairs({ 'notes', 'files' }) do dofile('server/apps/' .. f .. '.lua') end

    players[30] = 'char30'
    inv[30] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    local function tk() clock = clock + 5 end
    tk()
    local o = handlers['pop_tablet:device:open'](30, nil, '2026-06-14 08:30')
    tk()
    handlers['pop_tablet:device:setup'](30, { code = '4321', name = 'Cam Tab', lang = 'fr', mail = 'cam.test' })
    local serial = o.serial
    players[31] = 'char31'
    inv[31] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    tk()
    local o2 = handlers['pop_tablet:device:open'](31, nil, '2026-06-14 08:30')
    tk()
    handlers['pop_tablet:device:setup'](31, { code = '4321', name = 'Autre', lang = 'fr', mail = 'autre.test' })
    local serial2 = o2.serial

    -- Photos
    local mine = DB.InsertPhoto(serial, 'data:image/webp;base64,AAAA', clock, 'photo')
    local theirs = DB.InsertPhoto(serial2, 'data:image/webp;base64,BBBB', clock, 'photo')
    for _ = 1, 31 do DB.InsertPhoto(serial, 'data:image/webp;base64,AAAA', clock, 'square') end
    tk()
    local r = handlers['pop_tablet:photos:list'](30, { scope = 'all' })
    check('photos:list : 30 par page, compteurs et albums sur la première page', r.ok and #r.items == 30 and r.more and r.counts.total == 32 and r.albums ~= nil, r.err)
    r = handlers['pop_tablet:photos:list'](30, { scope = 'all', offset = 30 })
    check('photos:list : page 2 = le reste, sans compteurs', #r.items == 2 and not r.more and r.counts == nil)
    check('photos:list : portée ou décalage invalides refusés', handlers['pop_tablet:photos:list'](30, { scope = 'x' }).err == 'err_payload'
        and handlers['pop_tablet:photos:list'](30, { offset = -1 }).err == 'err_payload')
    check('photos:get : la photo d\'une autre tablette est introuvable', handlers['pop_tablet:photos:get'](30, theirs).err == 'err_not_found'
        and handlers['pop_tablet:photos:get'](30, mine).photo.data == 'data:image/webp;base64,AAAA')
    tk()
    r = handlers['pop_tablet:photos:favorite'](30, mine)
    check('favori : bascule', r.ok and r.fav == true and handlers['pop_tablet:photos:list'](30, { scope = 'fav' }).counts.fav == 1)
    check('favori : photo d\'autrui refusée', handlers['pop_tablet:photos:favorite'](30, theirs).err == 'err_not_found' and P[theirs].favorite == 0)
    tk()
    check('étoiles : 0 à 5, 6 refusé', handlers['pop_tablet:photos:rate'](30, { id = mine, rating = 4 }).ok and P[mine].rating == 4
        and handlers['pop_tablet:photos:rate'](30, { id = mine, rating = 6 }).err == 'err_payload')
    check('filtre : liste blanche', handlers['pop_tablet:photos:filter'](30, { id = mine, fx = 'sepia' }).ok and handlers['pop_tablet:photos:filter'](30, { id = mine, fx = 'evil' }).err == 'err_payload')
    tk()
    check('vignette : data URI image acceptée, texte quelconque et > 24 Ko refusés', handlers['pop_tablet:photos:thumb'](30, { id = mine, data = 'data:image/webp;base64,QUJD' }).ok
        and handlers['pop_tablet:photos:thumb'](30, { id = mine, data = '<script>' }).err == 'err_payload'
        and handlers['pop_tablet:photos:thumb'](30, { id = mine, data = 'data:image/webp;base64,' .. string.rep('A', 25000) }).err ~= nil)
    tk()
    r = handlers['pop_tablet:photos:albumSave'](30, { name = 'Garage' })
    local album = r.id
    check('album : création', r.ok and album ~= nil)
    tk()
    check('album : photo et album d\'autrui refusés', handlers['pop_tablet:photos:albumLink'](30, { albumId = album, photoId = theirs, on = true }).err == 'err_not_found'
        and handlers['pop_tablet:photos:albumLink'](31, { albumId = album, photoId = theirs, on = true }).err == 'err_not_found'
        and handlers['pop_tablet:photos:albumLink'](30, { albumId = album, photoId = mine, on = true }).ok)
    tk()
    check('album : liste de ses photos', #handlers['pop_tablet:photos:list'](30, { scope = 'album', albumId = album }).items == 1)
    for i = 1, 25 do tk() handlers['pop_tablet:photos:albumSave'](30, { name = 'A' .. i }) end
    tk()
    check('albums : plafond 20', handlers['pop_tablet:photos:albumSave'](30, { name = 'Trop' }).err == 'err_limit')
    -- Suppression : corbeille puis définitive ; fond d'écran remis en automatique
    tk()
    handlers['pop_tablet:settings:save'](30, { wall = 'photo:' .. theirs })
    check('fond depuis la photo d\'autrui refusé', rows[serial].settings == nil or rows[serial].settings.wall ~= 'photo:' .. theirs)
    tk()
    check('fond depuis sa photo accepté', handlers['pop_tablet:settings:save'](30, { wall = 'photo:' .. mine }).ok and rows[serial].settings.wall == 'photo:' .. mine)
    tk()
    r = handlers['pop_tablet:photos:delete'](30, mine)
    check('suppression : corbeille d\'abord', r.ok and r.permanent == false and handlers['pop_tablet:photos:list'](30, { scope = 'trash' }).counts.trash == 1)
    tk()
    check('restauration', handlers['pop_tablet:photos:restore'](30, mine).ok and P[mine].deleted_at == nil)
    tk()
    handlers['pop_tablet:photos:delete'](30, mine)
    tk()
    r = handlers['pop_tablet:photos:delete'](30, mine)
    check('suppression définitive + fond d\'écran remis en automatique', r.permanent and r.wallReset and rows[serial].settings.wall == 'auto' and P[mine] == nil)
    check('photo d\'autrui non supprimable', handlers['pop_tablet:photos:delete'](30, theirs).err == 'err_not_found' and P[theirs] ~= nil)
    tk()
    check('capture : format invalide refusé', handlers['pop_tablet:photos:capture'](30, { kind = 'video' }).err == 'err_payload')
    tk()
    r = handlers['pop_tablet:photos:capture'](30, { kind = 'pano' })
    check('capture : format panorama enregistré', r.ok and P[r.id].kind == 'pano', r.err)

    -- Notes
    local note = handlers['pop_tablet:notes:save'](30, { title = 'Plaque', blocks = {
        { type = 'text', value = 'Fourgon blanc\nplaque 42' }, { type = 'todo', items = { { t = 'Appeler', done = false } } },
        { type = 'table', rows = { { 'a', 'b' }, { 'c', 'd' } } } } })
    check('notes:save : création avec extrait', note.ok and note.excerpt == 'Fourgon blanc plaque 42' and note.hint == 'text', note.err)
    tk()
    local good = { { type = 'text', value = 'x' } }
    local bads = {
        type = { { type = 'script', value = 'x' } }, texte = { { type = 'text', value = 5 } }, ctrl = { { type = 'text', value = 'a\0b' } },
        coches = { { type = 'todo', items = { { t = 'a', done = 'oui' } } } }, tableau = { { type = 'table', rows = { { 'a', 'b' }, { 'c' } } } },
        large = { { type = 'table', rows = { { '1', '2', '3', '4', '5', '6', '7' } } } }, photoAutrui = { { type = 'photo', id = theirs } },
        trop = (function() local t = {} for i = 1, 41 do t[i] = good[1] end return t end)(),
    }
    for name, b in pairs(bads) do
        tk()
        check('notes:save : refusé (' .. name .. ')', handlers['pop_tablet:notes:save'](30, { title = 't', blocks = b }).ok == false)
    end
    tk()
    check('notes:save : titre 81 caractères refusé', handlers['pop_tablet:notes:save'](30, { title = string.rep('a', 81), blocks = good }).err == 'err_too_large')
    tk()
    check('notes:save : corps > 10 000 refusé', handlers['pop_tablet:notes:save'](30, { title = 't', blocks = { { type = 'text', value = string.rep('a', 10000) }, { type = 'text', value = string.rep('a', 100) } } }).err ~= nil)
    tk()
    local shot = DB.InsertPhoto(serial, 'data:image/webp;base64,AAAA', clock, 'photo')
    check('notes:save : photo à soi acceptée', handlers['pop_tablet:notes:save'](30, { title = 'p', blocks = { { type = 'photo', id = shot } } }).hint == 'photo')
    tk()
    local got = handlers['pop_tablet:notes:get'](30, note.id)
    check('notes:get : blocs relus', got.ok and #got.note.blocks == 3 and got.note.title == 'Plaque')
    check('notes:get : note d\'autrui introuvable', handlers['pop_tablet:notes:get'](31, note.id).err == 'err_not_found')
    tk()
    check('notes:save : épinglée + modification', handlers['pop_tablet:notes:save'](30, { id = note.id, title = 'Plaque 2', blocks = good, pinned = true }).ok and NO[note.id].pinned == true)
    check('notes:save : modifier la note d\'autrui refusé', handlers['pop_tablet:notes:save'](31, { id = note.id, title = 'x', blocks = good }).err == 'err_not_found' and NO[note.id].title == 'Plaque 2')
    tk()
    local f = handlers['pop_tablet:notes:folderSave'](30, { name = 'Travail' })
    tk()
    check('dossier de notes créé, note rangée dedans', f.ok and handlers['pop_tablet:notes:save'](30, { id = note.id, title = 'x', blocks = good, folder = f.id }).ok and NO[note.id].folder == f.id)
    tk()
    check('note dans le dossier d\'autrui refusée', handlers['pop_tablet:notes:save'](31, { title = 'x', blocks = good, folder = f.id }).err == 'err_not_found')
    tk()
    handlers['pop_tablet:notes:folderDelete'](30, f.id)
    check('dossier supprimé : la note revient au dossier par défaut', NO[note.id].folder == nil)
    tk()
    check('notes : corbeille puis restauration', handlers['pop_tablet:notes:delete'](30, note.id).permanent == false and NO[note.id].deleted_at ~= nil
        and handlers['pop_tablet:notes:restore'](30, note.id).ok and NO[note.id].deleted_at == nil)
    tk()
    handlers['pop_tablet:notes:delete'](30, note.id)
    tk()
    check('notes : deuxième suppression = définitive', handlers['pop_tablet:notes:delete'](30, note.id).permanent == true and NO[note.id] == nil)
    for _ = 1, 200 do DB.InsertNote(serial, { title = 't', excerpt = '', hint = '', body = 'J0', pinned = false }, clock) end
    tk()
    check('notes : la 201e est refusée', handlers['pop_tablet:notes:save'](30, { title = 't', blocks = good }).err == 'err_limit')

    -- Fichiers
    tk()
    local d1 = handlers['pop_tablet:files:save'](30, { kind = 'folder', name = 'Rapports' })
    check('files : dossier créé', d1.ok)
    tk()
    local doc = handlers['pop_tablet:files:save'](30, { kind = 'doc', name = 'Note.txt', body = 'Bonjour', parentId = d1.id })
    check('files : document dans le dossier', doc.ok and FI[doc.id].size == 7)
    tk()
    check('files : parent d\'autrui refusé', handlers['pop_tablet:files:save'](31, { kind = 'doc', name = 'x', parentId = d1.id }).err == 'err_not_found')
    check('files : document trop long refusé', handlers['pop_tablet:files:save'](30, { kind = 'doc', name = 'x', body = string.rep('a', 20001) }).err ~= nil)
    tk()
    check('files : tag inconnu refusé', handlers['pop_tablet:files:save'](30, { kind = 'doc', name = 'x', tag = 'pink' }).err == 'err_payload')
    tk()
    check('files : raccourci photo : la photo doit être à soi', handlers['pop_tablet:files:save'](30, { kind = 'photo', name = 'p', refId = theirs }).err == 'err_not_found')
    tk()
    check('files : raccourci photo à soi accepté', handlers['pop_tablet:files:save'](30, { kind = 'photo', name = 'p', refId = shot }).ok)
    tk()
    check('files:get : corps relu, autrui refusé', handlers['pop_tablet:files:get'](30, doc.id).file.body == 'Bonjour' and handlers['pop_tablet:files:get'](31, doc.id).err == 'err_not_found')
    tk()
    check('files : modification (tag, favori)', handlers['pop_tablet:files:save'](30, { id = doc.id, name = 'Note.txt', body = 'Salut', tag = 'red', fav = true }).ok
        and FI[doc.id].tag == 'red' and FI[doc.id].fav == 1 and FI[doc.id].size == 5)
    local parent, depthErr = nil, nil
    for i = 1, 7 do
        tk()
        local res = handlers['pop_tablet:files:save'](30, { kind = 'folder', name = 'n' .. i, parentId = parent })
        if res.ok then parent = res.id else depthErr = res.err end
    end
    check('files : profondeur <= 6 (le 7e niveau est refusé)', depthErr == 'err_depth', depthErr)
    tk()
    check('files:move : dans soi-même ou un descendant refusé', handlers['pop_tablet:files:move'](30, { id = d1.id, parentId = d1.id }).err == 'err_depth')
    tk()
    check('files:move : un document vers un autre dossier', handlers['pop_tablet:files:move'](30, { id = doc.id, parentId = parent }).ok and FI[doc.id].parent_id == parent)
    tk()
    check('files:move : vers la racine', handlers['pop_tablet:files:move'](30, { id = doc.id }).ok and FI[doc.id].parent_id == nil)
    tk()
    local sh = handlers['pop_tablet:files:share'](30, doc.id)
    check('files:share : jeton de 12 caractères', sh.ok and #sh.token == 12 and sh.token:match('^[A-Z2-9]+$') ~= nil)
    tk()
    check('files:share : un dossier ne se partage pas', handlers['pop_tablet:files:share'](30, d1.id).err == 'err_not_found')
    tk()
    local op = handlers['pop_tablet:files:open'](31, sh.token)
    check('files:open : un autre joueur lit le document partagé', op.ok and op.file.body == 'Salut' and op.file.name == 'Note.txt')
    tk()
    check('files:open : jeton invalide refusé', handlers['pop_tablet:files:open'](31, 'AAAAAAAAAAAA').err == 'err_token' and handlers['pop_tablet:files:open'](31, 'abc').err == 'err_token')
    tk()
    handlers['pop_tablet:files:unshare'](30, doc.id)
    tk()
    check('files:unshare : le jeton ne marche plus', handlers['pop_tablet:files:open'](31, sh.token).err == 'err_token')
    tk()
    check('files:delete : un dossier emporte son contenu', handlers['pop_tablet:files:delete'](30, d1.id).ok and FI[d1.id] == nil)
    check('files:delete : fichier d\'autrui refusé', handlers['pop_tablet:files:delete'](31, doc.id).err == 'err_not_found' and FI[doc.id] ~= nil)
    def('json', realJson)
end

------------------------------------------------------------------------
section('Productivité : Calendrier, Rappels, Horloge (app-cal, app-rem, app-hor)')
------------------------------------------------------------------------
do
    -- Base fictive en mémoire (même contrat que server/db.lua).
    local EV, RL, RM, AL = {}, {}, {}, {}
    local seq = 0
    local function nid() seq = seq + 1 return seq end
    local function count(t, serial, f) local n = 0 for _, v in pairs(t) do if v.serial == serial and (not f or f(v)) then n = n + 1 end end return n end
    DB.ListEvents = function(serial, from, to)
        local o = {}
        for _, e in pairs(EV) do if e.serial == serial and e.start_game <= to and e.end_game >= from then o[#o + 1] = e end end
        table.sort(o, function(a, b) return a.start_game < b.start_game end)
        return o
    end
    DB.CountEvents = function(serial) return count(EV, serial) end
    DB.GetEvent = function(serial, id) local e = EV[id] return e and e.serial == serial and e or nil end
    DB.InsertEvent = function(serial, e) local id = nid() EV[id] = { id = id, serial = serial, title = e.title, place = e.place, notes = e.notes, start_game = e.start, end_game = e.stop, all_day = e.allDay and 1 or 0, alert_min = e.alert, color = e.color, notified = 0 } return id end
    DB.UpdateEvent = function(serial, id, e) local o = DB.GetEvent(serial, id) if not o then return false end o.title, o.start_game, o.end_game, o.alert_min, o.notified = e.title, e.start, e.stop, e.alert, 0 return true end
    DB.DeleteEvent = function(serial, id) if not DB.GetEvent(serial, id) then return false end EV[id] = nil return true end
    DB.SetEventNotified = function(serial, id) EV[id].notified = 1 end
    DB.PendingEventAlerts = function(serial) local o = {} for _, e in pairs(EV) do if e.serial == serial and e.alert_min and e.notified == 0 then o[#o + 1] = e end end return o end
    DB.ListReminderLists = function(serial) local o = {} for _, l in pairs(RL) do if l.serial == serial then o[#o + 1] = l end end return o end
    DB.CountReminderLists = function(serial) return count(RL, serial) end
    DB.ReminderListOwned = function(serial, id) return RL[id] ~= nil and RL[id].serial == serial end
    DB.InsertReminderList = function(serial, name, color) local id = nid() RL[id] = { id = id, serial = serial, name = name, color = color } return id end
    DB.UpdateReminderList = function(serial, id, name, color) if not DB.ReminderListOwned(serial, id) then return false end RL[id].name, RL[id].color = name, color return true end
    DB.DeleteReminderList = function(serial, id)
        if not DB.ReminderListOwned(serial, id) then return false end
        RL[id] = nil
        for k, r in pairs(RM) do if r.list_id == id then RM[k] = nil end end
        return true
    end
    DB.ListReminders = function(serial) local o = {} for _, r in pairs(RM) do if r.serial == serial then o[#o + 1] = r end end return o end
    DB.CountReminders = function(serial) return count(RM, serial) end
    DB.GetReminder = function(serial, id) local r = RM[id] return r and r.serial == serial and r or nil end
    DB.InsertReminder = function(serial, r) local id = nid() RM[id] = { id = id, serial = serial, list_id = r.list, title = r.title, done = 0, due_game = r.due, flag = r.flag and 1 or 0 } return id end
    DB.UpdateReminder = function(serial, id, r) local o = DB.GetReminder(serial, id) if not o then return false end o.list_id, o.title, o.due_game = r.list, r.title, r.due return true end
    DB.SetReminderDone = function(serial, id, done) local o = DB.GetReminder(serial, id) if not o then return false end o.done = done and 1 or 0 return true end
    DB.DeleteReminder = function(serial, id) if not DB.GetReminder(serial, id) then return false end RM[id] = nil return true end
    DB.ListAlarms = function(serial) local o = {} for _, a in pairs(AL) do if a.serial == serial then o[#o + 1] = a end end return o end
    DB.CountAlarms = function(serial, kind) return count(AL, serial, function(a) return a.kind == kind end) end
    DB.GetAlarm = function(serial, id) local a = AL[id] return a and a.serial == serial and a or nil end
    DB.InsertAlarm = function(serial, a) local id = nid() AL[id] = { id = id, serial = serial, kind = a.kind, label = a.label, game_minute = a.minute, repeat_mask = a.mask or 0, ends_at = a.ends, enabled = a.enabled and 1 or 0, sound = a.sound or '' } return id end
    DB.UpdateAlarm = function(serial, id, a) local o = DB.GetAlarm(serial, id) if not o or o.kind ~= 'alarm' then return false end o.label, o.game_minute, o.repeat_mask, o.enabled = a.label, a.minute, a.mask, a.enabled and 1 or 0 return true end
    DB.SetAlarmEnabled = function(serial, id, on) AL[id].enabled = on and 1 or 0 end
    DB.DeleteAlarm = function(serial, id) if not DB.GetAlarm(serial, id) then return false end AL[id] = nil return true end
    DB.ListTimers = function() local o = {} for _, a in pairs(AL) do if a.kind == 'timer' then o[#o + 1] = a end end return o end
    Config.Session.IdleLockSeconds = 1000000
    for _, f in ipairs({ 'calendar', 'clock', 'reminders' }) do dofile('server/apps/' .. f .. '.lua') end
    local realBridgeNotify = Bridge.Notify
    local gameNotes = {}
    Bridge.Notify = function(src, msg) gameNotes[#gameNotes + 1] = { src = src, msg = msg } end

    local function tk() clock = clock + 5 end
    players[40], players[41] = 'char40', 'char41'
    inv[40] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    inv[41] = { { name = 'pop_tablet', count = 1, slot = 1, metadata = {} } }
    tk()
    local o = handlers['pop_tablet:device:open'](40, nil, '2026-11-22 08:00')
    tk()
    handlers['pop_tablet:device:setup'](40, { code = '4321', name = 'Prod', lang = 'fr', mail = 'prod.test' })
    tk()
    local o2 = handlers['pop_tablet:device:open'](41, nil, '2026-11-22 08:00')
    tk()
    handlers['pop_tablet:device:setup'](41, { code = '4321', name = 'Autre', lang = 'fr', mail = 'prod2.test' })
    local serial, serial2 = o.serial, o2.serial
    local H = handlers
    local Dates = Tablet.Dates

    -- Dates du jeu
    check('dates : 22/11/2026 est un dimanche, 23/11 un lundi', Dates.Weekday('2026-11-22 10:00') == 6 and Dates.Weekday('2026-11-23 10:00') == 0)
    check('dates : 1970-01-01 00:00 = minute 0, un jour = 1440', Dates.Minutes('1970-01-01 00:00') == 0 and Dates.Minutes('1970-01-02 00:00') == 1440)
    check('dates : 30 février, mois 13, heure 24 refusés', Dates.Minutes('2026-02-30 10:00') == nil and Dates.Minutes('2026-13-01 10:00') == nil and Dates.Minutes('2026-01-01 24:00') == nil)
    check('dates : 29 février d\'une année bissextile accepté', Dates.Minutes('2028-02-29 10:00') ~= nil and Dates.Minutes('2027-02-29 10:00') == nil)
    check('dates : texte libre refusé', Dates.Minutes('demain 10h') == nil and Dates.Minutes(42) == nil)

    -- Calendrier
    tk()
    local ev = H['pop_tablet:calendar:save'](40, { title = 'Patrouille', place = 'Centre', start = '2026-11-22 15:00', stop = '2026-11-22 17:00', alert = 15, color = '#0088ff' })
    check('calendar:save : création', ev.ok and ev.id, ev.err)
    tk()
    local ev2 = H['pop_tablet:calendar:save'](40, { title = 'Toute la journée', start = '2026-11-25 00:00', stop = '2026-11-25 23:59', allDay = true, alert = 0 })
    for name, bad in pairs({
        titre_vide = { title = '', start = '2026-11-22 15:00', stop = '2026-11-22 16:00' },
        fin_avant_debut = { title = 'x', start = '2026-11-22 16:00', stop = '2026-11-22 15:00' },
        date_invalide = { title = 'x', start = '2026-11-31 16:00', stop = '2026-12-01 15:00' },
        alerte_inconnue = { title = 'x', start = '2026-11-22 15:00', stop = '2026-11-22 16:00', alert = 7 },
        couleur = { title = 'x', start = '2026-11-22 15:00', stop = '2026-11-22 16:00', color = 'red' },
        notes_trop_longues = { title = 'x', start = '2026-11-22 15:00', stop = '2026-11-22 16:00', notes = string.rep('a', 501) },
    }) do tk() check('calendar:save : refusé (' .. name .. ')', H['pop_tablet:calendar:save'](40, bad).ok == false) end
    tk()
    local r = H['pop_tablet:calendar:list'](40, { from = '2026-11-01', to = '2026-11-30' })
    check('calendar:list : les deux événements, alertes en attente', r.ok and #r.events == 2 and r.events[1].title == 'Patrouille' and #r.alerts == 2, r.err)
    tk()
    r = H['pop_tablet:calendar:list'](40, { from = '2026-12-01', to = '2026-12-31' })
    check('calendar:list : plage sans événement', r.ok and #r.events == 0)
    tk()
    check('calendar:list : plage > 90 jours ou dates invalides refusées', H['pop_tablet:calendar:list'](40, { from = '2026-01-01', to = '2026-12-31' }).err == 'err_payload'
        and H['pop_tablet:calendar:list'](40, { from = 'x', to = 'y' }).err == 'err_payload')
    tk()
    check('calendar:list : l\'autre tablette ne voit rien', #H['pop_tablet:calendar:list'](41, { from = '2026-11-01', to = '2026-11-30' }).events == 0)
    tk()
    check('calendar:save : modifier l\'événement d\'autrui refusé', H['pop_tablet:calendar:save'](41, { id = ev.id, title = 'x', start = '2026-11-22 15:00', stop = '2026-11-22 16:00' }).err == 'err_not_found')
    tk()
    check('calendar:delete : événement d\'autrui refusé', H['pop_tablet:calendar:delete'](41, ev.id).err == 'err_not_found')
    local limit = Tablet.Productivity.events
    Tablet.Productivity.events = 2
    tk()
    check('calendar:save : plafond d\'événements', H['pop_tablet:calendar:save'](40, { title = 'x', start = '2026-11-22 15:00', stop = '2026-11-22 16:00' }).err == 'err_limit')
    Tablet.Productivity.events = limit

    -- Alerte : l'événement de 15:00 avec alerte 15 min sonne à 14:45 (le client signale l'échéance avec la date du jeu)
    local due = Tablet.DueHandlers
    local function fire(src, serialId, id, kind, stamp) for _, h in ipairs(due) do h(src, serialId, id, kind, stamp) end end
    sent = {}
    gameNotes = {}
    fire(40, serial, ev.id, 'event', '2026-11-22 14:30')
    check('alerte : trop tôt, rien', #sent == 0 and #gameNotes == 0 and EV[ev.id].notified == 0)
    fire(40, serial, ev.id, 'event', '2026-11-23 14:45')
    check('alerte : mauvais jour (même heure, autre date), rien', #gameNotes == 0 and EV[ev.id].notified == 0)
    fire(41, serial2, ev.id, 'event', '2026-11-22 14:45')
    check('alerte : événement d\'autrui, rien', #gameNotes == 0 and EV[ev.id].notified == 0)
    fire(40, serial, ev.id, 'event', 'pas une date')
    check('alerte : date illisible, rien', #gameNotes == 0 and EV[ev.id].notified == 0)
    fire(40, serial, ev.id, 'event', '2026-11-22 14:45')
    local pushed = false
    for _, p in ipairs(sent) do if p.name == 'pop_tablet:client:notify' and p.data.title == 'Patrouille' then pushed = true end end
    check('alerte : à l\'heure, notification dans la tablette ouverte, marquée notifiée', pushed and EV[ev.id].notified == 1)
    sent = {}
    fire(40, serial, ev.id, 'event', '2026-11-22 14:45')
    check('alerte : une seule fois', #sent == 0 and #gameNotes == 0)
    tk()
    H['pop_tablet:device:close'](40)
    fire(40, serial, ev2.id, 'event', '2026-11-25 00:00')
    check('alerte : tablette fermée, notification du jeu', #gameNotes == 1 and gameNotes[1].src == 40 and gameNotes[1].msg:find('Toute la journée', 1, true) ~= nil and (gameNotes[1].msg:find('Maintenant', 1, true) or gameNotes[1].msg:find('Now', 1, true)) ~= nil, gameNotes[1] and gameNotes[1].msg)
    tk()
    check('calendar:delete : suppression', H['pop_tablet:calendar:delete'](40, ev.id).ok and EV[ev.id] == nil)

    -- Rappels
    tk()
    local list = H['pop_tablet:reminders:listSave'](40, { name = 'Travail', color = '#ff8d28' })
    check('reminders:listSave : création de liste', list.ok and list.name == 'Travail', list.err)
    tk()
    check('reminders:listSave : nom vide ou couleur invalide refusés', H['pop_tablet:reminders:listSave'](40, { name = '  ' }).ok == false
        and H['pop_tablet:reminders:listSave'](40, { name = 'x', color = 'rouge' }).ok == false)
    tk()
    local rem = H['pop_tablet:reminders:save'](40, { list = list.id, title = 'Appeler le central', due = '2026-11-22 18:30', flag = true })
    check('reminders:save : création avec échéance et drapeau', rem.ok and RM[rem.id].flag == 1 and RM[rem.id].due_game == '2026-11-22 18:30', rem.err)
    tk()
    check('reminders:save : liste d\'autrui refusée', H['pop_tablet:reminders:save'](41, { list = list.id, title = 'x' }).err == 'err_not_found')
    tk()
    check('reminders:save : échéance invalide et titre trop long refusés', H['pop_tablet:reminders:save'](40, { list = list.id, title = 'x', due = '2026-02-30 10:00' }).err == 'err_payload'
        and H['pop_tablet:reminders:save'](40, { list = list.id, title = string.rep('a', 121) }).err == 'err_too_large')
    tk()
    local rl = H['pop_tablet:reminders:list'](40)
    check('reminders:list : listes et rappels', rl.ok and #rl.lists == 1 and #rl.items == 1 and rl.items[1].done == false and rl.items[1].flag == true, rl.err)
    tk()
    check('reminders:toggle : cocher', H['pop_tablet:reminders:toggle'](40, { id = rem.id, done = true }).ok and RM[rem.id].done == 1)
    tk()
    check('reminders:toggle : rappel d\'autrui ou valeur non booléenne refusés', H['pop_tablet:reminders:toggle'](41, { id = rem.id, done = false }).err == 'err_not_found'
        and H['pop_tablet:reminders:toggle'](40, { id = rem.id, done = 'oui' }).err == 'err_payload')
    gameNotes = {}
    fire(40, serial, rem.id, 'reminder', '2026-11-22 18:30')
    check('rappel coché : aucune alerte', #gameNotes == 0)
    tk()
    H['pop_tablet:reminders:toggle'](40, { id = rem.id, done = false })
    fire(40, serial, rem.id, 'reminder', '2026-11-22 18:00')
    check('rappel : trop tôt, rien', #gameNotes == 0)
    fire(40, serial, rem.id, 'reminder', '2026-11-22 18:30')
    check('rappel : à l\'échéance, notification du jeu (tablette fermée)', #gameNotes == 1 and gameNotes[1].msg:find('Appeler le central', 1, true) ~= nil)
    local rlimit = Tablet.Productivity.reminders
    Tablet.Productivity.reminders = 1
    tk()
    check('reminders:save : plafond de rappels', H['pop_tablet:reminders:save'](40, { list = list.id, title = 'y' }).err == 'err_limit')
    Tablet.Productivity.reminders = rlimit
    tk()
    check('reminders:listSave : supprimer la liste emporte ses rappels', H['pop_tablet:reminders:listSave'](40, { id = list.id, delete = true }).ok and RM[rem.id] == nil)

    -- Horloge : alarmes
    tk()
    H['pop_tablet:device:open'](40, nil, '2026-11-22 08:00')
    tk()
    check('clock:saveAlarm : minute hors bornes, masque invalide, libellé trop long refusés',
        H['pop_tablet:clock:saveAlarm'](40, { minute = 1440 }).err == 'err_payload' and H['pop_tablet:clock:saveAlarm'](40, { minute = 60, mask = 128 }).err == 'err_payload'
        and H['pop_tablet:clock:saveAlarm'](40, { minute = 60, label = string.rep('a', 41) }).err == 'err_too_large')
    tk()
    local al = H['pop_tablet:clock:saveAlarm'](40, { label = 'Réveil', minute = 420, mask = 0 })
    check('clock:saveAlarm : création', al.ok and AL[al.id].game_minute == 420 and AL[al.id].enabled == 1, al.err)
    tk()
    local week = H['pop_tablet:clock:saveAlarm'](40, { label = 'Semaine', minute = 420, mask = 31 }) -- lundi à vendredi
    gameNotes = {}
    H['pop_tablet:device:close'](40)
    fire(40, serial, week.id, 'alarm', '2026-11-22 07:00') -- dimanche
    check('alarme à répétition : pas le dimanche', #gameNotes == 0)
    fire(40, serial, week.id, 'alarm', '2026-11-23 07:00') -- lundi
    check('alarme à répétition : sonne le lundi, tablette fermée, reste active', #gameNotes == 1 and gameNotes[1].msg:find('Semaine', 1, true) ~= nil and AL[week.id].enabled == 1)
    gameNotes = {}
    fire(40, serial, al.id, 'alarm', '2026-11-22 06:00')
    check('alarme : pas avant l\'heure', #gameNotes == 0)
    fire(41, serial2, al.id, 'alarm', '2026-11-22 07:00')
    check('alarme d\'autrui : rien', #gameNotes == 0)
    fire(40, serial, al.id, 'alarm', '2026-11-22 07:01')
    check('alarme unique : sonne et s\'éteint', #gameNotes == 1 and AL[al.id].enabled == 0)
    fire(40, serial, al.id, 'alarm', '2026-11-22 07:01')
    check('alarme éteinte : ne sonne plus', #gameNotes == 1)
    tk()
    H['pop_tablet:device:open'](40, nil, '2026-11-22 08:00')
    tk()
    local cl = H['pop_tablet:clock:list'](40)
    check('clock:list : alarmes sans minuteurs', cl.ok and #cl.alarms == 2 and #cl.timers == 0, cl.err)
    tk()
    local alimit = Tablet.Productivity.alarms
    Tablet.Productivity.alarms = 2
    check('clock:saveAlarm : plafond d\'alarmes', H['pop_tablet:clock:saveAlarm'](40, { minute = 10 }).err == 'err_limit')
    Tablet.Productivity.alarms = alimit
    tk()
    check('clock:deleteAlarm : alarme d\'autrui refusée, la sienne supprimée', H['pop_tablet:clock:deleteAlarm'](41, al.id).err == 'err_not_found'
        and H['pop_tablet:clock:deleteAlarm'](40, al.id).ok and AL[al.id] == nil)

    -- Horloge : minuteurs (une seule échéance serveur, aucune boucle)
    Tablet.Scheduler.SetClock(function() return clock end)
    local before = Tablet.Scheduler.Count()
    tk()
    check('clock:startTimer : durée nulle, trop longue ou non entière refusée', H['pop_tablet:clock:startTimer'](40, { seconds = 0 }).err == 'err_payload'
        and H['pop_tablet:clock:startTimer'](40, { seconds = 86401 }).err == 'err_payload' and H['pop_tablet:clock:startTimer'](40, { seconds = 1.5 }).err == 'err_payload')
    tk()
    local tm = H['pop_tablet:clock:startTimer'](40, { seconds = 90, label = 'Pâtes' })
    check('clock:startTimer : échéance serveur armée', tm.ok and tm.remaining == 90 and Tablet.Scheduler.Count() == before + 1 and AL[tm.id].ends_at == clock + 90, tm.err)
    tk()
    cl = H['pop_tablet:clock:list'](40)
    check('clock:list : le minuteur avec son reste en secondes', #cl.timers == 1 and cl.timers[1].remaining == 85, cl.timers[1] and cl.timers[1].remaining)
    local ids = { tm.id }
    for _ = 1, 4 do tk() local t = H['pop_tablet:clock:startTimer'](40, { seconds = 600 }) ids[#ids + 1] = t.id end
    tk()
    check('clock:startTimer : plafond de 5 minuteurs', H['pop_tablet:clock:startTimer'](40, { seconds = 60 }).err == 'err_limit')
    tk()
    check('clock:cancelTimer : minuteur d\'autrui refusé', H['pop_tablet:clock:cancelTimer'](41, ids[2]).err == 'err_not_found')
    check('clock:cancelTimer : annule et désarme', H['pop_tablet:clock:cancelTimer'](40, ids[2]).ok and AL[ids[2]] == nil and Tablet.Scheduler.Count() == before + 4)
    for i = 3, 5 do H['pop_tablet:clock:cancelTimer'](40, ids[i]) end
    tk()
    check('clock:cancelTimer : alarme refusée (pas un minuteur)', H['pop_tablet:clock:cancelTimer'](40, week.id).err == 'err_not_found')
    sent = {}
    clock = clock + 100
    Tablet.Scheduler.Run()
    local done = false
    for _, p in ipairs(sent) do if p.name == 'pop_tablet:client:notify' and p.data.title == 'Pâtes' then done = true end end
    check('minuteur échu : notification, ligne supprimée, plus d\'échéance', done and AL[tm.id] == nil and Tablet.Scheduler.Count() == before)
    -- Réarmement au démarrage : un minuteur en cours est repris, un minuteur échu est supprimé
    local keep = DB.InsertAlarm(serial, { kind = 'timer', label = '', ends = clock + 50, enabled = true })
    local gone = DB.InsertAlarm(serial, { kind = 'timer', label = '', ends = clock - 1, enabled = true })
    Tablet.Clock.Rearm()
    check('Rearm : minuteur en cours repris, minuteur échu supprimé', AL[keep] ~= nil and AL[gone] == nil and Tablet.Scheduler.Count() == before + 1)
    Tablet.Scheduler.Cancel('timer:' .. keep)
    Bridge.Notify = realBridgeNotify
end

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
    def('joaat', function(name) local h = 0 for i = 1, #name do h = (h * 31 + name:byte(i)) % 4294967296 end return h end)
    local weatherPrev, weatherNext, weatherPct, rainLevel = 'CLEAR', 'RAIN', 0.8, 0.0
    def('GetPrevWeatherTypeHashName', function() return joaat(weatherPrev) end)
    def('GetNextWeatherTypeHashName', function() return joaat(weatherNext) end)
    def('GetWeatherTypeTransition', function() return joaat(weatherPrev), joaat(weatherNext), weatherPct end)
    def('GetRainLevel', function() return rainLevel end)
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
    local camCalls = {}
    for _, n in ipairs({ 'CreateMobilePhone', 'CellCamActivate', 'CellCamActivateSelfieMode', 'DestroyMobilePhone', 'CreateCam', 'SetCamCoord',
        'SetCamRot', 'SetCamFov', 'SetCamActive', 'RenderScriptCams', 'DestroyCam', 'SetGameplayCamRelativeHeading', 'SetGameplayCamRelativePitch',
        'GetEntityHeading', 'GetPedBoneCoords' }) do
        def(n, function(...) camCalls[#camCalls + 1] = n if n == 'CreateCam' then return 9 end if n == 'GetPedBoneCoords' then return { x = 0, y = 0, z = 0 } end if n == 'GetEntityHeading' then return 0.0 end end)
    end
    for _, f in ipairs({ 'locale', 'anim', 'camera', 'device', 'scheduler', 'main', 'nui', 'api' }) do dofile('client/' .. f .. '.lua') end
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
    check('ouverture : langue, pas de coque, date du jeu envoyée au serveur', lastMsg().data.lang == 'ar' and lastMsg().data.shell == nil
        and triggered('pop_tablet:device:open').args[2] == '2026-06-14 08:30')
    local wx = lastMsg().data.weather
    check('ouverture : météo {temp, kind, hi, lo, city} depuis les natives', wx and wx.kind == 'rain' and wx.temp == 16 and wx.hi == 21 and wx.lo == 13 and wx.city == 'Los Santos', wx and wx.temp)
    weatherPct = 0.2
    check('météo : transition < 50 % = type précédent', C.WeatherSnapshot().kind == 'clear')
    rainLevel = 0.8
    check('météo : ciel clair mais forte pluie = pluie', C.WeatherSnapshot().kind == 'rain')
    rainLevel, weatherPct = 0.0, 0.8
    check('température : maximum l après-midi, minimum la nuit', C.TempAt('clear', 15) == 31 and C.TempAt('clear', 3) == 23 and C.TempAt('snow', 15) == 3)
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
    nuiCb['tablet:map']({}, function(r) got = r end)
    check('carte/micro : réponse propre en attendant les applis', got.ok == false and got.err == 'err_unavailable')
    -- Appareil photo : natives CellCam, repli scripté, fermeture sans fuite
    camCalls = {}
    nuiCb['tablet:camera']({ action = 'start' }, function(r) got = r end)
    check('caméra native : CreateMobilePhone puis CellCamActivate, pas de zoom', got.ok and got.mode == 'native' and got.zoom == false
        and camCalls[1] == 'CreateMobilePhone' and camCalls[2] == 'CellCamActivate' and C.Camera.Active())
    nuiCb['tablet:camera']({ action = 'selfie', on = true }, function(r) got = r end)
    check('caméra : selfie par CellCamActivateSelfieMode', got.ok and camCalls[#camCalls] == 'CellCamActivateSelfieMode')
    nuiCb['tablet:camera']({ action = 'stop' }, function(r) got = r end)
    check('caméra : arrêt = DestroyMobilePhone, plus active', camCalls[#camCalls] == 'DestroyMobilePhone' and not C.Camera.Active())
    local n0 = #camCalls
    C.Camera.Stop()
    check('caméra : double arrêt sans effet', #camCalls == n0)
    Config.Camera.mode = 'scripted'
    camCalls = {}
    nuiCb['tablet:camera']({ action = 'start' }, function(r) got = r end)
    check('caméra scriptée : CreateCam + rendu, zoom possible', got.ok and got.mode == 'scripted' and got.zoom and camCalls[1] == 'CreateCam' and camCalls[#camCalls] == 'RenderScriptCams')
    check('caméra scriptée : zoom et orientation acceptés, valeurs folles refusées', C.Camera.Zoom(3) and not C.Camera.Zoom(9) and C.Camera.Look(5, 5) and not C.Camera.Look('a', 1))
    C.Close('key')
    check('fermeture de la tablette : caméra scriptée détruite', not C.Camera.Active() and camCalls[#camCalls] == 'DestroyCam')
    Config.Camera.mode = 'native'
    nuiCb['tablet:camera']({ action = 'start' }, function(r) got = r end)
    check('caméra : tablette fermée refusée', got.ok == false and got.err == 'err_session')
    cmds.pop_tablet_toggle()
    removedHandlers = 0

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
