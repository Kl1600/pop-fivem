-- Photo du titulaire de la carte (chargé avant client/main.lua, voir fxmanifest).

IdCard = IdCard or {}

local holderReqId = 0
local holderPending = {}

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
    SetTimeout(Config.HolderTimeout, function()
        if holderPending[reqId] then
            holderPending[reqId] = nil
            p:resolve(0)
        end
    end)
    return Citizen.Await(p)
end

-- NOTE: la photo n'est pas stockée dans l'item, seul l'identifiant (bridge) du titulaire l'est.
-- On photographie donc le ped du titulaire : le sien si c'est sa propre carte, sinon celui
-- du titulaire s'il est connecté et à portée (server id fourni par le serveur). Dans tous
-- les autres cas, aucun visage : le fond gris par défaut de la photo reste affiché,
-- jamais le visage du lecteur.
function IdCard.GetHolderPed(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    local myPed = PlayerPedId()

    local data = Bridge.GetPlayerData()
    if data and data.identifier == identifier then return myPed end

    local serverId = fetchHolderServerId(identifier)
    if serverId <= 0 then return nil end
    if serverId == GetPlayerServerId(PlayerId()) then return myPed end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(myPed)) > Config.HolderRange then return nil end
    return ped
end

function IdCard.TakeHeadshot(ped)
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
