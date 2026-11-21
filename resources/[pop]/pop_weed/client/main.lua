-- pop_weed client : synchro des plantes, streaming des props locaux, targets, carte d'info, alerte police.

local RES = GetCurrentResourceName()

-- Plantes connues : [id] = PlantData (lue aussi par client/placement.lua).
WeedPlants = {}

local entities = {}  -- [id] = { entity, targetId, stage }
local blips = {}     -- [blip] = true (alertes police)
local isPolice = false

local ANIM_GARDEN = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 }
local ANIM_WATER = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 1 }

------------------------------------------------------------------------
-- Heure serveur
------------------------------------------------------------------------

local syncNow, syncTimer = 0, 0

local function setNow(now)
    if type(now) == 'number' then syncNow, syncTimer = now, GetGameTimer() end
end

local function ServerNow()
    return syncNow + (GetGameTimer() - syncTimer) / 1000
end

------------------------------------------------------------------------
-- Police
------------------------------------------------------------------------

-- Config.Police.jobs : liste de noms ({ 'police' }) ou table à grades ({ police = 2 }).
local function computeIsPolice(job)
    if type(job) ~= 'table' or not job.onDuty or not job.name then return false end
    local jobs = Config.Police.jobs
    if type(jobs) == 'string' then return job.name == jobs end
    if type(jobs) ~= 'table' then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' then
            if v == job.name then return true end
        elseif k == job.name then
            return (tonumber(job.grade) or 0) >= (tonumber(v) or 0)
        end
    end
    return false
end

local lastPoliceCheck = -5000

-- Au plus une lecture du job toutes les 5 s (force = true : tout de suite).
local function refreshPolice(force)
    local t = GetGameTimer()
    if not force and t - lastPoliceCheck < 5000 then return end
    lastPoliceCheck = t
    isPolice = computeIsPolice(Bridge.GetJob())
end

------------------------------------------------------------------------
-- Actions (targets)
------------------------------------------------------------------------

local function runAction(id, entity, duration, label, anim, callbackName)
    if Bridge.IsBusy() then
        Bridge.Notify(L('busy'), 'error')
        return
    end
    if entity and DoesEntityExist(entity) then
        TaskTurnPedToFaceEntity(PlayerPedId(), entity, 500)
        Wait(500)
    end
    if not Bridge.Progress(label, duration, { anim = anim }) then return end
    local ok, reason, arg = Callback.Await(callbackName, id)
    if not ok then
        Bridge.Notify(L(type(reason) == 'string' and reason or 'error', arg), 'error')
    end
end

