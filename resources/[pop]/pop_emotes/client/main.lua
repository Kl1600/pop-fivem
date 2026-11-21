local active, generation, watching = nil, 0, false
local loadingDict
local menuOpen, pending, actionBusy = false, nil, false
local menuVersion = 0
local savedKey = 'pop_emotes:favorites:v1'
local favorites = {}
local encoded = GetResourceKvpString(savedKey)
if encoded then
    local ok, data = pcall(json.decode, encoded)
    if ok and type(data) == 'table' then
        for id, favorite in pairs(data) do
            if Config.Catalog[id] and favorite == true then favorites[id] = true end
        end
    end
end

local function send(action, data)
    data = data or {}
    data.action = 'pop_emotes:' .. action
    SendNUIMessage(data)
end

local function possible()
    local ped = PlayerPedId()
    local player = Bridge.GetPlayerData()
    local metadata = (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') and player.metadata
    return Bridge.IsLoaded() and ped ~= 0 and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false)
        and not (metadata and (metadata.ishandcuffed or metadata.isdead or metadata.inlaststand))
        and not IsPauseMenuActive() and not LocalPlayer.state.cuffed and not LocalPlayer.state.charcreatorOpen
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    menuVersion = menuVersion + 1
    SetNuiFocus(false, false)
    send('close')
end
Bridge.OnUiClose(closeMenu)

local function stop()
    generation = generation + 1
    if loadingDict then
        RemoveAnimDict(loadingDict)
        loadingDict = nil
    end
    if not active then return end
    if DoesEntityExist(active.ped) then StopAnimTask(active.ped, active.dict, active.clip, 3.0) end
    RemoveAnimDict(active.dict)
    active = nil
end

local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while active do
            if not possible() or PlayerPedId() ~= active.ped or GetGameTimer() >= active.expires
                or (GetGameTimer() - active.start > 450 and not IsEntityPlayingAnim(active.ped, active.dict, active.clip, 3)) then
                stop()
                break
            end
            Wait(200)
        end
        watching = false
    end)
end

local function play(id, target, responding)
    local choice = type(id) == 'string' and Config.Catalog[id]
    if not choice or not possible() or (choice.shared and not target) then return false end
    local clip = responding and choice.reply or choice.clip
    if not DoesAnimDictExist(choice.dict) or type(clip) ~= 'string' then return false end
    stop()
    local version, ped = generation, PlayerPedId()
    loadingDict = choice.dict
    RequestAnimDict(choice.dict)
    local deadline = GetGameTimer() + 2500
    while not HasAnimDictLoaded(choice.dict) and GetGameTimer() < deadline and generation == version do Wait(50) end
    if generation ~= version or ped ~= PlayerPedId() or not possible() or not HasAnimDictLoaded(choice.dict)
        or GetAnimDuration(choice.dict, clip) <= 0 then
        if generation == version then stop() end
        return false
    end
    if target then
        local player = GetPlayerFromServerId(target)
        local other = player ~= -1 and GetPlayerPed(player)
        if not other or not DoesEntityExist(other)
            or #(GetEntityCoords(ped) - GetEntityCoords(other)) > Config.InviteDistance + 0.75 then
            stop()
            return false
        end
        TaskTurnPedToFaceEntity(ped, other, 450)
        Wait(350)
        if generation ~= version or ped ~= PlayerPedId() or not possible() or not DoesEntityExist(other)
            or #(GetEntityCoords(ped) - GetEntityCoords(other)) > Config.InviteDistance + 0.75 then
            if generation == version then stop() end
            return false
        end
    end

    loadingDict = nil
    TaskPlayAnim(ped, choice.dict, clip, 4.0, -4.0, choice.duration, choice.flag, 0, false, false, false)
    local now = GetGameTimer()
    active = { id = id, ped = ped, dict = choice.dict, clip = clip, start = now, expires = now + choice.duration }
    watch()
    return true
end

