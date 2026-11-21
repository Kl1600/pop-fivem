-- Tables SQL (crews, crew_members) et chargement en mémoire au démarrage.

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crews (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            name       VARCHAR(16) NOT NULL UNIQUE,
            label      VARCHAR(32) NOT NULL,
            owner      VARCHAR(64) NOT NULL,
            color      VARCHAR(24) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_members (
            identifier VARCHAR(64) PRIMARY KEY,
            crew_id    INT NOT NULL,
            `rank`     VARCHAR(16) DEFAULT 'member',
            name       VARCHAR(64) DEFAULT NULL,
            joined_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    -- Compat anciennes installs : ajoute la colonne name si absente
    pcall(function() MySQL.query.await('ALTER TABLE crew_members ADD COLUMN name VARCHAR(64) DEFAULT NULL') end)

    for _, c in ipairs(MySQL.query.await('SELECT * FROM crews') or {}) do
        c.color = Crew.DecodeColor(c.color)
        -- Crews créés avant le filtrage : on nettoie l'affichage
        local lbl = Crew.CleanLabel(c.label)
        c.label = (lbl ~= '' and lbl) or c.name
        Crew.crewsById[c.id] = c
    end
    for _, m in ipairs(MySQL.query.await('SELECT identifier, crew_id FROM crew_members') or {}) do
        Crew.memberOf[m.identifier] = m.crew_id
    end
end)
