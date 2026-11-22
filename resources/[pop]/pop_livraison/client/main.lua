-- Commande de dev /previewlivraison : réservée aux admins (vérifiée côté serveur, voir server/main.lua)
RegisterNetEvent('pop_livraison:togglePreview', function()
    if Livraison.IsSpawned() then
        Livraison.DeletePreview()
    else
        Livraison.SpawnPreview()
    end
end)

-- Clean up on resource restart/stop
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Livraison.DeletePreview()
    end
end)
