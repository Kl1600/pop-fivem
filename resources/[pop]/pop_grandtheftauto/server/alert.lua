local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function GetPolicePlayers()
    local policePlayers = {}
    if Config.Framework == 'esx' and ESX then
        local xPlayers = ESX.GetExtendedPlayers('job', 'police')
        for _, xPlayer in pairs(xPlayers) do
            table.insert(policePlayers, xPlayer.source)
        end
    elseif Config.Framework == 'qbcore' and QBCore then
        local qbPlayers = QBCore.Functions.GetQBPlayers()
        for _, Player in pairs(qbPlayers) do
            if Player and Player.PlayerData.job.name == 'police' then
                table.insert(policePlayers, Player.PlayerData.source)
            end
        end
    else
        -- Fallback, pas de police, on retourne vide
    end
    return policePlayers
end

-- ============================================================
-- POLICE ALERTS (EXISTANT & SYNCHRONISÉ)
-- ============================================================

RegisterNetEvent('mission:server:alertPoliceLocation')
AddEventHandler('mission:server:alertPoliceLocation', function(coords)
    local policePlayers = GetPolicePlayers()
    for _, src in pairs(policePlayers) do
        TriggerClientEvent('grandtheftauto:client:ShowNotify', src, {
            title = "Braquage en cours",
            message = "Showroom Benefactor<br><span style='color:#2ecc71; font-weight:bold;'>[Y] Prendre l'appel</span>",
            duration = 20000
        })     
        TriggerClientEvent('mission:client:policeShowroomBlip', src, coords)
    end

    -- SYNCHRO : Le serveur ordonne la suppression du blip d'alerte après 2 minutes pour tous
    SetTimeout(100000, function()
        for _, src in pairs(policePlayers) do
            TriggerClientEvent('mission:client:removeShowroomBlip', src)
        end
    end)
end)

RegisterNetEvent('mission:server:alertPolice')
AddEventHandler('mission:server:alertPolice', function(vehicleNetIds)
    local policePlayers = GetPolicePlayers()
    
    -- Notification immédiate
    for _, src in pairs(policePlayers) do
        TriggerClientEvent('grandtheftauto:client:ShowNotify', src, {
            message = "Un <span style='color:#ECA95D; font-weight:bold;'>vol de véhicule</span> a été signalé dans la zone par un citoyen suspect, restez un moment pour plus d'informations.",
            duration = 10000
        })     
    end

    -- Boucle de tracking (Réglée sur 30 secondes)
    Citizen.CreateThread(function()
        local timer = 0
        local dureeEnSecondes = 1000 -- MODIFIEZ ICI : Temps total du tracker en secondes
        
        while timer < dureeEnSecondes do
            local trackingData = {}
            
            -- Récupération des positions sur le serveur
            for _, netId in ipairs(vehicleNetIds) do
                local entity = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(entity) then
                    table.insert(trackingData, {
                        netId = netId,
                        coords = GetEntityCoords(entity)
                    })
                end
            end

            -- Envoi des coordonnées aux policiers
            for _, src in pairs(policePlayers) do
                TriggerClientEvent('mission:client:startPoliceTracking', src, trackingData)
            end

            Wait(100) -- Actualisation toutes les 1 seconde (1000ms)
            timer = timer + 1
        end

        -- Désactivation après le délai
        for _, src in pairs(policePlayers) do
            TriggerClientEvent('mission:client:stopPoliceTracking', src)
        end
    end)
end)

-- Événement pour stopper le tracking de tous les policiers en même temps
RegisterNetEvent('mission:server:stopPoliceTracking')
AddEventHandler('mission:server:stopPoliceTracking', function()
    local policePlayers = GetPolicePlayers()
    for _, src in pairs(policePlayers) do
        TriggerClientEvent('mission:client:stopPoliceTracking', src)
    end
end)

-- ============================================================
-- SYNCHRO COOP (HEIST OWNER + RELAIS + ENTITÉS)
-- ============================================================

local Mission = {
    active = false,
    id = nil,
    owner = nil,
    entities = {},
}

local function NewHeistId(src)
    return string.format("%d_%d", os.time(), src or 0)
end

RegisterNetEvent('mission:server:startHeist')
AddEventHandler('mission:server:startHeist', function()
    local src = source
    if not Mission.active then
        Mission.active = true
        Mission.owner = src
        Mission.id = NewHeistId(src)
        Mission.entities = {}
    end
    TriggerClientEvent('mission:client:heistStart', -1, Mission.owner, Mission.id)
end)

