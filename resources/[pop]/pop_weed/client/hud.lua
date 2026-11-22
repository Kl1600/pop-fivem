-- HUD 3D (croissance + eau), prompt de récolte et création des props selon la distance.

-- Dimensions du panneau (coordonnées écran normalisées)
local HUD = {
    panelW  = 0.082,
    barW    = 0.072,
    barH    = 0.013,
    lineGap = 0.001,
    padTop  = 0.010,
    padBot  = 0.0005,
}

local function drawHudBar(cx, cy, pct, r, g, b)
    -- Effet de Halo (Glow) plus diffus
    DrawRect(cx, cy, HUD.barW + 0.0015, HUD.barH + 0.0015, r, g, b, 60)

    -- Fond de barre (semi-transparent)
    DrawRect(cx, cy, HUD.barW, HUD.barH, r, g, b, 100)

    -- Remplissage coloré (avec mini gap)
    if pct > 0 then
        local innerGap = 0.002
        local filledW = (HUD.barW - innerGap) * pct
        local filledH = HUD.barH - innerGap
        local fx = cx - (HUD.barW - innerGap) * 0.5 + filledW * 0.5
        -- Couleur principale bien opaque
        DrawRect(fx, cy, filledW, filledH, r, g, b, 255)
    end
end

local function drawHudLabel(lx, ly, text)
    SetTextScale(0.0, 0.15)
    SetTextFont(8)
    SetTextColour(210, 210, 210, 255)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(lx, ly)
end

local nearbyPlants = {}

-- Thread de proximité : crée / supprime les props selon la distance (boucle adaptative)
CreateThread(function()
    local spawnDist = Config.SpawnDistance or 80.0
    while true do
        local pedCoords = GetEntityCoords(cache.ped)
        local newNearby = {}
        local anyClose  = false

        for id, entry in pairs(Weed.plants) do
            local p    = entry.data
            local dist = #(pedCoords - vec3(p.x, p.y, p.z))

            if dist <= spawnDist then
                anyClose = true
                if not entry.entity then Weed.CreateProp(entry) end
            elseif entry.entity and dist > spawnDist + 10.0 then
                Weed.DeleteProp(entry)
            end

            if entry.entity and DoesEntityExist(entry.entity) and dist <= (Config.DrawDistance or 10.0) + 3.0 then
                local eCoords = GetEntityCoords(entry.entity)
                local eDist   = #(pedCoords - eCoords)
                if eDist <= (Config.DrawDistance or 10.0) then
                    newNearby[id] = { id = id, coords = eCoords, dist = eDist }
                end
            end
        end

        nearbyPlants = newNearby
        Wait(anyClose and 500 or 2000)
    end
end)

-- Thread de rendu (uniquement quand des plantes sont proches)
CreateThread(function()
    local key = Config.Keys.Interact
    while true do
        local hasNearby = false
        for id, data in pairs(nearbyPlants) do
            hasNearby = true
            local entry = Weed.plants[id]
            if entry and DoesEntityExist(entry.entity) then
                if Weed.IsReady(entry) then
                    -- Si prêt : on affiche le prompt pop_v3dui
                    if not entry.uiId then
                        entry.uiId = exports.pop_v3dui:Create({
                            coords = data.coords,
                            type = 'prompt',
                            content = {
                                key = key.label,
                                label = L('target_harvest'),
                                icon = 'fas fa-hand-holding-plant'
                            },
                            drawDistance = Config.DrawDistance,
                            offset = vector3(0, 0, 0.5)
                        })
                    end

                    -- Détection de l'appui sur E pour récolter
                    if data.dist <= Config.HarvestKeyDistance and IsControlJustPressed(0, key.control) then
                        Weed.HarvestPlant(id)
                    end
                else
                    -- Sinon : on affiche le HUD de croissance
                    if entry.uiId then
                        exports.pop_v3dui:Remove(entry.uiId)
                        entry.uiId = nil
                    end

                    local visible, sx, sy = World3dToScreen2d(data.coords.x, data.coords.y, data.coords.z + 0.1)
                    if visible then
                        local growPct  = math.min(1.0, Weed.GetElapsed(entry) / Config.TotalDuration)
                        local waterPct = Weed.GetWaterLevel(entry)

                        -- Fond du panneau
                        local panelH = HUD.padTop + (0.016 + HUD.barH + 0.004) * 2 + HUD.padBot
                        DrawRect(sx, sy, HUD.panelW, panelH, 0, 0, 0, 170)

                        -- Ligne 1 : Croissance
                        local y1label = sy - panelH * 0.5 + HUD.padTop
                        local y1bar   = y1label + 0.016
                        drawHudLabel(sx - HUD.barW * 0.5, y1label - 0.007, L('hud_growth', math.floor(growPct * 100)))
                        drawHudBar(sx, y1bar, growPct, 3, 163, 1)

                        -- Ligne 2 : Eau
                        local y2label = y1bar + HUD.barH + 0.004
                        local y2bar   = y2label + 0.016
                        drawHudLabel(sx - HUD.barW * 0.5, y2label - 0.007, L('hud_water', math.floor(waterPct * 100)))
                        drawHudBar(sx, y2bar, waterPct, 0, 142, 237)
                    end
                end
            end
        end

        -- Si aucune plante n'est proche, on peut ralentir l'attente pour économiser le CPU
        if not hasNearby then
            Wait(500)
        else
            Wait(0)
        end
    end
end)
