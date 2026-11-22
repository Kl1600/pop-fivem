-- Tablettes : numéro de série, objet porté, sessions, code, batterie, garde de sécurité.
-- Le serveur ne croit jamais le client : l'objet porté et la session sont revérifiés à CHAQUE appel.

Tablet = Tablet or {}
Tablet.Device = {}
Tablet.Battery = {}
Tablet.Lockout = {}
Tablet.DueHandlers = {} -- fonctions(src, serial, id, kind) appelées quand un client signale une échéance
local D = Tablet.Device

local DB = function() return Tablet.DB end

local sessions = {}   -- [src] = { serial, unlocked, last, openedAt }
local serialSrc = {}  -- [serial] = src
local converting = {} -- [src] = true pendant une conversion d'objet
local pepperCache
local mode

--- Horloge en secondes (remplaçable par les tests).
function Tablet.Now()
    return os.time()
end

local function fail(err, extra)
    return Tablet.Fail(err, extra)
end

------------------------------------------------------------------------
-- Aléatoire, numéros de série et de téléphone
------------------------------------------------------------------------

local function randomChars(chars, n)
    local t = {}
    for i = 1, n do
        local k = math.random(#chars)
        t[i] = chars:sub(k, k)
    end
    return table.concat(t)
end

--- Série unique 'PT-' + 10 caractères [A-Z2-9] ; `exists(serial)` dit si elle est déjà prise. nil si 10 essais échouent.
function D.NewSerial(exists)
    for _ = 1, 10 do
        local serial = Tablet.SerialPrefix .. randomChars(Tablet.SerialChars, Tablet.SerialLength)
        if not exists(serial) then return serial end
    end
    return nil
end

function D.SerialValid(serial)
    return type(serial) == 'string' and #serial == #Tablet.SerialPrefix + Tablet.SerialLength
        and serial:sub(1, #Tablet.SerialPrefix) == Tablet.SerialPrefix
        and serial:sub(#Tablet.SerialPrefix + 1):match('^[A-Z2-9]+$') ~= nil
end

--- Numéro selon le format ('#' = chiffre) ; `exists(phone)` dit s'il est pris. nil après 5 essais.
function D.NewPhone(format, exists)
    format = format or '###-####'
    for _ = 1, 5 do
        local phone = (format:gsub('#', function() return tostring(math.random(0, 9)) end))
        if not exists(phone) then return phone end
    end
    return nil
end

function D.PhoneValid(phone, format)
    format = format or '###-####'
    if type(phone) ~= 'string' or #phone ~= #format then return false end
    for i = 1, #format do
        local f, c = format:sub(i, i), phone:sub(i, i)
        if f == '#' then
            if not c:match('%d') then return false end
        elseif f ~= c then
            return false
        end
    end
    return true
end

--- Série dérivée d'un identifiant de personnage (mode repli : une tablette par personnage).
function D.OwnerSerial(identifier)
    local raw = Tablet.Hash.sha256raw('pop_tablet:owner:' .. tostring(identifier))
    local chars, t = Tablet.SerialChars, {}
    for i = 1, Tablet.SerialLength do
        local k = raw:byte(i) % #chars + 1
        t[i] = chars:sub(k, k)
    end
    return Tablet.SerialPrefix .. table.concat(t)
end

------------------------------------------------------------------------
-- Batterie (calculée à l'ouverture et à la fermeture, aucune minuterie)
------------------------------------------------------------------------

--- Batterie à l'ouverture : recharge de +1 % par ChargeMinutes écoulées depuis `at`.
function Tablet.Battery.OnOpen(battery, at, now, cfg)
    if not cfg.Enabled then return 100, now end
    battery = math.max(0, math.min(100, battery or 100))
    if not at or at <= 0 or now <= at then return battery, now end
    local gained = math.floor((now - at) / 60 / math.max(1, cfg.ChargeMinutes))
    return math.min(100, battery + gained), now
end

--- Batterie à la fermeture : -1 % par DrainMinutes d'utilisation.
function Tablet.Battery.OnClose(battery, openedAt, now, cfg)
    if not cfg.Enabled or not openedAt then return battery end
    local used = math.floor((now - openedAt) / 60 / math.max(1, cfg.DrainMinutes))
    return math.max(0, battery - used)
end

------------------------------------------------------------------------
-- Blocage progressif du code
------------------------------------------------------------------------

--- Secondes de blocage après l'échec numéro `fails` : 0 avant MaxFails, puis 60, 120, 240... jusqu'à 3600.
function Tablet.Lockout.Wait(fails, cfg)
    if fails < cfg.MaxFails then return 0 end
    local step = math.min(fails - cfg.MaxFails, 20)
    return math.min(cfg.LockBaseSeconds * (1 << step), cfg.LockMaxSeconds)
end

------------------------------------------------------------------------
-- Poivre et code
------------------------------------------------------------------------

local function pepper()
    if pepperCache then return pepperCache end
    local p = GetConvar('pop_tablet_pepper', '')
    if p == '' then
        p = GetResourceKvpString('pepper')
        if not p or p == '' then
            -- NOTE: repli sans convar : aléatoire mélangé au temps, conservé dans le KVP du serveur.
            p = Tablet.Hash.sha256(randomChars('0123456789abcdef', 64) .. tostring(os.clock()) .. tostring(os.time()))
            SetResourceKvp('pepper', p)
        end
    end
    pepperCache = p
    return p
end

local function hashCode(salt, code)
    return Tablet.Hash.code(pepper(), salt, code, Config.Security.HashIterations)
end

-- Budget global de hachages par seconde, tous joueurs confondus : le HMAC itéré coûte du temps serveur, donc
-- plusieurs joueurs ne peuvent pas, ensemble, saturer le serveur en essais de code.
local hashWindow = { t = 0, n = 0 }

--- Prend un hachage sur le budget de la seconde. false si le budget est épuisé.
local function hashBudget()
    local t = Tablet.Now()
    if hashWindow.t ~= t then hashWindow.t, hashWindow.n = t, 0 end
    hashWindow.n = hashWindow.n + 1
    return hashWindow.n <= (Config.Security.HashBudgetPerSec or 20)
end

local function codeFormat(code)
    return type(code) == 'string' and #code == 4 and code:match('^%d%d%d%d$') ~= nil
end

------------------------------------------------------------------------
-- Objet porté
------------------------------------------------------------------------

--- 'item' (serial en métadonnée) ou 'owner' (repli : une tablette par personnage).
function D.Mode()
    if not mode then mode = Bridge.SupportsMetadata() and 'item' or 'owner' end
    return mode
end

function D.ResetMode()
    mode = nil
end

--- true si `src` porte la tablette `serial`.
function D.Carries(src, serial)
    if D.Mode() == 'owner' then
        local id = Bridge.GetIdentifier(src)
        return id ~= nil and D.OwnerSerial(id) == serial and Bridge.HasItem(src, Config.Item)
    end
    for _, it in ipairs(Bridge.GetItems(src, Config.Item)) do
        if it.metadata and it.metadata.serial == serial then return true end
    end
    return false
end

--- true si `src` porte au moins un objet tablette (avec ou sans serial).
function D.HasTablet(src)
    return Bridge.HasItem(src, Config.Item)
end

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

-- Convertit un objet sans serial : retrait puis ajout avec serial, sous verrou par joueur.
-- La ligne en base n'est créée qu'après réussite ; tout échec restitue l'objet d'origine.
local function convert(src, bare)
    local serial = D.NewSerial(DB().SerialExists)
    if not serial then return nil, 'err_db' end
    local phone = D.NewPhone(Config.Phone.Format, DB().PhoneExists)
    if not phone then return nil, 'err_phone_gen' end
    local meta = copy(bare.metadata)
    meta.serial = serial
    if not Bridge.RemoveItem(src, Config.Item, 1, nil, bare.slot) then return nil, 'err_convert' end
    if not Bridge.AddItem(src, Config.Item, 1, meta) then
        Bridge.AddItem(src, Config.Item, 1, bare.metadata or {})
        return nil, 'err_convert'
    end
    if not DB().CreateDevice(serial, phone, nil, Tablet.Now(), 100) then
        Bridge.RemoveItem(src, Config.Item, 1, { serial = serial })
        Bridge.AddItem(src, Config.Item, 1, bare.metadata or {})
        return nil, 'err_db'
    end
    return serial
end

--- Choisit la tablette utilisée : celle demandée si elle est portée, sinon la première ; convertit un objet sans serial.
--- Renvoie serial, ownerHint | nil, clé d'erreur.
function D.ResolveSerial(src, hint)
    if D.Mode() == 'owner' then
        local id = Bridge.GetIdentifier(src)
        if not id then return nil, 'err_no_player' end
        if not Bridge.HasItem(src, Config.Item) then return nil, 'err_no_tablet' end
        return D.OwnerSerial(id), id
    end
    local first, bare
    for _, it in ipairs(Bridge.GetItems(src, Config.Item)) do
        local s = it.metadata and it.metadata.serial
        if D.SerialValid(s) then
            if s == hint then return s end
            first = first or s
        elseif not bare then
            bare = it
        end
    end
    if first then return first end
    if not bare then return nil, 'err_no_tablet' end
    if converting[src] then return nil, 'busy' end
    converting[src] = true
    local ok, serial, err = pcall(convert, src, bare)
    converting[src] = nil
    if not ok then return nil, 'err_convert' end
    return serial, nil, err
end

--- Ligne de la tablette ; la crée si elle manque (objet donné par un autre script, base vidée, mode repli).
local function ensureDevice(serial, ownerHint)
    local row = DB().GetDevice(serial)
    if row then
        if ownerHint and row.owner_hint and row.owner_hint ~= ownerHint then return nil, 'err_db' end
        return row
    end
    local phone = D.NewPhone(Config.Phone.Format, DB().PhoneExists)
    if not phone then return nil, 'err_phone_gen' end
    if not DB().CreateDevice(serial, phone, ownerHint, Tablet.Now(), 100) then return nil, 'err_db' end
    return DB().GetDevice(serial)
end

------------------------------------------------------------------------
-- Sessions
------------------------------------------------------------------------

function D.GetSession(src) return sessions[src] end
function D.HasSession(src) return sessions[src] ~= nil end
function D.SrcOf(serial) return serialSrc[serial] end

function D.SessionCount()
    local n = 0
    for _ in pairs(sessions) do n = n + 1 end
    return n
end

--- Joueurs ayant une session (pour les envois à tous : catalogue d'applis modifié).
function D.Sources()
    local list = {}
    for src in pairs(sessions) do list[#list + 1] = src end
    return list
end

function D.SerialOf(src)
    local s = sessions[src]
    return s and s.serial or nil
end

-- Fin d'usage : enregistre la batterie consommée.
local function endUse(s)
    if not s.openedAt then return end
    local row = DB().GetDevice(s.serial)
    if row then
        local t = Tablet.Now()
        DB().SetBattery(s.serial, Tablet.Battery.OnClose(row.battery, s.openedAt, t, Config.Battery), t)
    end
    s.openedAt = nil
end

--- Supprime la session (drop, retour au choix du personnage, arrêt, tablette perdue).
function D.DropSession(src)
    local s = sessions[src]
    converting[src] = nil
    -- Les limites de débit ne sont PAS remises à zéro ici : changer de session (perte, autre tablette) ne doit pas
    -- rendre des appels. Elles sont vidées au départ du joueur seulement (server/main.lua : Limits.Forget).
    if Tablet.Peer then Tablet.Peer.Unindex(src) end
    if not s then return end
    pcall(endUse, s)
    if Tablet.Phone then pcall(Tablet.Phone.Forget, src) end -- appel en cours : fin propre des deux côtés
    if serialSrc[s.serial] == src then serialSrc[s.serial] = nil end
    sessions[src] = nil
    if Tablet.Peer then Tablet.Peer.ForgetSettings(s.serial) end
    Tablet.Limits.Forget('tab:' .. s.serial)
end

function D.StopAll()
    local list = {}
    for src in pairs(sessions) do list[#list + 1] = src end
    for _, src in ipairs(list) do D.DropSession(src) end
end

------------------------------------------------------------------------
-- Garde de sécurité (section 7.1 de la SPEC)
------------------------------------------------------------------------

--- Contrôles communs, refaits à chaque appel. Renvoie la session, ou nil + clé d'erreur.
--- `serial` : seulement pour comparaison (jamais cru) ; `opts` : allowDead, public (sans déverrouillage),
--- payload (charge à mesurer), maxBytes, name + rate (appels par seconde).
function Tablet.Guard(src, serial, opts)
    opts = opts or {}
    if not Bridge.GetPlayer(src) then return nil, 'err_no_player' end
    if not opts.allowDead and Bridge.IsDead(src) then
        Tablet.Push.ForceClose(src, 'dead')
        return nil, 'err_dead'
    end
    local s = sessions[src]
    if not s then return nil, 'err_session' end
    if serial ~= nil and serial ~= s.serial then return nil, 'err_session' end
    if not D.Carries(src, s.serial) then
        D.DropSession(src)
        Tablet.Push.ForceClose(src, 'lost')
        return nil, 'err_no_tablet'
    end
    local t = Tablet.Now()
    if t - s.last > Config.Session.IdleLockSeconds then s.unlocked = false end
    if not opts.public and not s.unlocked then return nil, 'err_locked' end
    if opts.payload ~= nil and not Tablet.Limits.Payload(opts.payload, opts.maxBytes or Tablet.Max.payload) then
        return nil, 'err_too_large'
    end
    if opts.online and s.settings and (s.settings.air == true or s.settings.wifi == false) then
        if Config.Debug then print(('[pop_tablet] %s refusé : mode avion ou Wi-Fi coupé'):format(tostring(opts.name or 'online'))) end
        return nil, 'err_offline'
    end
    if opts.rate and not Tablet.Limits.Rate(src, opts.name or 'guard', opts.rate) then return nil, 'err_rate' end
    s.last = t
    return s
end

------------------------------------------------------------------------
-- Ouverture, démarrage de l'appareil
------------------------------------------------------------------------

local function decode(text, default)
    if type(text) == 'table' then return text end
    if type(text) ~= 'string' or text == '' then return default end
    local ok, value = pcall(json.decode, text)
    return ok and type(value) == 'table' and value or default
end

D.Decode = decode
Tablet.BootHooks = {} -- fonctions(serial, boot) : ajoutent badges et données des applis

--- Données de démarrage envoyées à l'interface une fois déverrouillée.
function D.Boot(row)
    local boot = {
        serial = row.serial, name = row.name, phone = row.phone, battery = row.battery,
        settings = decode(row.settings, {}), apps = decode(row.apps, {}), badges = {},
        created = row.created_at, lastOpen = row.last_open_at, model = Tablet.Model, os = Tablet.OsVersion,
    }
    for _, hook in ipairs(Tablet.BootHooks) do pcall(hook, row.serial, boot) end
    return boot
end

--- pop_tablet:device:open
function D.Open(src, hint, gameNow)
    if not Bridge.GetPlayer(src) then return fail('err_no_player') end
    -- Date du jeu 'AAAA-MM-JJ HH:MM' donnée par le client : sert seulement à filtrer les widgets (aucun droit).
    if type(gameNow) ~= 'string' or not gameNow:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$') then gameNow = nil end
    if Bridge.IsDead(src) then return fail('err_dead') end
    if not Tablet.Limits.Rate(src, 'open', 5) then return fail('err_rate') end
    if hint ~= nil and not D.SerialValid(hint) then hint = nil end
    local serial, ownerHint, convErr = D.ResolveSerial(src, hint)
    if not serial then return fail(ownerHint or convErr or 'err_no_tablet') end
    local row, err = ensureDevice(serial, D.Mode() == 'owner' and ownerHint or nil)
    if not row then return fail(err) end

    local t = Tablet.Now()
    local battery = Tablet.Battery.OnOpen(row.battery, row.battery_at, t, Config.Battery)
    if Config.Battery.Enabled and battery < Config.Battery.MinToOpen then
        DB().SetBattery(serial, battery, t)
        return fail('err_battery', { battery = battery })
    end

    local previous = serialSrc[serial]
    if previous and previous ~= src then
        D.DropSession(previous)
        Tablet.Push.ForceClose(previous, 'lost')
    end
    local s = sessions[src]
    if s and s.serial ~= serial then
        D.DropSession(src)
        s = nil
    end
    if not s then
        s = { serial = serial, unlocked = false, last = t }
        sessions[src] = s
        serialSrc[serial] = src
    end
    if t - s.last > Config.Session.IdleLockSeconds then s.unlocked = false end
    s.openedAt, s.last, s.gameNow = t, t, gameNow
    DB().TouchOpen(serial, battery, t)
    row.battery = battery
    if Tablet.Peer then Tablet.Peer.Index(src) end -- annuaire des porteurs : mis à jour à l'ouverture

    local needSetup = row.code_hash == nil
    local out = { ok = true, serial = serial, needSetup = needSetup, locked = needSetup or not s.unlocked }
    if not out.locked then out.boot = D.Boot(row) end
    return out
end

--- pop_tablet:device:close
function D.Close(src)
    local s, err = Tablet.Guard(src, nil, { public = true, allowDead = true })
    if not s then return fail(err) end
    endUse(s)
    if Tablet.Phone then Tablet.Phone.Forget(src) end -- fermer la tablette raccroche tout de suite (le contrôle de 20 s reste un filet)
    if Tablet.Peer then Tablet.Peer.Index(src) end -- annuaire des porteurs : mis à jour à la fermeture
    return { ok = true }
end

------------------------------------------------------------------------
-- Premier allumage, déverrouillage, changement de code
------------------------------------------------------------------------

local function newSalt()
    return randomChars(Tablet.SerialChars, 16)
end

-- Adresse complète depuis la saisie (partie locale, ou adresse avec le bon domaine).
local function mailAddress(input)
    if type(input) ~= 'string' then return nil end
    local domain = '@' .. Config.Mail.Domain:lower()
    local localPart = input:lower()
    if localPart:sub(-#domain) == domain then localPart = localPart:sub(1, -#domain - 1) end
    if #localPart < 3 or #localPart > Tablet.Max.mailLocal then return nil end
    if not localPart:match('^[a-z0-9][a-z0-9._-]*[a-z0-9]$') or localPart:find('%.%.') then return nil end
    return localPart .. domain
end

--- pop_tablet:device:setup
function D.Setup(src, data)
    local s, err = Tablet.Guard(src, nil, { public = true, payload = data, maxBytes = 1024, name = 'setup', rate = 2 })
    if not s then return fail(err) end
    if type(data) ~= 'table' then return fail('err_payload') end
    local row = DB().GetDevice(s.serial)
    if not row then return fail('err_db') end
    if row.code_hash ~= nil then return fail('err_setup_done') end
    if not codeFormat(data.code) then return fail('err_code_format') end
    if type(data.name) ~= 'string' then return fail('err_name_invalid') end
    local name = Tablet.Limits.Trim(data.name)
    if not Tablet.Limits.Field('name', name, { min = 1 }) then return fail('err_name_invalid') end
    if not Tablet.Limits.Enum(data.lang, Tablet.LanguageSet) then return fail('err_lang_invalid') end
    local address = mailAddress(data.mail)
    if not address then return fail('err_mail_invalid') end

    if not DB().ClaimMailbox(address, s.serial) then
        return fail(DB().MailboxOwner(address) == s.serial and 'err_setup_done' or 'err_mail_taken')
    end
    if not hashBudget() then
        DB().DeleteMailbox(address, s.serial)
        return fail('err_rate')
    end
    local salt = newSalt()
    local settings = json.encode({ lang = data.lang, dark = false, mail = address })
    local apps = json.encode(Tablet.Store and Tablet.Store.DefaultApps() or {})
    if not DB().ClaimSetup(s.serial, hashCode(salt, data.code), salt, name, settings, apps) then
        DB().DeleteMailbox(address, s.serial)
        return fail('err_setup_done')
    end
    s.unlocked, s.last = true, Tablet.Now()
    return { ok = true, boot = D.Boot(DB().GetDevice(s.serial)) }
end

-- Vérifie un code avec blocage progressif. Renvoie true, ou un échec { ok = false, err, wait? }.
local function attempt(row, code)
    local t = Tablet.Now()
    if (row.locked_until or 0) > t then
        return fail('err_code_blocked', { wait = row.locked_until - t })
    end
    if not hashBudget() then return fail('err_rate') end
    if Tablet.Hash.equals(hashCode(row.code_salt, code), row.code_hash) then
        if (row.fails or 0) > 0 then DB().SetFails(row.serial, 0, 0) end
        return true
    end
    local cfg = Config.Security
    local fails = math.min((row.fails or 0) + 1, 100)
    local wait = Tablet.Lockout.Wait(fails, cfg)
    DB().SetFails(row.serial, fails, wait > 0 and t + wait or 0)
    if wait > 0 then return fail('err_code_blocked', { wait = wait }) end
    return fail('err_code_wrong', { left = math.max(0, cfg.MaxFails - fails) })
end

--- pop_tablet:device:unlock
function D.Unlock(src, code)
    local s, err = Tablet.Guard(src, nil, { public = true, name = 'unlock', rate = Config.Security.UnlockRatePerSec })
    if not s then return fail(err) end
    local row = DB().GetDevice(s.serial)
    if not row then return fail('err_db') end
    if row.code_hash == nil then return fail('err_setup_needed') end
    -- Session déjà déverrouillée : aucun nouveau hachage (un client ne peut pas faire payer du calcul en boucle).
    if s.unlocked then return { ok = true, boot = D.Boot(row) } end
    if not codeFormat(code) then return fail('err_code_format') end
    local result = attempt(row, code)
    if result ~= true then return result end
    s.unlocked, s.last = true, Tablet.Now()
    return { ok = true, boot = D.Boot(row) }
end

--- pop_tablet:device:changeCode
function D.ChangeCode(src, old, new)
    local s, err = Tablet.Guard(src, nil, { name = 'changeCode', rate = Config.Security.UnlockRatePerSec })
    if not s then return fail(err) end
    local row = DB().GetDevice(s.serial)
    if not row or row.code_hash == nil then return fail('err_setup_needed') end
    if not codeFormat(old) or not codeFormat(new) then return fail('err_code_format') end
    local result = attempt(row, old)
    if result ~= true then return result end
    if not hashBudget() then return fail('err_rate') end
    local salt = newSalt()
    DB().SetCode(s.serial, hashCode(salt, new), salt)
    return { ok = true }
end

--- pop_tablet:device:lock
function D.Lock(src)
    local s, err = Tablet.Guard(src, nil, { public = true, allowDead = true })
    if not s then return fail(err) end
    s.unlocked = false
    return { ok = true }
end

------------------------------------------------------------------------
-- Création d'une tablette par un administrateur (/pop_tablet_give)
------------------------------------------------------------------------

--- Donne une tablette à `target`. Renvoie true, serial (ou nil en mode repli), ou false + clé d'erreur.
function D.Give(target)
    if D.Mode() == 'owner' then
        return Bridge.AddItem(target, Config.Item, 1) == true, nil, 'owner'
    end
    local serial = D.NewSerial(DB().SerialExists)
    if not serial then return false, nil, 'err_db' end
    local phone = D.NewPhone(Config.Phone.Format, DB().PhoneExists)
    if not phone then return false, nil, 'err_phone_gen' end
    if not Bridge.AddItem(target, Config.Item, 1, { serial = serial }) then return false, nil, 'inventory_full' end
    if not DB().CreateDevice(serial, phone, nil, Tablet.Now(), 100) then
        Bridge.RemoveItem(target, Config.Item, 1, { serial = serial })
        return false, nil, 'err_db'
    end
    if Tablet.Peer then Tablet.Peer.Index(target) end
    return true, serial
end

------------------------------------------------------------------------
-- Callbacks client -> serveur
------------------------------------------------------------------------

Callback.Register('pop_tablet:device:open', function(src, hint, gameNow) return D.Open(src, hint, gameNow) end)
Callback.Register('pop_tablet:device:close', function(src) return D.Close(src) end)
Callback.Register('pop_tablet:device:setup', function(src, data) return D.Setup(src, data) end)
Callback.Register('pop_tablet:device:unlock', function(src, code) return D.Unlock(src, code) end)
Callback.Register('pop_tablet:device:changeCode', function(src, old, new) return D.ChangeCode(src, old, new) end)
Callback.Register('pop_tablet:device:lock', function(src) return D.Lock(src) end)
