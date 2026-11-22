-- =====================================================
--  Module SABOT DE ROUE (ex tab_sabot) — CLIENT
--  Pose (item sabot) -> véhicule figé, retrait (item cle_sabot).
--  Synchronisation par events réseau + boucle de maintenance.
-- =====================================================

local busy = false
local clampedNetIds = {}  -- [netId] = true  (miroir de l'état serveur)
local localProps    = {}  -- [vehHandle] = propHandle (objet local, non réseau)

-- ---------- Helpers prop / freeze ----------

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasModelLoaded(model)
end

local function vehicleHasClampBone(veh)
    return GetEntityBoneIndexByName(veh, SabotConfig.WheelBone) ~= -1
end

local function attachProp(veh)
    if localProps[veh] and DoesEntityExist(localProps[veh]) then return end
    local bone = GetEntityBoneIndexByName(veh, SabotConfig.WheelBone)
    if bone == -1 then return end

    local model = GetHashKey(SabotConfig.PropModel)
    if not loadModel(model) then return end

    local coords = GetEntityCoords(veh)
    -- Apparition juste au-dessus du vehicule (et non sous la map) pour eviter l'invisibilite due a l'occlusion
    local prop = CreateObject(model, coords.x, coords.y, coords.z + 2.0, false, false, false)

    -- Desactivation des collisions pour eviter les bugs physiques avec le vehicule ou le sol
    SetEntityCompletelyDisableCollision(prop, false, false)
    SetEntityCollision(prop, false, false)

    local o, r = SabotConfig.PropOffset, SabotConfig.PropRotation
    AttachEntityToEntity(prop, veh, bone, o.x, o.y, o.z, r.x, r.y, r.z, false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)

    localProps[veh] = prop
end

local function detachProp(veh)
    if localProps[veh] and DoesEntityExist(localProps[veh]) then
        DeleteEntity(localProps[veh])
    end
    localProps[veh] = nil
end

local function applyClamp(veh)
    if not DoesEntityExist(veh) then return end
    attachProp(veh)
    FreezeEntityPosition(veh, true)
    SetVehicleUndriveable(veh, true)
end

local function clearClamp(veh)
    detachProp(veh)
    if DoesEntityExist(veh) then
        FreezeEntityPosition(veh, false)
        SetVehicleUndriveable(veh, false)
    end
end

local function isVehClamped(veh)
    if not DoesEntityExist(veh) then return false end
    -- Véhicule local (non réseau) : pas de netId, donc jamais saboté.
    if not NetworkGetEntityIsNetworked(veh) then return false end
    local nid = NetworkGetNetworkIdFromEntity(veh)
    return nid ~= 0 and clampedNetIds[nid] == true
end

-- ---------- Synchronisation réseau ----------

RegisterNetEvent('pop_sabot:client:sync', function(netId, state)
    if state then
        clampedNetIds[netId] = true
    else
        clampedNetIds[netId] = nil
    end
    local veh = NetToVeh(netId)
    if veh ~= 0 and DoesEntityExist(veh) then
        if state then applyClamp(veh) else clearClamp(veh) end
    end
end)

RegisterNetEvent('pop_sabot:client:fullSync', function(list)
    clampedNetIds = {}
    for _, netId in ipairs(list) do
        clampedNetIds[netId] = true
    end
end)

-- Demande l'état courant au démarrage
CreateThread(function()
    Wait(1500)
    TriggerServerEvent('pop_sabot:server:requestSync')
end)

-- Boucle de maintenance : applique l'état aux véhicules streamés
-- (gère stream in/out et changements de propriétaire réseau)
CreateThread(function()
    while true do
        Wait(2000)
        -- Rien à appliquer ni à nettoyer : on évite de parcourir tout le pool véhicules
        if next(clampedNetIds) == nil and next(localProps) == nil then goto continue end
        do
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            seen[veh] = true
            if isVehClamped(veh) then
                applyClamp(veh)
            elseif localProps[veh] then
                clearClamp(veh)
            end
        end
        -- Nettoie les props dont le véhicule a disparu localement
        for veh, prop in pairs(localProps) do
            if not seen[veh] or not DoesEntityExist(veh) then
                if DoesEntityExist(prop) then DeleteEntity(prop) end
                localProps[veh] = nil
            end
        end
        end
        ::continue::
    end
end)

-- Renforcement immédiat : si on monte dans un véhicule saboté, il reste figé
CreateThread(function()
    while true do
        Wait(250)
        local veh = next(clampedNetIds) ~= nil and GetVehiclePedIsIn(PlayerPedId(), false) or 0
        if veh ~= 0 and isVehClamped(veh) then
            applyClamp(veh)
        end
    end
end)

-- ---------- Action joueur (anim + barre de progression) ----------

local function DrawTextProgress(Text, Text3, Taille, Text2, Font, Justi, havetext)
    SetTextFont(Font)
    SetTextScale(Taille, Taille)
    SetTextColour(255, 255, 255, 255)
    SetTextJustification(Justi or 1)
    SetTextEntry("STRING")
    if havetext then SetTextWrap(Text, Text + .1) end
    AddTextComponentString(Text2)
    DrawText(Text, Text3)
end

local LoadPoint = {".", "..", "...", ""}

local function doAction(label, duration)
    local ped = PlayerPedId()
    local dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, 'machinic_loop_mechandplayer', 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    local ok = true
    local start = GetGameTimer()
    local endTime = start + duration
    local pointStr = ""
    local nextPointTime = start + 500

    while GetGameTimer() < endTime do
        Wait(0)
        local now = GetGameTimer()
        local progress = (now - start) / duration

        if now >= nextPointTime then
            nextPointTime = now + 500
            pointStr = LoadPoint[string.len(pointStr) + 1] or ""
            if string.len(pointStr) > 3 then pointStr = "" end
        end

        -- Rendu de la barre
        DrawRect(0.5, 0.84, 0.15, 0.03, 0, 0, 0, 100)
        local y, endroit = 0.15 - 0.0025, 0.03 - 0.005
        local chance = math.max(0, math.min(y, y * progress))
        DrawRect((0.5 - y / 2) + chance / 2, 0.84, chance, endroit, 0, 155, 255, 125)
        DrawTextProgress(0.5, 0.84 - 0.0125, 0.3, (label or L('action_in_progress')) .. pointStr, 0, 0, false)

        -- Blocage des controles
        DisableControlAction(0, 30, true) -- move lr
        DisableControlAction(0, 31, true) -- move ud
        DisableControlAction(0, 21, true) -- sprint
        DisableControlAction(0, 22, true) -- jump
        DisableControlAction(0, 24, true) -- attack
        DisableControlAction(0, 25, true) -- aim
        DisableControlAction(0, 36, true) -- duck

        -- Cancel avec X ou mort
        if IsDisabledControlJustPressed(0, 73) or IsEntityDead(ped) then
            ok = false
            break
        end
    end

    ClearPedTasks(ped)
    return ok
end

local function placeOnVehicle(veh)
    if busy or not DoesEntityExist(veh) then return end
    if not NetworkGetEntityIsNetworked(veh) then
        Bridge.Notify({ message = L('vehicle_not_networked'), type = 'error' })
        return
    end
    if isVehClamped(veh) then
        Bridge.Notify({ message = L('clamp_already'), type = 'error' })
        return
    end
    if not vehicleHasClampBone(veh) then
        Bridge.Notify({ message = L('vehicle_incompatible'), type = 'error' })
        return
    end

    busy = true
    if doAction(L('clamp_placing'), SabotConfig.PlaceDuration) then
        TriggerServerEvent('pop_sabot:server:place', NetworkGetNetworkIdFromEntity(veh))
    end
    busy = false
end

local function removeFromVehicle(veh)
    if busy or not DoesEntityExist(veh) then return end
    if not NetworkGetEntityIsNetworked(veh) then
        Bridge.Notify({ message = L('vehicle_not_networked'), type = 'error' })
        return
    end
    if not isVehClamped(veh) then
        Bridge.Notify({ message = L('clamp_none'), type = 'error' })
        return
    end

    busy = true
    if doAction(L('clamp_removing'), SabotConfig.RemoveDuration) then
        TriggerServerEvent('pop_sabot:server:remove', NetworkGetNetworkIdFromEntity(veh))
    end
    busy = false
end

local function getClosestVehicle()
    local c = GetEntityCoords(PlayerPedId())
    local veh = GetClosestVehicle(c.x, c.y, c.z, SabotConfig.Distance, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

-- ---------- Utilisation des items ----------

RegisterNetEvent('pop_sabot:client:useSabot', function()
    local veh = getClosestVehicle()
    if not veh then
        Bridge.Notify({ message = L('no_vehicle_nearby'), type = 'error' })
        return
    end
    placeOnVehicle(veh)
end)

RegisterNetEvent('pop_sabot:client:useCle', function()
    local veh = getClosestVehicle()
    if not veh then
        Bridge.Notify({ message = L('no_vehicle_nearby'), type = 'error' })
        return
    end
    removeFromVehicle(veh)
end)

-- ---------- ox_target : interactions sur les véhicules ----------

exports.ox_target:addGlobalVehicle({
    {
        name     = 'tab_sabot_place',
        icon     = 'fas fa-lock',
        label    = L('target_clamp_place'),
        distance = 3.0,
        canInteract = function(entity)
            if not IsEntityAVehicle(entity) then return false end
            if isVehClamped(entity) then return false end

            local status, count = pcall(function()
                return exports.pop_inventory:getItemCount(SabotConfig.SabotItem)
            end)

            if not status then return true end
            return count and tonumber(count) and tonumber(count) > 0
        end,
        onSelect = function(data)
            placeOnVehicle(data.entity)
        end
    },
    {
        name     = 'tab_sabot_remove',
        icon     = 'fas fa-key',
        label    = L('target_clamp_remove'),
        distance = 3.0,
        canInteract = function(entity)
            if not IsEntityAVehicle(entity) then return false end
            if not isVehClamped(entity) then return false end

            local status, count = pcall(function()
                return exports.pop_inventory:getItemCount(SabotConfig.KeyItem)
            end)

            if not status then return true end
            return count and tonumber(count) and tonumber(count) > 0
        end,
        onSelect = function(data)
            removeFromVehicle(data.entity)
        end
    }
})

-- ---------- Nettoyage à l'arrêt de la ressource ----------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh, prop in pairs(localProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
        if DoesEntityExist(veh) then
            FreezeEntityPosition(veh, false)
            SetVehicleUndriveable(veh, false)
        end
    end
    localProps = {}
end)
