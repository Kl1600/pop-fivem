-- Roues : porter, démonter et monter une roue (ox_target).

-- =====================================================
-- ROUES (Démontage / Montage avec ls_bolt_minigame)
-- =====================================================
local carryWheelProp = nil
local isCarryingWheel = false
local isMounting = false
local savedBoneCoords = {}

AddStateBagChangeHandler(nil, nil, function(bagName, key, value, _reserved, replicated)
    if not key:find('^wheelOffset_') then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local wheelIndex = tonumber(key:match('_(%d+)$'))
    if wheelIndex and type(value) == 'number' then
        SetVehicleWheelXOffset(entity, wheelIndex, value)
    end
end)

local function removeWheelProp()
    if carryWheelProp and DoesEntityExist(carryWheelProp) then
        DeleteEntity(carryWheelProp)
    end
    carryWheelProp = nil
    if isCarryingWheel then
        ClearPedTasks(PlayerPedId())
        isCarryingWheel = false
    end
end

local function attachWheelProp()
    local ped = PlayerPedId()
    if carryWheelProp and DoesEntityExist(carryWheelProp) then return end

    local model = GetHashKey('prop_wheel_tyre')
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end

    local coords = GetEntityCoords(ped)
    carryWheelProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)

    local bone = GetPedBoneIndex(ped, 28422) -- main droite
    RequestAnimDict('anim@heists@box_carry@')
    local t2 = GetGameTimer() + 2000
    while not HasAnimDictLoaded('anim@heists@box_carry@') and GetGameTimer() < t2 do Wait(0) end

    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
    AttachEntityToEntity(carryWheelProp, ped, bone, 0.0, -0.1, -0.05, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    isCarryingWheel = true
end

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local hasTyre = false
        pcall(function()
            if exports.pop_inventory and exports.pop_inventory.getItemCount then
                hasTyre = exports.pop_inventory:getItemCount('tyre') > 0 or exports.pop_inventory:getItemCount('tyre_burst') > 0
            end
        end)

        if hasTyre and not isMounting then
            if not isCarryingWheel then
                attachWheelProp()
            else
                if not IsEntityPlayingAnim(ped, 'anim@heists@box_carry@', 'idle', 3) then
                    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
                end
            end
        else
            if isCarryingWheel then
                removeWheelProp()
            end
        end
    end
end)

RegisterNetEvent('pop_inventory:client:useTyre', function()
    -- Géré automatiquement par la boucle de l'inventaire
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        removeWheelProp()
    end
end)

local function isWheelMounted(vehicle, wheelIndex)
    local state = Entity(vehicle).state['wheelOffset_'..wheelIndex]
    if state and state == 9999.0 then
        return false
    end
    local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
    local boneId = GetEntityBoneIndexByName(vehicle, bones[wheelIndex + 1])
    if boneId == -1 then return false end
    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneId)
    local chassisBone = GetEntityBoneIndexByName(vehicle, 'chassis_dummy')
    local chassisCoords = GetWorldPositionOfEntityBone(vehicle, chassisBone)
    if #(chassisCoords - boneCoords) > 10.0 then
        return false
    end
    return true
end

local function getClosestMissingWheel(vehicle, pCoords)
    local minDistance = 3.0
    local closest = nil
    for i = 0, 3 do
        if not isWheelMounted(vehicle, i) then
            local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
            local boneId = GetEntityBoneIndexByName(vehicle, bones[i + 1])
            if boneId ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneId)
                local dist = #(pCoords - boneCoords)
                if dist < minDistance then
                    minDistance = dist
                    closest = i
                end
            end
        end
    end
    return closest
end

