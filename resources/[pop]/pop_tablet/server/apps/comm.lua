-- Aide commune de Messages et Téléphone : retrouver la tablette qui porte un numéro et la prévenir.
-- Tablette ouverte : push vers l'interface. Fermée : notification du jeu. Hors ligne (Avion / Wi-Fi coupé) : rien, la remise se fait à la prochaine ouverture.

Tablet = Tablet or {}
Tablet.Peer = {}
local P = Tablet.Peer

--- Numéro de la tablette de la session (relu une fois, puis gardé dans la session).
function P.PhoneOf(s)
    if not s.phone then
        local row = Tablet.DB.GetDevice(s.serial)
        s.phone = row and row.phone or nil
    end
    return s.phone
end

------------------------------------------------------------------------
-- Annuaire des porteurs : série -> joueur. Tenu à jour à l'ouverture, à la fermeture, au chargement et au départ du
-- joueur ; jamais de parcours de tous les inventaires à chaque message.
------------------------------------------------------------------------

local carriers = {}  -- [serial] = src
local ownedBy = {}   -- [src] = { [serial] = true }

--- Oublie les tablettes indexées pour `src`.
function P.Unindex(src)
    for serial in pairs(ownedBy[src] or {}) do
        if carriers[serial] == src then carriers[serial] = nil end
    end
    ownedBy[src] = nil
end

--- Indexe les tablettes portées par `src` (une lecture de son inventaire).
function P.Index(src)
    P.Unindex(src)
    local mine = {}
    if Tablet.Device.Mode() == 'owner' then
        local id = Bridge.GetIdentifier(src)
        if id and Bridge.HasItem(src, Config.Item) then mine[Tablet.Device.OwnerSerial(id)] = true end
    else
        for _, it in ipairs(Tablet.Inventory.List(src)) do
            local serial = it.metadata and it.metadata.serial
            if Tablet.Device.SerialValid(serial) then mine[serial] = true end
        end
    end
    for serial in pairs(mine) do carriers[serial] = src end
    ownedBy[src] = mine
end

--- Joueur qui porte la tablette `serial` : session d'abord, sinon annuaire (revérifié par l'objet porté).
function P.Carrier(serial)
    local src = Tablet.Device.SrcOf(serial)
    if src then return src end
    local known = carriers[serial]
    if known and Bridge.GetPlayer(known) and Tablet.Device.Carries(known, serial) then return known end
    if known then
        carriers[serial] = nil
        if ownedBy[known] then ownedBy[known][serial] = nil end
    end
    return nil
end

if Bridge.OnPlayerLoaded then
    Bridge.OnPlayerLoaded(function(src) P.Index(src) end)
end

------------------------------------------------------------------------
-- Réglages d'une tablette : session si elle existe, sinon base (cache court)
------------------------------------------------------------------------

local settingsCache = {} -- [serial] = { v, at }
local CACHE_SECONDS = 60

--- Session ouverte sur cette tablette (et son joueur), ou nil.
function P.SessionFor(serial)
    local src = Tablet.Device.SrcOf(serial)
    local s = src and Tablet.Device.GetSession(src)
    if s and s.serial == serial then return s, src end
    return nil
end

--- Réglages de la tablette `serial` : ceux de la session, sinon ceux de la base (cache de 60 s).
function P.SettingsOf(serial)
    local s = P.SessionFor(serial)
    if s and s.settings then return s.settings end
    local now = Tablet.Now()
    local c = settingsCache[serial]
    if c and now - c.at < CACHE_SECONDS then return c.v end
    local row = Tablet.DB.GetDevice(serial)
    local v = Tablet.Device.Decode(row and row.settings, {})
    settingsCache[serial] = { v = v, at = now }
    return v
end

--- À appeler quand les réglages changent (enregistrement, fin de session).
function P.ForgetSettings(serial)
    settingsCache[serial] = nil
end

--- true si ces réglages permettent le réseau (ni Mode Avion, ni Wi-Fi coupé).
function P.NetworkOk(settings)
    return not (type(settings) == 'table' and (settings.air == true or settings.wifi == false))
end

--- true si la session peut recevoir du réseau (ni Mode Avion, ni Wi-Fi coupé).
function P.Online(s)
    return P.NetworkOk(s and s.settings)
end

--- true si la tablette `serial` a bloqué le numéro `phone`.
function P.Blocked(serial, phone)
    local d = Tablet.AppData.Get(serial, 'messages', {})
    for _, b in ipairs(type(d.blocked) == 'table' and d.blocked or {}) do
        if b == phone then return true end
    end
    return false
end

--- Push discret (accusé de lecture, fin d'appel) : seulement si la tablette est ouverte, jamais de notification du jeu.
function P.Quiet(phone, name, data)
    local serial = Tablet.DB.SerialOfPhone(phone)
    local src = serial and Tablet.Device.SrcOf(serial)
    local s = src and Tablet.Device.GetSession(src)
    if s and s.openedAt and P.Online(s) then return Tablet.Push.To(src, name, data) end
    return false
end

--- Prévient le porteur du numéro `phone`. `app` : 'messages' ou 'telephone' (réglage de notifications) ; `push` : { name, data } ;
--- `text` : texte de la notification du jeu si la tablette est fermée. Renvoie le joueur prévenu, ou nil.
function P.Alert(phone, app, push, text)
    local serial = Tablet.DB.SerialOfPhone(phone)
    if not serial then return nil end
    local src = P.Carrier(serial)
    if not src then return nil end
    local settings = P.SettingsOf(serial)
    if not P.NetworkOk(settings) then return nil end
    local s = P.SessionFor(serial)
    if s and s.openedAt then
        Tablet.Push.To(src, push.name, push.data)
    elseif not (settings.notif and settings.notif[app] == false) then
        Bridge.Notify(src, text, 'info')
    end
    return src
end
