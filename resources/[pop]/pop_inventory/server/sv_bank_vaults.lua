-- =====================================================
--  Coffres bancaires (pop_bank) : réutilise le mécanisme des coffres statiques
--  (Stores['static_'..chestId], cf. server/sv_remote_containers.lua) pour stocker
--  des billets ('cash') par identifiant (compte perso) ou par job (compte entreprise).
--  pop_bank reste seul responsable des vérifications d'accès (boss, solde...) ;
--  ces exports ne font QUE manipuler le contenu d'un coffre déjà désigné par son id,
--  indépendamment de toute session joueur active (fonctionne même hors-ligne).
-- =====================================================

local function getOrLoadChestStore(chestId)
  local sId = 'static_' .. chestId
  if not Stores[sId] then
    Stores[sId] = loadStore(sId)
  end
  return Stores[sId], sId
end

local function getOrCreateChestContainer(sStore)
  for cId, c in pairs(sStore.containers) do
    if c.defId == 'static_chest' then
      return cId, c
    end
  end
  local containerId = generateId('static_vault')
  sStore.containers[containerId] = {
    id = containerId,
    defId = 'static_chest',
    slots = 50,
    maxWeight = 1000.0,
    items = {},
  }
  return containerId, sStore.containers[containerId]
end

exports('AddItemToStaticChest', function(chestId, defId, qty, meta)
  if not chestId or not defId or not qty or qty <= 0 then
    return false, 'parametres invalides'
  end

  local def = getItemDef(defId)
  if not def then
    return false, 'item inconnu'
  end

  local sStore, sId = getOrLoadChestStore(chestId)
  if not sStore then
    return false, 'coffre introuvable'
  end

  local containerId, container = getOrCreateChestContainer(sStore)
  local maxStack = def.maxStack or 1
  local hasMeta = meta and next(meta) ~= nil
  local remaining = qty

  -- 1) Complète les piles existantes du même defId (jamais si l'item porte une meta
  --    distincte, ex: un objet unique - 'cash' n'en a pas).
  if not hasMeta then
    for _, itemId in pairs(container.items) do
      if remaining <= 0 then break end
      local item = sStore.items[itemId]
      if item and item.defId == defId then
        local room = maxStack - (tonumber(item.qty) or 0)
        if room > 0 then
          local add = math.min(room, remaining)
          item.qty = item.qty + add
          remaining = remaining - add
        end
      end
    end
  end

  -- 2) Crée de nouvelles piles pour le reste.
  while remaining > 0 do
    local slot = findEmptySlot(container)
    if not slot then
      markDirty(sId)
      saveStore(sId, sStore)
      return false, 'coffre plein'
    end
    local stackQty = math.min(maxStack, remaining)
    local itemId = createItem(sStore, defId, stackQty, meta)
    if not itemId then
      markDirty(sId)
      saveStore(sId, sStore)
      return false, 'erreur creation item'
    end
    placeItemInContainer(sStore, containerId, slot, itemId)
    remaining = remaining - stackQty
  end

  markDirty(sId)
  saveStore(sId, sStore)
  return true
end)

exports('GetStaticChestItemCount', function(chestId, defId)
  local sStore = getOrLoadChestStore(chestId)
  if not sStore then
    return 0
  end
  return countItemInStore(sStore, defId)
end)

exports('RemoveItemFromStaticChest', function(chestId, defId, qty)
  local sStore, sId = getOrLoadChestStore(chestId)
  if not sStore then
    return false, 'coffre introuvable'
  end

  if countItemInStore(sStore, defId) < (qty or 0) then
    return false, 'quantite insuffisante'
  end

  consumeItemInStore(sStore, defId, qty)
  markDirty(sId)
  saveStore(sId, sStore)
  return true
end)
