-- =================================================================
-- EXPORT UNIVERSEL
-- =================================================================

-- Cet export permet d'appeler la notification depuis n'importe quel script
-- Usage : exports['votre_nom_de_script']:ShowNotify(data)
local function ShowNotify(data)
    if data then
        SendNUIMessage({
            action = 'notify',
            data = data
        })
    end
end
exports('ShowNotify', ShowNotify)

-- =================================================================
-- ÉVÈNEMENT RÉSEAU (Pour appeler depuis le Server side)
-- =================================================================

RegisterNetEvent('notification:client:ShowNotify', function(data)
    ShowNotify(data)
end)

-- Décale les notifications vers le haut quand la checklist mécano est ouverte
-- (sinon elles s'affichent derrière, au même endroit que la liste).
AddEventHandler('notification:client:setRaised', function(state, bottom)
    SendNUIMessage({ action = 'setRaised', state = state and true or false, bottom = bottom })
end)

-- Checklist intégrée directement dans la pile de notifications (carte
-- persistante, ne disparaît pas toute seule) : même largeur/position/échelle
-- que les autres notifs, plus besoin de la (dé)caler manuellement.
-- Usage : TriggerEvent('notification:client:checklist', { type = 'show'|'reset'|'step', ... })
AddEventHandler('notification:client:checklist', function(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({
        action  = 'checklist',
        type    = data.type,
        visible = data.visible,
        title   = data.title,
        step    = data.step,
        done    = data.done,
        label   = data.label
    })
end)