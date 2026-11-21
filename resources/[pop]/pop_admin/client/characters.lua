-- =====================================================================
--  DOUBLE PERSONNAGE (STAFF)
--  Capture l'apparence courante du staff (skinchanger), la sauvegarde
--  côté serveur (liée à la licence) et permet de la réincarner.
-- =====================================================================

local function hasSkinchanger()
    return GetResourceState('skinchanger') == 'started'
end

-- Sauvegarde le perso actuel : on lit le skin courant et on l'envoie au serveur.
RegisterNUICallback('charSave', function(data, cb)
    if not hasSkinchanger() then
        AdminNotify('Ressource skinchanger absente', 'error')
        cb({ ok = false }); return
    end
    local skin = exports['skinchanger']:GetSkin()
    if type(skin) ~= 'table' or skin.sex == nil then
        AdminNotify("Impossible de lire l'apparence actuelle", 'error')
        cb({ ok = false }); return
    end
    TriggerServerEvent('pop_admin:chars:save', {
        label = data.label,
        skin  = skin,
    })
    cb({ ok = true })
end)

RegisterNUICallback('charRequest', function(_, cb)
    TriggerServerEvent('pop_admin:chars:request')
    cb({})
end)

RegisterNUICallback('charLoad', function(data, cb)
    TriggerServerEvent('pop_admin:chars:load', data.id)
    cb({})
end)

RegisterNUICallback('charDelete', function(data, cb)
    TriggerServerEvent('pop_admin:chars:delete', data.id)
    cb({})
end)

-- Liste (légère, sans la data skin) renvoyée par le serveur → NUI.
RegisterNetEvent('pop_admin:chars:receive', function(list)
    AdminSend('staffChars', { list = list or {} })
end)

-- Application d'un perso sauvegardé : on charge le skin puis on le persiste
-- comme apparence active du joueur (esx_skin).
RegisterNetEvent('pop_admin:chars:apply', function(skin, label)
    if type(skin) ~= 'table' then return end
    TriggerEvent('skinchanger:loadSkin', skin)
    Wait(300)
    TriggerServerEvent('esx_skin:save', skin)
    AdminNotify(('Personnage incarné : %s'):format(tostring(label or '')), 'success')
end)
