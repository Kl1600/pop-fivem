-- Création de la table pop_boards et de la colonne propriétaire (si absentes).

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS pop_boards (
            id INT AUTO_INCREMENT PRIMARY KEY,
            url LONGTEXT NOT NULL,
            pos VARCHAR(255) NOT NULL,
            normal VARCHAR(255) NOT NULL,
            width FLOAT NOT NULL,
            height FLOAT NOT NULL,
            resW INT DEFAULT 1024,
            resH INT DEFAULT 1024,
            fitType VARCHAR(50) DEFAULT 'fill',
            corners LONGTEXT
        )
    ]])
end)

CreateThread(function()
    Wait(1000)
    pcall(function()
        MySQL.query.await('ALTER TABLE pop_boards ADD COLUMN IF NOT EXISTS owner VARCHAR(64) DEFAULT NULL')
    end)
end)
