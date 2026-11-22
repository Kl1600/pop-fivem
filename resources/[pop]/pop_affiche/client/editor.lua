-- Fenêtre de saisie du lien (NUI) : modification d'une affiche ou fin de pose.

RegisterNUICallback('saveAffiche', function(data, cb)
    SetNuiFocus(false, false)
    local url = data.image_url or ''

    if Affiche.editingId then
        local pData = Affiche.data[Affiche.editingId]
        if pData then
            pData.image_url = url
            local duiId = Affiche.panels[Affiche.editingId]
            if duiId then
                exports["pop_duiengine"]:SendMessage(duiId, { type = 'setUrl', url = url })
            end
            TriggerServerEvent('pop_affiche:server:saveAffiche', { dbId = Affiche.editingId, image_url = url })
        end
        Affiche.editingId = nil
    elseif Affiche.pendingPlacement then
        -- La preview n'est détruite qu'une fois le lien confirmé
        if Affiche.previewPanelId then
            exports["pop_duiengine"]:DestroyPanel(Affiche.previewPanelId)
            Affiche.previewPanelId = nil
        end
        local p = Affiche.pendingPlacement
        Affiche.pendingPlacement = nil
        TriggerServerEvent('pop_affiche:server:saveAffiche', {
            image_url = url,
            pos       = p.pos,
            normal    = p.normal,
            width     = p.width,
            height    = p.height,
        })
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetNuiFocus(false, false)
    -- Annulation : on détruit la preview si on était en train de poser
    if Affiche.pendingPlacement and Affiche.previewPanelId then
        exports["pop_duiengine"]:DestroyPanel(Affiche.previewPanelId)
        Affiche.previewPanelId = nil
    end
    Affiche.editingId = nil
    Affiche.pendingPlacement = nil
    cb('ok')
end)
