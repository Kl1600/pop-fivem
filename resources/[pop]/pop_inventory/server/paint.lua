-- =====================================================================
--  PISTOLET A PEINTURE  -  Serveur
--  Gere la selection de couleur (consommation des pots), le reservoir
--  stocke dans la meta de l'arme, et le drain pendant le spray.
--  Utilise les exports de pop_inventory.
-- =====================================================================

local INV = exports.pop_inventory

-- Compte TOUTE la peinture du store (dans les pots, en vrac, etc.), par couleur.
local function countPaint(store)
  local counts = { peinture_rouge = 0, peinture_jaune = 0, peinture_bleue = 0 }
  if not store or not store.items then return counts end
  for _, it in pairs(store.items) do
    if counts[it.defId] ~= nil then
      counts[it.defId] = counts[it.defId] + (it.qty or 1)
    end
  end
  return counts
end

-- Consomme `amount` de peinture `defId` n'importe où dans le store.
local function consumePaint(store, defId, amount)
  if not store or not store.items or amount <= 0 then return end
  local remaining = amount
  for itemId, it in pairs(store.items) do
    if it.defId == defId then
      local take = math.min(remaining, it.qty or 1)
      it.qty = (it.qty or 1) - take
      remaining = remaining - take
      if it.qty <= 0 then
        local loc = store.itemLocations and store.itemLocations[itemId]
        if loc and loc.type == 'container' and store.containers[loc.containerId] then
          store.containers[loc.containerId].items[loc.slot] = nil
        end
        store.items[itemId] = nil
        if store.itemLocations then store.itemLocations[itemId] = nil end
      end
      if remaining <= 0 then break end
    end
  end
end

local function notify(src, msg, kind)
  local badgeColor = "#3498db"
  local badge = L('badge_info')
  local icon = "fas fa-paint-roller"

  if kind == 'success' then
    badgeColor = "#2ecc71"
    badge = L('badge_success')
    icon = "fas fa-check-circle"
  elseif kind == 'error' then
    badgeColor = "#e74c3c"
    badge = L('badge_error')
    icon = "fas fa-exclamation-triangle"
  end

  Bridge.Notify(src, {
    title = L('paint_title'),
    message = msg,
    icon = icon,
    badge = badge,
    badgeColor = badgeColor,
    duration = 5000
  })
end

-- Retrouve l'id de l'instance du pistolet equipe (slot arme longue).
local function getEquippedGunId(src)
  if not src or src == 0 or src == '' then return nil end
  local identifier = getIdentifier(src)
  if not identifier then
    return nil
  end
  local store = ensureStore(identifier)
  if not store then
    return nil
  end
  local itemId = store.equipment and store.equipment['weapon_long']
  if not itemId then
    return nil
  end
  local item = store.items and store.items[itemId]
  if item and item.defId == PaintGun.GunItem then
    return itemId, item
  end
  return nil
end

-- Envoie au client l'etat courant du pistolet equipe (couleur + reservoir).
local function pushState(src)
  if not src or src == 0 or src == '' then return end
  local itemId, item = getEquippedGunId(src)
  if not itemId then
    TriggerClientEvent('pop_paint:client:syncState', src, nil)
    return
  end
  local meta = item.meta or {}
  TriggerClientEvent('pop_paint:client:syncState', src, {
    itemId    = itemId,
    color     = meta.paintIndex,
    r         = meta.paintR or 255,
    g         = meta.paintG or 255,
    b         = meta.paintB or 255,
    reservoir = meta.reservoir or 0.0,
  })
end

-- Le client demande l'etat (ex: au moment d'equiper l'arme).
RegisterNetEvent('pop_paint:server:requestState', function()
  pushState(source)
end)

