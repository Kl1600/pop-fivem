local active, running = {}, false

local function send(markers, messages)
    SendNUIMessage({ action = 'pop_chat:frame', markers = markers, messages = messages })
end

local function draw()
    if running then return end
    running = true
    CreateThread(function()
        while #active > 0 do
            local now, markers, messages = GetGameTimer(), {}, {}
            local ownPed = PlayerPedId()
            local center = GetEntityCoords(ownPed)
            local paused = not Bridge.IsLoaded() or IsPauseMenuActive() or LocalPlayer.state.charcreatorOpen
            for i = #active, 1, -1 do
                local entry = active[i]
                if now >= entry.expires then
                    table.remove(active, i)
                elseif not paused then
                    local player = GetPlayerFromServerId(entry.id)
                    local ped = player ~= -1 and GetPlayerPed(player)
                    if ped and DoesEntityExist(ped) and NetworkGetNetworkIdFromEntity(ped) == entry.netId then
                        local pos = GetEntityCoords(ped)
                        if #(pos - center) <= Config.Distance + 1.0 then
                            messages[#messages + 1] = { id = entry.id, text = entry.text }
                            if ped == ownPed or HasEntityClearLosToEntity(ownPed, ped, 17) then
                                local visible, x, y = World3dToScreen2d(pos.x, pos.y, pos.z + 1.15)
                                if visible then markers[#markers + 1] = { id = entry.id, text = entry.text, x = x, y = y } end
                            end
                        end
                    end
                end
            end
            send(markers, messages)
            Wait(#markers > 0 and 33 or 200)
        end
        running = false
    end)
end

RegisterNetEvent('pop_chat:client:action', function(sender, netId, text, duration)
    if source ~= 65535 or math.type(sender) ~= 'integer' or math.type(netId) ~= 'integer' or type(text) ~= 'string'
        or math.type(duration) ~= 'integer' or duration <= 0 then return end
    for i = #active, 1, -1 do
        if active[i].id == sender then table.remove(active, i) end
    end
    if #active >= Config.MaxVisible then table.remove(active, 1) end
    active[#active + 1] = { id = sender, netId = netId, text = text, expires = GetGameTimer() + duration }
    draw()
end)

local function suggestion()
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, L('action_help'), { { name = L('action_arg') } })
end
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'chat' then suggestion() end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TriggerEvent('chat:removeSuggestion', '/' .. Config.Command) end
end)
