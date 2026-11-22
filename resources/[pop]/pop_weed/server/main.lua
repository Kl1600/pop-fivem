-- Démarrage, synchronisation des clients et croissance des plantes.

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Weed.Load()
end)

-- ─────────────────────────────────────────────
-- Sync à la connexion
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_weed:requestSync', function()
    local now = os.time()
    local list = {}
    for id, plant in pairs(Weed.plants) do
        Weed.UpdateGrowth(plant, now)
        list[id] = Weed.ClientView(plant)
    end
    TriggerClientEvent('pop_weed:syncAll', source, list, now)
end)

-- ─────────────────────────────────────────────
-- Tick stage (Config.TickInterval)
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(Config.TickInterval)
        local now = os.time()
        for _, plant in pairs(Weed.plants) do
            -- Croissance suspendue si eau vide (UpdateGrowth ne compte que le temps arrosé)
            Weed.UpdateGrowth(plant, now)
            local newStage = Weed.ComputeStage(plant)
            if newStage ~= plant.stage then
                -- Consommation d'eau : -50% par stade franchi
                for _ = plant.stage + 1, newStage do
                    local currentWater = math.max(0.0, 1.0 - (now - (plant.wateredAt or plant.plantedAt)) / Config.WaterDuration)
                    local newWater = currentWater * Config.WaterLossPerStage
                    -- On recule le temps de l'arrosage pour simuler la perte d'eau afin d'arriver à newWater
                    plant.wateredAt = now - math.floor(Config.WaterDuration * (1.0 - newWater))
                end

                plant.stage = newStage
                Weed.dirty = true
                TriggerClientEvent('pop_weed:updatePlant', -1, Weed.ClientView(plant), now)
            end
        end
        -- Écriture disque uniquement si quelque chose a changé
        if Weed.dirty then Weed.Save() end
    end
end)
