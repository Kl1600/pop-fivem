local spawnedPlants = {}  -- [plantId] = { entity, stage, elapsedAtReceive, localReceivedAt }
local pendingGhost  = nil -- placeholder visible en attendant la réponse serveur

-- ─────────────────────────────────────────────
-- Helpers  (pas d'os.time() côté client FiveM)
-- elapsedAtReceive = secondes écoulées au moment où le client a reçu les données (calculé par le serveur)
-- localReceivedAt  = GetGameTimer() au moment de la réception (ms)
-- ─────────────────────────────────────────────

local function getElapsed(entry)
    return entry.elapsedAtReceive + (GetGameTimer() - entry.localReceivedAt) / 1000.0
end

local function computeStage(entry)
    local elapsed = getElapsed(entry)
    local stage   = 1
    for i, s in ipairs(Config.Stages) do
        if elapsed >= s.minTime then stage = i end
    end
    return stage
end

local function getWaterElapsed(entry)
    return entry.waterElapsedAtReceive + (GetGameTimer() - entry.localReceivedAt) / 1000.0
end

local function getWaterLevel(entry)
    return math.max(0.0, 1.0 - getWaterElapsed(entry) / Config.WaterDuration)
end

local function isReady(entry)
    return getElapsed(entry) >= Config.TotalDuration
end

local function getPct(entry)
    return math.min(100, math.floor(getElapsed(entry) / Config.TotalDuration * 100))
end

-- ─────────────────────────────────────────────
-- Cible (ox_target)
-- ─────────────────────────────────────────────

local function harvestPlant(id)
    local entry = spawnedPlants[id]
    if not entry then return end

    local animDict = 'bzzz_cutting_sickle'
    local animClip = 'bzzz_cutting_sickle'
    local propModel = GetHashKey('bzzz_prop_sickle_a')
    local hasProp = true

    if not DoesAnimDictExist(animDict) or not IsModelValid(propModel) then
        animDict = 'amb@medic@standing@tendtodead@idle_a'
        animClip = 'idle_a'
        hasProp = false
    end

    local progressConfig = {
        duration = 5000,
        label    = 'Récolte en cours...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = animDict,
            clip = animClip
        }
    }

    if hasProp then
        progressConfig.prop = {
            model = propModel,
            bone = 57005,
            pos = vec3(0.1, 0.03, -0.01),
            rot = vec3(-123.0, -52.0, -36.0)
        }
    end

    local success = lib.progressCircle(progressConfig)

    if success then
        TriggerServerEvent('pop_weed:harvest', id)
    end
end

local function attachTarget(entity, entry)
    local id = entry.data.id
    exports.ox_target:addLocalEntity(entity, {
        {
            name     = 'weed_examine_' .. id,
            icon = 'fas fa-info',
            label    = 'Examiner',
            onSelect = function()
                exports["pop_notify"]:ShowNotify({
                    icon = 'fas fa-info',
                    message  = ('Croissance : <b>%d%%</b>'):format(getPct(entry)),
                    duration = 3000,
                })
            end,
        },
        {
            name        = 'weed_harvest_' .. id,
            icon = 'fas fa-hand-holding-plant',
            label       = 'Récolter',
            canInteract = function() return isReady(entry) end,
            onSelect    = function()
                harvestPlant(id)
            end,
        },
    })
end

-- ─────────────────────────────────────────────
-- Spawn / suppression de prop
-- ─────────────────────────────────────────────

local function spawnPlant(plant, serverNow)
    local entry = {
        data                  = plant,
        elapsedAtReceive      = serverNow - plant.plantedAt,
        waterElapsedAtReceive = serverNow - (plant.wateredAt or plant.plantedAt),
        localReceivedAt       = GetGameTimer(),
        stage                 = 1,
    }
    entry.stage = computeStage(entry)

    local stageCfg = Config.Stages[entry.stage]
    local model    = stageCfg.model
    local hash     = GetHashKey(model)
    lib.requestModel(hash)

    local zPos   = plant.z + (Config.ZOffset or 0.0) + (stageCfg.zOffset or 0.0)
    local entity = CreateObject(hash, plant.x, plant.y, zPos, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(entity, plant.heading)
    FreezeEntityPosition(entity, true)

    -- IMPORTANT: Ne PAS désactiver les collisions, sinon ox_target (raycasts) passe à travers la plante!
    SetEntityCollision(entity, true, true)

    entry.entity = entity
    attachTarget(entity, entry)
    exports.pop_inventory:registerDragTarget(entity, 'bouteille', function()
        TriggerServerEvent('pop_weed:water', plant.id)
    end)
    spawnedPlants[plant.id] = entry
end

local function removePlant(plantId)
    local entry = spawnedPlants[plantId]
    if not entry then return end

    if entry.uiId then
        exports.pop_v3dui:Remove(entry.uiId)
    end

    if DoesEntityExist(entry.entity) then
        exports.pop_inventory:unregisterDragTarget(entry.entity)
        exports.ox_target:removeLocalEntity(entry.entity)
        DeleteEntity(entry.entity)
    end
    spawnedPlants[plantId] = nil
end

-- ─────────────────────────────────────────────
-- Événements réseau
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:syncAll', function(plants, serverNow)
    for _, plant in pairs(plants) do
        spawnPlant(plant, serverNow)
    end
end)