local function buildOptions(id)
    return {
        {
            label = L('target_water'),
            icon = 'fa-solid fa-droplet',
            distance = Plant.TARGET_DISTANCE,
            canInteract = function()
                local p = WeedPlants[id]
                if not p then return false end
                local now = ServerNow()
                return not Plant.IsReady(p, now) and Plant.Water(p, now) < Plant.THIRSTY_BELOW
            end,
            onSelect = function(entity)
                runAction(id, entity, Config.Durations.water, L('watering'), ANIM_WATER, 'pop_weed:water')
            end,
        },
        {
            label = L('target_fertilize'),
            icon = 'fa-solid fa-flask',
            distance = Plant.TARGET_DISTANCE,
            canInteract = function()
                local p = WeedPlants[id]
                return p ~= nil and not p.fertilized and not Plant.IsReady(p, ServerNow())
            end,
            onSelect = function(entity)
                runAction(id, entity, Config.Durations.fertilize, L('fertilizing'), ANIM_GARDEN, 'pop_weed:fertilize')
            end,
        },
        {
            label = L('target_harvest'),
            icon = 'fa-solid fa-scissors',
            distance = Plant.TARGET_DISTANCE,
            canInteract = function()
                local p = WeedPlants[id]
                -- p.mine : envoyé par le serveur au seul planteur (le propriétaire n'est jamais transmis).
                return p ~= nil and Plant.IsReady(p, ServerNow()) and (not Config.OwnerOnly or p.mine == true)
            end,
            onSelect = function(entity)
                runAction(id, entity, Config.Durations.harvest, L('harvesting'), ANIM_GARDEN, 'pop_weed:harvest')
            end,
        },
        {
            label = L('target_destroy'),
            icon = 'fa-solid fa-trash',
            distance = Plant.TARGET_DISTANCE,
            canInteract = function()
                return isPolice and WeedPlants[id] ~= nil
            end,
            onSelect = function(entity)
                runAction(id, entity, Config.Durations.destroy, L('destroying'), ANIM_GARDEN, 'pop_weed:destroy')
            end,
        },
    }
end

------------------------------------------------------------------------
-- Props locaux
------------------------------------------------------------------------

--- Charge un modèle (3 s max). Partagé avec client/placement.lua.
function WeedLoadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    if HasModelLoaded(hash) then return true end
    SetModelAsNoLongerNeeded(hash)
    return false
end

local function despawn(id)
    local e = entities[id]
    if not e then return end
    entities[id] = nil
    if e.targetId then Bridge.Target.Remove(e.targetId) end
    if DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
end

-- Crée (ou remplace) le prop d'une plante au stade courant.
local function spawn(id)
    local p = WeedPlants[id]
    if not p then return end
    local stage = Plant.Stage(p, ServerNow())
    local cfg = Config.Stages[stage]
    if not cfg then return end
    local hash = joaat(cfg.model)
    if not WeedLoadModel(hash) then return end

    -- La plante a pu changer pendant le chargement du modèle.
    p = WeedPlants[id]
    if not p then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    despawn(id)

    local obj = CreateObject(hash, p.x + 0.0, p.y + 0.0, p.z + (cfg.offset or 0.0), false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if obj == 0 then return end
    SetEntityHeading(obj, (p.heading or 0.0) + 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, true, true)

    entities[id] = { entity = obj, stage = stage, targetId = Bridge.Target.AddLocalEntity(obj, buildOptions(id)) }
end

------------------------------------------------------------------------
-- Carte d'info
------------------------------------------------------------------------

local info = { shown = false }

local function hideInfo()
    if not info.shown then return end
    info.shown = false
    SendNUIMessage({ action = 'pop_weed:info', show = false })
end

local function showInfo(p, now)
    local stage = Plant.Stage(p, now)
    local growth = math.floor(Plant.Progress(p, now) * 100)
    local water = math.floor(Plant.Water(p, now) + 0.5)
    local quality = math.floor(Plant.Quality(p, now) + 0.5)
    local fertilized = p.fertilized == true
    local ready = Plant.IsReady(p, now)

    if info.shown and info.stage == stage and info.growth == growth and info.water == water
        and info.quality == quality and info.fertilized == fertilized and info.ready == ready then
        return
    end
    info.shown, info.stage, info.growth, info.water = true, stage, growth, water
    info.quality, info.fertilized, info.ready = quality, fertilized, ready

    SendNUIMessage({
        action = 'pop_weed:info', show = true,
        stage = stage, stages = #Config.Stages, growth = growth, water = water, quality = quality,
        fertilized = fertilized, ready = ready,
    })
end

------------------------------------------------------------------------
-- Boucle unique (adaptative) : streaming + carte d'info
------------------------------------------------------------------------

CreateThread(function()
    local toSpawn = {}
    while true do
        if next(WeedPlants) == nil then
            hideInfo()
            Wait(2000)
        else
            local pos = GetEntityCoords(PlayerPedId())
            local now = ServerNow()
            local spawnDist, despawnDist = Config.SpawnDistance, Config.SpawnDistance + 10.0
            local nearest, nearestCreated, infoPlant = math.huge, math.huge, nil
            local count = 0

            -- Pas d'attente dans ce parcours : les créations sont faites après.
            for id, p in pairs(WeedPlants) do
                local dx, dy, dz = pos.x - p.x, pos.y - p.y, pos.z - p.z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < nearest then nearest = d end
                local e = entities[id]
                if e then
                    if d > despawnDist then
                        despawn(id)
                    else
                        if Plant.Stage(p, now) ~= e.stage then
                            count = count + 1
                            toSpawn[count] = id
                        end
                        if d < nearestCreated then nearestCreated, infoPlant = d, p end
                    end
                elseif d <= spawnDist then
                    count = count + 1
                    toSpawn[count] = id
                end
            end

            for i = 1, count do
                spawn(toSpawn[i])
                toSpawn[i] = nil
            end

            if infoPlant and nearestCreated <= Plant.INFO_DISTANCE and not Bridge.IsBusy() then
                -- Près d'une plante : rafraîchit aussi le statut police (prise de service sans event de job).
                refreshPolice()
                showInfo(infoPlant, ServerNow())
            else
                hideInfo()
            end

            Wait(nearest <= Plant.INFO_DISTANCE and 250 or nearest <= spawnDist and 1000 or 2000)
        end
    end
end)

------------------------------------------------------------------------
-- Chargement et synchro
------------------------------------------------------------------------

local function loadPlants()
    local plants, now = Callback.Await('pop_weed:getPlants')
    if type(plants) ~= 'table' then return end
    setNow(now)
    for id in pairs(entities) do despawn(id) end
    for id in pairs(WeedPlants) do WeedPlants[id] = nil end
    for _, p in ipairs(plants) do
        if type(p) == 'table' and p.id then WeedPlants[p.id] = p end
    end
end

Bridge.OnPlayerLoaded(function()
    refreshPolice(true)
    loadPlants()
end)

Bridge.OnJobUpdate(function(job)
    isPolice = computeIsPolice(job)
    lastPoliceCheck = GetGameTimer()
end)

RegisterNetEvent('pop_weed:client:plantAdded', function(plant, now)
    if type(plant) ~= 'table' or not plant.id or WeedPlants[plant.id] then return end
    setNow(now)
    WeedPlants[plant.id] = plant
end)

RegisterNetEvent('pop_weed:client:plantUpdated', function(plant, now)
    if type(plant) ~= 'table' or not plant.id or not WeedPlants[plant.id] then return end
    setNow(now)
    plant.mine = WeedPlants[plant.id].mine
    WeedPlants[plant.id] = plant
end)

RegisterNetEvent('pop_weed:client:plantRemoved', function(id)
    if id == nil or not WeedPlants[id] then return end
    WeedPlants[id] = nil
    despawn(id)
end)

------------------------------------------------------------------------
-- Alerte police
------------------------------------------------------------------------

local function removeBlip(blip)
    if not blips[blip] then return end
    blips[blip] = nil
    if DoesBlipExist(blip) then RemoveBlip(blip) end
end

RegisterNetEvent('pop_weed:client:policeAlert', function(coords)
    if type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not (x and y and z) then return end

    Bridge.Notify(L('police_alert'), 'warning')

    local blip = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)
    SetBlipSprite(blip, 140)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('police_blip'))
    EndTextCommandSetBlipName(blip)
    blips[blip] = true

    SetTimeout((tonumber(Config.Police.blipTime) or 60) * 1000, function() removeBlip(blip) end)
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id in pairs(entities) do despawn(id) end
    for blip in pairs(blips) do removeBlip(blip) end
    SendNUIMessage({ action = 'pop_weed:info', show = false })
    SendNUIMessage({ action = 'pop_weed:placement', show = false })
end)