-- Selection d'une couleur dans le menu : consomme les pots et remplit
-- le reservoir si le joueur a assez de pigment.
RegisterNetEvent('pop_paint:server:selectColor', function(itemId, paintIndex)
  local src = source
  if not src or src == 0 or src == '' then return end
  if not itemId then
    return
  end
  paintIndex = tonumber(paintIndex)

  local color
  for _, c in ipairs(PaintGun.Colors) do
    if c.index == paintIndex then color = c break end
  end
  if not color then
    return
  end

  -- Verifie que l'item vise est bien un pistolet possede.
  local meta = INV.GetItemMetadata(src, itemId)
  if not meta then
    notify(src, L('paint_gun_not_found'), 'error')
    return
  end

  local cost = PaintGun.GetPotCost(color.r, color.g, color.b)

  -- Stocks (toute la peinture du joueur).
  local store = ensureStore(getIdentifier(src))
  local pot = countPaint(store)
  local have = {
    rouge = pot.peinture_rouge,
    jaune = pot.peinture_jaune,
    bleu  = pot.peinture_bleue,
  }
  local missing = {}
  if have.rouge < cost.rouge then missing[#missing+1] = L('paint_missing_red', have.rouge, cost.rouge) end
  if have.jaune < cost.jaune then missing[#missing+1] = L('paint_missing_yellow', have.jaune, cost.jaune) end
  if have.bleu  < cost.bleu  then missing[#missing+1] = L('paint_missing_blue', have.bleu,  cost.bleu)  end

  if #missing > 0 then
    notify(src, L('paint_not_enough', table.concat(missing, ', ')), 'error')
    return
  end

  -- Consomme la peinture.
  consumePaint(store, 'peinture_rouge', cost.rouge)
  consumePaint(store, 'peinture_jaune', cost.jaune)
  consumePaint(store, 'peinture_bleue', cost.bleu)

  -- Remplit le reservoir (assez pour une voiture entiere) + stocke la couleur.
  meta.paintIndex = color.index
  meta.paintR = color.r
  meta.paintG = color.g
  meta.paintB = color.b
  meta.reservoir = PaintGun.ReservoirMax
  meta.description = L('paint_desc_full', color.name)
  local updated = INV.UpdateItemMetadata(src, itemId, meta) -- luacheck: ignore 211

  notify(src, L('paint_loaded', color.name), 'success')

  -- Notifs : conso de pigment par pot (uniquement ceux qui ont ete utilises).
  if cost.rouge > 0 then
    notify(src, L('paint_pot_red', cost.rouge, have.rouge - cost.rouge), 'info')
  end
  if cost.jaune > 0 then
    notify(src, L('paint_pot_yellow', cost.jaune, have.jaune - cost.jaune), 'info')
  end
  if cost.bleu > 0 then
    notify(src, L('paint_pot_blue', cost.bleu, have.bleu - cost.bleu), 'info')
  end

  -- Pousse l'état DIRECTEMENT (réservoir plein) sans dépendre de getEquippedGunId.
  TriggerClientEvent('pop_paint:client:syncState', src, {
    itemId    = itemId,
    color     = color.index,
    r         = color.r,
    g         = color.g,
    b         = color.b,
    reservoir = PaintGun.ReservoirMax,
  })
end)

-- Drain du reservoir pendant le spray (le client envoie la conso ecoulee).
RegisterNetEvent('pop_paint:server:drain', function(itemId, amount)
  local src = source
  if not src or src == 0 or src == '' then return end
  if not itemId then return end
  amount = tonumber(amount) or 0
  if amount <= 0 then return end

  local meta = INV.GetItemMetadata(src, itemId)
  if not meta or not meta.reservoir then return end

  meta.reservoir = math.max(0.0, (meta.reservoir or 0.0) - amount)
  local pct = math.floor((meta.reservoir / PaintGun.ReservoirMax) * 100 + 0.5)
  local cname = PaintGun.ColorByIndex[meta.paintIndex] and PaintGun.ColorByIndex[meta.paintIndex].name or L('paint_default_name')
  meta.description = L('paint_desc', cname, pct)
  INV.UpdateItemMetadata(src, itemId, meta)

  if meta.reservoir <= 0 then
    notify(src, L('paint_tank_empty'), 'error')
  end
end)
