Police = Police or {}
local cuffs, officer, pendingFine
local cuffLoop, escortLoop = false, false
local cuffPed, attachedPed
local controls = { 21, 22, 23, 24, 25, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264 }
local anim = 'mp_arresting'

local function removeCuffs()
    if cuffPed and DoesEntityExist(cuffPed) then
        StopAnimTask(cuffPed, anim, 'idle', 2.0)
        SetEnableHandcuffs(cuffPed, false)
    end
    cuffPed = nil
end

local function setCuffs(state)
    cuffs = state == true
    if not cuffs then
        removeCuffs()
        RemoveAnimDict(anim)
        return
    end
    Police.CloseUi()
    Bridge.CancelProgress()
    if cuffLoop then return end
    cuffLoop = true
    CreateThread(function()
        RequestAnimDict(anim)
        local nextAnimation = 0
        while cuffs do
            local ped = PlayerPedId()
            if ped ~= cuffPed then
                removeCuffs()
                cuffPed = ped
                SetEnableHandcuffs(ped, true)
                SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
                nextAnimation = 0
            end
            DisablePlayerFiring(PlayerId(), true)
            for _, control in ipairs(controls) do DisableControlAction(0, control, true) end
            local now = GetGameTimer()
            if now >= nextAnimation then
                nextAnimation = now + 1000
                SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
                if not IsEntityDead(ped) and HasAnimDictLoaded(anim) and not IsEntityPlayingAnim(ped, anim, 'idle', 3) then
                    TaskPlayAnim(ped, anim, 'idle', 4.0, -4.0, -1, 49, 0, false, false, false)
                elseif not HasAnimDictLoaded(anim) then
                    RequestAnimDict(anim)
                end
            end
            Wait(0)
        end
        cuffLoop = false
    end)
end

local function detach()
    if attachedPed and DoesEntityExist(attachedPed) then DetachEntity(attachedPed, true, false) end
    attachedPed = nil
end

local function setEscort(id)
    officer = type(id) == 'number' and id or nil
    if not officer then
        detach()
        return
    end
    if escortLoop then return end
    escortLoop = true
    CreateThread(function()
        while officer do
            local player = GetPlayerFromServerId(officer)
            local escort = player ~= -1 and GetPlayerPed(player)
            local ped = PlayerPedId()
            if attachedPed and attachedPed ~= ped then detach() end
            if escort and DoesEntityExist(escort) and not IsEntityDead(escort)
                and not IsPedInAnyVehicle(escort, false) and not IsPedInAnyVehicle(ped, false) then
                if not IsEntityAttachedToEntity(ped, escort) then
                    local offset = Police.ESCORT_OFFSET
                    AttachEntityToEntity(ped, escort, GetPedBoneIndex(escort, 11816), offset.x, offset.y, offset.z,
                        0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    attachedPed = ped
                end
            else
                detach()
            end
            Wait(500)
        end
        escortLoop = false
    end)
end

AddStateBagChangeHandler(Police.STATE_CUFFED, nil, function(bagName, _, value)
    if bagName == 'player:' .. GetPlayerServerId(PlayerId()) then setCuffs(value) end
end)
AddStateBagChangeHandler(Police.STATE_ESCORT, nil, function(bagName, _, value)
    if bagName == 'player:' .. GetPlayerServerId(PlayerId()) then setEscort(value) end
end)
local function readEffects()
    setCuffs(LocalPlayer.state[Police.STATE_CUFFED])
    setEscort(LocalPlayer.state[Police.STATE_ESCORT])
end
Bridge.OnPlayerLoaded(readEffects)
CreateThread(readEffects)

RegisterNetEvent('pop_police:client:beingCuffed', function()
    if source == 65535 then Bridge.Notify(L('being_cuffed'), 'warning') end
end)

Callback.Register('pop_police:enterVehicle', function(netId)
    if not cuffs or math.type(netId) ~= 'integer' or not NetworkDoesEntityExistWithNetworkId(netId) then return false end
    local vehicle, ped = NetToVeh(netId), PlayerPedId()
    if vehicle == 0 or not DoesEntityExist(vehicle) or IsPedInAnyVehicle(ped, false) then return false end
    detach()
    for _, seat in ipairs({ 1, 2, 0 }) do
        if seat < GetVehicleMaxNumberOfPassengers(vehicle) and IsVehicleSeatFree(vehicle, seat) then
            TaskWarpPedIntoVehicle(ped, vehicle, seat)
            return true
        end
    end
    return false
end)

RegisterNetEvent('pop_police:client:leaveVehicle', function()
    if source ~= 65535 or not cuffs then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then TaskLeaveVehicle(ped, vehicle, 16) end
end)

local function hideFine()
    pendingFine = nil
    SendNUIMessage({ action = 'pop_police:fineRequest', show = false })
end

RegisterNetEvent('pop_police:client:fineRequest', function(data)
    if source ~= 65535 then return end
    pendingFine = data.id
    SendNUIMessage({
        action = 'pop_police:fineRequest', show = true, theme = Config.Theme, id = data.id, amount = data.amount,
        reason = data.reason, officer = data.officer, timeout = Config.Fines.timeout,
        -- FiveM allows per-player remapping. The card uses the server defaults.
        acceptKey = Config.KeyMappings.acceptFine, declineKey = Config.KeyMappings.declineFine,
    })
    SetTimeout((Config.Fines.timeout + 2) * 1000, function()
        if pendingFine == data.id then hideFine() end
    end)
end)
RegisterNetEvent('pop_police:client:fineClosed', function(id)
    if source == 65535 and pendingFine == id then hideFine() end
end)

local function respondFine(accept)
    if not pendingFine then return end
    local id = pendingFine
    hideFine()
    CreateThread(function() Police.Request('respondFine', id, accept) end)
end
RegisterCommand('pop_police_accept', function() respondFine(true) end, false)
RegisterCommand('pop_police_decline', function() respondFine(false) end, false)
RegisterKeyMapping('pop_police_accept', L('keymap_accept'), 'keyboard', Config.KeyMappings.acceptFine)
RegisterKeyMapping('pop_police_decline', L('keymap_decline'), 'keyboard', Config.KeyMappings.declineFine)

exports('IsCuffed', function() return LocalPlayer.state[Police.STATE_CUFFED] == true end)
exports('IsEscorted', function() return officer ~= nil end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    setCuffs(false)
    setEscort(nil)
    hideFine()
end)