RegisterNetEvent('mission:server:registerEntity')
AddEventHandler('mission:server:registerEntity', function(key, payload)
    local src = source
    if not Mission.active or src ~= Mission.owner then return end
    Mission.entities[key] = payload
    TriggerClientEvent('mission:client:entity', -1, key, payload, Mission.id)
end)

RegisterNetEvent('mission:server:relay')
AddEventHandler('mission:server:relay', function(action, data, includeSender)
    local src = source
    if not Mission.active then return end
    TriggerClientEvent('mission:client:relay', -1, action, data, src, includeSender == true, Mission.id)
end)

RegisterNetEvent('mission:server:syncMissionToPlayer')
AddEventHandler('mission:server:syncMissionToPlayer', function()
    local src = source
    if not Mission.active then return end
    TriggerClientEvent('mission:client:heistStart', src, Mission.owner, Mission.id)
    for key, payload in pairs(Mission.entities) do
        TriggerClientEvent('mission:client:entity', src, key, payload, Mission.id)
    end
end)

-- ============================================================
-- SYNCHRO COOP (LOCKS HACK)
-- ============================================================

local HackLocks = {}
local HackCompleted = {}

local function IsLockExpired(lock)
    if not lock then return true end
    return (os.time() - (lock.t or 0)) > 300
end

RegisterNetEvent('mission:server:tryLockHack')
AddEventHandler('mission:server:tryLockHack', function(plate)
    local src = source
    if not plate or plate == "" then return end
    if HackCompleted[plate] then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "completed")
        return
    end
    local lock = HackLocks[plate]
    if lock and not IsLockExpired(lock) and lock.holder ~= src then
        TriggerClientEvent('mission:client:hackLockResult', src, plate, false, "locked")
        return
    end
    HackLocks[plate] = { holder = src, t = os.time() }
    TriggerClientEvent('mission:client:hackLockResult', src, plate, true, "ok")
    TriggerClientEvent('mission:client:hackState', -1, plate, false, src)
end)

RegisterNetEvent('mission:server:releaseHackLock')
AddEventHandler('mission:server:releaseHackLock', function(plate)
    local src = source
    local lock = HackLocks[plate]
    if lock and (lock.holder == src or IsLockExpired(lock)) then
        HackLocks[plate] = nil
        TriggerClientEvent('mission:client:hackState', -1, plate, false, nil)
    end
end)

RegisterNetEvent('mission:server:setHackCompleted')
AddEventHandler('mission:server:setHackCompleted', function(plate, completed)
    local src = source
    local lock = HackLocks[plate]
    if lock and not IsLockExpired(lock) and lock.holder ~= src then return end
    if completed == true then
        HackCompleted[plate] = true
        HackLocks[plate] = nil
        TriggerClientEvent('mission:client:hackState', -1, plate, true, nil)
    else
        HackLocks[plate] = nil
        TriggerClientEvent('mission:client:hackState', -1, plate, false, nil)
    end
end)

RegisterNetEvent('mission:server:requestHackState')
AddEventHandler('mission:server:requestHackState', function()
    local src = source
    for plate, _ in pairs(HackCompleted) do
        TriggerClientEvent('mission:client:hackState', src, plate, true, nil)
    end
    for plate, lock in pairs(HackLocks) do
        if lock and not IsLockExpired(lock) then
            TriggerClientEvent('mission:client:hackState', src, plate, false, lock.holder)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for plate, lock in pairs(HackLocks) do
        if lock and lock.holder == src then
            HackLocks[plate] = nil
            TriggerClientEvent('mission:client:hackState', -1, plate, false, nil)
        end
    end
    if Mission.active and Mission.owner == src then
        Mission.active = false
        -- On arrête aussi le tracking police si l'owner quitte
        TriggerEvent('mission:server:stopPoliceTracking')
    end
end)



local globalUsedSlots = {}

RegisterNetEvent('mission:server:requestDeliverySlot')
AddEventHandler('mission:server:requestDeliverySlot', function()
    local src = source
    local slotIndex = nil

    -- On cherche la première place libre parmi les 4 disponibles
    for i = 1, 4 do 
        if not globalUsedSlots[i] then
            globalUsedSlots[i] = true
            slotIndex = i
            break
        end
    end

    -- On renvoie l'index au client (ou nil si tout est plein)
    TriggerClientEvent('mission:client:receiveDeliverySlot', src, slotIndex)
end)

-- Optionnel : Réinitialiser les slots si la ressource redémarre
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        globalUsedSlots = {}
    end
end)