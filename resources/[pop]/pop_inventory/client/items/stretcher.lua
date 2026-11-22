-- Brancard : pousser, s'allonger, placer un blessé, ambulance.

-- =============================================================
-- LOGIQUE DU BRANCARD (EMS STRETCHER)
-- =============================================================
local isPushing = false
local pushedStretcher = nil
local isAttachedToStretcher = false
local stretcherEntity = nil
local wasPlaced = false -- luacheck: ignore 231
local equippedStretcherObj = nil

local function GetClosestAmbulance(coords)
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        if GetEntityModel(veh) == GetHashKey("ambulance") then
            local vCoords = GetEntityCoords(veh)
            if #(coords - vCoords) < 5.0 then
                return veh
            end
        end
    end
    return nil
end

local function stopPushingStretcher()
    if not isPushing then return end
    isPushing = false
    if DoesEntityExist(pushedStretcher) then
        local stretcher = pushedStretcher
        DetachEntity(stretcher, true, true)
        CreateThread(function()
            local count = 0
            while DoesEntityExist(stretcher) and count < 10 do
                FreezeEntityPosition(stretcher, false)
                SetEntityCollision(stretcher, true, true)
                PlaceObjectOnGroundProperly(stretcher)
                FreezeEntityPosition(stretcher, true)
                Wait(100)
                count = count + 1
            end
            if DoesEntityExist(stretcher) then
                FreezeEntityPosition(stretcher, true)
                SetEntityCollision(stretcher, true, true)
                SetEntityHasGravity(stretcher, false)
            end
        end)
    end
    pushedStretcher = nil
end

local function pushStretcher(stretcher)
    local ped = PlayerPedId()
    isPushing = true
    pushedStretcher = stretcher

    NetworkRequestControlOfEntity(stretcher)
    FreezeEntityPosition(stretcher, false)
    SetEntityCollision(stretcher, true, true)
    AttachEntityToEntity(stretcher, ped, 0, 0.0, 1.3, -1.0, 0.0, 0.0, 90.0, true, true, false, true, 1, true)

    CreateThread(function()
        RequestAnimDict("anim@mp_ferris_wheel")
        while not HasAnimDictLoaded("anim@mp_ferris_wheel") do Wait(10) end

        while isPushing do
            if not IsEntityPlayingAnim(ped, "anim@mp_ferris_wheel", "idle_a_player_two", 3) then
                TaskPlayAnim(ped, "anim@mp_ferris_wheel", "idle_a_player_two", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(500)
        end
        ClearPedTasks(ped)
    end)
end

-- Spawning stretcher automatically when equipped in inventory
RegisterNetEvent('pop_inventory:client:applyEquipment', function(equipment)
    local hasStretcherEquipped = false
    if equipment and equipment['briefcase'] then
        local item = equipment['briefcase']
        local defId = (type(item) == 'table' and item.defId) or item
        if defId == 'brancard' then
            hasStretcherEquipped = true
        end
    end

    if hasStretcherEquipped then
        if not equippedStretcherObj or not DoesEntityExist(equippedStretcherObj) then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            local hash = GetHashKey("strykergurney")
            RequestModel(hash)
            while not HasModelLoaded(hash) do Wait(10) end

            equippedStretcherObj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, true)
            SetEntityHeading(equippedStretcherObj, heading)

            pushStretcher(equippedStretcherObj)
        end
    else
        if equippedStretcherObj and DoesEntityExist(equippedStretcherObj) then
            stopPushingStretcher()
            DeleteEntity(equippedStretcherObj)
            equippedStretcherObj = nil
            wasPlaced = false
        end
    end
end)

-- Thread to handle keypresses and help UI while pushing to place stretcher
CreateThread(function()
    while true do
        local sleep = 500
        if isPushing and equippedStretcherObj and DoesEntityExist(equippedStretcherObj) then
            sleep = 0

            -- Display help text using basic GTA native to ensure it shows regardless of ESX timing
            AddTextEntry('HELP_TXT', L('stretcher_place_help'))
            BeginTextCommandDisplayHelp('HELP_TXT')
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, 47) or IsDisabledControlJustReleased(0, 47) then -- 47 is G by default (INPUT_DETONATE)
                wasPlaced = true
                TriggerServerEvent('pop_inventory:server:dropBrancard')
            end
        end
        Wait(sleep)
    end
