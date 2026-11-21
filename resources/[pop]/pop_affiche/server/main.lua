-- pop_affiche - server/main.lua
local ESX = exports['es_extended']:getSharedObject()

-- --- CONFIGURATION VIP ---
-- Configurez ici comment le statut VIP est détecté et quels groupes y ont accès.
Config = {
    VIPCheckMethod = 'group', -- Options : 'group' (via ESX getGroup()) ou 'custom' (votre propre logique)
    
    -- Liste des groupes autorisés à utiliser les affiches (si VIPCheckMethod = 'group')
    VIPGroups = {
        ['vip'] = true,
        ['vip_gold'] = true,
        ['vip_diamond'] = true,
        ['admin'] = true,      -- Les administrateurs ont l'autorisation par défaut
        ['superadmin'] = true,
    }
}

-- Fonction globale de vérification du statut VIP du joueur
local function IsPlayerVIP(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    if Config.VIPCheckMethod == 'group' then
        local playerGroup = xPlayer.getGroup()
        if Config.VIPGroups[playerGroup] then
            return true
        end
    elseif Config.VIPCheckMethod == 'custom' then
        -- Écrivez votre propre logique de vérification VIP personnalisée ici
        -- Exemple : si vous utilisez un champ 'vip' dans la table 'users'
        -- return xPlayer.get('vip') == 1 or xPlayer.get('vip') == true
    end

    return false
end

-- Callback serveur pour vérifier si le client est VIP
lib.callback.register('pop_affiche:server:isVIP', function(source)
    return IsPlayerVIP(source)
end)

-- Initialisation et restructuration automatique de la base de données
CreateThread(function()
    local success, err = pcall(function()
        -- 1. On s'assure d'abord que la table existe
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS pop_affiche (
                id INT AUTO_INCREMENT PRIMARY KEY,
                pos VARCHAR(255) NOT NULL,
                normal VARCHAR(255) NOT NULL,
                width FLOAT NOT NULL,
                height FLOAT NOT NULL
            )
        ]])
        
        -- 2. On inspecte les colonnes existantes de pop_affiche pour s'adapter dynamiquement
        local columns = MySQL.query.await("DESCRIBE pop_affiche")
        local hasImageUrl = false
        local hasUrl = false
        if columns then
            for _, col in ipairs(columns) do
                if col.Field == 'image_url' then
                    hasImageUrl = true
                elseif col.Field == 'url' then
                    hasUrl = true
                end
            end
        end

        -- 3. Adaptation/Correction dynamique de la structure
        if not hasImageUrl and hasUrl then
            print("^3[Affiche]^7 Colonne 'url' detectee, renommage en 'image_url' pour correspondre au script...")
            MySQL.query.await("ALTER TABLE pop_affiche CHANGE url image_url VARCHAR(2048) NOT NULL")
            print("^2[Affiche]^7 Renommage de la colonne reussi !")
        elseif not hasImageUrl and not hasUrl then
            print("^3[Affiche]^7 Colonne 'image_url' manquante, ajout de la colonne...")
            MySQL.query.await("ALTER TABLE pop_affiche ADD COLUMN image_url VARCHAR(2048) NOT NULL")
            print("^2[Affiche]^7 Ajout de la colonne reussi !")
        else
            print("^2[Affiche]^7 Colonne 'image_url' deja presente et valide.")
        end
    end)
    if success then
        print("^2[Affiche]^7 Initialisation de la base de donnees et verification de la structure reussies.")
    else
        print("^1[Affiche-SQL-Error]^7 Echec de l'initialisation/verification de la table pop_affiche : " .. tostring(err))
    end
end)

lib.callback.register('pop_affiche:server:getAffiches', function(source)
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM pop_affiche')
    end)
    if success then
        return result
    else
        print("^1[Affiche-SQL-Error]^7 Echec getAffiches : " .. tostring(result))
        return {}
    end
end)

RegisterNetEvent('pop_affiche:server:saveAffiche', function(data)
    local src = source
    
    -- Sécurité serveur : Vérification du statut VIP avant enregistrement
    if not IsPlayerVIP(src) then
        print("^1[Affiche-Hack-Warning]^7 Tentative d'enregistrement d'affiche sans statut VIP par " .. GetPlayerName(src) .. " (ID: " .. tostring(src) .. ")")
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Seuls les membres VIP peuvent poser des affiches !' })
        return
    end

    if type(data) ~= 'table' or type(data.image_url) ~= 'string' or data.image_url == '' then
        print("^1[Affiche]^7 image_url manquant ou vide")
        return
    end
    if string.len(data.image_url) > 2048 then
        return
    end
    if data.dbId ~= nil and type(data.dbId) ~= 'number' then return end
    if not data.dbId then
        -- Validation de la nouvelle affiche (taille et distance du joueur)
        local p = data.pos
        if type(p) ~= 'table' or type(p.x) ~= 'number' or type(p.y) ~= 'number' or type(p.z) ~= 'number'
            or type(data.normal) ~= 'table' or type(data.width) ~= 'number' or type(data.height) ~= 'number'
            or data.width <= 0 or data.height <= 0 or data.width > 20.0 or data.height > 20.0 then
            return
        end
        local ped = GetPlayerPed(src)
        if ped == 0 or #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) > 30.0 then return end
    end

    local function broadcast(syncData)
        TriggerClientEvent('pop_affiche:client:notifyUpdate', -1, syncData)
    end

    if data.dbId then
        local success, err = pcall(function()
            MySQL.update.await('UPDATE pop_affiche SET image_url = ? WHERE id = ?', { data.image_url, data.dbId })
        end)
        if success then
            broadcast(data)
        else
            print("^1[Affiche-SQL-Error]^7 Echec UPDATE ID " .. tostring(data.dbId) .. " : " .. tostring(err))
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Erreur SQL lors de la mise à jour !' })
        end
    else
        local success, err = pcall(function()
            return MySQL.insert.await([[
                INSERT INTO pop_affiche (image_url, pos, normal, width, height)
                VALUES (?, ?, ?, ?, ?)
            ]], { data.image_url, json.encode(data.pos), json.encode(data.normal), data.width, data.height })
        end)
        if success then
            local id = err -- pcall returns status flag + result values
            data.dbId = id
            broadcast(data)
        else
            print("^1[Affiche-SQL-Error]^7 Echec INSERT : " .. tostring(err))
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Erreur SQL lors de la creation !' })
        end
    end
end)

RegisterNetEvent('pop_affiche:server:deleteAffiche', function(dbId)
    local src = source
    
    -- Sécurité serveur : Vérification du statut VIP avant suppression
    if not IsPlayerVIP(src) then
        print("^1[Affiche-Hack-Warning]^7 Tentative de suppression d'affiche sans statut VIP par " .. GetPlayerName(src) .. " (ID: " .. tostring(src) .. ")")
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Seuls les membres VIP peuvent supprimer des affiches !' })
        return
    end

    if type(dbId) ~= 'number' then return end
    local success, err = pcall(function()
        MySQL.update.await('DELETE FROM pop_affiche WHERE id = ?', { dbId })
    end)
    if success then
        TriggerClientEvent('pop_affiche:client:removeAffiche', -1, dbId)
    else
        print("^1[Affiche-SQL-Error]^7 Echec DELETE ID " .. tostring(dbId) .. " : " .. tostring(err))
    end
end)
