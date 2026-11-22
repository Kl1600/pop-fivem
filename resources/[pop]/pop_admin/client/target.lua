-- Options admin dans ox_target (clic gauche sur un joueur ou un véhicule).
-- Visibles par le staff seulement ; chaque action est revérifiée et journalisée côté serveur.
if GetResourceState('ox_target') == 'missing' then return end

local function isStaff()
    return Admin.isAdmin == true
end

local function serverIdOf(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return nil end
    return GetPlayerServerId(idx)
end

local function playerAction(action)
    return function(data)
        local id = serverIdOf(data.entity)
        if id then TriggerServerEvent('pop_admin:playerAction', { action = action, target = id }) end
    end
end

local function vehicleAction(action)
    return function(data)
        if not DoesEntityExist(data.entity) or not NetworkGetEntityIsNetworked(data.entity) then return end
        TriggerServerEvent('pop_admin:vehicleAction', action, NetworkGetNetworkIdFromEntity(data.entity))
    end
end

local function option(menu, name, icon, label, onSelect)
    return { name = name, icon = icon, label = label, menuName = menu, canInteract = isStaff, onSelect = onSelect, distance = 4.0 }
end

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(1000) end
    local target = exports.ox_target
    local P, V = 'pop_admin_player', 'pop_admin_vehicle'

    target:addGlobalPlayer({
        { name = 'pop_admin:player', icon = 'fa-solid fa-shield-halved', label = 'Options admin', openMenu = P, canInteract = isStaff, distance = 4.0 },
        option(P, 'pop_admin:p_info', 'fa-solid fa-circle-info', 'Infos du joueur', playerAction('info')),
        option(P, 'pop_admin:p_heal', 'fa-solid fa-heart-pulse', 'Soigner', playerAction('heal')),
        option(P, 'pop_admin:p_revive', 'fa-solid fa-kit-medical', 'Réanimer', playerAction('revive')),
        option(P, 'pop_admin:p_freeze', 'fa-solid fa-snowflake', 'Geler', playerAction('freeze')),
        option(P, 'pop_admin:p_unfreeze', 'fa-solid fa-person-walking', 'Dégeler', playerAction('unfreeze')),
    })

    target:addGlobalVehicle({
        { name = 'pop_admin:vehicle', icon = 'fa-solid fa-shield-halved', label = 'Options admin', openMenu = V, canInteract = isStaff, distance = 4.0 },
        option(V, 'pop_admin:v_repair', 'fa-solid fa-wrench', 'Réparer', vehicleAction('repair')),
        option(V, 'pop_admin:v_clean', 'fa-solid fa-spray-can-sparkles', 'Nettoyer', vehicleAction('clean')),
        option(V, 'pop_admin:v_fuel', 'fa-solid fa-gas-pump', "Faire le plein", vehicleAction('fuel')),
        option(V, 'pop_admin:v_flip', 'fa-solid fa-rotate', 'Remettre sur les roues', vehicleAction('flip')),
        option(V, 'pop_admin:v_unlock', 'fa-solid fa-lock-open', 'Déverrouiller', vehicleAction('unlock')),
        option(V, 'pop_admin:v_delete', 'fa-solid fa-trash', 'Supprimer le véhicule', vehicleAction('delete')),
    })
end)

-- Exécuté par le client qui contrôle le véhicule (envoyé par le serveur après vérification).
RegisterNetEvent('pop_admin:vehicleFix', function(action, netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    if action == 'repair' then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
    elseif action == 'clean' then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    elseif action == 'flip' then
        SetEntityRotation(veh, 0.0, 0.0, GetEntityHeading(veh), 2, true)
        SetVehicleOnGroundProperly(veh)
    elseif action == 'fuel' then
        if GetResourceState('pop_fuel') == 'started' then
            exports.pop_fuel:SetFuel(veh, 100.0)
        else
            SetVehicleFuelLevel(veh, 100.0)
        end
    end
end)
