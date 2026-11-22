-- Appareil photo : natives CellCam (téléphone de jeu) ou caméra scriptée (CreateCam) selon Config.Camera.mode.
-- Aucun thread tant que l'orientation libre (touche Alt, contrôle 19) est inactive : tout vient d'un appel de l'interface
-- (démarrer, retourner, zoomer, orienter, arrêter). Pendant l'orientation libre, un seul thread tourne (voir lookThread).
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

local function cfg()
    return Config.Camera or {}
end

-- Caméra scriptée : à hauteur des yeux, face au regard. Selfie (inspiré de LB Phone) : devant le visage, tournée vers le joueur.
local function placeScripted(a)
    local ped = PlayerPedId()
    local h = head(ped)
    local heading = GetEntityHeading(ped) + a.yaw
    local rad = math.rad(heading)
    local fx, fy = -math.sin(rad), math.cos(rad)
    if a.selfie then
        local s = cfg().Selfie or {}
        local o = s.Offset or { 0.05, 0.55, 0.0 }
        SetCamCoord(a.cam, h.x + fx * o[2] + math.cos(rad) * o[1], h.y + fy * o[2] + math.sin(rad) * o[1], h.z + o[3])
        SetCamRot(a.cam, (s.Pitch or 10.0) - a.pitch, 0.0, heading + 180.0, 2)
    else
        SetCamCoord(a.cam, h.x + fx * 0.15, h.y + fy * 0.15, h.z + 0.05)
        SetCamRot(a.cam, a.pitch, 0.0, heading, 2)
    end
end

local function applyFov(a)
    if a.mode ~= 'scripted' then return end
    local fov = a.selfie and (cfg().Selfie or {}).Fov or (cfg().Fov or {})[a.zoom]
    SetCamFov(a.cam, fov or 50.0)
end

-- Contrôles coupés pendant l'orientation libre : attaque, visée, armes, pause, déplacements, sprint, saut, couvert, et Alt (19).
local BLOCKED = { 24, 25, 37, 140, 141, 142, 257, 263, 199, 200, 30, 31, 32, 33, 34, 35, 21, 22, 44, 19 }

--- Fin de l'orientation libre : focus et entrées rendus. `notify` : prévient l'interface (sortie par la touche Alt).
local function endLook(a, notify)
    if not a.looking then return end
    a.looking = false
    SetNuiFocusKeepInput(false)
    if C.IsOpen and C.IsOpen() then SetNuiFocus(true, true) end
    if notify then C.Post('tablet:cameraLook', { on = false }) end
end

-- Seule boucle du script, vivante seulement pendant l'orientation libre.
local function lookThread(a)
    local armed = false -- la touche Alt qui a lancé le mode doit d'abord être relâchée
    while active == a and a.looking do
        for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
        if not armed then
            armed = not IsDisabledControlPressed(0, 19)
        elseif IsDisabledControlJustPressed(0, 19) then
            endLook(a, true)
            return
        end
        if a.mode == 'scripted' then
            local sens = cfg().Sens or 8.0
            a.yaw = (a.yaw - GetDisabledControlNormal(0, 1) * sens) % 360.0
            a.pitch = math.max(-60.0, math.min(60.0, a.pitch - GetDisabledControlNormal(0, 2) * sens))
            placeScripted(a)
        end
        Wait(0)
    end
    endLook(a, false)
end

function Cam.Active() return active ~= nil end

--- Démarre la caméra. Renvoie { ok, mode, zoom, selfie } ; sans effet si déjà active.
function Cam.Start()
    if active then return { ok = true, mode = active.mode, zoom = active.mode == 'scripted', selfie = true } end
    local mode = cfg().mode == 'native' and 'native' or 'scripted'
    active = { mode = mode, selfie = false, yaw = 0.0, pitch = 0.0, zoom = 2 }
    if mode == 'native' then
        CreateMobilePhone(0)
        CellCamActivate(true, true)
    else
        active.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        applyFov(active)
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
    endLook(a, false)
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
    if active.mode == 'native' then CellCamActivateSelfieMode(active.selfie) else applyFov(active) placeScripted(active) end
    return true
end

--- Zoom 1 (0,5x), 2 (1x) ou 3 (2x) : caméra scriptée seulement.
function Cam.Zoom(level)
    if not active or active.mode ~= 'scripted' or type(level) ~= 'number' or level < 1 or level > 3 then return false end
    active.zoom = math.floor(level)
    applyFov(active)
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

--- Orientation libre à la souris (touche Alt) : `on` true = focus sans curseur, entrées du jeu gardées, un thread ;
--- false = tout est rendu. La sortie par Alt se fait dans le thread. Renvoie true si l'état demandé est atteint.
function Cam.LookMode(on)
    if not active then return false end
    if on ~= true then endLook(active, false) return true end
    if active.looking then return true end
    active.looking = true
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
    local a = active
    CreateThread(function() lookThread(a) end)
    return true
end

function Cam.IsLooking() return active ~= nil and active.looking == true end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Cam.Stop() end
end)
