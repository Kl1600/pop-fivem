-- Objets de la mission : vérification (flipper / pcb) et utilisation du module pirate.

local CheckableItems = { flipper = true, pcb = true }

Callback.Register('hasItem', function(source, item)
    if not CheckableItems[item] then return false end
    return Bridge.HasItem(source, item, 1)
end)

-- Utiliser le module pirate depuis l'inventaire = même action que /voler_auto
Bridge.RegisterUsableItem('pcb', function(source)
    TriggerClientEvent('grandtheftauto:usePCB', source)
end)
