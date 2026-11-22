-- Téléphone : appels entre tablettes. L'état d'un appel vit en mémoire (une table par appel) ; la base garde l'historique.
-- La voix passe par pma-voice (`setPlayerCall`, côté serveur) : les deux joueurs rejoignent le même canal, puis le quittent (0).
-- Aucune boucle : une échéance de sonnerie par appel, puis, pendant la communication seulement, une vérification de l'objet
-- toutes les 20 secondes. L'appel se termine proprement si l'objet est perdu, si un joueur part ou si la session tombe.

Tablet = Tablet or {}
Tablet.Phone = {}
local PH = Tablet.Phone
local P = Tablet.Peer

local BIG = 4294967295
local CHECK_SECONDS = 20

local calls = {}     -- [id] = { id, from, to, fp, tp, state = 'ring' | 'active', answeredAt }
local byPlayer = {}  -- [src] = id

local function phoneOk(p) return type(p) == 'string' and Tablet.Device.PhoneValid(p, Config.Phone.Format) end

local function voice(src, channel)
    if type(GetResourceState) == 'function' and GetResourceState('pma-voice') ~= 'started' then return end
    pcall(function() exports['pma-voice']:setPlayerCall(src, channel) end)
end

local function alive(src)
    local s = Tablet.Device.GetSession(src)
    return s ~= nil and Bridge.GetPlayer(src) ~= nil and Tablet.Device.Carries(src, s.serial)
end

local function tell(src, data)
    if src then Tablet.Push.To(src, 'call', data) end
end

local function finish(c, status, why, actor)
    if not calls[c.id] then return end
    calls[c.id] = nil
    if byPlayer[c.from] == c.id then byPlayer[c.from] = nil end
    if byPlayer[c.to] == c.id then byPlayer[c.to] = nil end
    Tablet.Scheduler.Cancel('call:' .. c.id)
    Tablet.Scheduler.Cancel('callchk:' .. c.id)
    if c.state == 'active' then
        voice(c.from, 0)
        voice(c.to, 0)
    end
    Tablet.DB.UpdateCall(c.id, status, c.answeredAt, Tablet.Now())
    local data = { id = c.id, state = 'end', why = why, from = c.fp }
    if actor ~= c.from then tell(c.from, data) end
    if actor ~= c.to then
        local s = Tablet.Device.GetSession(c.to)
        if s and s.openedAt then
            tell(c.to, data)
        elseif c.state == 'ring' and status == 'missed' then
            Bridge.Notify(c.to, L('call_missed', c.fp), 'info') -- tablette fermée : appel manqué en notification du jeu
        end
    end
end

local function check(c)
    if not calls[c.id] or c.state ~= 'active' then return end
    if not alive(c.from) or not alive(c.to) then return finish(c, 'answered', 'lost') end
    Tablet.Scheduler.Add('callchk:' .. c.id, Tablet.Now() + CHECK_SECONDS, function() check(c) end)
end

--- Fin propre quand un joueur part ou perd sa session (appelée par Device.DropSession).
function PH.Forget(src)
    local id = byPlayer[src]
    local c = id and calls[id]
    if c then finish(c, c.state == 'active' and 'answered' or 'missed', 'lost', src) end
end

function PH.ActiveCount()
    local n = 0
    for _ in pairs(calls) do n = n + 1 end
    return n
end

