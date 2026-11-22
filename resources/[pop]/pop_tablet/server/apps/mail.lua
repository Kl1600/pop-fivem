-- Mail : une adresse par tablette (choisie à l'installation), boîtes Réception, Envoyés, Brouillons, Archive, Corbeille et vue
-- « Drapeau ». Les mails sont rangés par tablette (300 au plus). Le serveur donne l'expéditeur : jamais le client.
-- Aucune boucle : un envoi prévient le destinataire par push (tablette ouverte) ou notification du jeu (fermée).
-- Export serveur `SendMail(to, subject, body, from?)` : une autre ressource envoie un mail à une tablette.
-- Mode Avion / Wi-Fi coupé : lecture des mails déjà reçus autorisée, envoi bloqué (brouillons autorisés : rien ne part).

Tablet = Tablet or {}
Tablet.Mail = {}
local M = Tablet.Mail
local P = Tablet.Peer

local BIG = 4294967295
local B = Tablet.MailBox

local function address(v)
    if type(v) ~= 'string' or #v > 80 or #v < 3 then return nil end
    local a = v:lower()
    if not a:match('^[%w%._%-]+@[%w%.%-]+$') then return nil end
    return a
end

local function view(r)
    return { id = tonumber(r.id), from = r.from_addr, to = r.to_addr, subject = r.subject, preview = r.preview, at = r.created_at,
        read = r.read_at ~= nil, flag = tonumber(r.flagged) == 1, folder = r.folder }
end

--- Prévient la tablette `serial` d'un mail reçu. Hors ligne (Avion / Wi-Fi coupé) : rien, le mail attend dans la boîte.
local function alert(serial, from, subject, id)
    local src = P.Carrier(serial)
    if not src then return end
    local settings = P.SettingsOf(serial) -- session, sinon base (cache)
    if not P.NetworkOk(settings) then return end
    local s = P.SessionFor(serial)
    if s and s.openedAt then
        Tablet.Push.To(src, 'mail', { id = id, from = from:sub(1, 80), subject = subject:sub(1, 80) })
    elseif not (settings.notif and settings.notif.mail == false) then
        Bridge.Notify(src, L('mail_notif', from, subject), 'info')
    end
end

--- Dépose un mail dans la boîte de réception de `serial`. Renvoie l'id, ou nil + clé d'erreur.
--- `fromScript` : mail d'une autre ressource, jamais bloqué par le quota par expéditeur.
--- Boîte pleine : le plus ancien mail reçu est retiré pour faire de la place (un expéditeur ne peut pas la bloquer).
local function deliver(serial, from, to, subject, body, fromScript)
    if not fromScript and Tablet.DB.CountInboxFrom(serial, from) >= B.perSender then return nil, 'err_limit' end
    if Tablet.DB.CountMails(serial) >= B.max and not Tablet.DB.EvictOldestReceived(serial) then return nil, 'err_limit' end
    local id = Tablet.DB.InsertMail(serial, 'inbox', from, to, subject, body, Tablet.Now(), nil)
    if not id then return nil, 'err_db' end
    alert(serial, from, subject, id)
    return id
end

--- pop_tablet:mail:folders : adresse, compteurs et non-lus par dossier
function M.Folders(src)
    local s, err = Tablet.Guard(src, nil, { name = 'mailFolders', rate = 3 })
    if not s then return Tablet.Fail(err) end
    local out = {}
    local flagged = 0
    for _, r in ipairs(Tablet.DB.MailCounts(s.serial)) do
        out[r.folder] = { n = tonumber(r.n) or 0, unread = tonumber(r.unread) or 0 }
        if r.folder ~= 'trash' then flagged = flagged + (tonumber(r.flagged) or 0) end
    end
    out.flagged = { n = flagged, unread = 0 }
    return { ok = true, address = Tablet.DB.MailAddress(s.serial), folders = out, max = B.max }
end

--- pop_tablet:mail:list  { folder, before? } : 30 mails, du plus récent au plus ancien
function M.List(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'mailList', rate = 4, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not (B.folders[data.folder] or data.folder == 'flagged') then return Tablet.Fail('err_payload') end
    local before = data.before ~= nil and Tablet.Limits.Int(data.before, 1, BIG) or BIG
    if not before then return Tablet.Fail('err_payload') end
    local rows = Tablet.DB.ListMails(s.serial, data.folder, before)
    local items = {}
    for _, r in ipairs(rows) do items[#items + 1] = view(r) end
    return { ok = true, items = items, more = #rows >= 30 }
end

--- pop_tablet:mail:get  id : mail complet ; le marque lu
function M.Get(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'mailGet', rate = 4, payload = id, maxBytes = 64 })
    if not s then return Tablet.Fail(err) end
    local mid = Tablet.Limits.Int(id, 1, BIG)
    local r = mid and Tablet.DB.GetMail(s.serial, mid)
    if not r then return Tablet.Fail('err_not_found') end
    if r.read_at == nil then Tablet.DB.MarkMailRead(s.serial, mid, Tablet.Now()) end
    local v = view(r)
    v.body = r.body or ''
    v.read = true
    return { ok = true, mail = v }
end

--- pop_tablet:mail:send  { to, subject, body, draft?, id? } : envoie, ou enregistre un brouillon (`draft`) ; `id` : brouillon remplacé
function M.Send(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'mailSend', rate = 1, payload = data, maxBytes = 8192, online = not (type(data) == 'table' and data.draft == true) })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.subject) ~= 'string' or type(data.body) ~= 'string' then return Tablet.Fail('err_payload') end
    local draft = data.draft == true
    local ok, ferr = Tablet.Limits.Field('title', data.subject, { min = draft and 0 or 1 })
    if not ok then return Tablet.Fail(ferr) end
    ok, ferr = Tablet.Limits.Field('mail', data.body, { multiline = true })
    if not ok then return Tablet.Fail(ferr) end
    local me = Tablet.DB.MailAddress(s.serial)
    if not me then return Tablet.Fail('err_not_found') end
    local old
    if data.id ~= nil then
        local did = Tablet.Limits.Int(data.id, 1, BIG)
        old = did and Tablet.DB.GetMail(s.serial, did)
        if not old or old.folder ~= 'draft' then return Tablet.Fail('err_not_found') end
    end
    -- Un brouillon remplacé libère sa place : le plafond ne compte que les mails en plus.
    local room = Tablet.DB.CountMails(s.serial) - (old and 1 or 0)
    if draft then
        local to = data.to == '' and '' or address(data.to)
        if not to then return Tablet.Fail('err_payload') end
        if room >= B.max then return Tablet.Fail('err_limit') end
        if old then Tablet.DB.DeleteMail(s.serial, tonumber(old.id)) end
        local id = Tablet.DB.InsertMail(s.serial, 'draft', me, to, data.subject, data.body, Tablet.Now(), Tablet.Now())
        if not id then return Tablet.Fail('err_db') end
        return { ok = true, id = id, draft = true }
    end
    local to = address(data.to)
    if not to then return Tablet.Fail('err_payload') end
    local owner = Tablet.DB.MailboxOwner(to)
    if not owner then return Tablet.Fail('err_not_found') end
    if room >= B.max then return Tablet.Fail('err_limit') end
    local id, derr = deliver(owner, me, to, data.subject, data.body)
    if not id then return Tablet.Fail(derr) end
    if old then Tablet.DB.DeleteMail(s.serial, tonumber(old.id)) end
    local now = Tablet.Now()
    Tablet.DB.InsertMail(s.serial, 'sent', me, to, data.subject, data.body, now, now)
    return { ok = true, id = id }
end

--- pop_tablet:mail:move  { id, folder } : Réception, Archive ou Corbeille
function M.Move(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'mailMove', rate = 4, payload = data, maxBytes = 128 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not Tablet.Limits.Enum(data.folder, B.movable) then return Tablet.Fail('err_payload') end
    local mid = Tablet.Limits.Int(data.id, 1, BIG)
    if not mid or not Tablet.DB.MoveMail(s.serial, mid, data.folder) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:mail:flag  { id, on } : drapeau
function M.Flag(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'mailFlag', rate = 4, payload = data, maxBytes = 128 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' then return Tablet.Fail('err_payload') end
    local mid = Tablet.Limits.Int(data.id, 1, BIG)
    if not mid or not Tablet.DB.FlagMail(s.serial, mid, data.on) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:mail:delete  id : vers la Corbeille ; déjà dans la Corbeille (ou brouillon) : supprimé pour de bon
function M.Delete(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'mailDelete', rate = 4, payload = id, maxBytes = 64 })
    if not s then return Tablet.Fail(err) end
    local mid = Tablet.Limits.Int(id, 1, BIG)
    local r = mid and Tablet.DB.GetMail(s.serial, mid)
    if not r then return Tablet.Fail('err_not_found') end
    if r.folder == 'trash' or r.folder == 'draft' then Tablet.DB.DeleteMail(s.serial, mid) else Tablet.DB.MoveMail(s.serial, mid, 'trash') end
    return { ok = true }
end

--- Export serveur : envoie un mail à une adresse de tablette. `from` : nom affiché (80 caractères, sans caractère de contrôle).
--- Renvoie true, ou false + clé d'erreur.
function M.SendFromScript(to, subject, body, from)
    local a = address(to)
    if not a or type(subject) ~= 'string' or type(body) ~= 'string' then return false, 'err_payload' end
    local f = from == nil and ('noreply@' .. Config.Mail.Domain:lower()) or from
    local ok, ferr = Tablet.Limits.Field('title', f, { min = 1 })
    if ok then ok, ferr = Tablet.Limits.Field('title', subject, { min = 1 }) end
    if ok then ok, ferr = Tablet.Limits.Field('mail', body, { multiline = true }) end
    if not ok then return false, ferr end
    local owner = Tablet.DB.MailboxOwner(a)
    if not owner then return false, 'err_not_found' end
    local id, derr = deliver(owner, f, a, subject, body, true)
    if not id then return false, derr end
    return true
end

Tablet.BootHooks[#Tablet.BootHooks + 1] = function(serial, boot)
    local n = Tablet.DB.UnreadMail(serial)
    boot.badges = boot.badges or {}
    if n > 0 then boot.badges.mail = n end
end

Callback.Register('pop_tablet:mail:folders', function(src) return M.Folders(src) end)
Callback.Register('pop_tablet:mail:list', function(src, data) return M.List(src, data) end)
Callback.Register('pop_tablet:mail:get', function(src, id) return M.Get(src, id) end)
Callback.Register('pop_tablet:mail:send', function(src, data) return M.Send(src, data) end)
Callback.Register('pop_tablet:mail:move', function(src, data) return M.Move(src, data) end)
Callback.Register('pop_tablet:mail:flag', function(src, data) return M.Flag(src, data) end)
Callback.Register('pop_tablet:mail:delete', function(src, id) return M.Delete(src, id) end)

exports('SendMail', function(to, subject, body, from) return M.SendFromScript(to, subject, body, from) end)
