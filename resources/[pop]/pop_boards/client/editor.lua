-- Éditeur de peinture (NUI) et envoi du dessin par morceaux.

function Boards.OpenEditor(dbId)
    dbId = tonumber(dbId)
    local data = Boards.data[dbId]
    if not data then
        Boards.Debug("Tentative d'ouverture de l'éditeur pour un ID inconnu : %s", tostring(dbId))
        return
    end

    Boards.editingId = dbId
    SetNuiFocus(true, true)

    -- Un léger délai permet au focus de s'installer avant d'envoyer les données
    Wait(200)

    SendNUIMessage({
        action = "openMenu",
        dbId = dbId,
        url = data.url,
        resW = data.resW or 1024,
        resH = data.resH or 1024
    })
end

RegisterNUICallback("saveBoard", function(data, cb)
    SetNuiFocus(false, false)

    local editingId = Boards.editingId
    if editingId and data.image then
        local pData = Boards.data[editingId]
        if pData then
            -- Mise à jour locale visuelle immédiate
            pData.url = data.image
            local duiId = Boards.panels[editingId]
            if duiId then
                exports["pop_duiengine"]:SendMessage(duiId, { type = "updateTexture", url = data.image })
            end

            -- Envoi par morceaux de 8 Ko
            local imageData = data.image
            local chunkSize = 8000
            local len = string.len(imageData)
            for i = 1, len, chunkSize do
                TriggerServerEvent('pop_boards:server:uploadChunk', string.sub(imageData, i, i + chunkSize - 1), i == 1)
                Wait(50) -- laisse le temps au réseau
            end

            -- Sauvegarde finale
            TriggerServerEvent('pop_boards:server:saveBoard', {
                dbId = editingId,
                useChunks = true
            })
            Boards.editingId = nil
        else
            Boards.Debug("Erreur: panelData introuvable pour ID %s", tostring(editingId))
        end
    else
        Boards.Debug("Erreur: ID ou Image invalide.")
    end
    cb('ok')
end)

RegisterNUICallback("closeMenu", function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
