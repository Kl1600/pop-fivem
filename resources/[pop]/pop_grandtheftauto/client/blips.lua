-- cl_blips.lua

-- ============================================================
-- BLIP "Panneau électrique" (anti-doublon)
-- ============================================================

local panelBlipId = nil
local panelBlipCreated = false

RegisterNetEvent('mission:setupBlips')
AddEventHandler('mission:setupBlips', function()
    if panelBlipCreated and panelBlipId and DoesBlipExist(panelBlipId) then
        return
    end

    panelBlipId = AddBlipForCoord(-54.8242, 78.8582, 71.6542)
    SetBlipSprite(panelBlipId, 461)
    SetBlipScale(panelBlipId, 0.9)
    SetBlipColour(panelBlipId, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('Panneau électrique')
    EndTextCommandSetBlipName(panelBlipId)

    panelBlipCreated = true
end)

RegisterCommand('removeblip1', function()
    if panelBlipId and DoesBlipExist(panelBlipId) then
        RemoveBlip(panelBlipId)
    end
    panelBlipId = nil
    panelBlipCreated = false
end, false)



-- ============================================================
-- PED DÉCOR (local, inchangé)
-- ============================================================

Citizen.CreateThread(function()
    local anim = "amb@business_talk@male_b@base"
    RequestAnimDict(anim)
    while not HasAnimDictLoaded(anim) do
        Wait(1)
    end

    local hash = GetHashKey("ig_valentina")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(1)
    end

    local ped = CreatePed(4, hash, -1029.3354, -2966.0518, 13.9468, 347.2004, false, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    TaskPlayAnim(ped, anim, "base", 15.0, 8.0, -1, 1, 0, 0, 0, 0)
end)


RegisterCommand('dv100', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local radius = 100.0 -- Rayon de 100 mètres
    local count = 0

    -- Liste des types d'entités à nettoyer
    local pools = {'CVehicle', 'CPed', 'CObject'}

    for _, poolName in ipairs(pools) do
        local entities = GetGamePool(poolName)

        for _, entity in ipairs(entities) do
            if DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local distance = #(playerCoords - entityCoords)

                -- Vérification : Distance + Exclusion des joueurs
                if distance <= radius and not IsPedAPlayer(entity) then
                    
                    -- Demande du contrôle réseau pour les entités synchronisées
                    NetworkRequestControlOfEntity(entity)
                    
                    local timeout = 2000
                    while timeout > 0 and not NetworkHasControlOfEntity(entity) do
                        Wait(10)
                        timeout = timeout - 10
                    end

                    -- Suppression de l'entité
                    SetEntityAsMissionEntity(entity, true, true)
                    
                    if poolName == 'CVehicle' then
                        DeleteVehicle(entity)
                    end
                    
                    if not DoesEntityExist(entity) then
                        count = count + 1
                    end
                end
            end
        end
    end

    -- Feedback dans la console et le chat
    print("Nettoyage terminé : " .. count .. " entités supprimées.")
    TriggerEvent('chat:addMessage', {
        args = { "Système", count .. " entités (véhicules, peds, objets) ont été supprimées dans un rayon de 100m." }
    })
end, true)