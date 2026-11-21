Cam = nil
camHeading = 357.0
camRadius = 1.0
camHeight = 0.65
currentPart = 'identity'

local offsets = {
    identity = { z = 0.75, d = 3.0, fov = 9.0 }, -- Un FOV de 5.0 écrase la profondeur et annule le flou du jeu
    genetics = { z = 0.75, d = 3.0, fov = 7.0 },
    features = { z = 0.75, d = 3.0, fov = 7.0 },
    hair = { z = 0.75, d = 3.0, fov = 7.0 },
    appearance = { z = 0.65, d = 0.9, fov = 30.0 },
    tops = { z = 0.5, d = 1.5, fov = 35.0 },
    undershirts = { z = 0.5, d = 1.5, fov = 35.0 },
    legs = { z = 0.1, d = 1.5, fov = 40.0 },
    shoes = { z = -0.6, d = 1.0, fov = 40.0 },
    bags = { z = 0.5, d = 1.8, fov = 40.0 },
    hats = { z = 0.75, d = 0.8, fov = 30.0 },
    glasses = { z = 0.75, d = 0.6, fov = 30.0 },
    ears = { z = 0.75, d = 0.6, fov = 30.0 },
    masks = { z = 0.75, d = 0.6, fov = 30.0 },
    arms = { z = 0.5, d = 1.5, fov = 35.0 },
    accessories = { z = 0.6, d = 1.2, fov = 35.0 },
    size = { z = 0.1, d = 2.8, fov = 45.0 }
}

function UpdateCamera()
    if not DoesCamExist(Cam) then return end
    
    -- Nouvelles coordonnées fixes du joueur
    local px, py, pz = -578.3015, 44.7212, 92.2444
    
    -- Calculer la position relative de la caméra pour qu'elle soit toujours devant le joueur
    local headingRad = math.rad(275.8544)
    local forwardX = -math.sin(headingRad)
    local forwardY = math.cos(headingRad)
    
    -- Pour décaler le perso sur la droite de l'écran, on bouge la caméra vers sa propre gauche (donc la droite du joueur)
    local shiftAmount = 0.1 -- Réduit à 0.2 (au lieu de 0.4) pour que ce soit moins collé à droite
    local rightHeadingRad = math.rad(245.8544 - 90.0)
    local rightX = -math.sin(rightHeadingRad) * shiftAmount
    local rightY = math.cos(rightHeadingRad) * shiftAmount

    -- Position finale de la caméra (devant + décalée)
    local cx = px + (forwardX * camRadius) + rightX
    local cy = py + (forwardY * camRadius) + rightY
    local cz = pz + camHeight
    
    SetCamCoord(Cam, cx, cy, cz)
    PointCamAtCoord(Cam, px + rightX, py + rightY, cz - 0.1) 
    
    -- Activer le flou d'arrière-plan (Depth of Field) de façon plus agressive
    SetCamUseShallowDofMode(Cam, true)
    SetCamDofFnumberOfLens(Cam, 0.0) -- Force un flou maximal optique absolu (f/0.0)
    SetCamDofFocalLengthMultiplier(Cam, 10.0) -- Multiplie l'effet optique du flou
    SetCamNearDof(Cam, 0.1)
    SetCamFarDof(Cam, camRadius) -- Le flou commence PILE sur le personnage
    SetCamDofStrength(Cam, 1.0)
end

function CreateCamera()
    if not DoesCamExist(Cam) then
        Cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end
    
    local playerPed = PlayerPedId()
    camHeading = GetEntityHeading(playerPed) + 180.0
    camRadius = offsets.identity.d
    camHeight = offsets.identity.z
    
    SetCamActive(Cam, true)
    UpdateCamera()
    
    -- Activer le flou exactement comme sur le menu staff
    SetCamUseShallowDofMode(Cam, true)
    SetCamNearDof(Cam, 0.6)
    SetCamFarDof(Cam, camRadius + 0.5)
    SetCamDofStrength(Cam, 1.0)
    
    -- Le thread dédié pour le HiDof comme dans le staff menu
    Citizen.CreateThread(function()
        while DoesCamExist(Cam) do
            Wait(0)
            SetUseHiDof()
        end
    end)
    
    RenderScriptCams(true, true, 500, true, true)
end

function DestroyCamera()
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(Cam, false)
    Cam = nil
end

function FocusOn(part)
    currentPart = part
    local offset = offsets[part] or offsets.identity
    camRadius = offset.d
    camHeight = offset.z
    SetCamFov(Cam, offset.fov)
    UpdateCamera()
end

RegisterNUICallback('rotate', function(data, cb)
    local playerPed = PlayerPedId()
    
    if data.deltaX then
        local heading = GetEntityHeading(playerPed)
        SetEntityHeading(playerPed, heading + (data.deltaX * 0.5))
    end
    
    if data.deltaY then
        camHeight = camHeight + (data.deltaY * 0.005)
        -- Bounds checking for height
        if camHeight < -0.8 then camHeight = -0.8 end
        if camHeight > 1.2 then camHeight = 1.2 end
        UpdateCamera()
    end
    
    cb('ok')
end)

RegisterNUICallback('zoom', function(data, cb)
    if (tonumber(data.delta) or 0) > 0 then
        camRadius = camRadius + 0.1
    else
        camRadius = camRadius - 0.1
    end
    
    -- Bounds checking
    if camRadius < 0.4 then camRadius = 0.4 end
    if camRadius > 4.0 then camRadius = 4.0 end
    
    UpdateCamera()
    cb('ok')
end)

exports('CreateCamera', CreateCamera)
exports('DestroyCamera', DestroyCamera)
exports('FocusOn', FocusOn)