RegisterNetEvent('pop_weed:spawnPlant', function(plant, serverNow)
    if pendingGhost then
        DeleteEntity(pendingGhost)
        pendingGhost = nil
    end
    if spawnedPlants[plant.id] then return end
    spawnPlant(plant, serverNow)
end)

RegisterNetEvent('pop_weed:removePlant', function(plantId)
    removePlant(plantId)
end)

RegisterNetEvent('pop_weed:updatePlant', function(plant, serverNow)
    local entry = spawnedPlants[plant.id]
    if not entry then return end

    local newStage = computeStage({ elapsedAtReceive = serverNow - plant.plantedAt, localReceivedAt = GetGameTimer() })
    if newStage == entry.stage then return end

    removePlant(plant.id)
    spawnPlant(plant, serverNow)
end)

-- ─────────────────────────────────────────────
-- Commande /plantweed
-- ─────────────────────────────────────────────

RegisterCommand('plantweed', function()
    local hash = GetHashKey(Config.Stages[1].model)
    lib.requestModel(hash)

    local pedCoords = GetEntityCoords(cache.ped)
    local heading   = GetEntityHeading(cache.ped)
    local rad       = math.pi / 180.0
    local spawnPos  = vector3(
        pedCoords.x - math.sin(heading * rad) * 1.5,
        pedCoords.y + math.cos(heading * rad) * 1.5,
        pedCoords.z - 1.05
    )

    local ghost = CreateObject(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
    SetEntityHeading(ghost, heading)

    local result = exports.object_gizmo:useGizmo(ghost)

    -- Le gizmo peut invalider le ghost : on le supprime quoi qu'il arrive
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end

    if not result then return end

    -- Respawn un placeholder à la position confirmée, visible jusqu'à la réponse serveur
    lib.requestModel(hash)
    pendingGhost = CreateObject(hash, result.position.x, result.position.y, result.position.z, false, false, false)
    SetEntityHeading(pendingGhost, result.rotation.z)
    SetEntityAlpha(pendingGhost, 180, false)
    FreezeEntityPosition(pendingGhost, true)
    SetEntityCollision(pendingGhost, false, false)

    TriggerServerEvent('pop_weed:plant', result.position.x, result.position.y, result.position.z, result.rotation.z)

    -- Fallback : supprime le placeholder après 3s si le serveur ne répond pas
    local ref = pendingGhost
    CreateThread(function()
        Wait(3000)
        if pendingGhost == ref then
            DeleteEntity(ref)
            pendingGhost = nil
        end
    end)
end, false)

-- ─────────────────────────────────────────────
-- Sync au démarrage
-- ─────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(500)
    TriggerServerEvent('pop_weed:requestSync')
end)

-- Notification depuis le serveur
RegisterNetEvent('pop_weed:notify', function(data)
    exports["pop_notify"]:ShowNotify(data)
end)

-- Utilisation de la bouteille d'eau depuis l'inventaire → arrose la plante la plus proche
RegisterNetEvent('pop_weed:useWaterBottle', function()
    local pedCoords = GetEntityCoords(cache.ped)
    local closest, closestDist = nil, 3.0  -- portée max 3m

    for id, entry in pairs(spawnedPlants) do
        if DoesEntityExist(entry.entity) then
            local d = #(pedCoords - GetEntityCoords(entry.entity))
            if d < closestDist then
                closest     = id
                closestDist = d
            end
        end
    end

    if not closest then
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-info', message = 'Aucune plante à proximité.', duration = 2000 })
        return
    end

    TriggerServerEvent('pop_weed:water', closest)
end)

