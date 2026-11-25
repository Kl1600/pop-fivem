-- pop_passport : commande admin /givepassport [id] [us/mx] (ACE pop.admin ou groupe admin
-- du framework, via le bridge), utilisable depuis la console.

RegisterCommand(Config.GiveCommand, function(src, args)
    if src ~= 0 and not Bridge.IsAdmin(src) then
        return Bridge.Notify(src, { icon = 'fas fa-passport', message = L('no_permission') })
    end
    local target = tonumber(args[1]) or (src ~= 0 and src or nil)
    if not target or not GetPlayerName(target) then
        if src == 0 then return print(L('cmd_usage', Config.GiveCommand)) end
        return Bridge.Notify(src, { icon = 'fas fa-passport', message = L('cmd_usage', Config.GiveCommand) })
    end
    Passport.Issue(target, args[2] == 'mx' and 'mx' or 'us')
end, false)
