-- Fabrication, exports d'inventaire, boutiques, sauvegarde auto (suite de sv_player_items.lua).

-- ===== CRAFT SYSTEM =====

function countItemInStore(store, defId)
  local count = 0
  for _, item in pairs(store.items) do
    if item.defId == defId and not item._isTemporary then
      count = count + (tonumber(item.qty) or 1)
    end
  end
  return count
end

function consumeItemInStore(store, defId, qty)
  local remaining = qty
  for _, item in pairs(store.items) do
    if remaining <= 0 then break end
    if item.defId == defId and not item._isTemporary then
      local itemQty = tonumber(item.qty) or 1
      local toRemove = math.min(remaining, itemQty)
      if toRemove >= itemQty then
        local loc = store.itemLocations[item.id]
        if loc and loc.type == 'container' then
          local c = store.containers[loc.containerId]
          if c then c.items[loc.slot] = nil end
        elseif loc and loc.type == 'equipment' then
          store.equipment[loc.slot] = nil
        end
        store.items[item.id] = nil
        store.itemLocations[item.id] = nil
      else
        item.qty = itemQty - toRemove
      end
      remaining = remaining - toRemove
    end
  end
end

RegisterNetEvent('pop_inventory:server:craft', function(recipeId)
  local src = source
  local identifier = getIdentifier(src)
  if not identifier then return end

  local recipe = nil
  for _, r in ipairs(Config.Recipes or {}) do
    if r.id == recipeId then recipe = r; break end
  end
  if not recipe then
    notify(src, L('recipe_unknown'))
    return
  end

  -- Anti-triche : il faut être à un établi proposant cette recette (comme côté client)
  if type(Config.CraftZones) == 'table' and #Config.CraftZones > 0 then
    local ped = GetPlayerPed(src)
    local pc = ped ~= 0 and GetEntityCoords(ped)
    if pc and #(pc) > 1.0 then
      local okZone = false
      for _, zone in ipairs(Config.CraftZones) do
        if #(pc - zone.coords) <= (zone.radius or 2.0) + 3.0 then
          if not zone.recipes or #zone.recipes == 0 then okZone = true; break end
          for _, id in ipairs(zone.recipes) do
            if id == recipeId then okZone = true; break end
          end
          if okZone then break end
        end
      end
      if not okZone then return end
    end
  end

  local store = ensureStore(identifier)

  -- Vérification des ingrédients : quantités additionnées par objet (un même objet
  -- listé sur plusieurs lignes était vérifié ligne par ligne, donc mal compté).
  local needed = {}
  for _, ing in ipairs(recipe.ingredients) do
    needed[ing.defId] = (needed[ing.defId] or 0) + ing.qty
  end
  for defId, qty in pairs(needed) do
    if countItemInStore(store, defId) < qty then
      local def = getItemDef(defId)
      notify(src, L('craft_missing', def and def.label or defId))
      return
    end
  end

  -- Consommation des ingrédients
  for _, ing in ipairs(recipe.ingredients) do
    consumeItemInStore(store, ing.defId, ing.qty)
  end

  -- Ajout du résultat
  local ok, err = autoInsertItem(store, recipe.output.defId, recipe.output.qty)
  if not ok then
    -- Remboursement en cas d'échec
    for _, ing in ipairs(recipe.ingredients) do
      autoInsertItem(store, ing.defId, ing.qty)
    end
    notify(src, err or L('craft_no_space'))
    return
  end

  markDirty(identifier)
  sendState(src)
  TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
  notify(src, L('craft_success'))
end)

exports('getInventory', function(source)
  local identifier = getIdentifier(source)
  if not identifier then return {} end

  local store = ensureStore(identifier)
  local inventory = {}
  local aggregated = {}

  for _, item in pairs(store.items) do
    if not item._isTemporary then
      local def = getItemDef(item.defId)
      if def then
        if not aggregated[item.defId] then
          aggregated[item.defId] = {
            name = item.defId,
            label = def.label or item.defId,
            count = 0,
            limit = -1,
            rare = false,
            canRemove = true
          }
        end
        aggregated[item.defId].count = aggregated[item.defId].count + (item.qty or 1)
      end
    end
  end

  for _, data in pairs(aggregated) do
    table.insert(inventory, data)
  end

  return inventory
end)

