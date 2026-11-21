-- pop_idcard client side

local headshotStr = ""
local isOpen = false

local function closeCard()
    isOpen = false
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)
end

-- Function to handle ID card display
RegisterNetEvent('pop_idcard:display', function(itemData)
    local metadata = itemData.meta or {}
    
    if not metadata.firstname then 
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-id-card', message = 'Cette carte est illisible.', duration = 3000 })
        return 
    end

    -- Create local mugshot
    local handle = RegisterPedheadshot(PlayerPedId())
    local t = 0
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        Wait(5)
        t = t + 5
        if t > 2000 then break end -- Safety breakaway
    end
    
    headshotStr = GetPedheadshotTxdString(handle)
    
    SendNUIMessage({
        action = "show",
        data = {
            firstname   = metadata.firstname,
            lastname    = metadata.lastname,
            sex         = (metadata.sex == "M") and "Homme" or "Femme",
            identifier  = metadata.identifier or "V-XXXXXX",
            headshot    = headshotStr,
            cardType    = metadata.cardType or 'us',
            nationality = (metadata.cardType == 'mx') and "Mexicaine" or "Américaine"
        }
    })
    SetNuiFocus(true, true)

    -- ESC key handling (thread actif uniquement pendant l'affichage)
    if not isOpen then
        isOpen = true
        CreateThread(function()
            while isOpen do
                Wait(0)
                if IsDisabledControlJustPressed(0, 200) then
                    closeCard()
                end
            end
        end)
    end
    
    -- Cleanup headshot after 5s
    SetTimeout(5000, function()
        UnregisterPedheadshot(handle)
    end)
end)

-- NUI Close callback
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)
