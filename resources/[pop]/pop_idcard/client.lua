-- pop_idcard client side

local isOpen = false            -- reflète l'affichage réel de la carte (remis à false à chaque fermeture)
local escThreadRunning = false  -- évite de lancer deux boucles Échap en parallèle

local HOLDER_RANGE = 15.0       -- distance max pour photographier le titulaire
local holderReqId = 0
local holderPending = {}

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

-- Réponse du serveur : server id du titulaire (0 si absent ou trop loin)
RegisterNetEvent('pop_idcard:client:holder', function(reqId, serverId)
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
    TriggerServerEvent('pop_idcard:server:holder', reqId, identifier)
    SetTimeout(2000, function()
        if holderPending[reqId] then
            holderPending[reqId] = nil
            p:resolve(0)
        end
    end)
    return Citizen.Await(p)
end

-- NOTE: la photo n'est pas stockée dans l'item, seul l'identifiant ESX du titulaire l'est.
-- On photographie donc le ped du titulaire : le sien si c'est sa propre carte, sinon celui
-- du titulaire s'il est connecté et à portée (server id fourni par le serveur). Dans tous
-- les autres cas, aucun visage : le fond gris par défaut de la photo reste affiché,
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
        if t > 2000 then break end -- Safety breakaway
    end

    local str = ""
    if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
        str = GetPedheadshotTxdString(handle)
    end

    -- Cleanup headshot after 5s
    SetTimeout(5000, function()
        UnregisterPedheadshot(handle)
    end)
    return str
end

-- Function to handle ID card display
RegisterNetEvent('pop_idcard:display', function(itemData)
    local metadata = (itemData and itemData.meta) or {}

    if not metadata.firstname then
        exports["pop_notify"]:ShowNotify({ icon = 'fas fa-id-card', message = 'Cette carte est illisible.', duration = 3000 })
        return
    end

    -- Photo du titulaire (voir NOTE ci-dessus)
    local ped = getHolderPed(metadata.identifier)
    local headshotStr = ped and takeHeadshot(ped) or ""

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

    isOpen = true
    startEscThread()
end)

-- NUI Close callback (Échap / Entrée côté interface)
RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    isOpen = false
    SetNuiFocus(false, false)
end)
