local plants  = {}
local nextId  = 1
local dataPath = GetResourcePath(GetCurrentResourceName()) .. '/data/plants.json'

-- ─────────────────────────────────────────────
-- Persistence
-- ─────────────────────────────────────────────

local dirty = false

-- Anti-abus : le joueur doit être à portée de la plante / du point de plantation
local function isNear(src, x, y, z, maxDist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - vec3(x, y, z)) <= maxDist
end

local function savePlants()
    dirty = false
    local list = {}
    for _, p in pairs(plants) do list[#list + 1] = p end
    local f = io.open(dataPath, 'w')
    if not f then
        print('^1[pop_weed] Impossible d\'écrire plants.json^7')
        return
    end
    f:write(json.encode(list))
    f:close()
end

local function loadPlants()
    local f = io.open(dataPath, 'r')
    if not f then return end
    local raw = f:read('*all')
    f:close()
    if not raw or raw == '' then return end
    local data = json.decode(raw)
    if not data then return end
    local count = 0
    for _, plant in pairs(data) do
        if type(plant) ~= 'table' or not plant.id then goto skip end
        if not plant.wateredAt then plant.wateredAt = plant.plantedAt end
        plants[plant.id] = plant
        if plant.id >= nextId then nextId = plant.id + 1 end
        count = count + 1
        ::skip::
    end
    print(('[pop_weed] %d plante(s) chargée(s)'):format(count))
end

-- ─────────────────────────────────────────────
-- Stage helper
-- ─────────────────────────────────────────────

local function computeStage(plantedAt)
    local elapsed = os.time() - plantedAt
    local stage   = 1
    for i, s in ipairs(Config.Stages) do
        if elapsed >= s.minTime then stage = i end
    end
    return stage
end

-- ─────────────────────────────────────────────
-- Startup
-- ─────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    loadPlants()
end)

-- ─────────────────────────────────────────────
-- Sync à la connexion
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:requestSync', function()
    TriggerClientEvent('pop_weed:syncAll', source, plants, os.time())
end)

-- ─────────────────────────────────────────────
-- Tick stage : vérification toutes les minutes
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, plant in pairs(plants) do
            -- Croissance suspendue si eau vide
            local water = math.max(0.0, 1.0 - (now - (plant.wateredAt or plant.plantedAt)) / Config.WaterDuration)
            if water > 0 then
                local newStage = computeStage(plant.plantedAt)
                if newStage ~= plant.stage then
                    -- Consommation d'eau : -50% par stade franchi
                    for _ = plant.stage + 1, newStage do
                        local currentWater = math.max(0.0, 1.0 - (now - (plant.wateredAt or plant.plantedAt)) / Config.WaterDuration)
                        local newWater = currentWater * 0.5
                        -- On recule le temps de l'arrosage pour simuler la perte d'eau afin d'arriver à newWater
                        plant.wateredAt = now - math.floor(Config.WaterDuration * (1.0 - newWater))
                    end

                    plant.stage = newStage
                    dirty = true
                    TriggerClientEvent('pop_weed:updatePlant', -1, plant, now)
                end
            end
        end
        -- Écriture disque uniquement si quelque chose a changé
        if dirty then savePlants() end
    end
end)

-- ─────────────────────────────────────────────
-- Arroser
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:water', function(plantId)
    local src   = source
    local plant = plants[plantId]
    if not plant then return end
    if not isNear(src, plant.x, plant.y, plant.z, 5.0) then return end

    if exports.pop_inventory:getItemCount(src, 'bouteille') < 1 then
        TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = "Il vous faut une bouteille d'eau.", duration = 3000 })
        return
    end

    exports.pop_inventory:removeItem(src, 'bouteille', 1)
    plant.wateredAt = os.time()
    savePlants()

    TriggerClientEvent('pop_weed:waterUpdate', -1, plantId, plant.wateredAt, plant.wateredAt)
    TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = 'Plante arrosée !', duration = 2000 })
end)

-- ─────────────────────────────────────────────
-- Planter
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:plant', function(x, y, z, heading)
    local src = source
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading) or 0.0
    if not x or not y or not z or not isNear(src, x, y, z, 15.0) then return end

    local potCount  = exports.pop_inventory:getItemCount(src, 'pot')
    local seedCount = exports.pop_inventory:getItemCount(src, 'grainecana')

    if potCount < 1 then
        TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = 'Il vous faut un pot.', duration = 3000 })
        return
    end
    if seedCount < 1 then
        TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = 'Il vous faut une graine de cannabis.', duration = 3000 })
        return
    end

    exports.pop_inventory:removeItem(src, 'pot',        1)
    exports.pop_inventory:removeItem(src, 'grainecana', 1)

    local id    = nextId
    nextId      = nextId + 1
    local now   = os.time()
    local plant = {
        id        = id,
        x         = x,
        y         = y,
        z         = z,
        heading   = heading,
        plantedAt = now,
        wateredAt = now,
        stage     = 1,
    }
    plants[id] = plant
    savePlants()

    TriggerClientEvent('pop_weed:spawnPlant', -1, plant, os.time())
    TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = 'Plante mise en terre !', duration = 3000 })
end)

-- ─────────────────────────────────────────────
-- Récolter
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:harvest', function(plantId)
    local src   = source
    local plant = plants[plantId]

    if not plant then return end
    if not isNear(src, plant.x, plant.y, plant.z, 5.0) then return end

    if computeStage(plant.plantedAt) < #Config.Stages then
        TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = 'La plante n\'est pas encore prête.', duration = 3000 })
        return
    end

    local amount = math.random(2, 3)
    exports.pop_inventory:addItem(src, 'weed', amount)
    plants[plantId] = nil
    savePlants()

    TriggerClientEvent('pop_weed:removePlant', -1, plantId)
    TriggerClientEvent('pop_weed:notify', src, { icon = 'fas fa-info', message = ('Récolte : <b>%d weed</b> obtenus.'):format(amount), duration = 4000 })
end)
