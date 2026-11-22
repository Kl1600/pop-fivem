-- Liste, pose, modification et suppression des affiches (VIP).

Callback.Register('pop_affiche:isVIP', function(source)
    return Affiche.IsPlayerVIP(source)
end)

Callback.Register('pop_affiche:getAffiches', function()
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM pop_affiche')
    end)
    if success then return result end
    Affiche.Debug("^1[Affiche-SQL-Error]^7 Echec getAffiches : %s", tostring(result))
    return {}
end)

local function UpdateAffiche(src, dbId, url)
    local row = Affiche.GetRow(dbId)
    if not row or not Affiche.IsVec(row.pos) or not Affiche.PlayerNear(src, row.pos) then return end
    local success, err = pcall(function()
        MySQL.update.await('UPDATE pop_affiche SET image_url = ? WHERE id = ?', { url, dbId })
    end)
    if success then
        -- On ne rediffuse que des champs propres
        TriggerClientEvent('pop_affiche:client:notifyUpdate', -1, {
            dbId = dbId, image_url = url, pos = row.pos, normal = row.normal, width = row.width, height = row.height,
        })
    else
        Affiche.Debug("^1[Affiche-SQL-Error]^7 Echec UPDATE ID %s : %s", tostring(dbId), tostring(err))
        Affiche.NotifyError(src, L('affiche_sql_update'))
    end
end

local function CreateAffiche(src, data, url)
    -- Validation de la nouvelle affiche (taille et distance du joueur)
    local p, n = data.pos, data.normal
    if not Affiche.IsVec(p) or not Affiche.IsVec(n) or type(data.width) ~= 'number' or type(data.height) ~= 'number'
        or data.width <= 0 or data.height <= 0 or data.width > 20.0 or data.height > 20.0 then
        return
    end
    if not Affiche.PlayerNear(src, p) then return end
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
        Affiche.Debug("^1[Affiche-SQL-Error]^7 Echec INSERT : %s", tostring(id))
        Affiche.NotifyError(src, L('affiche_sql_create'))
    end
end

RegisterNetEvent('pop_affiche:server:saveAffiche', function(data)
    local src = source

    -- Statut VIP vérifié par le serveur
    if not Affiche.IsPlayerVIP(src) then
        Affiche.Debug("^1[Affiche-Hack-Warning]^7 Tentative d'enregistrement d'affiche sans statut VIP par %s (ID: %s)", GetPlayerName(src) or '?', tostring(src))
        Affiche.NotifyError(src, L('affiche_vip_save_error'))
        return
    end

    if type(data) ~= 'table' then return end
    if data.dbId ~= nil and type(data.dbId) ~= 'number' then return end
    local url = Affiche.CleanUrl(data.image_url)
    if not url then
        Affiche.NotifyError(src, L('affiche_bad_link'))
        return
    end
    if Affiche.OnCooldown(src) then return end

    if data.dbId then
        UpdateAffiche(src, data.dbId, url)
    else
        CreateAffiche(src, data, url)
    end
end)

RegisterNetEvent('pop_affiche:server:deleteAffiche', function(dbId)
    local src = source

    if not Affiche.IsPlayerVIP(src) then
        Affiche.Debug("^1[Affiche-Hack-Warning]^7 Tentative de suppression d'affiche sans statut VIP par %s (ID: %s)", GetPlayerName(src) or '?', tostring(src))
        Affiche.NotifyError(src, L('affiche_vip_delete_error'))
        return
    end

    if type(dbId) ~= 'number' then return end
    if Affiche.OnCooldown(src) then return end
    local row = Affiche.GetRow(dbId)
    if not row or not Affiche.IsVec(row.pos) or not Affiche.PlayerNear(src, row.pos) then return end
    local success, err = pcall(function()
        MySQL.update.await('DELETE FROM pop_affiche WHERE id = ?', { dbId })
    end)
    if success then
        TriggerClientEvent('pop_affiche:client:removeAffiche', -1, dbId)
    else
        Affiche.Debug("^1[Affiche-SQL-Error]^7 Echec DELETE ID %s : %s", tostring(dbId), tostring(err))
    end
end)
