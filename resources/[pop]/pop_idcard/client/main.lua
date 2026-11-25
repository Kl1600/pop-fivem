-- pop_idcard client : affichage de la carte et fermeture.

IdCard = IdCard or {}

local isOpen = false            -- reflète l'affichage réel de la carte (remis à false à chaque fermeture)
local escThreadRunning = false  -- évite de lancer deux boucles Échap en parallèle

local function closeCard()
    isOpen = false
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)
end

-- Échap : boucle active uniquement tant que la carte est affichée, s'arrête dès la fermeture
local function startEscThread()
    if escThreadRunning then return end
    escThreadRunning = true
    CreateThread(function()
        while isOpen do
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 177, true)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322)
                or IsDisabledControlJustPressed(0, 177) then
                closeCard()
            end
            Wait(0)
        end
        escThreadRunning = false
    end)
end

-- Affichage de la carte (déclenché par pop_inventory à l'utilisation de l'objet)
RegisterNetEvent('pop_idcard:display', function(itemData)
    local metadata = (itemData and itemData.meta) or {}

    if not metadata.firstname then
        Bridge.Notify({ icon = 'fas fa-id-card', message = L('card_unreadable'), duration = Config.NotifyUnreadableDuration })
        return
    end

    -- Photo du titulaire (voir NOTE dans client/photo.lua)
    local ped = IdCard.GetHolderPed(metadata.identifier)
    local headshotStr = ped and IdCard.TakeHeadshot(ped) or ""

    SendNUIMessage({
        action = "show",
        data = {
            firstname   = metadata.firstname,
            lastname    = metadata.lastname,
            sex         = (metadata.sex == "M") and L('sex_male') or L('sex_female'),
            identifier  = metadata.identifier or "V-XXXXXX",
            headshot    = headshotStr,
            cardType    = metadata.cardType or 'us',
            nationality = (metadata.cardType == 'mx') and L('nationality_mx') or L('nationality_us')
        }
    })
    SetNuiFocus(true, true)

    isOpen = true
    startEscThread()
end)

-- NUI Close callback (Échap / Entrée côté interface). Le bridge enregistre aussi 'close'
-- (rend le focus) : les deux s'exécutent, sans effet en double.
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Aide de la commande admin dans le chat
TriggerEvent('chat:addSuggestion', '/' .. Config.GiveCommand, L('cmd_help'), { { name = 'id', help = L('cmd_arg_id') } })

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    isOpen = false
    SetNuiFocus(false, false)
end)