exports('getItemCount', function(source, itemName)
  local identifier = getIdentifier(source)
  if not identifier then return 0 end
  local store = ensureStore(identifier)
  local count = 0
  for _, item in pairs(store.items) do
    if item.defId == itemName and not item._isTemporary then
      count = count + (item.qty or 1)
    end
  end
  return count
end)

exports('UpdateItemMetadata', function(source, itemId, newMeta)
    local identifier = getIdentifier(source)
    if not identifier then return false end
    local store = ensureStore(identifier)

    local item = store.items[itemId]
    if item then
        item.meta = newMeta
        markDirty(identifier)
        sendState(source)
        return true
    end
    debugPrint('UpdateItemMetadata failing - item not found:', itemId)
    return false
end)

exports('GetItemMetadata', function(source, itemId)
    local identifier = getIdentifier(source)
    if not identifier then return {} end
    local store = ensureStore(identifier)

    local item = store.items[itemId]
    if item and item.meta then
        return item.meta
    end
    return {}
end)

-- Retire un item précis par son id (et pas "un item au hasard qui matche le defId"comme
-- removeItem/RemoveItem) : nécessaire pour des items non-stackables mais multi-instances
-- avec metadata distincte (ex: chèques de montants différents) où on doit retirer
-- exactement l'instance déposée/utilisée, pas une autre instance du même defId.
exports('removeItemById', function(source, itemId)
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local store = ensureStore(identifier)
    local item = store.items[itemId]
    if not item then return false end

    local loc = store.itemLocations[itemId]
    if loc and loc.type == 'container' then
        local parentContainer = store.containers[loc.containerId]
        if parentContainer then
            parentContainer.items[loc.slot] = nil
        end
    elseif loc and loc.type == 'equipment' then
        store.equipment[loc.slot] = nil
    end

    store.items[itemId] = nil
    store.itemLocations[itemId] = nil

    markDirty(identifier)
    sendState(source)
    return true
end)

exports('RemoveItem', function(source, itemName, qty)
    local identifier = getIdentifier(source)
    if not identifier then return false end
    local store = ensureStore(identifier)

    local removed = 0
    -- On parcourt les items pour trouver ceux à supprimer
    for itemId, item in pairs(store.items) do
        if item.defId == itemName and not item._isTemporary then
            local qtyInSlot = item.qty or 1
            local toRemove = math.min(qty - removed, qtyInSlot)

            item.qty = qtyInSlot - toRemove
            removed = removed + toRemove

            if item.qty <= 0 then
                -- Si l'item a un container (sac à dos, etc), on le supprime aussi
                if item.containerId then
                    store.containers[item.containerId] = nil
                end
                store.items[itemId] = nil
                removeItemLocation(store, itemId)
            end

            if removed >= qty then break end
        end
    end

    if removed > 0 then
        rebuildLocations(store)
        markDirty(identifier)
        sendState(source)
        return true
    end
    return false
end)

exports('getStore', function(source)
  local identifier = getIdentifier(source)
  if not identifier then return nil end
  return ensureStore(identifier)
end)

