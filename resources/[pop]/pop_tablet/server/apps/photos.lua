-- Photos : prise de vue côté serveur (mode 'database'). Sert à l'Appareil photo et à « Enregistrement » du centre de contrôle.
-- Le serveur demande la capture à screencapture (export serveur serverCapture) ; aucun jeton ne passe par le client.

Tablet = Tablet or {}
Tablet.Photos = {}
local P = Tablet.Photos

local MAX_BYTES = 150 * 1024 -- texte base64 de la capture
local SHOT_GAP = 3           -- secondes entre deux prises
local WAIT_MS = 10000

local lastShot = {} -- [src] = seconde

--- pop_tablet:photos:capture
function P.Capture(src)
    local s, err = Tablet.Guard(src, nil, { name = 'photoCapture', rate = 2 })
    if not s then return Tablet.Fail(err) end
    if Config.Photos.Mode ~= 'database' then return Tablet.Fail('err_unavailable') end
    local now = Tablet.Now()
    if lastShot[src] and now - lastShot[src] < SHOT_GAP then return Tablet.Fail('err_rate') end
    if GetResourceState('screencapture') ~= 'started' then return Tablet.Fail('err_unavailable') end
    if Tablet.DB.CountPhotos(s.serial) >= Config.Photos.Max then return Tablet.Fail('err_photos_full') end
    lastShot[src] = now

    local p = promise.new()
    exports.screencapture:serverCapture(src, { encoding = 'webp', maxWidth = 960 }, function(data) p:resolve(data) end)
    SetTimeout(WAIT_MS, function() p:resolve(nil) end)
    local data = Citizen.Await(p)

    if type(data) ~= 'string' or data == '' then return Tablet.Fail('err_unavailable') end
    if #data > MAX_BYTES then return Tablet.Fail('err_too_large') end
    -- La session peut avoir disparu pendant l'attente : la photo n'est enregistrée que pour la tablette encore portée.
    if not Tablet.Device.GetSession(src) or Tablet.Device.SerialOf(src) ~= s.serial or not Tablet.Device.Carries(src, s.serial) then
        return Tablet.Fail('err_session')
    end
    local id = Tablet.DB.InsertPhoto(s.serial, data, Tablet.Now())
    return { ok = true, id = id }
end

Bridge.OnPlayerDropped(function(src) lastShot[src] = nil end)

Callback.Register('pop_tablet:photos:capture', function(src) return P.Capture(src) end)
