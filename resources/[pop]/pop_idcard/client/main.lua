RegisterCommand(Config.Command, function(_, args)
    local variant = args[1] and args[1]:lower() or 'us'
    local target = args[2] and math.tointeger(tonumber(args[2]))
    if args[2] and not target then return Bridge.Notify(L('invalid_viewer'), 'error') end
    CreateThread(function()
        local ok, reason = Callback.Await('pop_idcard:show', variant, target)
        if not ok then Bridge.Notify(L(reason or 'error'), 'error') end
    end)
end, false)

RegisterNetEvent('pop_idcard:client:show', function(document)
    if source ~= 65535 or type(document) ~= 'table' then return end
    SendNUIMessage({ action = 'pop_idcard:card', document = document, duration = Config.DisplayMs })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'pop_idcard:hide' })
end)
