-- Plantes côté client : calcul de croissance, props, cible ox_target, évènements réseau.

Weed = {}

Weed.plants       = {}  -- [plantId] = { entity, stage, elapsedAtReceive, localReceivedAt }
Weed.pendingGhost = nil -- placeholder visible en attendant la réponse serveur

local ICON = 'fas fa-info'

--- Notification au style d'origine (icône info, sans titre).
function Weed.Notify(message, duration)
    Bridge.Notify({ icon = ICON, message = message, duration = duration })
end

-- ─────────────────────────────────────────────
-- Helpers  (pas d'os.time() côté client FiveM)
-- elapsedAtReceive = secondes écoulées au moment où le client a reçu les données (calculé par le serveur)
-- localReceivedAt  = GetGameTimer() au moment de la réception (ms)
-- ─────────────────────────────────────────────

-- La croissance n'avance que tant qu'il reste de l'eau (même règle que le serveur)
function Weed.GetElapsed(entry)
    local delta = (GetGameTimer() - entry.localReceivedAt) / 1000.0
    local waterLeft = math.max(0.0, Config.WaterDuration - (entry.waterElapsedAtReceive or 0))
    return entry.elapsedAtReceive + math.min(delta, waterLeft)
end

function Weed.ComputeStage(entry)
    local elapsed = Weed.GetElapsed(entry)
    local stage   = 1
    for i, s in ipairs(Config.Stages) do
        if elapsed >= s.minTime then stage = i end
    end
    return stage
end

local function getWaterElapsed(entry)
    return entry.waterElapsedAtReceive + (GetGameTimer() - entry.localReceivedAt) / 1000.0
end

function Weed.GetWaterLevel(entry)
    return math.max(0.0, 1.0 - getWaterElapsed(entry) / Config.WaterDuration)
end

function Weed.IsReady(entry)
    return Weed.GetElapsed(entry) >= Config.TotalDuration
end

local function getPct(entry)
    return math.min(100, math.floor(Weed.GetElapsed(entry) / Config.TotalDuration * 100))
end

-- ─────────────────────────────────────────────
-- Récolte
-- ─────────────────────────────────────────────

function Weed.HarvestPlant(id)
    local entry = Weed.plants[id]
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
        duration = Config.HarvestDuration,
        label    = L('harvest_progress'),
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

-- ─────────────────────────────────────────────
-- Cible (ox_target direct : noms d'options et retrait par entité conservés)
-- ─────────────────────────────────────────────

local function attachTarget(entity, entry)
    local id = entry.data.id
    exports.ox_target:addLocalEntity(entity, {
        {
            name     = 'weed_examine_' .. id,
            icon     = 'fas fa-info',
            label    = L('target_examine'),
            onSelect = function()
                Weed.Notify(L('growth_notify', getPct(entry)), Config.NotifyDuration.Normal)
            end,
        },
        {
            name        = 'weed_harvest_' .. id,
            icon        = 'fas fa-hand-holding-plant',
            label       = L('target_harvest'),
            canInteract = function() return Weed.IsReady(entry) end,
            onSelect    = function()
                Weed.HarvestPlant(id)
            end,
        },
    })
end

-- ─────────────────────────────────────────────
-- Spawn / suppression de prop
-- ─────────────────────────────────────────────

-- Création du prop (uniquement quand le joueur est proche, voir thread de proximité)
function Weed.CreateProp(entry)
    local plant    = entry.data
    entry.stage    = Weed.ComputeStage(entry)
    local stageCfg = Config.Stages[entry.stage]
    local hash     = GetHashKey(stageCfg.model)
    if not IsModelInCdimage(hash) then return end
    if not pcall(lib.requestModel, hash, 5000) then return end

    local zPos   = plant.z + (Config.ZOffset or 0.0) + (stageCfg.zOffset or 0.0)
    local entity = CreateObject(hash, plant.x, plant.y, zPos, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(entity, plant.heading)
    FreezeEntityPosition(entity, true)

    -- IMPORTANT: Ne PAS désactiver les collisions, sinon ox_target (raycasts) passe à travers la plante!
    SetEntityCollision(entity, true, true)

    entry.entity = entity
    attachTarget(entity, entry)
    -- pop_inventory direct : glisser la bouteille sur la plante pour l'arroser
    exports.pop_inventory:registerDragTarget(entity, Config.Items.Water, function()
        TriggerServerEvent('pop_weed:water', plant.id)
    end)
end

function Weed.DeleteProp(entry)
    if entry.uiId then
        exports.pop_v3dui:Remove(entry.uiId)
        entry.uiId = nil
    end

    if entry.entity and DoesEntityExist(entry.entity) then
        exports.pop_inventory:unregisterDragTarget(entry.entity)
        exports.ox_target:removeLocalEntity(entry.entity)
        DeleteEntity(entry.entity)
    end
    entry.entity = nil
end

local function spawnPlant(plant, serverNow)
    local entry = {
        data                  = plant,
        elapsedAtReceive      = plant.growth or (serverNow - plant.plantedAt),
        waterElapsedAtReceive = serverNow - (plant.wateredAt or plant.plantedAt),
        localReceivedAt       = GetGameTimer(),
        stage                 = 1,
    }
    entry.stage = Weed.ComputeStage(entry)
    Weed.plants[plant.id] = entry

    -- Prop créé tout de suite si le joueur est déjà à portée
    if #(GetEntityCoords(cache.ped) - vec3(plant.x, plant.y, plant.z)) <= (Config.SpawnDistance or 80.0) then
        Weed.CreateProp(entry)
    end
end

local function removePlant(plantId)
    local entry = Weed.plants[plantId]
    if not entry then return end
    Weed.DeleteProp(entry)
    Weed.plants[plantId] = nil
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
    if Weed.pendingGhost then
        DeleteEntity(Weed.pendingGhost)
        Weed.pendingGhost = nil
    end
    if Weed.plants[plant.id] then return end
    spawnPlant(plant, serverNow)
end)

RegisterNetEvent('pop_weed:removePlant', function(plantId)
    removePlant(plantId)
end)

RegisterNetEvent('pop_weed:updatePlant', function(plant, serverNow)
    local entry = Weed.plants[plant.id]
    if not entry then return end

    local newStage = Weed.ComputeStage({
        elapsedAtReceive      = plant.growth or (serverNow - plant.plantedAt),
        waterElapsedAtReceive = serverNow - (plant.wateredAt or plant.plantedAt),
        localReceivedAt       = GetGameTimer(),
    })
    if newStage == entry.stage then return end

    removePlant(plant.id)
    spawnPlant(plant, serverNow)
end)

RegisterNetEvent('pop_weed:waterUpdate', function(plantId, wateredAt, serverNow)
    local entry = Weed.plants[plantId]
    if not entry then return end
    entry.elapsedAtReceive      = Weed.GetElapsed(entry) -- garde la croissance acquise
    entry.waterElapsedAtReceive = serverNow - wateredAt
    entry.localReceivedAt       = GetGameTimer()
end)

-- Ancien évènement de notification (gardé pour compatibilité : le serveur passe par le bridge)
RegisterNetEvent('pop_weed:notify', function(data)
    Bridge.Notify(data)
end)

-- Utilisation de la bouteille d'eau depuis l'inventaire → arrose la plante la plus proche
RegisterNetEvent('pop_weed:useWaterBottle', function()
    local pedCoords = GetEntityCoords(cache.ped)
    local closest, closestDist = nil, Config.WaterBottleRange

    for id, entry in pairs(Weed.plants) do
        if DoesEntityExist(entry.entity) then
            local d = #(pedCoords - GetEntityCoords(entry.entity))
            if d < closestDist then
                closest     = id
                closestDist = d
            end
        end
    end

    if not closest then
        Weed.Notify(L('no_plant_nearby'), Config.NotifyDuration.Short)
        return
    end

    TriggerServerEvent('pop_weed:water', closest)
end)

-- ─────────────────────────────────────────────
-- Sync au démarrage / nettoyage à l'arrêt
-- ─────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(500)
    TriggerServerEvent('pop_weed:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Weed.plants) do removePlant(id) end
end)
