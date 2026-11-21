-- pop_passport : affichage du passeport (NUI) et fermeture.

Passport = Passport or {}

local isOpen = false            -- reflète l'affichage réel du passeport (remis à false à chaque fermeture)
local escThreadRunning = false  -- évite de lancer deux boucles Échap en parallèle

local function closePassport()
    isOpen = false
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)
end

-- Échap : boucle active uniquement tant que le passeport est affiché, s'arrête dès la fermeture
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
                closePassport()
            end
            Wait(0)
        end
        escThreadRunning = false
    end)
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
    local meta = (itemData and itemData.meta) or {}

    if not meta.firstname then
        Bridge.Notify({ icon = 'fas fa-passport', message = L('passport_unreadable'), duration = Config.NotifyUnreadable })
        return
    end

    -- Photo du titulaire (voir NOTE dans client/photo.lua)
    local ped = Passport.GetHolderPed(meta.identifier)
    local headshotStr = ped and Passport.TakeHeadshot(ped) or ""

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

    isOpen = true
    startEscThread()
end

RegisterNetEvent('pop_passport:display:us', function(itemData)
    display(itemData, 'us')
end)

RegisterNetEvent('pop_passport:display:mx', function(itemData)
    display(itemData, 'mx')
end)

-- NUI Close callback (Échap / Entrée côté interface).
-- NOTE: bridge/client.lua enregistre aussi 'close' (rend le focus) : les deux s'exécutent, sans effet de bord.
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    if cb then cb('ok') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    isOpen = false
    SetNuiFocus(false, false)
end)
