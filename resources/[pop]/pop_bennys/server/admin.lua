-- pop_bennys — serveur : /bennys, ouverture à distance réservée aux admins (Bridge.IsAdmin)

RegisterCommand(Config.Command, function(src)
    if src == 0 or not Bridge.IsAdmin(src) then return end
    TriggerClientEvent('pop_bennys:adminOpen', src)
end, false)
