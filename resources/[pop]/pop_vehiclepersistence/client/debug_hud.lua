-- pop_vehiclepersistence — client : outil admin /showvehicles (HUD + repères 3D).

-- ─── /showvehicles : markers 3D + HUD natif temps réel ──────────────────────

local showAllVehiclesActive = false
local allVehiclesCache      = {}

-- Stats reçues du serveur (rafraîchies toutes les 2s tant que le HUD est actif)
local liveStats = {
    total         = 0,
    driven        = 0,
    spawnedServer = 0,
    placeholders  = 0,
    owned         = 0,
    onlinePlayers = 0,
    cullRadius    = 250.0,
    promoteRadius = 30.0,
    autoSave      = 1,
    maxPersistenceDays = 0,
}

-- Stats locales calculées chaque frame
local localStats = { inCull = 0, near50 = 0, renderedReal = 0, lastCompute = 0, renderedPlates = {} }

local function DrawHudText(text, x, y, scale, r, g, b, a, align)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.0, scale)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    if align == 'right' then
        SetTextJustification(2)
        SetTextWrap(0.0, x)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(0.0, y)
    else
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

RegisterNetEvent("pop_vehiclepersistence:receiveAllVehicles")
AddEventHandler("pop_vehiclepersistence:receiveAllVehicles", function(list)
    allVehiclesCache = list or {}
end)

RegisterNetEvent("pop_vehiclepersistence:receiveStats")
AddEventHandler("pop_vehiclepersistence:receiveStats", function(stats)
    if not stats then return end
    for k, v in pairs(stats) do liveStats[k] = v end
end)

