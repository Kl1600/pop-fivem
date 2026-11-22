-- Inventaire : ouverture / fermeture, touches d'armes, torse, achat en boutique.

Inv.isOpen = false
Inv.currentEquipment = {}
Inv.currentState = nil
Inv.customTorso = nil

function Inv.openUi()
  if Inv.isOpen then
    return
  end
  Inv.isOpen = true
  SetNuiFocus(true, true)
  DisplayHud(false)
  DisplayRadar(false)
  TriggerEvent('hud:toggleui', false)
  if GetResourceState('ox_target') == 'started' then
    pcall(function() exports.ox_target:setMechanicChecklistHidden(true) end)
  end
  local attachmentItems = {}
  local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
  end
  if Config.WeaponAttachments then
    for _, mapping in pairs(Config.WeaponAttachments) do
      for _, slotDef in pairs(mapping) do
        local def = Config.Items and Config.Items[slotDef.item]
        if def and not attachmentItems[slotDef.item] then
          attachmentItems[slotDef.item] = {
            label = def.label,
            icon = def.icon,
            gradientColor = def.gradientColor,
            isMagazine = hasTag(def, 'magazine'),
          }
        end
      end
    end
  end
  -- Inclure TOUS les chargeurs (tag 'magazine'), meme ceux non listes dans la config
  -- d'une arme, pour pouvoir les proposer dans n'importe quel slot chargeur.
  if Config.Items then
    for defId, def in pairs(Config.Items) do
      if type(defId) == 'string' and hasTag(def, 'magazine') and not attachmentItems[defId] then
        attachmentItems[defId] = {
          label = def.label,
          icon = def.icon,
          gradientColor = def.gradientColor,
          isMagazine = true,
        }
      end
    end
  end
  SendNUIMessage({
    action = 'open',
    enablePager = Config.EnablePagerSlot,
    weaponAttachments = Config.WeaponAttachments or {},
    attachmentItems = attachmentItems,
  })
  TriggerScreenblurFadeIn(500)
  local coords = GetEntityCoords(PlayerPedId())
  TriggerServerEvent('pop_inventory:server:requestState', { x = coords.x, y = coords.y, z = coords.z })
  TriggerServerEvent('pop_inventory:server:adminCheck')
end

function Inv.closeUi()
  if not Inv.isOpen then
    return
  end
  Inv.isOpen = false
  SendNUIMessage({ action = 'close' })

  CreateThread(function()
    TriggerScreenblurFadeOut(0)
    ClearTimecycleModifier()

    Wait(150)
    SetNuiFocus(false, false)
    DisplayHud(true)
    DisplayRadar(true)
    TriggerEvent('hud:toggleui', true)
    if GetResourceState('ox_target') == 'started' then
      pcall(function() exports.ox_target:setMechanicChecklistHidden(false) end)
    end
    SetFrontendActive(false)
    ClearTimecycleModifier()

    -- Double vérification rapide (toutes les 25ms pendant 500ms) pour tuer le flou instantanément
    for _=1, 20 do
      Wait(25)
      if not Inv.isOpen then
        TriggerScreenblurFadeOut(0)
        ClearTimecycleModifier()
      end
    end
  end)
end

-- Fermeture forcee depuis une autre logique du resource (ex: pistolet a peinture).
AddEventHandler('pop_inventory:client:forceClose', function()
  Inv.closeUi()
end)

-- Ouverture depuis une autre logique du resource (ex: pistolet a peinture).
AddEventHandler('pop_inventory:client:openInventory', function()
  if not Inv.isOpen and not IsNuiFocused() then
    Inv.openUi()
  end
end)

-- Etat de l'inventaire, utilise par les autres modules (radio, peinture...)
-- pour ne jamais superposer deux UI.
exports('IsInventoryOpen', function()
  return Inv.isOpen == true
end)

function Inv.toggleInventory()
  if Inv.isOpen then
    Inv.closeUi()
  else
    -- Ne pas ouvrir l'inventaire si une AUTRE interface (NUI) a déjà le focus
    -- (menu admin, coffre, etc.) : la touche reste à l'interface active.
    if IsNuiFocused() then return end
    Inv.openUi()
  end
end