exports('GiveCardboardBoxWithItems', function(target, itemsList, doNotEquip)
  local identifier = getIdentifier(target)
  if not identifier then return false, L('player_not_found') end

  local store = ensureStore(identifier)
  local boxItemId, err = createItem(store, 'cardboard_box', 1, {})
  if not boxItemId then
    return false, err or L('box_create_error')
  end

  local containerId = store.items[boxItemId].containerId
  if containerId then
    local container = store.containers[containerId]
    for slot, itemData in ipairs(itemsList) do
      if slot <= container.slots then
        local subItemId, subErr = createItem(store, itemData.defId or itemData.itemDefId, itemData.qty or 1, itemData.meta or {}) -- luacheck: ignore 211
        if subItemId then
          container.items[slot] = subItemId
          setItemLocation(store, subItemId, { type = 'container', containerId = containerId, slot = slot })
        end
      end
    end
  end

  local placed = false
  if doNotEquip then
    local def = getItemDef('cardboard_box')
    local ordered = getOrderedContainers(store)
    for _, containerId in ipairs(ordered) do -- luacheck: ignore 421
      local container = store.containers[containerId]
      if isAllowedInContainer(container.defId, 'cardboard_box', def) then
        local slot = findEmptySlot(container)
        if slot then
          local weight = getItemWeight(store, boxItemId)
          if canAddWeight(store, containerId, weight) then
            placeItemInContainer(store, containerId, slot, boxItemId)
            placed = true
            break
          end
        end
      end
    end
  end

  if not placed then
    local success, equipErr = equipItem(store, boxItemId) -- luacheck: ignore 211
    if not success then
      -- Force unequip if there's no space for currently equipped briefcase
      local oldItemId = store.equipment['briefcase']
      if oldItemId then
        store.equipment['briefcase'] = nil
        removeItemLocation(store, oldItemId)

        -- Place it on the ground
        local coords = getPlayerCoords(target)
        local pile = getOrCreateGroundPile(target, coords)
        if pile then
          local groundContainer = GroundStore.containers[pile.containerId]
          local gSlot = findEmptySlot(groundContainer)
          if gSlot then
            moveItemTree(store, GroundStore, oldItemId)
            placeItemInContainer(GroundStore, pile.containerId, gSlot, oldItemId)
            markGroundDirty()
          end
        end
      end

      -- Equip the new box forcibly
      store.equipment['briefcase'] = boxItemId
      setItemLocation(store, boxItemId, { type = 'equipment', slot = 'briefcase' })
      ensureActiveContainer(store)
    end
  end

  markDirty(identifier)
  sendState(target)

  if not placed then
    TriggerClientEvent('pop_inventory:client:applyEquipment', target, buildEquipmentDefs(store))
    TriggerClientEvent('pop_inventory:client:equipCardboardBox', target)
  end

  return true
end)

exports('openContainer', function(source, containerId)
  local identifier = getIdentifier(source)
  if not identifier then return end
  local store = ensureStore(identifier)
  if store.containers[containerId] then
    store.activeContainerId = containerId
    store.activeContainerIsGround = false
    sendState(source)
  end
end)

