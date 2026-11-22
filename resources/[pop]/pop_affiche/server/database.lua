-- Création de la table pop_affiche et mise à niveau de la colonne image_url.

CreateThread(function()
    local success, err = pcall(function()
        -- 1. La table doit exister
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS pop_affiche (
                id INT AUTO_INCREMENT PRIMARY KEY,
                pos VARCHAR(255) NOT NULL,
                normal VARCHAR(255) NOT NULL,
                width FLOAT NOT NULL,
                height FLOAT NOT NULL
            )
        ]])

        -- 2. Colonnes existantes
        local columns = MySQL.query.await("DESCRIBE pop_affiche")
        local hasImageUrl, hasUrl = false, false
        if columns then
            for _, col in ipairs(columns) do
                if col.Field == 'image_url' then
                    hasImageUrl = true
                elseif col.Field == 'url' then
                    hasUrl = true
                end
            end
        end

        -- 3. Correction de la structure si besoin
        if not hasImageUrl and hasUrl then
            Affiche.Debug("^3[Affiche]^7 Colonne 'url' detectee, renommage en 'image_url' pour correspondre au script...")
            MySQL.query.await("ALTER TABLE pop_affiche CHANGE url image_url VARCHAR(2048) NOT NULL")
            Affiche.Debug("^2[Affiche]^7 Renommage de la colonne reussi !")
        elseif not hasImageUrl and not hasUrl then
            Affiche.Debug("^3[Affiche]^7 Colonne 'image_url' manquante, ajout de la colonne...")
            MySQL.query.await("ALTER TABLE pop_affiche ADD COLUMN image_url VARCHAR(2048) NOT NULL")
            Affiche.Debug("^2[Affiche]^7 Ajout de la colonne reussi !")
        else
            Affiche.Debug("^2[Affiche]^7 Colonne 'image_url' deja presente et valide.")
        end
    end)
    if success then
        Affiche.Debug("^2[Affiche]^7 Initialisation de la base de donnees et verification de la structure reussies.")
    else
        Affiche.Debug("^1[Affiche-SQL-Error]^7 Echec de l'initialisation/verification de la table pop_affiche : %s", tostring(err))
    end
end)