RegisterCommand("showvehicles", function()
    showAllVehiclesActive = not showAllVehiclesActive
    if showAllVehiclesActive then
        TriggerServerEvent("pop_vehiclepersistence:requestAllVehicles")
        TriggerServerEvent("pop_vehiclepersistence:requestStats")
        if Config.Debug then print(("[Persistence] HUD ON (%d véhicules)"):format(#allVehiclesCache)) end
    else
        allVehiclesCache = {}
        if Config.Debug then print("[Persistence] HUD OFF") end
    end
end, false)

-- Refresh périodique (un seul thread) : stats toutes les 2 s, liste toutes les 5 s, tant que l'affichage est actif
CreateThread(function()
    local lastList = 0
    while true do
        Wait(2000)
        if showAllVehiclesActive then
            TriggerServerEvent("pop_vehiclepersistence:requestStats")
            local now = GetGameTimer()
            if now - lastList >= 5000 then
                lastList = now
                TriggerServerEvent("pop_vehiclepersistence:requestAllVehicles")
            end
        end
    end
end)

-- Calcule les stats locales (compte des véhicules réels rendus côté client)
local function ComputeLocalStats()
    local pCoords = GetEntityCoords(PlayerPedId())
    local cullSq  = (liveStats.cullRadius or 250.0) * (liveStats.cullRadius or 250.0)
    local inCull, near50 = 0, 0
    local plateSet = {}

    for _, v in ipairs(allVehiclesCache) do
        local dx, dy, dz = v.x - pCoords.x, v.y - pCoords.y, v.z - pCoords.z
        local d = dx*dx + dy*dy + dz*dz
        if d < cullSq then inCull = inCull + 1 end
        if d < 2500.0 then near50 = near50 + 1 end
        plateSet[string.upper(string.gsub(v.plate or '', '%s+', ''))] = true
    end

    local rendered = 0
    local renderedPlates = {}
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local vp = GetVehicleNumberPlateText(veh)
            local clean = vp and string.upper(string.gsub(vp, '%s+', ''))
            if clean and plateSet[clean] then
                rendered = rendered + 1
                renderedPlates[clean] = true
            end
        end
    end

    localStats.inCull         = inCull
    localStats.near50         = near50
    localStats.renderedReal   = rendered
    localStats.renderedPlates = renderedPlates
end

-- HUD natif RP / sobre — bandeau en haut à gauche
local function DrawPersistenceHUD()
    local x, y = 0.013, 0.025
    local w    = 0.205
    local rowH = 0.022
    local rows = 10

    local headerH = 0.030
    local effH    = 0.082   -- section "chargement a la demande" (separateur + titre + barre + legende)
    local h       = headerH + (rows * rowH) + 0.010 + effH

    -- Fond sombre semi-transparent
    DrawRect(x + w*0.5, y + h*0.5, w, h, 8, 10, 14, 220)
    -- Bandeau d'en-tête (un ton plus clair)
    DrawRect(x + w*0.5, y + headerH*0.5, w, headerH, 16, 22, 30, 240)
    -- Accent vertical à gauche
    DrawRect(x + 0.0025, y + h*0.5, 0.005, h, 80, 200, 130, 255)
    -- Séparateur sous le titre
    DrawRect(x + w*0.5, y + headerH, w, 0.0015, 80, 200, 130, 200)
    -- Pulse "live" : petit point qui clignote dans le header
    local pulse = (math.floor(GetGameTimer() / 600) % 2) == 0
    if pulse then
        DrawRect(x + w - 0.012, y + headerH*0.5, 0.006, 0.010, 80, 220, 130, 255)
    end

    -- Titre
    DrawHudText(L('hud_title'), x + 0.010, y + 0.007, 0.30, 230, 245, 235, 255)

    local rowY = y + headerH + 0.005
    local function row(label, value, vr, vg, vb)
        DrawHudText(label, x + 0.010, rowY, 0.28, 170, 178, 184, 255)
        DrawHudText(tostring(value), x + w - 0.010, rowY, 0.30, vr, vg, vb, 255, 'right')
        rowY = rowY + rowH
    end

    -- Données
    local total      = liveStats.total or 0
    local inCull     = localStats.inCull
    local rendered   = localStats.renderedReal
    local serverSpawn= liveStats.spawnedServer or 0
    local driven     = liveStats.driven or 0
    local near       = localStats.near50
    local owned      = liveStats.owned or 0
    local players    = liveStats.onlinePlayers or 0

    -- Couleur dynamique : vert si proche limite serveur, jaune si moyen
    local cullColor = {120, 200, 255}
    if inCull >= 50 then cullColor = {255, 180, 90} end
    if inCull >= 120 then cullColor = {255, 110, 110} end

    row(L('hud_total'),              total,                         255, 255, 255)
    row(L('hud_cull', math.floor(liveStats.cullRadius or 250)),
                                        inCull .. " / " .. total,      cullColor[1], cullColor[2], cullColor[3])
    row(L('hud_spawned'),            serverSpawn,                   255, 210, 120)
    row(L('hud_rendered'),              rendered,                      130, 220, 255)
    row(L('hud_driven'),                  driven,                        120, 230, 150)
    row(L('hud_near'),               near,                          255, 150, 150)
    row(L('hud_owned'),         owned,                         200, 180, 255)
    row(L('hud_players'),            players,                       200, 200, 210)
    row(L('hud_autosave'),                    (liveStats.autoSave == 1) and L('hud_on') or L('hud_off'),
                                        (liveStats.autoSave == 1) and 120 or 255,
                                        (liveStats.autoSave == 1) and 230 or 110,
                                        (liveStats.autoSave == 1) and 150 or 110)

    local expDays = liveStats.maxPersistenceDays or 0
    row(L('hud_expiration'),          (expDays > 0) and L('hud_days', expDays) or L('hud_off'),
                                        (expDays > 0) and 255 or 120,
                                        (expDays > 0) and 200 or 230,
                                        (expDays > 0) and 120 or 150)

    -- ─── Section "CHARGEMENT A LA DEMANDE" : valorise le culling spatial ───────
    -- Le serveur ne matérialise QUE les véhicules proches d'un joueur. Le reste
    -- vit en base/mémoire sans entité : 0 charge CPU/réseau/synchro.
    local loaded = serverSpawn
    if loaded > total then loaded = total end
    local atRest = total - loaded
    if atRest < 0 then atRest = 0 end
    local loadRatio = (total > 0) and (loaded / total) or 0.0
    local savedPct  = math.floor((1.0 - loadRatio) * 100 + 0.5)

    -- Séparateur
    rowY = rowY + 0.006
    DrawRect(x + w*0.5, rowY, w - 0.014, 0.0015, 80, 200, 130, 160)
    rowY = rowY + 0.010

    -- Titre + badge d'économie (vert = positif) à droite
    DrawHudText(L('hud_ondemand'), x + 0.010, rowY, 0.27, 170, 178, 184, 255)
    DrawHudText(L('hud_saved', savedPct), x + w - 0.010, rowY, 0.30, 120, 230, 150, 255, 'right')
    rowY = rowY + 0.024

    -- Barre bicolore : actifs (bleu) + au repos (vert) = total
    local barX, barW, barH = x + 0.010, w - 0.020, 0.011
    DrawRect(barX + barW*0.5, rowY + barH*0.5, barW, barH, 28, 34, 42, 230)
    local activeW = barW * loadRatio
    if activeW > 0.0005 then
        DrawRect(barX + activeW*0.5, rowY + barH*0.5, activeW, barH, 90, 150, 220, 235)
    end
    local restW = barW - activeW
    if restW > 0.0005 then
        DrawRect(barX + activeW + restW*0.5, rowY + barH*0.5, restW, barH, 80, 200, 130, 235)
    end
    rowY = rowY + barH + 0.011

    -- Légende sous la barre (couleurs alignées sur la barre)
    DrawHudText(L('hud_active', loaded, total), barX, rowY, 0.27, 130, 200, 255, 255)
    DrawHudText(L('hud_rest', atRest),           x + w - 0.010, rowY, 0.27, 120, 230, 150, 255, 'right')
end

-- ─── 3D UI persistence : raconte le "chargement à la demande" dans le monde ──
-- Code couleur d'état :
--   AU REPOS (bleu)     = persisté en base, AUCUNE entité → 0 ressource
--   EN CHARGE (jaune)   = dans TON rayon → va être matérialisé (clignote)
--   ACTIF (vert)        = entité réelle rendue chez toi
--   ACTIF RESEAU (cyan) = matérialisé pour un autre joueur (pas encore streamé chez toi)
local function StateForVehicle(plate, distSq, cullSq, serverActive)
    if localStats.renderedPlates[plate] then
        return L('tag_active'), 80, 230, 140, false
    elseif serverActive then
        return L('tag_active_net'), 90, 210, 235, false
    elseif distSq < cullSq then
        return L('tag_loading'), 255, 200, 90, true
    else
        return L('tag_rest'), 120, 165, 235, false
    end
end

local function DrawTagLine(sx, sy, str, scale, r, g, b, a)
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(str)
    DrawText(sx, sy)
end

-- Panneau flottant (plaque + état + distance) avec fond, mis à l'échelle par distance
local function DrawVehTag3D(wx, wy, wz, plate, dist, label, r, g, b, blink, expiresIn)
    local onScreen, sx, sy = World3dToScreen2d(wx, wy, wz)
    if not onScreen then return end

    local s = 1.0 - (dist / 90.0)
    if s < 0.45 then s = 0.45 elseif s > 1.0 then s = 1.0 end

    local pw, ph = 0.066 * s, 0.054 * s
    local cy = sy + ph * 0.5

    -- Fond + liseré d'état (haut) + accent gauche
    DrawRect(sx, cy, pw, ph, 8, 10, 14, 205)
    DrawRect(sx, cy - ph*0.5 + 0.004*s, pw, 0.008*s, r, g, b, 240)
    DrawRect(sx - pw*0.5 + 0.003*s, cy, 0.005*s, ph, r, g, b, 200)

    DrawTagLine(sx, sy + 0.006*s, plate, 0.44*s, 255, 255, 255, 255)

    local show = (not blink) or ((math.floor(GetGameTimer() / 250) % 2) == 0)
    if show then
        DrawTagLine(sx, sy + 0.024*s, label, 0.34*s, r, g, b, 255)
    end

    local foot = L('tag_distance', dist)
    local dr, dg, db = 190, 205, 220
    if expiresIn then
        foot = foot .. L('tag_expire', expiresIn)
        if expiresIn <= 3 then dr, dg, db = 255, 120, 120 end   -- bientôt supprimé
    end
    DrawTagLine(sx, sy + 0.040*s, foot, 0.28*s, dr, dg, db, 235)
end

-- Gros placeholder volumétrique (cube translucide) à l'emplacement du véhicule.
-- Aligné sur les axes du monde (la liste serveur n'envoie pas le heading), ce qui
-- suffit à matérialiser "un véhicule persisté est ici" sans charger aucun modèle.
local function DrawPlaceholderBox(cx, cy, cz, r, g, b)
    local hl, hw = 2.4, 1.2            -- demi-dimensions (~4.8 x 2.4 m)
    local zBot   = cz - 1.0
    local zTop   = cz + 1.5
    local a      = math.floor(85 + math.sin(GetGameTimer() / 350.0) * 25)  -- "respire"
    DrawBox(cx - hl, cy - hw, zBot, cx + hl, cy + hw, zTop, r, g, b, a)
end

-- Render loop : HUD + 3D UI
CreateThread(function()
    while true do
        if showAllVehiclesActive then
            -- Recalcule les stats locales 5x/s (assez réactif sans cramer le CPU)
            local now = GetGameTimer()
            if now - localStats.lastCompute > 200 then
                ComputeLocalStats()
                localStats.lastCompute = now
            end

            DrawPersistenceHUD()

            -- 3D UI très visible : gros placeholder (cube) + halo + chevron + panneau
            if #allVehiclesCache > 0 then
                local pCoords = GetEntityCoords(PlayerPedId())
                local cullSq  = (liveStats.cullRadius or 250.0) * (liveStats.cullRadius or 250.0)
                for _, v in ipairs(allVehiclesCache) do
                    local dx, dy, dz = v.x - pCoords.x, v.y - pCoords.y, v.z - pCoords.z
                    local distSq = dx*dx + dy*dy + dz*dz
                    if distSq < 40000.0 then   -- 200 m
                        local plate        = string.upper(string.gsub(v.plate or '', '%s+', ''))
                        local renderedHere = localStats.renderedPlates[plate]
                        local label, r, g, b, blink = StateForVehicle(plate, distSq, cullSq, v.active)

                        -- Gros placeholder cube : UNIQUEMENT si aucune entité réelle n'est
                        -- rendue ici. Quand on s'approche et que le véhicule passe ACTIF,
                        -- le cube laisse place au vrai modèle => démonstration directe du
                        -- chargement à la demande.
                        if not renderedHere then
                            DrawPlaceholderBox(v.x, v.y, v.z, r, g, b)
                        end

                        -- Halo cylindre au sol
                        DrawMarker(1, v.x, v.y, v.z - 1.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            2.0, 2.0, 1.0,
                            r, g, b, 130,
                            false, false, 2, false, nil, nil, false)

                        -- Chevron animé au-dessus du cube
                        DrawMarker(2, v.x, v.y, v.z + 2.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.9, 0.9, 0.7,
                            r, g, b, 225,
                            true, false, 2, false, nil, nil, false)

                        -- Panneau plaque + état + distance à <120 m
                        if distSq < 14400.0 then
                            DrawVehTag3D(v.x, v.y, v.z + 2.3, v.plate,
                                math.sqrt(distSq), label, r, g, b, blink, v.expiresIn)
                        end
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
