--User qui utilise le chéquier (perso ou entreprise) --> open chèque en NUI
-- item/def : transmis par sv_actions.lua (TriggerClientEvent(def.clientEvent, src, item, def)).
-- L'itemId est renvoyé au serveur à la validation pour que celui-ci résolve l'émetteur
-- (perso ou entreprise) à partir de l'item exact utilisé, jamais depuis une saisie cliente.
RegisterNetEvent("pop_inventory:openNUIcheck", function (item, def)
  local playerData = ESX.GetPlayerData()
  local meta = item and item.meta or {}
  local fullName = ''
  if playerData then
    fullName = (playerData.firstname or '') .. " " .. (playerData.lastname or '')
  end
  SetNuiFocus(true, true)
  SendNUIMessage({
    action = "open",
    dataUser = {
      fullName = fullName,
    },
    itemId = item and item.id,
    companyLabel = meta.companyLabel,
  })
end)

--Si user appuie sur le bouton close (close le NUI)
RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
    action = "close"
    })
    cb({})
end)

--Si user appuie sur le bouton valider (close le NUI et envoie au serveur)
-- Ni le numéro de compte ni l'entreprise émettrice ne sont saisis ici : le serveur les
-- résout à partir de l'item chéquier exact utilisé (itemId), seule donnée transmise
-- en plus du contenu libre du chèque (évite toute falsification côté client).
RegisterNUICallback("validateCheque", function(data, cb)
    local cheque = {
        beneficiaire = data.beneficiaire,
        montant = tonumber(data.montant),
        itemId = data.itemId,
    }
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "close"
    })
    TriggerServerEvent("pop_inventory:createCheque", cheque)
    cb({})
end)