-- Utilisation du pot depuis l'inventaire → lance le placement gizmo
RegisterNetEvent('pop_weed:usePot', function()
    if exports.pop_inventory:getItemCount('grainecana') < 1 then
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-info', message = 'Il vous faut une graine de cannabis pour utiliser ce pot.', duration = 3000 })
        return
    end

    local hash = GetHashKey(Config.Stages[1].model)
    lib.requestModel(hash)

    local pedCoords = GetEntityCoords(cache.ped)
    local heading   = GetEntityHeading(cache.ped)
    local rad       = math.pi / 180.0
    local spawnPos  = vector3(
        pedCoords.x - math.sin(heading * rad) * 1.5,
        pedCoords.y + math.cos(heading * rad) * 1.5,
        pedCoords.z
    )

    local ghost = CreateObject(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
    SetEntityHeading(ghost, heading)

    local result = exports.object_gizmo:useGizmo(ghost)

    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    if not result then return end

    lib.requestModel(hash)
    pendingGhost = CreateObject(hash, result.position.x, result.position.y, result.position.z, false, false, false)
    SetEntityHeading(pendingGhost, result.rotation.z)
    SetEntityAlpha(pendingGhost, 180, false)
    FreezeEntityPosition(pendingGhost, true)
    SetEntityCollision(pendingGhost, false, false)

    TriggerServerEvent('pop_weed:plant', result.position.x, result.position.y, result.position.z, result.rotation.z)

    local ref = pendingGhost
    CreateThread(function()
        Wait(3000)
        if pendingGhost == ref then
            DeleteEntity(ref)
            pendingGhost = nil
        end
    end)
end)

RegisterNetEvent('pop_weed:waterUpdate', function(plantId, wateredAt, serverNow)
    local entry = spawnedPlants[plantId]
    if not entry then return end
    entry.waterElapsedAtReceive = serverNow - wateredAt
    entry.localReceivedAt       = GetGameTimer()
end)

-- ─────────────────────────────────────────────
-- HUD 3D (croissance + eau)
-- ─────────────────────────────────────────────

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

-- Thread de détection de proximité (optimisé: check toutes les 500ms)
CreateThread(function()
    while true do
        local pedCoords = GetEntityCoords(cache.ped)
        local newNearby = {}

        for id, entry in pairs(spawnedPlants) do
            if DoesEntityExist(entry.entity) then
                local eCoords = GetEntityCoords(entry.entity)
                local dist = #(pedCoords - eCoords)
                if dist <= (Config.DrawDistance or 10.0) then
                    newNearby[id] = { id = id, coords = eCoords, dist = dist }
                end
            end
        end

        nearbyPlants = newNearby
        Wait(500)
    end
end)

-- Thread de rendu (uniquement quand des plantes sont proches)
CreateThread(function()
    while true do
        local hasNearby = false
        for id, data in pairs(nearbyPlants) do
            hasNearby = true
            local entry = spawnedPlants[id]
            if entry and DoesEntityExist(entry.entity) then
                if isReady(entry) then
                    -- Si prêt : on affiche le prompt pop_v3dui
                    if not entry.uiId then
                        entry.uiId = exports.pop_v3dui:Create({
                            coords = data.coords,
                            type = 'prompt',
                            content = {
                                key = 'E',
                                label = 'Récolter',
                                icon = 'fas fa-hand-holding-plant'
                            },
                            drawDistance = Config.DrawDistance,
                            offset = vector3(0, 0, 0.5)
                        })
                    end

                    -- Détection de l'appui sur E pour récolter (portée 2m)
                    if data.dist <= 2.0 and IsControlJustPressed(0, 38) then
                        harvestPlant(id)
                    end
                else
                    -- Sinon : on affiche le HUD de croissance
                    if entry.uiId then
                        exports.pop_v3dui:Remove(entry.uiId)
                        entry.uiId = nil
                    end

                    local visible, sx, sy = World3dToScreen2d(data.coords.x, data.coords.y, data.coords.z + 0.1)
                    if visible then
                        local growPct  = math.min(1.0, getElapsed(entry) / Config.TotalDuration)
                        local waterPct = getWaterLevel(entry)

                        -- Fond du panneau
                        local panelH = HUD.padTop + (0.016 + HUD.barH + 0.004) * 2 + HUD.padBot
                        DrawRect(sx, sy, HUD.panelW, panelH, 0, 0, 0, 170)

                        -- Ligne 1 : Croissance
                        local y1label = sy - panelH * 0.5 + HUD.padTop
                        local y1bar   = y1label + 0.016
                        drawHudLabel(sx - HUD.barW * 0.5, y1label - 0.007, ('Croissance   %d%%'):format(math.floor(growPct * 100)))
                        drawHudBar(sx, y1bar, growPct, 3, 163, 1)

                        -- Ligne 2 : Eau
                        local y2label = y1bar + HUD.barH + 0.004
                        local y2bar   = y2label + 0.016
                        drawHudLabel(sx - HUD.barW * 0.5, y2label - 0.007, ('Eau   %d%%'):format(math.floor(waterPct * 100)))
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(spawnedPlants) do removePlant(id) end
end)
