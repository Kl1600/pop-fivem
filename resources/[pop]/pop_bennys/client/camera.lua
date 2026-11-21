-- pop_bennys — client : caméra (une vue par catégorie)

local cam = nil

function Bennys.FocusCamera(catId)
    if not DoesEntityExist(Bennys.vehicle) then return end
    local c = (Config.Cameras and Config.Cameras[catId]) or (Config.Cameras and Config.Cameras.body)
    if not c then return end

    local p = GetOffsetFromEntityInWorldCoords(Bennys.vehicle, c.pos[1],  c.pos[2],  c.pos[3])
    local t = GetOffsetFromEntityInWorldCoords(Bennys.vehicle, c.look[1], c.look[2], c.look[3])

    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        p.x, p.y, p.z, 0.0, 0.0, 0.0, Config.CameraFov or 50.0, false, 0)
    PointCamAtCoord(newCam, t.x, t.y, t.z)

    if cam then
        -- Transition douce depuis la vue précédente.
        SetCamActiveWithInterp(newCam, cam, 700, 1, 1)
        local old = cam
        CreateThread(function()
            Wait(750)
            if DoesCamExist(old) then DestroyCam(old, false) end
        end)
    else
        SetCamActive(newCam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    cam = newCam
end

function Bennys.DestroyCamera()
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
end
