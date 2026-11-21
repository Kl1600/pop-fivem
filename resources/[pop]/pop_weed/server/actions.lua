-- Actions des joueurs : arroser, planter, récolter.

local Items = Config.Items
local D = Config.NotifyDuration

-- ─────────────────────────────────────────────
-- Arroser
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:water', function(plantId)
    local src   = source
    local plant = Weed.plants[plantId]
    if not plant then return end
    if not Bridge.IsNear(src, plant, Config.ActionDistance) then return end

    if Bridge.GetItemCount(src, Items.Water) < 1 then
        Weed.Notify(src, L('need_water_bottle'), D.Normal)
        return
    end

    Bridge.RemoveItem(src, Items.Water, 1)
    local now = os.time()
    Weed.UpdateGrowth(plant, now) -- fige la croissance acquise avant de remettre l'eau
    plant.wateredAt = now
    Weed.Save()

    TriggerClientEvent('pop_weed:waterUpdate', -1, plantId, plant.wateredAt, plant.wateredAt)
    Weed.Notify(src, L('plant_watered'), D.Short)
end)

-- ─────────────────────────────────────────────
-- Planter
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:plant', function(x, y, z, heading)
    local src = source
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading) or 0.0
    if not x or not y or not z or not Bridge.IsNear(src, vector3(x, y, z), Config.PlantDistance) then return end

    -- Limite de plantes par joueur
    local owner = Weed.OwnerOf(src)
    local maxPlants = Config.MaxPlantsPerPlayer or 0
    if maxPlants > 0 then
        local owned = 0
        for _, p in pairs(Weed.plants) do
            if p.owner == owner then owned = owned + 1 end
        end
        if owned >= maxPlants then
            Weed.Notify(src, L('max_plants', owned), D.Normal)
            return
        end
    end

    local potCount  = Bridge.GetItemCount(src, Items.Pot)
    local seedCount = Bridge.GetItemCount(src, Items.Seed)

    if potCount < 1 then
        Weed.Notify(src, L('need_pot'), D.Normal)
        return
    end
    if seedCount < 1 then
        Weed.Notify(src, L('need_seed'), D.Normal)
        return
    end

    Bridge.RemoveItem(src, Items.Pot,  1)
    Bridge.RemoveItem(src, Items.Seed, 1)

    local id    = Weed.nextId
    Weed.nextId = Weed.nextId + 1
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
        growth    = 0,
        lastTick  = now,
        owner     = owner,
    }
    Weed.plants[id] = plant
    Weed.Save()

    TriggerClientEvent('pop_weed:spawnPlant', -1, Weed.ClientView(plant), now)
    Weed.Notify(src, L('plant_planted'), D.Normal)
end)

-- ─────────────────────────────────────────────
-- Récolter
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:harvest', function(plantId)
    local src   = source
    local plant = Weed.plants[plantId]

    if not plant then return end
    if not Bridge.IsNear(src, plant, Config.ActionDistance) then return end

    Weed.UpdateGrowth(plant, os.time())
    if Weed.ComputeStage(plant) < #Config.Stages then
        Weed.Notify(src, L('plant_not_ready'), D.Normal)
        return
    end

    local amount = math.max(1, math.floor(tonumber(Config.HarvestAmount) or 1))
    Bridge.AddItem(src, Items.Harvest, amount)
    Weed.plants[plantId] = nil
    Weed.Save()

    TriggerClientEvent('pop_weed:removePlant', -1, plantId)
    Weed.Notify(src, L('harvest_done', amount), D.Long)
end)