local function openMenu()
    if menuOpen then closeMenu() return end
    if not possible() then return end
    local catalog = {}
    for id, item in pairs(Config.Catalog) do
        catalog[#catalog + 1] = { id = id, label = item.label, shared = item.shared == true }
    end
    table.sort(catalog, function(a, b) return a.id < b.id end)
    menuOpen = true
    SetNuiFocus(true, true)
    send('menu', { catalog = catalog, favorites = favorites, current = active and active.id, invite = pending })
    local version = menuVersion
    CreateThread(function()
        while menuOpen and menuVersion == version do
            if not possible() then closeMenu() break end
            Wait(250)
        end
    end)
end

local function closest()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local distance, id = Config.InviteDistance
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local other = GetPlayerPed(player)
            if DoesEntityExist(other) and not IsEntityDead(other) and not IsPedInAnyVehicle(other, false) then
                local range = #(GetEntityCoords(other) - pos)
                if range <= distance then distance, id = range, GetPlayerServerId(player) end
            end
        end
    end
    return id
end

RegisterNUICallback('play', function(data, cb)
    local id = type(data) == 'table' and data.id
    local choice = type(id) == 'string' and Config.Catalog[id]
    if not menuOpen or actionBusy or not choice or not possible() then cb({ ok = false }) return end
    actionBusy = true
    closeMenu()
    cb({ ok = true })
    CreateThread(function()
        local ok, reason, arg
        if choice.shared then
            local target = closest()
            if target then
                ok, reason, arg = Callback.Await('pop_emotes:invite', target, id)
                if ok then Bridge.Notify(L('invite_sent'), 'info') end
            else
                reason = 'no_target'
            end
        else
            ok = play(id)
        end
        if not ok then Bridge.Notify(L(reason or 'unavailable', arg), 'error') end
        actionBusy = false
    end)
end)

RegisterNUICallback('favorite', function(data, cb)
    local id = type(data) == 'table' and data.id
    if not menuOpen or type(id) ~= 'string' or not Config.Catalog[id] then cb({ ok = false }) return end
    favorites[id] = not favorites[id] or nil
    SetResourceKvp(savedKey, json.encode(favorites))
    cb({ ok = true, favorite = favorites[id] == true })
end)

RegisterNUICallback('stop', function(_, cb)
    if menuOpen then
        closeMenu()
        stop()
    end
    cb({ ok = true })
end)

local function clearInvite(ticket)
    if pending and pending.ticket == ticket then
        pending = nil
        send('inviteClosed', { ticket = ticket })
    end
end

RegisterNUICallback('respond', function(data, cb)
    if not menuOpen or actionBusy or not pending or type(data) ~= 'table' or type(data.accept) ~= 'boolean'
        or pending.ticket ~= data.ticket then cb({ ok = false }) return end
    local ticket = pending.ticket
    actionBusy = true
    clearInvite(ticket)
    if data.accept then closeMenu() end
    cb({ ok = true })
    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_emotes:respond', ticket, data.accept)
        if not ok then Bridge.Notify(L(reason or 'invite_missing', arg), 'error') end
        actionBusy = false
    end)
end)

RegisterNetEvent('pop_emotes:client:invite', function(ticket, name, id, timeout)
    if source ~= 65535 or not Config.Catalog[id] then return end
    pending = { ticket = ticket, name = name, label = Config.Catalog[id].label }
    send('invite', pending)
    Bridge.Notify(L('invite_prompt', name, Config.MenuKey), 'info', timeout * 1000)
    SetTimeout((timeout + 1) * 1000, function() clearInvite(ticket) end)
end)
RegisterNetEvent('pop_emotes:client:inviteClosed', function(ticket)
    if source == 65535 then clearInvite(ticket) end
end)
RegisterNetEvent('pop_emotes:client:play', function(id, target, responding)
    if source ~= 65535 then return end
    closeMenu()
    CreateThread(function()
        if not play(id, target, responding) then Bridge.Notify(L('unavailable'), 'error') end
    end)
end)

RegisterCommand('popemotes', openMenu, false)
RegisterKeyMapping('popemotes', L('menu_title'), 'keyboard', Config.MenuKey)
RegisterCommand('popemotes_cancel', stop, false)
RegisterKeyMapping('popemotes_cancel', L('cancel_emote'), 'keyboard', Config.CancelKey)
exports('GetCurrentEmoteName', function() return active and active.id end)
exports('Play', function(id)
    if type(id) ~= 'string' or not Config.Catalog[id] or Config.Catalog[id].shared or not possible() then return false end
    CreateThread(function() play(id) end)
    return true
end)
exports('Stop', stop)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeMenu()
    stop()
end)
