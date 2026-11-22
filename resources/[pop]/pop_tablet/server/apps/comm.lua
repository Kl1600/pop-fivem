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

--- Joueur qui porte la tablette `serial` : session d'abord, sinon recherche parmi les joueurs (une seule fois par événement).
function P.Carrier(serial)
    local src = Tablet.Device.SrcOf(serial)
    if src then return src end
    for _, other in ipairs(Bridge.GetPlayers()) do
        if Tablet.Device.Carries(other, serial) then return other end
    end
    return nil
end

--- true si la session peut recevoir du réseau (ni Mode Avion, ni Wi-Fi coupé).
function P.Online(s)
    return not (s and s.settings and (s.settings.air == true or s.settings.wifi == false))
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
    local s = Tablet.Device.GetSession(src)
    if s and not P.Online(s) then return nil end
    if s and s.openedAt then
        Tablet.Push.To(src, push.name, push.data)
    elseif not (s and s.settings and s.settings.notif and s.settings.notif[app] == false) then
        Bridge.Notify(src, text, 'info')
    end
    return src
end
