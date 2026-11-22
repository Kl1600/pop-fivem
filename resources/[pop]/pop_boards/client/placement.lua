-- Placement d'un nouveau tableau (aperçu au bout du regard) et commande /board_add.

local function RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function RaycastFromCamera(dist)
    local camPos = GetGameplayCamCoord()
    local dir = RotToDir(GetGameplayCamRot(2))
    local dest = camPos + dir * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, _ = GetShapeTestResult(ray)
    return hit == 1, endCoords, surfaceNormal
end

RegisterNetEvent('pop_boards:client:placement', function()
    if Boards.placing then return end
    Boards.placing = true

    local defaultRes = Config.DefaultRes
    local defaultWidth = Config.DefaultWidth
    local defaultHeight = Config.DefaultHeight
    local initialUrl = Config.DefaultCanvas

    local finalUrl = "nui://pop_boards/html/index.html?url=" .. Boards.URLEncode(initialUrl) .. "&fit=fill&resW=" .. defaultRes .. "&resH=" .. defaultRes

    local previewPanelId = exports["pop_duiengine"]:CreatePanel({
        url = finalUrl,
        pos = vector3(0, 0, 0),
        normal = vector3(0, 1, 0),
        width = defaultWidth,
        height = defaultHeight,
        alpha = 150,
        resW = defaultRes,
        resH = defaultRes,
        faceCamera = false,
        zOffset = 0.0
    })

    local alreadyConfirmed = false

    CreateThread(function()
        local scaleW = 1.0
        local scaleH = 1.0
        while Boards.placing do
            Wait(0)
            local hit, hitPos, hitNormal = RaycastFromCamera(Config.PlaceRange)
            if hit then
                local pos = hitPos + (hitNormal * 0.01)
                exports["pop_duiengine"]:SetPanelTransform(previewPanelId, pos, hitNormal)

                -- Taille uniforme (molette)
                local changed = false
                if IsControlJustPressed(0, 15) then scaleW = scaleW + 0.1; scaleH = scaleH + 0.1; changed = true end
                if IsControlJustPressed(0, 14) then scaleW = math.max(0.1, scaleW - 0.1); scaleH = math.max(0.1, scaleH - 0.1); changed = true end

                -- Taille indépendante (flèches)
                if IsControlPressed(0, 172) then scaleH = scaleH + 0.05; changed = true end
                if IsControlPressed(0, 173) then scaleH = math.max(0.1, scaleH - 0.05); changed = true end
                if IsControlPressed(0, 174) then scaleW = math.max(0.1, scaleW - 0.05); changed = true end
                if IsControlPressed(0, 175) then scaleW = scaleW + 0.05; changed = true end

                if changed then
                    exports["pop_duiengine"]:SetPanelSize(previewPanelId, defaultWidth * scaleW, defaultHeight * scaleH)
                end

                -- Valider (ENTRÉE ou CLIC GAUCHE)
                if not alreadyConfirmed and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 24)) then
                    alreadyConfirmed = true
                    Boards.Notify(L('board_placing'))
                    Boards.placing = false
                    exports["pop_duiengine"]:DestroyPanel(previewPanelId)

                    -- Résolution selon le ratio
                    local finalW, finalH = 1024, 1024
                    local w = defaultWidth * scaleW
                    local h = defaultHeight * scaleH
                    if w > h * 1.2 then -- paysage
                        finalW, finalH = 1920, 1080
                    elseif h > w * 1.2 then -- portrait
                        finalW, finalH = 1080, 1920
                    end

                    TriggerServerEvent('pop_boards:server:saveBoard', {
                        url = initialUrl .. "?t=" .. GetGameTimer(), -- évite le cache
                        pos = pos,
                        normal = hitNormal,
                        width = w,
                        height = h,
                        resW = finalW,
                        resH = finalH,
                        fitType = 'cover'
                    })
                    Wait(500)
                    break
                end
            end

            -- Annuler
            if IsControlJustPressed(0, 177) then
                Boards.placing = false
                exports["pop_duiengine"]:DestroyPanel(previewPanelId)
                break
            end
        end
    end)
end)

RegisterCommand('board_add', function()
    if not Boards.placing then
        TriggerEvent('pop_boards:client:placement')
    else
        Boards.Debug("Déjà en mode placement.")
        Boards.Notify(L('board_already_placing'))
    end
end, false)
