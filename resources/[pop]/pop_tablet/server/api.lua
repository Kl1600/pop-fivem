-- Exports serveur (partie socle) : GetApiVersion, GetSerial, OpenApp. Le reste de l'API (RegisterApp, Notify...) viendra avec les applis.

Tablet = Tablet or {}

local APP_ID = '^[a-z0-9_]+$'

--- Demande au client `src` d'ouvrir la tablette sur l'appli `appId`. Le code reste exigé : aucun contournement.
local function openApp(src, appId, data)
    if type(appId) ~= 'string' or #appId < 3 or #appId > 32 or not appId:match(APP_ID) then return false end
    if data ~= nil and not Tablet.Limits.Payload(data, 2048) then return false end
    if not Bridge.GetPlayer(src) or not Tablet.Device.HasTablet(src) then return false end
    return (Tablet.Push.To(src, 'open', { app = appId, data = data }, true))
end

exports('GetApiVersion', function() return 1 end)
exports('GetSerial', function(src) return Tablet.Device.SerialOf(src) end)
exports('OpenApp', function(src, appId, data) return openApp(tonumber(src), appId, data) end)

-- Appel du client (export client OpenApp) : mêmes contrôles, anti-spam en plus.
Callback.Register('pop_tablet:app:open', function(src, appId, data)
    if not Tablet.Limits.Rate(src, 'appOpen', 2) then return false end
    return openApp(src, appId, data)
end)
