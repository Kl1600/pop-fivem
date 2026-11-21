-- /previewlivraison : commande de dev, réservée aux admins (ACE pop.admin, cf. pop.cfg)
RegisterCommand('previewlivraison', function(source)
    if source <= 0 then return end
    if not IsPlayerAceAllowed(source, 'pop.admin') then return end
    TriggerClientEvent('pop_livraison:togglePreview', source)
end, false)