-- Commande simple (utilisée aussi par d'autres scripts) + touche I.
RegisterCommand('pop_inventory', function()
  -- Ancien raccourci TAB resté sur certains PC : géré par +pop_inventory_key
  if IsControlPressed(0, 37) or IsDisabledControlPressed(0, 37) then return end
  Inv.toggleInventory()
end, false)
RegisterCommand('pop_inventory_alt', Inv.toggleInventory, false)
RegisterKeyMapping('pop_inventory_alt', L('key_inventory_alt'), 'keyboard', 'I')

-- Switch weapons keys (touches 1 à 4 pour les petites cases)
function Inv.switchToWeaponSlot(slot)
  -- Bloqué si l'inventaire OU une autre interface (NUI) est ouverte.
  if Inv.isOpen or IsNuiFocused() then return end
  local ped = PlayerPedId()

  -- Règle : Si une arme lourde est dans le slot, elle doit TOUT LE TEMPS être dans les mains
  if Inv.currentEquipment['weapon_long'] then
    local heavyItem = Inv.currentEquipment['weapon_long']
    local heavyDefId = (type(heavyItem) == 'table' and heavyItem.defId) or heavyItem
    local heavyDef = Config.Items and Config.Items[heavyDefId]
    if heavyDef and heavyDef.weaponHash then
      local heavyHash = GetHashKey(heavyDef.weaponHash)
      if HasPedGotWeapon(ped, heavyHash, false) then
        -- Force l'arme lourde dans les mains
        SetCurrentPedWeapon(ped, heavyHash, true)

        -- Empêche le switch vers une autre arme
        Bridge.Notify({
          title = L('action_impossible'),
          message = L('heavy_weapon_first'),
          icon = 'fas fa-hand-paper',
          duration = 3000
        })
        return
      end
    end
  end

  local item = Inv.currentEquipment[slot]
  if not item then return end

  local defId = (type(item) == 'table' and item.defId) or item
  local itemDef = Config.Items and Config.Items[defId]
  if itemDef and itemDef.weaponHash then
    local hash = GetHashKey(itemDef.weaponHash)

    if HasPedGotWeapon(ped, hash, false) then
      if GetSelectedPedWeapon(ped) == hash then
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
      else
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        CreateThread(function()
          Wait(50)
          SetCurrentPedWeapon(ped, hash, true)
        end)
      end
    end
  end
end

RegisterCommand('pop_inventory_slot1', function() Inv.switchToWeaponSlot('weapon_pistol') end, false)
RegisterKeyMapping('pop_inventory_slot1', L('key_slot1'), 'keyboard', '1')

RegisterCommand('pop_inventory_slot2', function() Inv.switchToWeaponSlot('weapon_tazer')  end, false)
RegisterKeyMapping('pop_inventory_slot2', L('key_slot2'), 'keyboard', '2')

RegisterCommand('pop_inventory_slot3', function() Inv.switchToWeaponSlot('weapon_misc')   end, false)
RegisterKeyMapping('pop_inventory_slot3', L('key_slot3'), 'keyboard', '3')

RegisterCommand('pop_inventory_slot4', function() Inv.switchToWeaponSlot('weapon_tool')   end, false)
RegisterKeyMapping('pop_inventory_slot4', L('key_slot4'), 'keyboard', '4')


RegisterNUICallback('close', function(_, cb)
  local wasOpen = Inv.isOpen
  Inv.closeUi()
  -- bridge/client.lua rend aussi le focus sur 'close' (Échap, TAB, I) : si une autre
  -- interface du script garde le focus (roue, radio), on le lui laisse comme avant.
  if not wasOpen and (Inv.wheelOpen or (Inv.isRadioOpen and Inv.isRadioOpen())) then
    SetNuiFocus(true, true)
  end
  cb('ok')
end)

RegisterNUICallback('changeTorse', function(_, cb)
  TriggerEvent('pop_inventory:client:changeTorse')
  cb('ok')
end)

RegisterNUICallback('selectTorso', function(data, cb)
  local index = data.index
  if index then
    TriggerEvent('pop_inventory:client:selectTorso', index)
  end
  cb('ok')
end)

RegisterNetEvent('pop_inventory:client:selectTorso')
AddEventHandler('pop_inventory:client:selectTorso', function(index)
  local ped = PlayerPedId()

  -- /!\ Attention: les drawable IDs exacts dépendent de votre serveur.
  -- Par défaut pour un ped multiplayer, le torse nu standard est souvent 15.
  -- Ajustez ce tableau (`drawableId`) pour qu'il corresponde à vos 15 fichiers images male_1 à male_15.
  local torsoMapping = {
    [1]  = 15, -- male_1.webp
    [2]  = 0,  -- male_2.webp
    [3]  = 1,
    [4]  = 2,
    [5]  = 3,
    [6]  = 4,
    [7]  = 5,
    [8]  = 6,
    [9]  = 7,
    [10] = 8,
    [11] = 9,
    [12] = 10,
    [13] = 11,
    [14] = 12,
    [15] = 13,
  }

  local drawableId = torsoMapping[index]
  if drawableId ~= nil then
    Inv.customTorso = drawableId -- Sauvegarde locale pour applyNude
    -- Modifie les bras/torse (componentId = 3) du ped instantanément
    SetPedComponentVariation(ped, 3, drawableId, 0, 0)

    -- Sauvegarde de la variation via skinchanger si présent (ESX)
    if GetResourceState('skinchanger') == 'started' then
      TriggerEvent('skinchanger:getSkin', function(skin)
        skin['arms'] = drawableId
        -- On sauvegarde en base de données sans déclencher un reload complet du ped (loadSkin)
        -- car loadSkin écraserait les vêtements appliqués par l'inventaire.
        TriggerServerEvent('esx_skin:save', skin)

        -- On ne ré-applique pas applyClothing ici, car l'équipement forcerait les bras (component 3)
        -- définis dans la métadonnée des vêtements, ce qui annulerait le choix du joueur.
      end)
    end
  end
end)

RegisterNUICallback('shopBuy', function(data, cb)
  TriggerServerEvent('pop_inventory:server:shopBuy', data)
  cb('ok')
end)
