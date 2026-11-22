-- Caméra de la cabine d'essayage (cadrage par catégorie, flou d'arrière-plan).

local categoryOffsets = {
    -- Clothes
    Hats            = { z = 0.75, d = 0.9,  fov = 28.0 },
    Masks           = { z = 0.75, d = 0.7,  fov = 28.0 },
    Ears            = { z = 0.75, d = 0.6,  fov = 28.0 },
    Glasses         = { z = 0.75, d = 0.6,  fov = 28.0 },
    Tops            = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Undershirts     = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Torsos          = { z = 0.5,  d = 1.5,  fov = 35.0 },
    Legs            = { z = 0.1,  d = 1.5,  fov = 40.0 },
    Shoes           = { z = -0.6, d = 1.0,  fov = 40.0 },
    Bags            = { z = 0.5,  d = 1.8,  fov = 38.0 },
    Accessories     = { z = 0.6,  d = 1.2,  fov = 35.0 },
    Decals          = { z = 0.5,  d = 1.3,  fov = 35.0 },
    Watches         = { z = 0.6,  d = 1.2,  fov = 35.0 },
    Bracelets       = { z = 0.5,  d = 1.5,  fov = 35.0 },
    ['Body Armors'] = { z = 0.6,  d = 1.2,  fov = 35.0 },
    -- Barber
    Hair            = { z = 0.7,  d = 0.7,  fov = 35.0 },
    Beard           = { z = 0.6,  d = 0.6,  fov = 30.0 },
    Eyebrows        = { z = 0.75, d = 0.5,  fov = 25.0 },
    ChestHair       = { z = 0.4,  d = 1.0,  fov = 40.0 },
    Makeup          = { z = 0.75, d = 0.5,  fov = 25.0 },
    Lipstick        = { z = 0.65, d = 0.5,  fov = 25.0 },
    Blush           = { z = 0.75, d = 0.5,  fov = 25.0 },
    -- Tattoos
    Head            = { z = 0.75, d = 0.7,  fov = 30.0 },
    Torso           = { z = 0.4,  d = 1.2,  fov = 40.0 },
    LeftArm         = { z = 0.4,  d = 1.2,  fov = 40.0 },
    RightArm        = { z = 0.4,  d = 1.2,  fov = 40.0 },
    LeftLeg         = { z = -0.4, d = 1.2,  fov = 40.0 },
    RightLeg        = { z = -0.4, d = 1.2,  fov = 40.0 },
}

function Clothes.UpdateCamera()
    local cam = Clothes.cam
    if not cam then return end

    if Clothes.HasFixedCam() then
        local shop = Clothes.currentShop
        local c = shop.cam.coords
        local la = shop.cam.lookAt or (shop.pedCoords or shop.coords)
        SetCamCoord(cam, c.x, c.y, c.z)
        PointCamAtCoord(cam, la.x, la.y, la.z)
    else
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local rad = math.rad(Clothes.camHeading)
        local x = coords.x + (math.sin(rad) * Clothes.camRadius)
        local y = coords.y + (math.cos(rad) * Clothes.camRadius)
        local z = coords.z + Clothes.camHeight
        SetCamCoord(cam, x, y, z)
        PointCamAtCoord(cam, coords.x, coords.y, coords.z + Clothes.camHeight)
    end

    -- Activer le flou d'arrière-plan (Depth of Field) de façon plus agressive (comme dans le charcreator)
    SetCamUseShallowDofMode(cam, true)
    SetCamDofFnumberOfLens(cam, 0.0) -- Force un flou maximal optique absolu (f/0.0)
    SetCamDofFocalLengthMultiplier(cam, 10.0) -- Multiplie l'effet optique du flou
    SetCamNearDof(cam, 0.1)
    SetCamFarDof(cam, Clothes.camRadius + 0.5) -- Le flou commence pile après le personnage
    SetCamDofStrength(cam, 1.0)
end

function Clothes.FocusOnCategory(category)
    local cam = Clothes.cam
    if not cam or not DoesCamExist(cam) then return end
    if Clothes.HasFixedCam() then return end -- camera locked by shop config
    local offset = categoryOffsets[category] or { z = 0.2, d = 2.5, fov = 45.0 }
    Clothes.camRadius = offset.d
    Clothes.camHeight = offset.z
    SetCamFov(cam, offset.fov)
    Clothes.UpdateCamera()

    -- Automatically rotate player ped based on category focus in tattoo shops
    if Clothes.currentShopType == 'tattoo' then
        local ped = PlayerPedId()
        local camHeading = Clothes.camHeading
        if category == 'Head' then
            SetEntityHeading(ped, camHeading - 180.0) -- front
        elseif category == 'Torso' then
            SetEntityHeading(ped, camHeading - 180.0) -- front default (chest)
        elseif category == 'LeftArm' then
            SetEntityHeading(ped, camHeading - 90.0)  -- left arm facing camera
        elseif category == 'RightArm' then
            SetEntityHeading(ped, camHeading - 270.0) -- right arm facing camera
        elseif category == 'LeftLeg' then
            SetEntityHeading(ped, camHeading - 90.0)  -- left leg facing camera
        elseif category == 'RightLeg' then
            SetEntityHeading(ped, camHeading - 270.0) -- right leg facing camera
        end
    end
end
