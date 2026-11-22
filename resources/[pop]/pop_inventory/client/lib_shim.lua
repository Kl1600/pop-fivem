-- =====================================================
--  Shim `lib` minimal (pop_inventory n'embarque PAS @ox_lib/init.lua).
--  Fournit progressBar / inputDialog / alertDialog sans ox_lib.
--  Chargé en PREMIER pour que les modules (items_client, interactions, douilles)
--  qui utilisent lib.* fonctionnent.
-- =====================================================
lib = lib or {}

-- Barre de progression : action minutée, contrôles désactivés, annulable (Retour arrière).
-- Retourne true si terminée, false si annulée.
function lib.progressBar(opts)
    opts = opts or {}
    local dur = opts.duration or 1000
    local startT = GetGameTimer()
    local disable = opts.disable or {}
    while GetGameTimer() - startT < dur do
        Wait(0)
        if disable.move then
            DisableControlAction(0, 30, true); DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true);  DisableControlAction(0, 22, true)
        end
        if disable.car then DisableControlAction(0, 71, true); DisableControlAction(0, 72, true) end
        if disable.combat then
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true); DisableControlAction(0, 263, true)
        end
        if opts.label then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(opts.label)
            EndTextCommandDisplayHelp(0, false, true, -1)
        end
        if opts.canCancel and IsControlJustReleased(0, 177) then -- Retour arrière
            return false
        end
    end
    return true
end

-- Dialogue d'entrée (1 champ géré, suffisant pour TPE/facture). Retourne { valeur } ou nil.
function lib.inputDialog(title, fields)
    local f = fields and fields[1]
    local label = (f and (f.label or f.description)) or title or L('input_default')
    local res
    if ESX and ESX.KeyboardInput then -- ESX direct
        res = ESX.KeyboardInput(label, '', 30)
    else
        -- ESX Legacy n'a pas KeyboardInput : clavier natif GTA en repli
        AddTextEntry('POP_INV_INPUT', label)
        DisplayOnscreenKeyboard(1, 'POP_INV_INPUT', '', '', '', '', '', 30)
        while UpdateOnscreenKeyboard() == 0 do Wait(0) end
        if UpdateOnscreenKeyboard() == 1 then res = GetOnscreenKeyboardResult() end
    end
    if res == nil or res == '' then return nil end
    if f and f.type == 'number' then
        local n = tonumber(res)
        if not n then return nil end
        return { n }
    end
    return { res }
end

-- Dialogue d'alerte -> notification (markdown simplifié).
function lib.alertDialog(opts)
    opts = opts or {}
    local txt = tostring(opts.content or '')
    txt = txt:gsub('%*%*', ''):gsub('`', ''):gsub('  \n', '<br>'):gsub('\n', '<br>')
    Bridge.Notify({
        title = opts.header or L('alert_default_title'),
        message = txt,
        icon = 'fas fa-circle-info',
        duration = 12000,
    })

    -- Sans bouton Annuler : simple information.
    if not opts.cancel then return 'confirm' end

    -- Avec Annuler (ex. paiement TPE) : on attend la réponse du joueur.
    -- E = accepter, Retour arrière = refuser ; sans réponse en 15 s = refus.
    AddTextEntry('POP_INV_ALERT', L('alert_accept_refuse'))
    local limit = GetGameTimer() + 15000
    while GetGameTimer() < limit do
        Wait(0)
        BeginTextCommandDisplayHelp('POP_INV_ALERT')
        EndTextCommandDisplayHelp(0, false, false, -1)
        if IsControlJustReleased(0, 38) then return 'confirm' end
        if IsControlJustReleased(0, 177) then return 'cancel' end
    end
    return 'cancel'
end

-- Ancien pont de notifications (gardé pour compatibilité) : voir Inv.NotifyTyped (client/common.lua).
RegisterNetEvent('notification:client:send', function(data)
    if type(data) ~= 'table' then return end
    Inv.NotifyTyped(data)
end)
