-- pop_passport client side

local headshotStr = ""
local isOpen = false

local function closePassport()
    isOpen = false
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)
end

-- Mois pour formater les dates "JJ MMM AAAA"
local MONTHS = { 'JAN','FÉV','MARS','AVR','MAI','JUIN','JUIL','AOÛT','SEP','OCT','NOV','DÉC' }

-- Formate une date stockée 'AAAA-MM-JJ' (ou 'JJ/MM/AAAA') -> "JJ MMM AAAA"
local function formatDate(str)
    if not str then return '' end
    local y, m, d = str:match('(%d+)%-(%d+)%-(%d+)')
    if not y then
        d, m, y = str:match('(%d+)/(%d+)/(%d+)')
    end
    if not y then return str end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    return string.format('%02d %s %d', d, MONTHS[m] or '???', y)
end

-- Affichage générique pour un type de passeport ('us' | 'mx')
local function display(itemData, passportType)
    local meta = itemData.meta or {}

    if not meta.firstname then
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-passport', message = 'Ce passeport est illisible.', duration = 3000 })
        return
    end

    -- Photo du joueur
    local handle = RegisterPedheadshot(PlayerPedId())
    local t = 0
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        Wait(5)
        t = t + 5
        if t > 2000 then break end
    end
    headshotStr = GetPedheadshotTxdString(handle)

    SendNUIMessage({
        action = "show",
        type   = passportType,
        data = {
            number    = meta.number or 'XXXXXXXXX',
            firstname = meta.firstname,
            lastname  = meta.lastname,
            sex       = (meta.sex == 'F') and 'F' or 'M',
            dob       = formatDate(meta.dob),
            expiry    = formatDate(meta.expiryDate),
            headshot  = headshotStr
        }
    })
    SetNuiFocus(true, true)

    -- Fermeture via ESC (thread actif uniquement pendant l'affichage)
    if not isOpen then
        isOpen = true
        CreateThread(function()
            while isOpen do
                Wait(0)
                if IsDisabledControlJustPressed(0, 200) then
                    closePassport()
                end
            end
        end)
    end

    SetTimeout(5000, function()
        UnregisterPedheadshot(handle)
    end)
end

RegisterNetEvent('pop_passport:display:us', function(itemData)
    display(itemData, 'us')
end)

RegisterNetEvent('pop_passport:display:mx', function(itemData)
    display(itemData, 'mx')
end)

RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    if cb then cb('ok') end
end)
