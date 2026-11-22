-- Pose d'une affiche (aperçu au bout du regard) et commande /affiche_add.

local function RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function RaycastFromCamera(dist)
    local camPos = GetGameplayCamCoord()
    local dir    = RotToDir(GetGameplayCamRot(2))
    local dest   = camPos + dir * dist
    local ray    = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, _ = GetShapeTestResult(ray)
    return hit == 1, endCoords, surfaceNormal
end

RegisterNetEvent('pop_affiche:client:placement', function()
    if Affiche.placing then return end
    Affiche.placing = true

    local defaultWidth  = Config.DefaultWidth
    local defaultHeight = Config.DefaultHeight

    Affiche.previewPanelId = exports["pop_duiengine"]:CreatePanel({
        url        = 'nui://pop_affiche/html/affiche.html?preview=1',
        pos        = vector3(0, 0, 0),
        normal     = vector3(0, 1, 0),
        up         = vector3(0.0, 0.0, 1.0),
        width      = defaultWidth,
        height     = defaultHeight,
        alpha      = 150,
        resW       = 1024,
        resH       = 1024,
        faceCamera = false,
        frontOnly  = true,
        zOffset    = 0.0,
    })

    local alreadyConfirmed = false

    CreateThread(function()
        local scaleW, scaleH = 1.0, 1.0
        while Affiche.placing do
            Wait(0)
            local hit, hitPos, hitNormal = RaycastFromCamera(Config.PlaceRange)
            if hit then
                local pos = hitPos + (hitNormal * 0.01)
                exports["pop_duiengine"]:SetPanelTransform(Affiche.previewPanelId, pos, hitNormal, vector3(0.0, 0.0, 1.0))

                local changed = false
                if IsControlJustPressed(0, 15) then scaleW = scaleW + 0.1;              scaleH = scaleH + 0.1;              changed = true end
                if IsControlJustPressed(0, 14) then scaleW = math.max(0.1, scaleW-0.1); scaleH = math.max(0.1, scaleH-0.1); changed = true end
                if IsControlPressed(0, 172)    then scaleH = scaleH + 0.05;             changed = true end
                if IsControlPressed(0, 173)    then scaleH = math.max(0.1, scaleH-0.05); changed = true end
                if IsControlPressed(0, 174)    then scaleW = math.max(0.1, scaleW-0.05); changed = true end
                if IsControlPressed(0, 175)    then scaleW = scaleW + 0.05;             changed = true end
                if changed then
                    exports["pop_duiengine"]:SetPanelSize(Affiche.previewPanelId, defaultWidth * scaleW, defaultHeight * scaleH)
                end

                if not alreadyConfirmed and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 24)) then
                    alreadyConfirmed = true
                    Affiche.placing  = false

                    -- La preview reste visible pendant la saisie du lien
                    Affiche.pendingPlacement = {
                        pos    = { x = pos.x,       y = pos.y,       z = pos.z       },
                        normal = { x = hitNormal.x, y = hitNormal.y, z = hitNormal.z },
                        width  = defaultWidth * scaleW,
                        height = defaultHeight * scaleH,
                    }

                    Wait(200)
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = 'openMenu', dbId = nil, image_url = '' })
                    break
                end
            end

            if IsControlJustPressed(0, 177) then
                Affiche.placing = false
                exports["pop_duiengine"]:DestroyPanel(Affiche.previewPanelId)
                Affiche.previewPanelId = nil
                break
            end
        end
    end)
end)

RegisterCommand('affiche_add', function()
    if not Affiche.placing then
        Callback.Trigger('pop_affiche:isVIP', function(isVIP)
            if isVIP then
                TriggerEvent('pop_affiche:client:placement')
            else
                Affiche.Notify(L('affiche_vip_place'))
            end
        end)
    else
        Affiche.Notify(L('affiche_already_placing'), 4000)
    end
end, false)