if Config.DebugOptions.Commands then
    RegisterCommand('testshop', function(source)
        local src = source
        local items = {
            { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.webp" },
            { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.webp" },
            { id = "soda", price = 40, label = "Soda", icon = "img/soda.webp" },
            { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.webp" },
        }
        TriggerClientEvent('pop_inventory:client:openShop', src, 'LTD', items)
    end, true)
end


RegisterNetEvent('pop_inventory:server:shopBuy', function(data)
    local src = source
    local xPlayer = nil
    if ESX then xPlayer = ESX.GetPlayerFromId(src) end
    if QBCore then xPlayer = QBCore.Functions.GetPlayer(src) end

    if not xPlayer then
        print("^1[Shop-Error]^7 Joueur non trouvé pour source:", src)
        return
    end

    if type(data) ~= 'table' then return end
    local shopId = data.shopId
    local itemId = data.itemId
    -- SÉCURITÉ : quantité entière et positive (une quantité négative rendait le prix
    -- négatif -> removeAccountMoney d'un montant négatif = argent crédité).
    local qty = math.floor(tonumber(data.qty) or 1)
    if qty < 1 or qty > 1000 then return end
    local method = data.paymentMethod or 'cash'


    local shop = Config.Shops[shopId]
    if not shop then
        print("^1[Shop-Error]^7 Boutique inconnue:", tostring(shopId))
        return
    end

    local itemData = nil
    for _, item in ipairs(shop) do
        if item.id == itemId then
            itemData = item
            break
        end
    end

    if not itemData then
        print("^1[Shop-Error]^7 Item non trouvé dans la boutique:", tostring(itemId))
        return
    end

    -- Le joueur doit être dans une zone de cette boutique (Config.ShopZones)
    local ped = GetPlayerPed(src)
    local pos = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    local nearShop = false
    if pos then
        for _, zone in ipairs(Config.ShopZones or {}) do
            if zone.shopId == shopId and #(pos - zone.coords) <= (zone.radius or 3.5) + 3.0 then
                nearShop = true
                break
            end
        end
    end
    if not nearShop then return end

    local totalPrice = itemData.price * qty
    local tvaRate = GlobalState.tva or 20
    local taxAmount = math.floor(totalPrice * (tvaRate / 100))
    local finalPrice = totalPrice + taxAmount
    local success = false

    if method == 'cash' then
        -- Cash is stored as an inventory item on this server (incl. inside the wallet container),
        -- not in the ESX cash account. Check & consume the inventory cash item directly.
        local identifier = getIdentifier(src)
        local store = identifier and Stores[identifier]
        if store and countItemInStore(store, 'cash') >= finalPrice then
            consumeItemInStore(store, 'cash', finalPrice)
            markDirty(identifier)
            success = true
        end
    elseif method == 'bank' then
        if ESX then
            if xPlayer.getAccount('bank').money >= finalPrice then
                xPlayer.removeAccountMoney('bank', finalPrice)
                success = true
            end
        elseif QBCore then
            if xPlayer.Functions.GetMoney('bank') >= finalPrice then
                xPlayer.Functions.RemoveMoney('bank', finalPrice)
                success = true
            end
        end
    end

    if success then
        -- Inventaire plein : on rembourse au lieu de garder l'argent
        local given = GiveItem(src, itemId, qty)
        if not given then
            if method == 'cash' then
                GiveItem(src, 'cash', finalPrice)
            elseif method == 'bank' then
                if ESX then xPlayer.addAccountMoney('bank', finalPrice)
                elseif QBCore then xPlayer.Functions.AddMoney('bank', finalPrice) end
            end
            notify(src, L('shop_inventory_full_refund'))
            return
        end
        if Config.Debug then print("^2[Shop-Success]^7 Achat validé pour " .. xPlayer.getName() .. " (Incluant " .. taxAmount .. "$ TVA)") end
        notify(src, L('shop_success', itemQtyTag(qty), itemData.label or itemId, taxAmount))

        -- Credit TVA to society_gouv for cash and bank methods
        if (method == 'cash' or method == 'bank') and taxAmount > 0 then
            local accountUsName = Config.GouvUSAccount or 'society_gouv'
            TriggerEvent('esx_addonaccount:getSharedAccount', accountUsName, function(gouvAccount)
                if gouvAccount then
                    gouvAccount.addMoney(taxAmount)
                else
                    exports.oxmysql:execute('UPDATE addon_account_data SET money = money + ? WHERE account_name = ?', {taxAmount, accountUsName})
                end
            end)
        end
    else
        if Config.Debug then print("^1[Shop-Wait]^7 Fonds insuffisants pour " .. xPlayer.getName() .. " (" .. finalPrice .. "$ avec TVA)") end
        notify(src, L('shop_no_money', finalPrice))
    end
end)

-- Thread d'optimisation : Sauvegarde asynchrone échelonnée (Staggered Ultra)
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(Config.InventorySettings.AutoSaveIntervalMs or 60000)

    -- Delay between ground saves and player saves to avoid concurrent heavy disk IO
    saveRemoteContainers()
    Citizen.Wait(10000) -- Délai accru pour étaler la charge

    -- Les inventaires joueurs modifiés sont sauvegardés par un seul thread (sv_stores.lua).
    saveGround() -- S'assure que le sol est aussi sauvegardé régulièrement
  end
end)

-- Kit de depart : hotdog + bouteille d'eau dans les poches au premier spawn
AddEventHandler('esx:playerLoaded', function(playerId, _, isNew)
    if not isNew then return end
    GiveItem(playerId, 'hotdog', 1)
    GiveItem(playerId, 'bouteille', 1)
end)
