-- pop_enterprisegarage — table et flotte initiale

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS enterprise_garage_vehicles (
            id     INT AUTO_INCREMENT PRIMARY KEY,
            garage VARCHAR(64)  NOT NULL,
            job    VARCHAR(64)  NOT NULL,
            model  VARCHAR(64)  NOT NULL,
            label  VARCHAR(64),
            plate  VARCHAR(12)  NOT NULL UNIQUE,
            state  VARCHAR(12)  NOT NULL DEFAULT 'in',
            props  LONGTEXT,
            INDEX idx_garage (garage),
            INDEX idx_job (job)
        )
    ]], {}, function()
        -- Seed : insère la flotte configurée uniquement si le garage est vide.
        for _, g in ipairs(Config.Garages) do
            MySQL.scalar('SELECT COUNT(*) FROM enterprise_garage_vehicles WHERE garage = ?', { g.label }, function(count)
                if (count or 0) > 0 then return end
                CreateThread(function()
                    for _, v in ipairs(g.vehicles or {}) do
                        MySQL.insert(
                            'INSERT INTO enterprise_garage_vehicles (garage, job, model, label, plate, state) VALUES (?, ?, ?, ?, ?, ?)',
                            { g.label, g.job, v.model, v.label or v.model, Garage.UniquePlate(), 'in' }
                        )
                    end
                    if Config.Debug then print(L('debug_fleet_seeded', g.label, #(g.vehicles or {}))) end
                end)
            end)
        end
    end)
end)
