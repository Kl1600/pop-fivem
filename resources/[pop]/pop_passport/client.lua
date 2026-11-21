-- pop_passport client side

local isOpen = false            -- reflète l'affichage réel du passeport (remis à false à chaque fermeture)
local escThreadRunning = false  -- évite de lancer deux boucles Échap en parallèle

local HOLDER_RANGE = 15.0       -- distance max pour photographier le titulaire
local holderReqId = 0
local holderPending = {}

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

-- Réponse du serveur : server id du titulaire (0 si absent ou trop loin)
RegisterNetEvent('pop_passport:client:holder', function(reqId, serverId)
    local p = holderPending[reqId]
    if p then
        holderPending[reqId] = nil
        p:resolve(tonumber(serverId) or 0)
    end
end)

local function fetchHolderServerId(identifier)
    holderReqId = holderReqId + 1
    local reqId = holderReqId
    local p = promise.new()
    holderPending[reqId] = p
    TriggerServerEvent('pop_passport:server:holder', reqId, identifier)
    SetTimeout(2000, function()
        if holderPending[reqId] then
            holderPending[reqId] = nil
            p:resolve(0)
        end
    end)
    return Citizen.Await(p)
end

-- NOTE: la photo n'est pas stockée dans l'item, seul l'identifiant ESX du titulaire l'est.
-- On photographie donc le ped du titulaire : le sien si c'est son propre passeport, sinon
-- celui du titulaire s'il est connecté et à portée (server id fourni par le serveur). Dans
-- tous les autres cas, aucun visage : le fond par défaut de la photo reste affiché,
-- jamais le visage du lecteur.
local function getHolderPed(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    local myPed = PlayerPedId()

    local data = ESX and ESX.GetPlayerData and ESX.GetPlayerData() or nil
    if data and data.identifier == identifier then return myPed end

    local serverId = fetchHolderServerId(identifier)
    if serverId <= 0 then return nil end
    if serverId == GetPlayerServerId(PlayerId()) then return myPed end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(myPed)) > HOLDER_RANGE then return nil end
    return ped
end

local function takeHeadshot(ped)
    local handle = RegisterPedheadshot(ped)
    local t = 0
    while not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) do
        Wait(5)
        t = t + 5
        if t > 2000 then break end
    end

    local str = ""
    if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
        str = GetPedheadshotTxdString(handle)
    end

    SetTimeout(5000, function()
        UnregisterPedheadshot(handle)
    end)
    return str
end

-- Affichage générique pour un type de passeport ('us' | 'mx')
local function display(itemData, passportType)
    local meta = (itemData and itemData.meta) or {}

    if not meta.firstname then
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-passport', message = 'Ce passeport est illisible.', duration = 3000 })
        return
    end

    -- Photo du titulaire (voir NOTE ci-dessus)
    local ped = getHolderPed(meta.identifier)
    local headshotStr = ped and takeHeadshot(ped) or ""

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

-- NUI Close callback (Échap / Entrée côté interface)
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
