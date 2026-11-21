-- Exports client : IsOpen, Close, OpenApp.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

exports('IsOpen', function()
    return C.IsOpen()
end)

exports('Close', function()
    C.Close('export')
end)

-- Demande au serveur (mêmes contrôles que l'export serveur) ; le serveur renvoie `pop_tablet:client:open`.
exports('OpenApp', function(appId, data)
    Callback.Trigger('pop_tablet:app:open', function() end, appId, data)
end)
