-- Appareil photo : natives CellCam (téléphone de jeu) ou caméra scriptée (CreateCam) selon Config.Camera.mode.
-- Aucun thread ni boucle : tout vient d'un appel de l'interface (démarrer, retourner, zoomer, orienter, arrêter).
-- La capture elle-même est faite par le serveur (photos:capture, screencapture).

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client
C.Camera = {}
local Cam = C.Camera

local active = nil -- nil | { mode, cam, selfie, yaw, pitch, fov, headingBase }

local function head(ped)
    return GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
end

local function placeScripted(a)
    local ped = PlayerPedId()
    local h = head(ped)
    local heading = GetEntityHeading(ped) + a.yaw
    local rad = math.rad(heading)
    local fx, fy = -math.sin(rad), math.cos(rad)
    if a.selfie then
        SetCamCoord(a.cam, h.x + fx * 0.9, h.y + fy * 0.9, h.z + 0.05)
        SetCamRot(a.cam, -a.pitch, 0.0, heading + 180.0, 2)
    else
        SetCamCoord(a.cam, h.x + fx * 0.25, h.y + fy * 0.25, h.z + 0.05)
        SetCamRot(a.cam, a.pitch, 0.0, heading, 2)
    end
end

function Cam.Active() return active ~= nil end

--- Démarre la caméra. Renvoie { ok, mode, zoom, selfie } ; sans effet si déjà active.
function Cam.Start()
    if active then return { ok = true, mode = active.mode, zoom = active.mode == 'scripted', selfie = true } end
    local mode = Config.Camera and Config.Camera.mode == 'scripted' and 'scripted' or 'native'
    active = { mode = mode, selfie = false, yaw = 0.0, pitch = 0.0, zoom = 2 }
    if mode == 'native' then
        CreateMobilePhone(0)
        CellCamActivate(true, true)
    else
        active.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(active.cam, (Config.Camera.Fov or {})[2] or 50.0)
        placeScripted(active)
        SetCamActive(active.cam, true)
        RenderScriptCams(true, false, 0, true, false)
    end
    return { ok = true, mode = mode, zoom = mode == 'scripted', selfie = true }
end

--- Arrête la caméra et libère tout (téléphone, caméra scriptée, rendu). Sans effet si inactive.
function Cam.Stop()
    if not active then return end
    local a = active
    active = nil
    if a.mode == 'native' then
        CellCamActivateSelfieMode(false)
        CellCamActivate(false, false)
        DestroyMobilePhone()
    else
        RenderScriptCams(false, false, 0, true, false)
        SetCamActive(a.cam, false)
        DestroyCam(a.cam, false)
    end
end

--- Retourne la caméra (selfie).
function Cam.Selfie(on)
    if not active then return false end
    active.selfie = on == true
    if active.mode == 'native' then CellCamActivateSelfieMode(active.selfie) else placeScripted(active) end
    return true
end

--- Zoom 1 (0,5x), 2 (1x) ou 3 (2x) : caméra scriptée seulement.
function Cam.Zoom(level)
    if not active or active.mode ~= 'scripted' or type(level) ~= 'number' or level < 1 or level > 3 then return false end
    active.zoom = math.floor(level)
    SetCamFov(active.cam, (Config.Camera.Fov or {})[active.zoom] or 50.0)
    return true
end

--- Oriente la vue : dx, dy (degrés, bornés) tirés d'un glissement sur le viseur.
function Cam.Look(dx, dy)
    if not active or type(dx) ~= 'number' or type(dy) ~= 'number' then return false end
    dx = math.max(-30.0, math.min(30.0, dx))
    dy = math.max(-30.0, math.min(30.0, dy))
    active.yaw = (active.yaw - dx) % 360.0
    active.pitch = math.max(-60.0, math.min(60.0, active.pitch + dy))
    if active.mode == 'scripted' then
        placeScripted(active)
    else
        SetGameplayCamRelativeHeading(active.yaw)
        SetGameplayCamRelativePitch(active.pitch, 1.0)
    end
    return true
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Cam.Stop() end
end)
