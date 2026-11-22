-- /previewlivraison : commande de dev, réservée aux admins (Bridge.IsAdmin : ACE pop.admin, cf. pop.cfg)
RegisterCommand(Config.Command, function(source)
    if source <= 0 then return end
    if not Bridge.IsAdmin(source) then return end
    if Config.Debug then print(('[pop_livraison] preview demandée par %s'):format(source)) end
    TriggerClientEvent('pop_livraison:togglePreview', source)
end, false)
