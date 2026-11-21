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

-- --- VALIDATION ---
local lastAction = {}  -- [src] = GetGameTimer() du dernier enregistrement/suppression
local ACTION_COOLDOWN = 2000
local MAX_DISTANCE = 30.0

local function OnCooldown(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < ACTION_COOLDOWN then return true end
    lastAction[src] = now
    return false
end

local function IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
        and t.x == t.x and t.y == t.y and t.z == t.z
end

-- Lien d'image : http(s) seulement, sans espace ni guillemet ni chevron
local function CleanUrl(url)
    if type(url) ~= 'string' or url == '' or #url > 2048 then return nil end
    if not url:match('^https?://[%w%-%.]+') then return nil end
    if url:find('[%s"\'<>`\\]') then return nil end
    return url
end

local function PlayerNear(src, p)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(p.x, p.y, p.z)) <= MAX_DISTANCE
end

local function GetAfficheRow(dbId)
    local ok, row = pcall(function() return MySQL.single.await('SELECT * FROM pop_affiche WHERE id = ?', { dbId }) end)
    if not ok or not row then return nil end
    if type(row.pos) == 'string' then row.pos = json.decode(row.pos) end
    if type(row.normal) == 'string' then row.normal = json.decode(row.normal) end
    return row
end

AddEventHandler('playerDropped', function() lastAction[source] = nil end)

RegisterNetEvent('pop_affiche:server:saveAffiche', function(data)
    local src = source

    -- Sécurité serveur : Vérification du statut VIP avant enregistrement
    if not IsPlayerVIP(src) then
        print("^1[Affiche-Hack-Warning]^7 Tentative d'enregistrement d'affiche sans statut VIP par " .. GetPlayerName(src) .. " (ID: " .. tostring(src) .. ")")
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Seuls les membres VIP peuvent poser des affiches !' })
        return
    end

    if type(data) ~= 'table' then return end
    if data.dbId ~= nil and type(data.dbId) ~= 'number' then return end
    local url = CleanUrl(data.image_url)
    if not url then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Lien invalide : utilisez un lien http(s) vers une image.' })
        return
    end
    if OnCooldown(src) then return end

    if data.dbId then
        local row = GetAfficheRow(data.dbId)
        if not row or not IsVec(row.pos) or not PlayerNear(src, row.pos) then return end
        local success, err = pcall(function()
            MySQL.update.await('UPDATE pop_affiche SET image_url = ? WHERE id = ?', { url, data.dbId })
        end)
        if success then
            -- On ne rediffuse que des champs propres
            TriggerClientEvent('pop_affiche:client:notifyUpdate', -1, {
                dbId = data.dbId, image_url = url, pos = row.pos, normal = row.normal, width = row.width, height = row.height,
            })
        else
            print("^1[Affiche-SQL-Error]^7 Echec UPDATE ID " .. tostring(data.dbId) .. " : " .. tostring(err))
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Erreur SQL lors de la mise à jour !' })
        end
    else
        -- Validation de la nouvelle affiche (taille et distance du joueur)
        local p, n = data.pos, data.normal
        if not IsVec(p) or not IsVec(n) or type(data.width) ~= 'number' or type(data.height) ~= 'number'
            or data.width <= 0 or data.height <= 0 or data.width > 20.0 or data.height > 20.0 then
            return
        end
        if not PlayerNear(src, p) then return end
        local pos = { x = p.x, y = p.y, z = p.z }
        local normal = { x = n.x, y = n.y, z = n.z }

        local success, id = pcall(function()
            return MySQL.insert.await([[
                INSERT INTO pop_affiche (image_url, pos, normal, width, height)
                VALUES (?, ?, ?, ?, ?)
            ]], { url, json.encode(pos), json.encode(normal), data.width, data.height })
        end)
        if success and id then
            TriggerClientEvent('pop_affiche:client:notifyUpdate', -1, {
                dbId = id, image_url = url, pos = pos, normal = normal, width = data.width, height = data.height,
            })
        else
            print("^1[Affiche-SQL-Error]^7 Echec INSERT : " .. tostring(id))
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
    if OnCooldown(src) then return end
    local row = GetAfficheRow(dbId)
    if not row or not IsVec(row.pos) or not PlayerNear(src, row.pos) then return end
    local success, err = pcall(function()
        MySQL.update.await('DELETE FROM pop_affiche WHERE id = ?', { dbId })
    end)
    if success then
        TriggerClientEvent('pop_affiche:client:removeAffiche', -1, dbId)
    else
        print("^1[Affiche-SQL-Error]^7 Echec DELETE ID " .. tostring(dbId) .. " : " .. tostring(err))
    end
end)
