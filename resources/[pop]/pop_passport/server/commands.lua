-- pop_passport : commande admin givepassport (ESX direct : ESX.RegisterCommand, groupe admin).

Passport.ESX.RegisterCommand('givepassport', 'admin', function(xPlayer, args, showError)
    -- Depuis la console, xPlayer est nil : l'ID du joueur est alors obligatoire
    local target = args.id or (xPlayer and xPlayer.source)
    if not target or not GetPlayerName(target) then
        return print(L('cmd_usage'))
    end
    local pType = (args.type == 'mx') and 'mx' or 'us'
    Passport.Issue(target, pType)
end, true, {
    help = L('cmd_help'),
    arguments = {
        { name = 'id',   help = L('cmd_arg_id'),   type = 'number' },
        { name = 'type', help = L('cmd_arg_type'), type = 'string' }
    }
})