local function getWheelIndexFromBone(entity, bone)
    if type(bone) == 'string' then
        if bone == 'wheel_rf' then return 1
        elseif bone == 'wheel_lr' then return 2
        elseif bone == 'wheel_rr' then return 3
        else return 0 end
    elseif type(bone) == 'number' then
        local bones = {'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr'}
        for i = 0, 3 do
            if GetEntityBoneIndexByName(entity, bones[i + 1]) == bone then
                return i
            end
        end
    end
    -- Fallback si ox_target ne passe pas de bone (on prend la plus proche du joueur)
    local pedCoords = GetEntityCoords(PlayerPedId())
    local minDistance = 3.0
    local closest = nil
    for i = 0, 3 do
        local bones = {'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr'}
        local boneId = GetEntityBoneIndexByName(entity, bones[i + 1])
        if boneId ~= -1 then
            local boneCoords = GetWorldPositionOfEntityBone(entity, boneId)
            local dist = #(pedCoords - boneCoords)
            if dist < minDistance then
                minDistance = dist
                closest = i
            end
        end
    end
    return closest
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'unmount_wheel',
        icon = 'fas fa-wrench',
        label = L('target_wheel_remove'),
        groups = { 'mechanic', 'bennys' },
        bones = { 'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr' },
        distance = 2.0,
        canInteract = function(entity, distance, coords, name, bone)
            local wheelIndex = getWheelIndexFromBone(entity, bone)
            if not wheelIndex then return false end
            return isWheelMounted(entity, wheelIndex)
        end,
        onSelect = function(data)
            local wheelIndex = getWheelIndexFromBone(data.entity, data.bone)
            if not wheelIndex then return end

            local bones = {'wheel_lf','wheel_rf', 'wheel_lr', 'wheel_rr'}
            local boneId = GetEntityBoneIndexByName(data.entity, bones[wheelIndex + 1])
            local boneCoords = GetWorldPositionOfEntityBone(data.entity, boneId)

            local vehNetId = NetworkGetNetworkIdFromEntity(data.entity)
            if vehNetId ~= 0 then
                savedBoneCoords[vehNetId .. '_' .. wheelIndex] = boneCoords
            end

            local success = exports['ls_bolt_minigame']:BoltMinigame(data.entity, wheelIndex, false, true)
            if success then
                local originalOffset = GetVehicleWheelXOffset(data.entity, wheelIndex)
                Entity(data.entity).state:set('wheelOrig_'..wheelIndex, originalOffset, true)
                Entity(data.entity).state:set('wheelCoords_'..wheelIndex, boneCoords, true)
                Entity(data.entity).state:set('wheelOffset_'..wheelIndex, 9999.0, true)

                -- Donne TOUJOURS un pneu usé lors du démontage
                TriggerServerEvent('pop_inventory:server:giveWheel', true)
                Wait(500)
                if (exports.pop_inventory:getItemCount('tyre') > 0 or exports.pop_inventory:getItemCount('tyre_burst') > 0) and not isCarryingWheel then
                    attachWheelProp()
                end
            end
        end
    },
    {
        name = 'mount_wheel',
        icon = 'fas fa-wrench',
        label = L('target_wheel_mount'),
        groups = { 'mechanic', 'bennys' },
        bones = { 'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr' },
        canInteract = function(entity, distance, coords, name, bone)
            if exports.pop_inventory:getItemCount('tyre') == 0 then return false end
            local missingIndex = getClosestMissingWheel(entity, coords)
            return missingIndex ~= nil
        end,
        onSelect = function(data)
            local ped = PlayerPedId()
            local missingIndex = getClosestMissingWheel(data.entity, GetEntityCoords(ped))
            if missingIndex then
                local coordsForMinigame = Entity(data.entity).state['wheelCoords_'..missingIndex]
                local vehNetId = NetworkGetNetworkIdFromEntity(data.entity)
                if not coordsForMinigame and vehNetId ~= 0 then
                    coordsForMinigame = savedBoneCoords[vehNetId .. '_' .. missingIndex]
                end

                -- Retirer le prop des mains avant de commencer
                if isCarryingWheel then
                    removeWheelProp()
                end

                -- Remettre la roue sur la voiture visuellement pour le minijeu
                local origOffset = Entity(data.entity).state['wheelOrig_'..missingIndex]
                if not origOffset then
                    origOffset = (missingIndex % 2 == 0) and -0.8 or 0.8
                end
                Entity(data.entity).state:set('wheelOffset_'..missingIndex, origOffset, true)

                -- Lancer le minijeu
                isMounting = true
                local success = exports['ls_bolt_minigame']:BoltMinigame(data.entity, missingIndex, true, true, coordsForMinigame)
                isMounting = false

                if success then
                    -- Retirer l'item de l'inventaire
                    TriggerServerEvent('pop_inventory:server:removeWheel')

                    -- Informer la checklist mécano (et réparer la crevaison)
                    TriggerEvent('vg_engine:client:wheelMountedChecklist', data.entity, missingIndex)
                else
                    -- Le joueur a annulé ou échoué, on recache la roue
                    Entity(data.entity).state:set('wheelOffset_'..missingIndex, 9999.0, true)
                    -- On lui remet le prop dans les mains s'il a toujours l'item
                    if exports.pop_inventory:getItemCount('tyre') > 0 then
                        attachWheelProp()
                    end
                end
            end
        end
    }
})
