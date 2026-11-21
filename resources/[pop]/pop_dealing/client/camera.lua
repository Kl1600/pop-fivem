-- ─────────────────────────────────────────────
-- pop_dealing - caméra de négociation (focus + DOF) façon charcreator
-- ─────────────────────────────────────────────

local dealCam       = nil
local dealCamPed    = nil
local camDofThread  = false

-- Distances / offsets de la cam (Config.DealCam)
local CAM_OFFSET    = Config.DealCam.offset
local CAM_SIDE      = Config.DealCam.side
local CAM_HEIGHT    = Config.DealCam.height

local function aimDealCam(ped)
    if not DoesEntityExist(ped) or not DoesCamExist(dealCam) then return end
    local pedCoords = GetEntityCoords(ped)
    local pedHead   = GetEntityHeading(ped)
    local rad       = math.rad(pedHead)

    -- "Devant" le ped client
    local fwdX = -math.sin(rad)
    local fwdY =  math.cos(rad)
    -- "Droite" du ped client
    local rightRad = math.rad(pedHead - 90.0)
    local rgtX = -math.sin(rightRad)
    local rgtY =  math.cos(rightRad)

    local cx = pedCoords.x + fwdX * CAM_OFFSET + rgtX * CAM_SIDE
    local cy = pedCoords.y + fwdY * CAM_OFFSET + rgtY * CAM_SIDE
    local cz = pedCoords.z + CAM_HEIGHT

    SetCamCoord(dealCam, cx, cy, cz)
    PointCamAtCoord(dealCam, pedCoords.x, pedCoords.y, pedCoords.z + CAM_HEIGHT - 0.05)
end

function Dealing.startDealCam(ped)
    if not DoesEntityExist(ped) then return end
    if dealCam and DoesCamExist(dealCam) then
        DestroyCam(dealCam, false)
    end

    dealCam    = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    dealCamPed = ped
    SetCamFov(dealCam, Config.DealCam.fov)
    SetCamActive(dealCam, true)

    -- DOF (flou d'arrière-plan) - réglages doux
    SetCamUseShallowDofMode(dealCam, true)
    SetCamNearDof(dealCam, 0.6)
    SetCamFarDof(dealCam, CAM_OFFSET + 0.5)
    SetCamDofStrength(dealCam, 0.8)

    aimDealCam(ped)
    RenderScriptCams(true, true, 400, true, true)

    -- Tick : maintenir le HiDof + re-viser le client en continu
    camDofThread = true
    CreateThread(function()
        while camDofThread and DoesCamExist(dealCam) do
            SetUseHiDof()
            if dealCamPed and DoesEntityExist(dealCamPed) then
                aimDealCam(dealCamPed)
            end
            Wait(0)
        end
    end)
end

function Dealing.stopDealCam()
    camDofThread = false
    if dealCam and DoesCamExist(dealCam) then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(dealCam, false)
    end
    dealCam    = nil
    dealCamPed = nil
end

--- Ped visé par la caméra (nil si pas de caméra).
function Dealing.getDealCamPed()
    return dealCamPed
end