--- pop_tablet:phone:call  { to } : fait sonner la tablette de ce numéro
function PH.Call(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneCall', rate = 1, payload = data, maxBytes = 128, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not phoneOk(data.to) then return Tablet.Fail('err_payload') end
    local me = P.PhoneOf(s)
    if data.to == me then return Tablet.Fail('err_payload') end
    local now = Tablet.Now()
    if s.lastCall and now - s.lastCall < 5 then return Tablet.Fail('err_rate') end
    local serial = Tablet.DB.SerialOfPhone(data.to)
    if not serial then return Tablet.Fail('err_not_found') end
    if byPlayer[src] then return Tablet.Fail('err_busy') end
    s.lastCall = now
    local id = Tablet.DB.InsertCall(me, data.to, now)
    if not id then return Tablet.Fail('err_db') end
    local to = P.Carrier(serial)
    local ts = to and Tablet.Device.GetSession(to)
    if not to or (ts and not P.Online(ts)) then
        Tablet.DB.UpdateCall(id, 'missed', nil, now)
        return Tablet.Fail('err_unreachable', { callId = id })
    end
    if byPlayer[to] then
        Tablet.DB.UpdateCall(id, 'busy', nil, now)
        return Tablet.Fail('err_busy', { callId = id })
    end
    local c = { id = id, from = src, to = to, fp = me, tp = data.to, state = 'ring' }
    calls[id], byPlayer[src], byPlayer[to] = c, id, id
    if ts and ts.openedAt then
        tell(to, { id = id, state = 'ring', from = me })
    else
        Bridge.Notify(to, L('call_incoming', me), 'info') -- tablette fermée : la sonnerie est une notification du jeu
        if ts and not (ts.settings and ts.settings.notif and ts.settings.notif.telephone == false) then
            Tablet.Push.To(to, 'call', { id = id, state = 'ring', from = me })
        end
    end
    Tablet.Scheduler.Add('call:' .. id, now + Config.Phone.RingSeconds, function()
        if calls[id] and calls[id].state == 'ring' then finish(calls[id], 'missed', 'missed') end
    end)
    return { ok = true, callId = id }
end

local function mine(src, callId)
    local id = Tablet.Limits.Int(callId, 1, BIG)
    local c = id and calls[id]
    if not c or (c.from ~= src and c.to ~= src) then return nil end
    return c
end

--- pop_tablet:phone:answer  callId : seul le destinataire, pendant la sonnerie
function PH.Answer(src, callId)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneAnswer', rate = 2, payload = callId, maxBytes = 64, online = true })
    if not s then return Tablet.Fail(err) end
    local c = mine(src, callId)
    if not c or c.to ~= src or c.state ~= 'ring' then return Tablet.Fail('err_not_found') end
    c.state, c.answeredAt = 'active', Tablet.Now()
    Tablet.Scheduler.Cancel('call:' .. c.id)
    local channel = Config.Phone.ChannelBase + c.id
    voice(c.from, channel)
    voice(c.to, channel)
    tell(c.from, { id = c.id, state = 'active', from = c.tp })
    Tablet.Scheduler.Add('callchk:' .. c.id, Tablet.Now() + CHECK_SECONDS, function() check(c) end)
    return { ok = true, channel = channel }
end

--- pop_tablet:phone:decline  callId : refus par le destinataire pendant la sonnerie
function PH.Decline(src, callId)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneAnswer', rate = 2, payload = callId, maxBytes = 64 })
    if not s then return Tablet.Fail(err) end
    local c = mine(src, callId)
    if not c or c.to ~= src or c.state ~= 'ring' then return Tablet.Fail('err_not_found') end
    finish(c, 'declined', 'declined', src)
    return { ok = true }
end

--- pop_tablet:phone:hangup  callId : raccroche (les deux côtés sont prévenus)
function PH.Hangup(src, callId)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneAnswer', rate = 2, payload = callId, maxBytes = 64, allowDead = true })
    if not s then return Tablet.Fail(err) end
    local c = mine(src, callId)
    if not c then return Tablet.Fail('err_not_found') end
    if c.state == 'ring' then
        finish(c, 'missed', c.from == src and 'cancelled' or 'declined', src)
    else
        finish(c, 'answered', 'hangup', src)
    end
    return { ok = true }
end

--- pop_tablet:phone:history : 50 derniers appels, { id, peer, dir = in | out | missed, at, secs }
function PH.History(src)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneHistory', rate = 2 })
    if not s then return Tablet.Fail(err) end
    local me = P.PhoneOf(s)
    local items = {}
    for _, r in ipairs(Tablet.DB.CallHistory(me)) do
        local out = r.from_phone == me
        local dir = out and 'out' or ((r.status == 'answered') and 'in' or 'missed')
        local secs = r.answered_at and r.ended_at and math.max(0, r.ended_at - r.answered_at) or 0
        items[#items + 1] = { id = tonumber(r.id), peer = out and r.to_phone or r.from_phone, dir = dir, at = r.started_at, secs = secs }
    end
    return { ok = true, items = items }
end

--- pop_tablet:phone:voicemail  { to, text } : message vocal simple (texte) laissé à un numéro
function PH.Voicemail(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneVm', rate = 1, payload = data, maxBytes = 1024, online = true })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not phoneOk(data.to) or type(data.text) ~= 'string' then return Tablet.Fail('err_payload') end
    local len = utf8.len(data.text)
    if not len or len < 1 or len > Tablet.Comm.voicemail then return Tablet.Fail('err_payload') end
    local me = P.PhoneOf(s)
    if data.to == me then return Tablet.Fail('err_payload') end
    if not Tablet.DB.PhoneExists(data.to) then return Tablet.Fail('err_not_found') end
    local now = Tablet.Now()
    local id = Tablet.DB.InsertMessage(me, data.to, data.text, 'text', 'vm', now)
    if not id then return Tablet.Fail('err_db') end
    P.Alert(data.to, 'telephone', { name = 'message', data = { id = id, from = me, to = data.to, kind = 'text', body = data.text:sub(1, Tablet.Comm.preview), at = now, vm = true } }, L('call_voicemail', me))
    return { ok = true, id = id }
end

--- pop_tablet:phone:voicemails : messages vocaux reçus
function PH.Voicemails(src)
    local s, err = Tablet.Guard(src, nil, { name = 'phoneHistory', rate = 2 })
    if not s then return Tablet.Fail(err) end
    local items = {}
    for _, r in ipairs(Tablet.DB.Voicemails(P.PhoneOf(s))) do
        items[#items + 1] = { id = tonumber(r.id), from = r.from_phone, text = r.body, at = r.sent_at }
    end
    return { ok = true, items = items }
end

Callback.Register('pop_tablet:phone:call', function(src, data) return PH.Call(src, data) end)
Callback.Register('pop_tablet:phone:answer', function(src, id) return PH.Answer(src, id) end)
Callback.Register('pop_tablet:phone:decline', function(src, id) return PH.Decline(src, id) end)
Callback.Register('pop_tablet:phone:hangup', function(src, id) return PH.Hangup(src, id) end)
Callback.Register('pop_tablet:phone:history', function(src) return PH.History(src) end)
Callback.Register('pop_tablet:phone:voicemail', function(src, data) return PH.Voicemail(src, data) end)
Callback.Register('pop_tablet:phone:voicemails', function(src) return PH.Voicemails(src) end)
