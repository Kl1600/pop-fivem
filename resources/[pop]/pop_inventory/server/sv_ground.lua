SearchingPlayers = {}
GroundGrid = {} -- Grille spatiale pour les performances
CachedGroundSnapshot = nil
groundDirty = false
groundLoaded = false

-- UtilityNet: snapshot entry ID → uNetId for ground drop visual props
GroundDropUNetIds = {}
-- snapshot entry ID → {x,y,z} for coord change detection
GroundDropLastCoords = {}

RegisterNetEvent('pop_inventory:server:startSearchingPlayer', function(targetId)
    local src = source
    local targetPed = GetPlayerPed(targetId)
    if not DoesEntityExist(targetPed) then return end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(targetPed))
    if dist > 3.0 then
        Inv.NotifyTyped(src, { type = 'error', message = L('inv_too_far') })
        return
    end

    -- Nouveau flux : fouille en mode standby (cf. openSearchStandby). On ne pose plus
    -- SearchingPlayers (ancien affichage target_ superposé à l'inventaire principal).
    TriggerClientEvent('pop_inventory:client:openSearch', src, targetId)
end)

RegisterNetEvent('pop_inventory:server:stopSearchingPlayer', function()
    local src = source
    SearchingPlayers[src] = nil
end)

-- Audit des props au sol : un client signale les modèles de Config.GroundProps que
-- GTA ne connaît pas (IsModelValid = false). On les mémorise pour les remplacer par
-- le `default` (cf. resolveGroundProp) et on log une fois pour que tu corriges la config.
RegisterNetEvent('pop_inventory:server:reportInvalidGroundProps', function(invalidList)
    if type(invalidList) ~= 'table' then return end
    local added = {}
    for _, model in ipairs(invalidList) do
        if type(model) == 'string' and not InvalidGroundProps[model] then
            InvalidGroundProps[model] = true
            added[#added + 1] = model
        end
    end
    if #added > 0 then
        print(('[pop_inventory] GroundProps INVALIDES (remplacés par le default): %s'):format(table.concat(added, ', ')))
        markGroundDirty() -- re-résoudre les props des piles existantes
    end
end)

function getItemDef(defId)
  return Config.Items and Config.Items[defId]
end

-- Props GTA introuvables côté client (signalés par l'audit client, cf.
-- pop_inventory:server:reportInvalidGroundProps). On les remplace par le `default`
-- pour qu'un mauvais nom dans Config.GroundProps ne rende JAMAIS un item invisible
-- au sol (au pire on retombe sur le prop par défaut, comportement d'origine).
InvalidGroundProps = InvalidGroundProps or {}

local function resolveGroundProp(defId)
  local fallback = (Config.GroundProps and Config.GroundProps.default) or 'prop_paper_box_02'
  local model = (Config.GroundProps and Config.GroundProps[defId]) or fallback
  if InvalidGroundProps[model] then
    return fallback
  end
  return model
end

function getGroundDropSnapshot()
  if CachedGroundSnapshot and not groundDirty then return CachedGroundSnapshot end

  local drops = {}
  local iterationCount = 0

  for _, pile in pairs(GroundPiles or {}) do
    iterationCount = iterationCount + 1
    if iterationCount % 50 == 0 then Wait(0) end -- Laisser respirer le thread principal

    if pile and pile.coords then
      local container = GroundStore.containers[pile.containerId]
      if container and container.items then
        local visualCount = 0
        local cashPropModel = nil

        for _, itemId in pairs(container.items) do
          if visualCount >= 5 then break end -- MAX 5 props par pile pour éviter le crash réseau

          if itemId then
            local item = GroundStore.items[itemId]
            if item then
              if item.defId == 'cash' or item.defId == 'money' or item.defId == 'black_money' then
                if not cashPropModel then
                  cashPropModel = resolveGroundProp(item.defId)
                end
              else
                local propModel = resolveGroundProp(item.defId)

                local offsetX = (visualCount > 0) and (math.cos(visualCount * 2.0) * 0.15) or 0.0
                local offsetY = (visualCount > 0) and (math.sin(visualCount * 2.0) * 0.15) or 0.0

                table.insert(drops, {
                  id = pile.id .. '_' .. itemId,
                  -- On arrondit pour gagner du poids en JSON
                  coords = { x = math.floor((pile.coords.x + offsetX)*1000)/1000, y = math.floor((pile.coords.y + offsetY)*1000)/1000, z = pile.coords.z, h = pile.coords.h },
                  containerId = pile.containerId,
                  propModel = propModel,
                })
                visualCount = visualCount + 1
              end
            end
          end
        end

        if cashPropModel then
           table.insert(drops, {
             id = pile.id .. '_cash',
             coords = { x = pile.coords.x, y = pile.coords.y, z = pile.coords.z, h = pile.coords.h },
             containerId = pile.containerId,
             propModel = cashPropModel,
           })
        end
      end
    end
  end
  CachedGroundSnapshot = drops
  return drops
end


-- Sync UtilityNet entities to current ground drop snapshot.
-- Creates missing entities, updates moved ones, deletes stale ones.
function syncGroundDropEntities()
  if GetResourceState("utility_lib") ~= "started" then return end

  local snapshot = getGroundDropSnapshot()
  local seen = {}

  for _, drop in ipairs(snapshot) do
    seen[drop.id] = true
    local uNetId = GroundDropUNetIds[drop.id]
    local cx, cy, cz = drop.coords.x, drop.coords.y, drop.coords.z
    local ch = drop.coords.h or 0.0

    if not uNetId then
      -- Nouvelle entrée : créer l'entité UtilityNet
      local ok, id = pcall(
        exports["utility_lib"].CreateEntity, exports["utility_lib"],
        drop.propModel,
        vector3(cx, cy, cz),
        {
          rotation  = vector3(0.0, 0.0, ch),
          createdBy = GetCurrentResourceName(),
          tabInventoryGroundDrop = true,
        }
      )
      if ok and type(id) == "number" and id > 0 then
        GroundDropUNetIds[drop.id] = id
        GroundDropLastCoords[drop.id] = { x = cx, y = cy, z = cz, h = ch }
      end
    else
      -- Entrée existante : mettre à jour coords ET rotation si la pile a bougé
      -- (le déplacement au gizmo change aussi le cap -> il faut le resynchroniser).
      local last = GroundDropLastCoords[drop.id]
      if not last or last.x ~= cx or last.y ~= cy or last.z ~= cz then
        pcall(exports["utility_lib"].SetEntityCoords, exports["utility_lib"], uNetId, vector3(cx, cy, cz))
      end
      if not last or last.h ~= ch then
        pcall(exports["utility_lib"].SetEntityRotation, exports["utility_lib"], uNetId, vector3(0.0, 0.0, ch))
      end
      GroundDropLastCoords[drop.id] = { x = cx, y = cy, z = cz, h = ch }
    end
  end

  -- Supprimer les entités des piles supprimées
  for entryId, uNetId in pairs(GroundDropUNetIds) do
    if not seen[entryId] then
      pcall(exports["utility_lib"].DeleteEntity, exports["utility_lib"], uNetId)
      GroundDropUNetIds[entryId] = nil
      GroundDropLastCoords[entryId] = nil
    end
  end
end

function safeTableName(value)
  return tostring(value or ''):gsub('[^%w_]', '')
end


function ensureDatabaseTables()
  if not (Config.Persistence and Config.Persistence.UseDatabase) or not MySQL then
    return
  end

  local invTable = safeTableName(Config.Persistence.InventoriesTable or 'tab_inventory_inventories')
  local groundTable = safeTableName(Config.Persistence.GroundTable or 'tab_inventory_ground')

  if invTable and invTable ~= '' then
    mysqlUpdate(([[
CREATE TABLE IF NOT EXISTS `%s` (
  `identifier` VARCHAR(64) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]):format(invTable))
  end

  if groundTable ~= '' then
    mysqlUpdate(([[
CREATE TABLE IF NOT EXISTS `%s` (
  `id` VARCHAR(64) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]):format(groundTable))
  end
end

CreateThread(function()
  while not MySQL do
    Wait(200)
  end
  ensureDatabaseTables()
  checkRequiredTables(function()
    -- Wait a brief second for database tables validation to complete before running repair
    Wait(1000)
    autoRepairMissingJobGrades()
  end)
end)