end)

local function getUpFromStretcher()
    if not isAttachedToStretcher then return end
    isAttachedToStretcher = false
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    ClearPedTasks(ped)

    if DoesEntityExist(stretcherEntity) then
        local netId = NetworkGetNetworkIdFromEntity(stretcherEntity)
        TriggerServerEvent('pop_inventory:server:setStretcherPlayer', netId, false)
    end
    stretcherEntity = nil
end

local function layOnStretcher(stretcher)
    local ped = PlayerPedId()
    isAttachedToStretcher = true
    stretcherEntity = stretcher

    local netId = NetworkGetNetworkIdFromEntity(stretcher)
    TriggerServerEvent('pop_inventory:server:setStretcherPlayer', netId, true)

    AttachEntityToEntity(ped, stretcher, 0, 0.0, 0.0, 1.05, 0.0, 0.0, 180.0, true, true, false, true, 1, true)

    RequestAnimDict("anim@gangops@facility@hospital_bed@")
    while not HasAnimDictLoaded("anim@gangops@facility@hospital_bed@") do Wait(10) end
    TaskPlayAnim(ped, "anim@gangops@facility@hospital_bed@", "floor_help_loop_b", 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function GetClosestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestPlayer = -1
    local closestDistance = -1
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped then
            local tCoords = GetEntityCoords(targetPed)
            local dist = #(coords - tCoords)
            if dist < 3.0 and (closestDistance == -1 or dist < closestDistance) then
                closestPlayer = playerId
                closestDistance = dist
            end
        end
    end
    return closestPlayer
end

local function placeWoundedOnStretcher(stretcher)
    local closestPlayer = GetClosestPlayer()
    if closestPlayer ~= -1 then
        local targetServerId = GetPlayerServerId(closestPlayer)
        local netId = NetworkGetNetworkIdFromEntity(stretcher)
        TriggerServerEvent('pop_inventory:server:placePlayerOnStretcher', targetServerId, netId)
    else
        Inv.NotifyTyped({
            title = L('stretcher_title'),
            message = L('no_wounded_nearby'),
            type = 'error',
            duration = 5000
        })
    end
end

local function detachWoundedFromStretcher(stretcher)
    local netId = NetworkGetNetworkIdFromEntity(stretcher)
    TriggerServerEvent('pop_inventory:server:detachPlayerFromStretcher', netId)
end

local function putStretcherInAmbulance(stretcher)
    local coords = GetEntityCoords(stretcher)
    local ambulance = GetClosestAmbulance(coords)
    if ambulance then
        if isPushing and pushedStretcher == stretcher then
            stopPushingStretcher()
            if equippedStretcherObj == stretcher then
                wasPlaced = true
                TriggerServerEvent('pop_inventory:server:removeBrancard')
            end
        end
        NetworkRequestControlOfEntity(stretcher)
        AttachEntityToEntity(stretcher, ambulance, 0, 0.0, -2.1, -0.4, 0.0, 0.0, 0.0, false, false, true, false, 2, true)
    end
end

local function takeStretcherOutAmbulance(stretcher)
    NetworkRequestControlOfEntity(stretcher)
    DetachEntity(stretcher, true, true)

    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local pos = GetEntityCoords(ped) + forward * 1.0
    SetEntityCoords(stretcher, pos.x, pos.y, pos.z - 0.5, false, false, false, true)

    CreateThread(function()
        local count = 0
        while DoesEntityExist(stretcher) and count < 10 do
            FreezeEntityPosition(stretcher, false)
            SetEntityCollision(stretcher, true, true)
            PlaceObjectOnGroundProperly(stretcher)
            FreezeEntityPosition(stretcher, true)
            Wait(100)
            count = count + 1
        end
        if DoesEntityExist(stretcher) then
            FreezeEntityPosition(stretcher, true)
            SetEntityCollision(stretcher, true, true)
            SetEntityHasGravity(stretcher, false)
        end
    end)
end

local function pickupStretcher(stretcher)
    local coords = GetEntityCoords(stretcher)
    TriggerServerEvent('pop_inventory:server:pickupStretcherProp', coords)
    if DoesEntityExist(stretcher) then
        NetworkRequestControlOfEntity(stretcher)
        DeleteEntity(stretcher)
    end
end

local function startPushingStretcherFromGround(stretcher)
    local coords = GetEntityCoords(stretcher)
    TriggerServerEvent('pop_inventory:server:pushStretcherProp', coords)
    if DoesEntityExist(stretcher) then
        NetworkRequestControlOfEntity(stretcher)
        DeleteEntity(stretcher)
    end
end

-- Item usage event from inventory
RegisterNetEvent('pop_inventory:client:useBrancard', function()
    TriggerServerEvent('pop_inventory:server:useBrancard')
end)

RegisterNetEvent('pop_inventory:client:forcedOnStretcher', function(stretcherNetId)
    local stretcher = NetworkGetEntityFromNetworkId(stretcherNetId)
    if DoesEntityExist(stretcher) then
        layOnStretcher(stretcher)
    end
end)

RegisterNetEvent('pop_inventory:client:forcedOffStretcher', function()
    getUpFromStretcher()
end)

-- ox_target integration
CreateThread(function()
    while not exports or not exports.ox_target do Wait(100) end

    local options = {
        {
            name = 'push_stretcher',
            icon = 'fas fa-hand-holding',
            label = L('target_stretcher_push'),
            canInteract = function(entity, distance, coords, name, bone)
                return not isPushing and not isAttachedToStretcher and not Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                startPushingStretcherFromGround(data.entity)
            end
        },
        {
            name = 'stop_push_stretcher',
            icon = 'fas fa-hand-holding-slash',
            label = L('target_stretcher_release'),
            canInteract = function(entity, distance, coords, name, bone)
                return isPushing and pushedStretcher == entity
            end,
            onSelect = function(data)
                stopPushingStretcher()
            end
        },
        {
            name = 'lay_on_stretcher',
            icon = 'fas fa-bed',
            label = L('target_stretcher_lay'),
            canInteract = function(entity, distance, coords, name, bone)
                return not isAttachedToStretcher and not Entity(entity).state.hasPlayer and not isPushing and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                layOnStretcher(data.entity)
            end
        },
        {
            name = 'get_up_stretcher',
            icon = 'fas fa-walking',
            label = L('target_stretcher_getup'),
            canInteract = function(entity, distance, coords, name, bone)
                return isAttachedToStretcher and stretcherEntity == entity
            end,
            onSelect = function(data)
                getUpFromStretcher()
            end
        },
        {
            name = 'place_wounded',
            icon = 'fas fa-user-injured',
            label = L('target_stretcher_place'),
            canInteract = function(entity, distance, coords, name, bone)
                return not Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                placeWoundedOnStretcher(data.entity)
            end
        },
        {
            name = 'detach_wounded',
            icon = 'fas fa-user-plus',
            label = L('target_stretcher_detach'),
            canInteract = function(entity, distance, coords, name, bone)
                return Entity(entity).state.hasPlayer and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                detachWoundedFromStretcher(data.entity)
            end
        },
        {
            name = 'put_in_ambulance',
            icon = 'fas fa-ambulance',
            label = L('target_stretcher_in_amb'),
            canInteract = function(entity, distance, coords, name, bone)
                local ambulance = GetClosestAmbulance(coords)
                return ambulance ~= nil and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                putStretcherInAmbulance(data.entity)
            end
        },
        {
            name = 'take_out_ambulance',
            icon = 'fas fa-ambulance',
            label = L('target_stretcher_out_amb'),
            canInteract = function(entity, distance, coords, name, bone)
                return IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                takeStretcherOutAmbulance(data.entity)
            end
        },
        {
            name = 'pickup_stretcher',
            icon = 'fas fa-hands',
            label = L('target_stretcher_pickup'),
            canInteract = function(entity, distance, coords, name, bone)
                return not Entity(entity).state.hasPlayer and not isPushing and not IsEntityAttachedToAnyVehicle(entity)
            end,
            onSelect = function(data)
                pickupStretcher(data.entity)
            end
        }
    }
    exports.ox_target:addModel('strykergurney', options)
end)

-- Safety thread to handle vehicle entries and deaths
CreateThread(function()
    while true do
        local sleep = 500
        if isPushing then
            sleep = 100
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, true) or IsEntityDead(ped) then
                stopPushingStretcher()
            end
        end
        Wait(sleep)
    end
end)
