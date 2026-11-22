-- Établis (craft), zones de boutique et ped iFruit.

-- ===== CRAFT ZONES =====

local function openCraftMode(zoneRecipes)
  local recipes = {}
  for _, r in ipairs(Config.Recipes or {}) do
    local include = not zoneRecipes or #zoneRecipes == 0
    if not include then
      for _, id in ipairs(zoneRecipes) do
        if r.id == id then include = true; break end
      end
    end
    if include then
      -- Enrichissement avec icônes/labels depuis Config.Items
      local outDef = Config.Items and Config.Items[r.output.defId]
      local enriched = {
        id = r.id,
        output = {
          defId = r.output.defId,
          qty   = r.output.qty,
          icon  = outDef and outDef.icon  or '',
          label = outDef and outDef.label or r.output.defId,
        },
        ingredients = {},
      }
      for _, ing in ipairs(r.ingredients or {}) do
        local ingDef = Config.Items and Config.Items[ing.defId]
        table.insert(enriched.ingredients, {
          defId = ing.defId,
          qty   = ing.qty,
          icon  = ingDef and ingDef.icon  or '',
          label = ingDef and ingDef.label or ing.defId,
        })
      end
      table.insert(recipes, enriched)
    end
  end
  if not Inv.isOpen then
    Inv.openUi()
  end
  SendNUIMessage({ action = 'craft_mode', recipes = recipes })
end

CreateThread(function()
  while not (Config and Config.CraftZones) do
    Wait(200)
  end

  local craftPromptId = nil

  while true do
    local interval = 1000
    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local zoneInRange = nil

    for _, zone in ipairs(Config.CraftZones) do
      local dist = #(pCoords - zone.coords)
      if dist < zone.radius then
        zoneInRange = zone
        interval = 0
        break
      elseif dist < 30.0 then
        interval = 100
      end
    end

    if zoneInRange then
      local notifType = (Config.UI and Config.UI.HelpNotificationType) or 'pop_inventory'
      local msg = L('craft_help', zoneInRange.label or L('craft_default'))

      if notifType == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
        if not craftPromptId then
          craftPromptId = exports['pop_v3dui']:Create({
            coords = zoneInRange.coords,
            type = 'prompt',
            content = {
              label = L('prompt_open', zoneInRange.label or L('craft_default')),
              icon = 'fas fa-hammer',
              key = 'E',
            },
          })
        end
        if IsControlJustReleased(0, 38) then
          openCraftMode(zoneInRange.recipes)
        end
      else
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentString(msg)
        EndTextCommandDisplayHelp(0, false, true, -1)
        if IsControlJustReleased(0, 38) then
          openCraftMode(zoneInRange.recipes)
        end
      end
    else
      if craftPromptId then
        exports['pop_v3dui']:Remove(craftPromptId)
        craftPromptId = nil
      end
    end

    Wait(interval)
  end
end)

-- ===== SHOP ZONES =====

local function openShopMode(shopId, shopItems)
    local enrichedItems = {}
    for _, item in ipairs(shopItems or {}) do
        local itemDef = Config.Items and Config.Items[item.id]
        table.insert(enrichedItems, {
            id = item.id,
            price = item.price,
            label = itemDef and itemDef.label or item.label or item.id,
            icon = itemDef and itemDef.icon or item.icon or ""
        })
    end

    if not Inv.isOpen then
        Inv.openUi()
    end
    SendNUIMessage({ action = 'shop_mode', shopId = shopId, items = enrichedItems })
end

CreateThread(function()
  while not (Config and Config.ShopZones) do
    Wait(200)
  end

  local shopPromptId = nil

  while true do
    local interval = 1000
    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local zoneInRange = nil

    for _, zone in ipairs(Config.ShopZones) do
      local dist = #(pCoords - zone.coords)
      if dist < zone.radius then
        zoneInRange = zone
        interval = 0
        break
      elseif dist < 20.0 then
        interval = 100
      end
    end

    if zoneInRange then
      local notifType = (Config.UI and Config.UI.HelpNotificationType) or 'pop_inventory'
      local shopItems = Config.Shops[zoneInRange.shopId] or {}

      if notifType == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
        if not shopPromptId then
          shopPromptId = exports['pop_v3dui']:Create({
            coords = zoneInRange.coords,
            type = 'prompt',
            content = {
              label = L('shop_prompt', zoneInRange.label or L('shop_default_upper')),
              icon = 'fas fa-shopping-cart',
              key = 'E',
            },
          })
        end
        if IsControlJustReleased(0, 38) then
          openShopMode(zoneInRange.shopId, shopItems)
        end
      else
        local msg = L('shop_help', zoneInRange.label or L('shop_default'))
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentString(msg)
        EndTextCommandDisplayHelp(0, false, true, -1)
        if IsControlJustReleased(0, 38) then
          openShopMode(zoneInRange.shopId, shopItems)
        end
      end
    else
      if shopPromptId then
        exports['pop_v3dui']:Remove(shopPromptId)
        shopPromptId = nil
      end
    end

    Wait(interval)
  end
end)

-- ===== PEDS =====
-- NOTE: pas de blip iFruit (retiré). Seul le ped reste pour l'interaction.
CreateThread(function()
    -- iFruit Ped
    local pedModel = GetHashKey("a_m_y_hipster_01")
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(10)
    end

    local shopPed = CreatePed(4, pedModel, -1244.4222, -806.1169, 17.8327 - 1.0, 304.4915, false, false)
    SetEntityAsMissionEntity(shopPed, true, true)
    SetBlockingOfNonTemporaryEvents(shopPed, true)
    SetEntityInvincible(shopPed, true)
    FreezeEntityPosition(shopPed, true)

    TaskStartScenarioInPlace(shopPed, "WORLD_HUMAN_STAND_MOBILE", 0, true)
    SetModelAsNoLongerNeeded(pedModel)

    -- Supprimé à l'arrêt de la ressource : sinon un restart en recréait un de plus.
    AddEventHandler('onResourceStop', function(resourceName)
      if resourceName ~= GetCurrentResourceName() then return end
      if DoesEntityExist(shopPed) then DeleteEntity(shopPed) end
    end)
end)

RegisterNUICallback('craft', function(data, cb)
  if data and data.recipeId then
    TriggerServerEvent('pop_inventory:server:craft', data.recipeId)
  end
  cb('ok')
end)
