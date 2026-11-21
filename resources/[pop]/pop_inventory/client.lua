local isOpen = false
local ESX = nil
local QBCore = nil
local lastStateSeq = 0
local loadedModels = {}
local currentEquipment = {}
local currentState = nil
local customTorso = nil
local applyClothing
local applyNude

if Config.Framework == 'esx' then
  ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
  if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
  end
end

local function sendNui(action, payload)
  SendNUIMessage(payload or { action = action })
end

local function openUi()
  if isOpen then
    return
  end
  isOpen = true
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

local function closeUi()
  if not isOpen then
    return
  end
  isOpen = false
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
    for i=1, 20 do
      Wait(25)
      if not isOpen then
        TriggerScreenblurFadeOut(0)
        ClearTimecycleModifier()
      end
    end
  end)
end

-- Fermeture forcee depuis une autre logique du resource (ex: pistolet a peinture).
AddEventHandler('pop_inventory:client:forceClose', function()
  closeUi()
end)

-- Ouverture depuis une autre logique du resource (ex: pistolet a peinture).
AddEventHandler('pop_inventory:client:openInventory', function()
  if not isOpen and not IsNuiFocused() then
    openUi()
  end
end)

-- Etat de l'inventaire, utilise par les autres modules (radio, peinture...)
-- pour ne jamais superposer deux UI.
exports('IsInventoryOpen', function()
  return isOpen == true
end)

local function toggleInventory()
  if isOpen then
    closeUi()
  else
    -- Ne pas ouvrir l'inventaire si une AUTRE interface (NUI) a déjà le focus
    -- (menu admin, coffre, etc.) : la touche reste à l'interface active.
    if IsNuiFocused() then return end
    openUi()
  end
end

-- Commande simple (utilisée aussi par d'autres scripts) + touche I.
RegisterCommand('pop_inventory', function()
  -- Ancien raccourci TAB resté sur certains PC : géré par +pop_inventory_key
  if IsControlPressed(0, 37) or IsDisabledControlPressed(0, 37) then return end
  toggleInventory()
end, false)
RegisterCommand('pop_inventory_alt', toggleInventory, false)
RegisterKeyMapping('pop_inventory_alt', 'Inventaire : ouvrir / fermer (touche 2)', 'keyboard', 'I')

-- Switch weapons keys (touches 1 à 4 pour les petites cases)
local function switchToWeaponSlot(slot)
  -- Bloqué si l'inventaire OU une autre interface (NUI) est ouverte.
  if isOpen or IsNuiFocused() then return end
  local ped = PlayerPedId()

  -- Règle : Si une arme lourde est dans le slot, elle doit TOUT LE TEMPS être dans les mains
  if currentEquipment['weapon_long'] then
    local heavyItem = currentEquipment['weapon_long']
    local heavyDefId = (type(heavyItem) == 'table' and heavyItem.defId) or heavyItem
    local heavyDef = Config.Items and Config.Items[heavyDefId]
    if heavyDef and heavyDef.weaponHash then
      local heavyHash = GetHashKey(heavyDef.weaponHash)
      if HasPedGotWeapon(ped, heavyHash, false) then
        -- Force l'arme lourde dans les mains
        SetCurrentPedWeapon(ped, heavyHash, true)
        
        -- Empêche le switch vers une autre arme
        if GetResourceState('pop_notify') == 'started' then
          exports['pop_notify']:ShowNotify({
            title = 'Action impossible',
            message = 'Vous devez poser ou ranger votre arme lourde d\'abord.',
            icon = 'fas fa-hand-paper',
            duration = 3000
          })
        end
        return
      end
    end
  end

  local item = currentEquipment[slot]
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

RegisterCommand('pop_inventory_slot1', function() switchToWeaponSlot('weapon_pistol') end, false)
RegisterKeyMapping('pop_inventory_slot1', 'Arme Secondaire (Pistolet)', 'keyboard', '1')

RegisterCommand('pop_inventory_slot2', function() switchToWeaponSlot('weapon_tazer')  end, false)
RegisterKeyMapping('pop_inventory_slot2', 'Tazer / Arme Spéciale', 'keyboard', '2')

RegisterCommand('pop_inventory_slot3', function() switchToWeaponSlot('weapon_misc')   end, false)
RegisterKeyMapping('pop_inventory_slot3', 'Arme Misc / Couteau', 'keyboard', '3')

RegisterCommand('pop_inventory_slot4', function() switchToWeaponSlot('weapon_tool')   end, false)
RegisterKeyMapping('pop_inventory_slot4', 'Outil (Lampe UV...)', 'keyboard', '4')


-- =====================================================================
--  TAB : appui court = inventaire, maintenu = roue façon GTA
--  (armes équipées + objets utilisables : nourriture, boisson, soins…)
-- =====================================================================
local TAP_MAX_MS = 220
local WHEEL_WEAPON_SLOTS = {
  { slot = 'weapon_long',   label = 'Arme lourde' },
  { slot = 'weapon_pistol', label = 'Pistolet' },
  { slot = 'weapon_tazer',  label = 'Tazer' },
  { slot = 'weapon_misc',   label = 'Arme blanche' },
  { slot = 'weapon_tool',   label = 'Outil' },
}
local WHEEL_ITEM_TAGS = { food = true, drink = true, drug = true, drugs = true, ems = true, medical = true, consumable = true }
local wheelOpen, tabHeld, tabDownAt = false, false, 0

local function defOf(item)
  local defId = item and ((type(item) == 'table' and item.defId) or item)
  return defId, defId and Config.Items and Config.Items[defId]
end

local function isWheelItem(def)
  if not def or not def.usable or def.weaponHash or def.container or def.equipSlot or def.gridSpan then return false end
  for _, t in ipairs(def.tags or {}) do
    if WHEEL_ITEM_TAGS[t] then return true end
  end
  return false
end

local function buildWheelEntries()
  local entries = {}
  -- 1. Armes équipées (slots vides affichés grisés)
  for _, w in ipairs(WHEEL_WEAPON_SLOTS) do
    local _, def = defOf(currentEquipment[w.slot])
    entries[#entries + 1] = {
      kind = 'weapon', slot = w.slot,
      label = def and def.label or w.label, icon = def and def.icon or nil,
      empty = def == nil,
    }
  end
  entries[#entries + 1] = { kind = 'unarmed', label = 'Mains nues', empty = false }
  -- 2. Objets utilisables du joueur (regroupés par type)
  local byDef, order = {}, {}
  local st = currentState
  if st and type(st.containers) == 'table' then
    local skip = {}
    if st.ground and st.ground.id then skip[st.ground.id] = true end
    for _, entry in ipairs(st.containerOrder or {}) do
      if entry.isTarget and entry.containerId then skip[entry.containerId] = true end
    end
    for containerId, container in pairs(st.containers) do
      if not skip[containerId] and type(container) == 'table' and type(container.items) == 'table' then
        for slot, item in pairs(container.items) do
          if type(item) == 'table' and item.defId then
            local def = Config.Items and Config.Items[item.defId]
            if isWheelItem(def) then
              local agg = byDef[item.defId]
              if not agg then
                agg = { kind = 'item', defId = item.defId, containerId = containerId, slot = tonumber(slot) or slot,
                        label = def.label or item.defId, icon = def.icon, qty = 0, empty = false }
                byDef[item.defId] = agg
                order[#order + 1] = item.defId
              end
              agg.qty = agg.qty + (tonumber(item.qty) or 1)
            end
          end
        end
      end
    end
  end
  table.sort(order, function(x, y) return (byDef[x].label or x) < (byDef[y].label or y) end)
  for _, defId in ipairs(order) do entries[#entries + 1] = byDef[defId] end
  return entries
end

local function setWheelFocus(on)
  if on then
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- le jeu reçoit encore le relâchement de TAB
  else
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
  end
end

local function openWheel()
  if wheelOpen or isOpen then return end
  wheelOpen = true
  setWheelFocus(true)
  SendNUIMessage({ action = 'wheelOpen', entries = buildWheelEntries() })
  -- Rafraîchit le contenu (quantités à jour)
  local c = GetEntityCoords(PlayerPedId())
  TriggerServerEvent('pop_inventory:server:requestState', { x = c.x, y = c.y, z = c.z })
  SetTimeout(350, function()
    if wheelOpen then SendNUIMessage({ action = 'wheelUpdate', entries = buildWheelEntries() }) end
  end)
  CreateThread(function()
    while wheelOpen do
      -- caméra et tir bloqués pendant la sélection, déplacement libre
      DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
      DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
      DisableControlAction(0, 257, true); DisableControlAction(0, 142, true)
      DisableControlAction(0, 106, true); DisableControlAction(0, 14, true)
      DisableControlAction(0, 15, true); DisableControlAction(0, 16, true)
      DisableControlAction(0, 17, true)
      Wait(0)
    end
  end)
end

local function closeWheel()
  if not wheelOpen then return end
  wheelOpen = false
  SendNUIMessage({ action = 'wheelClose' }) -- la NUI répond avec wheelPick
  setWheelFocus(false)
end

RegisterNUICallback('wheelPick', function(data, cb)
  cb('ok')
  if wheelOpen then -- choix au clic : on ferme ici
    wheelOpen = false
    tabHeld = false
    setWheelFocus(false)
  end
  local e = data and data.entry
  if type(e) ~= 'table' then return end
  SetTimeout(120, function()
    local ped = PlayerPedId()
    if e.kind == 'unarmed' then
      SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    elseif e.kind == 'weapon' and e.slot then
      local _, def = defOf(currentEquipment[e.slot])
      -- Déjà en main : on ne range pas (la roue sert à choisir)
      if def and def.weaponHash and GetSelectedPedWeapon(ped) == GetHashKey(def.weaponHash) then return end
      switchToWeaponSlot(e.slot)
    elseif e.kind == 'item' and e.containerId and e.slot then
      local c = GetEntityCoords(ped)
      TriggerServerEvent('pop_inventory:server:action', {
        type = 'use', fromType = 'container', containerId = e.containerId, slot = e.slot,
        coords = { x = c.x, y = c.y, z = c.z },
      })
    end
  end)
end)

RegisterCommand('+pop_inventory_key', function()
  if isOpen or wheelOpen or IsNuiFocused() then return end
  if IsPedDeadOrDying(PlayerPedId(), true) then return end
  tabHeld = true
  local t = GetGameTimer()
  tabDownAt = t
  CreateThread(function()
    while tabHeld and tabDownAt == t do
      if GetGameTimer() - t >= TAP_MAX_MS then
        openWheel()
        return
      end
      Wait(0)
    end
  end)
end, false)

RegisterCommand('-pop_inventory_key', function()
  if not tabHeld then return end
  tabHeld = false
  if wheelOpen then
    closeWheel()
  elseif GetGameTimer() - tabDownAt < TAP_MAX_MS then
    toggleInventory()
  end
end, false)

RegisterKeyMapping('+pop_inventory_key', 'Inventaire (appui) / roue (maintenir TAB)', 'keyboard', 'TAB')

CreateThread(function()
  -- Natives localisées : boucle obligatoirement par frame (DisableControlAction ne vaut que pour la frame courante)
  local Wait, HudWeaponWheelIgnoreSelection, DisableControlAction = Wait, HudWeaponWheelIgnoreSelection, DisableControlAction
  local HideHudAndRadarThisFrame, DisplayRadar = HideHudAndRadarThisFrame, DisplayRadar
  while true do
    Wait(0)
    -- La roue native de GTA est remplacée par la roue « maison » (TAB maintenu)
    HudWeaponWheelIgnoreSelection()
    DisableControlAction(0, 37, true)

    if isOpen then
      -- Disable other controls if needed when UI is open
      DisableControlAction(0, 1, true) -- LookLeftRight
      DisableControlAction(0, 2, true) -- LookUpDown
      DisableControlAction(0, 24, true) -- Attack
      DisableControlAction(0, 257, true) -- Attack 2
      DisableControlAction(0, 25, true) -- Aim
      DisableControlAction(0, 142, true) -- MeleeAttackAlternate
      DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
      -- Masquer HUD et minimap à chaque frame (GTA réinitialise chaque tick)
      HideHudAndRadarThisFrame()
      DisplayRadar(false)
    end
  end
end)

RegisterNUICallback('close', function(_, cb)
  closeUi()
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
    [1]  = 15, -- male_1.png
    [2]  = 0,  -- male_2.png
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
    customTorso = drawableId -- Sauvegarde locale pour applyNude
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

-- =============================================
--  ADMIN : Sélecteur d'items
-- =============================================
RegisterNUICallback('adminRequestItems', function(_, cb)
  TriggerServerEvent('pop_inventory:server:adminRequestItems')
  cb('ok')
end)

RegisterNUICallback('adminGiveItem', function(data, cb)
  if type(data) == 'table' and data.id then
    local qty = tonumber(data.qty) or 1
    if qty < 1 then qty = 1 end
    local meta = nil

    -- Cas spécial : carkeys -> remplir auto plate + model du véhicule actuel (sinon le plus proche)
    if data.id == 'carkeys' then
      local ped = PlayerPedId()
      local vehicle = GetVehiclePedIsIn(ped, false)

      if vehicle == 0 then
        local pedCoords = GetEntityCoords(ped)
        local closestVehicle, closestDistance = 0, 5.0
        local pool = GetGamePool('CVehicle')
        for i = 1, #pool do
          local v = pool[i]
          local dist = #(pedCoords - GetEntityCoords(v))
          if dist < closestDistance then
            closestDistance = dist
            closestVehicle = v
          end
        end
        vehicle = closestVehicle
      end

      if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then plate = plate:gsub('^%s*(.-)%s*$', '%1') end
        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local labelText = GetLabelText(displayName)
        local modelName
        if labelText == 'NULL' then
          modelName = displayName:sub(1, 1):upper() .. displayName:sub(2):lower()
        else
          modelName = labelText
        end
        meta = { plate = plate, model = modelName }
      end
    end

    TriggerServerEvent('pop_inventory:server:adminGiveItem', data.id, qty, meta)
  end
  cb('ok')
end)

RegisterNetEvent('pop_inventory:client:setAdminItems', function(items)
  SendNUIMessage({ action = 'setAdminItems', items = items or {} })
end)

adminAllowed = false  -- global : accessible depuis remote_container.lua (canInteract ox_target)

RegisterNetEvent('pop_inventory:client:setAdminAllowed', function(allowed)
  adminAllowed = allowed == true
  SendNUIMessage({ action = 'setAdminAllowed', allowed = allowed == true })
end)

-- Vérifie le statut admin au démarrage pour que le target ox_target fonctionne
-- même si le joueur n'a pas encore ouvert son inventaire.
CreateThread(function()
  Wait(3000)
  TriggerServerEvent('pop_inventory:server:adminCheck')
end)

RegisterNetEvent('pop_inventory:client:adminDeleteVehicleResult', function(success)
  if success then
    exports['pop_notify']:ShowNotify({ message = 'Véhicule supprimé de la carte.', type = 'success' })
  else
    exports['pop_notify']:ShowNotify({ message = 'Véhicule introuvable.', type = 'error' })
  end
end)

RegisterNUICallback('adminOpenClotheShop', function(_, cb)
    TriggerEvent('pop_inventory:client:openClotheShop')
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:openClotheShop', function()
    closeUi()
    
    if GetResourceState('pop_clothes') == 'started' then
        exports['pop_clothes']:openAdmin()
    elseif GetResourceState('fivem-appearance') == 'started' then
        TriggerEvent('fivem-appearance:client:openAppearanceMenu')
    elseif GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openAppearanceMenu')
    else
        TriggerEvent('pop_inventory:client:notify', "Aucun système de vêtements détecté.")
    end
end)

RegisterNUICallback('adminRequestJobs', function(_, cb)
    TriggerServerEvent('pop_inventory:server:adminRequestJobs')
    cb('ok')
end)

RegisterNUICallback('adminSetJob', function(data, cb)
    if data and data.job then
        TriggerServerEvent('pop_inventory:server:adminSetJob', data.job, data.grade)
    end
    cb('ok')
end)

RegisterNUICallback('adminCreateJob', function(data, cb)
    if data and data.name and data.label then
        TriggerServerEvent('pop_inventory:server:adminCreateJob', data.name, data.label)
    end
    cb('ok')
end)

RegisterNUICallback('adminAddGrade', function(data, cb)
    if data and data.job and data.name and data.label then
        TriggerServerEvent('pop_inventory:server:adminAddGrade', data.job, data.level, data.name, data.label, data.salary)
    end
    cb('ok')
end)

RegisterNUICallback('adminAddSocietyMoney', function(data, cb)
    if data and data.job and data.amount then
        TriggerServerEvent('pop_inventory:server:adminAddSocietyMoney', data.job, data.amount)
    end
    cb('ok')
end)

RegisterNUICallback('adminDeleteJob', function(data, cb)
    if data and data.job then
        TriggerServerEvent('pop_inventory:server:adminDeleteJob', data.job)
    end
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:debugPrint', function(msg)
    print('[POP_INVENTORY][SRV→CLI] ' .. tostring(msg))
end)

-- Commande F8 pour dump le schema MySQL et identifier les colonnes NOT NULL
-- qui font potentiellement planter l'INSERT.
RegisterCommand('popjobschema', function()
    TriggerServerEvent('pop_inventory:server:adminDumpSchema')
end, false)

RegisterNetEvent('pop_inventory:client:setAdminJobs', function(jobs)
  SendNUIMessage({ action = 'setAdminJobs', jobs = jobs or {} })
end)

RegisterNUICallback('adminSetWeather', function(data, cb)
    if data and data.weather then
        TriggerServerEvent('pop_inventory:server:adminSetWeather', data.weather)
    end
    cb('ok')
end)

-- Admin Vehicles logic
RegisterNUICallback('adminGiveVehicleKeys', function(_, cb)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then plate = plate:gsub('^%s*(.-)%s*$', '%1') end
        
        local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local labelText = GetLabelText(displayName)
        local modelName = (labelText == 'NULL') and displayName or labelText

        local meta = { plate = plate, model = modelName }
        TriggerServerEvent('pop_inventory:server:adminGiveItem', 'carkeys', 1, meta)
        TriggerEvent('pop_inventory:client:notify', "Clés du véhicule " .. plate .. " reçues.")
    else
        TriggerEvent('pop_inventory:client:notify', "Aucun véhicule détecté.")
    end
    cb('ok')
end)

RegisterNUICallback('adminToggleShowVehicles', function(_, cb)
    ExecuteCommand('showvehicles')
    cb('ok')
end)

RegisterNUICallback('adminToggleShowCasings', function(_, cb)
    ExecuteCommand('showcasings')
    cb('ok')
end)

RegisterNetEvent('pop_inventory:client:syncWeather', function(weather)
    SetWeatherTypeOverTime(weather, 15.0)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNUICallback('action', function(data, cb)
  local coords = GetEntityCoords(PlayerPedId())
  data.coords = { x = coords.x, y = coords.y, z = coords.z }
  TriggerServerEvent('pop_inventory:server:action', data)
  cb('ok')
end)

local isDraggingOut   = false
local targetPlayer    = nil
local isDragItem      = nil   -- defId de l'item en cours de drag
local targetDragEntity = nil  -- entité monde survolée pendant un drag

-- ── Registry de cibles drag ──────────────────────────────────────────────────
local dragTargets = {}  -- [entityHandle] = { itemFilter, callback }

exports('registerDragTarget', function(entity, itemFilter, callback)
    dragTargets[entity] = { itemFilter = itemFilter, callback = callback }
end)

exports('unregisterDragTarget', function(entity)
    if dragTargets[entity] then
        if DoesEntityExist(entity) then SetEntityDrawOutline(entity, false) end
        dragTargets[entity] = nil
    end
end)

local function GetHoveredDragTarget()
    if not isDragItem then return nil end
    local cursorX, cursorY = GetNuiCursorPosition()
    local resX,   resY    = GetActiveScreenResolution()
    if resX == 0 or resY == 0 then return nil end
    local normX  = cursorX / resX
    local normY  = cursorY / resY
    local aspect = resX / resY
    local pPed   = PlayerPedId()
    local best, minDist = nil, 0.12

    for entity, target in pairs(dragTargets) do
        if (target.itemFilter == nil or target.itemFilter == isDragItem) and DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            if #(GetEntityCoords(pPed) - coords) < 10.0 then
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + 0.5)
                if onScreen then
                    local dx = (sx - normX) * aspect
                    local dy = sy - normY
                    local d  = math.sqrt(dx^2 + dy^2)
                    if d < minDist then minDist = d ; best = entity end
                end
            end
        end
    end
    return best
end
-- ─────────────────────────────────────────────────────────────────────────────

RegisterNUICallback("startDraggingOut", function(data, cb)
    isDraggingOut = true
    isDragItem    = data.item and data.item.defId or nil
    if cb then cb('ok') end
end)

RegisterNUICallback("stopDraggingOut", function(data, cb)
    isDraggingOut = false
    isDragItem    = nil
    targetPlayer  = nil
    if targetDragEntity then
        if DoesEntityExist(targetDragEntity) then SetEntityDrawOutline(targetDragEntity, false) end
        targetDragEntity = nil
    end
    if cb then cb('ok') end
end)

function GetHoveredPlayer()
    local cursorX, cursorY = GetNuiCursorPosition()
    local resX, resY = GetActiveScreenResolution()
    
    local normX = 0.5
    local normY = 0.5
    
    if resX > 0 and resY > 0 then
        normX = cursorX / resX
        normY = cursorY / resY
    end
    
    local players = GetActivePlayers()
    local pPed = PlayerPedId()
    local aspect = 1.0
    if resY > 0 then aspect = resX / resY end
    
    local hoveredPlayer = nil
    local minScreenDist = 0.08
    
    for i=1, #players do
        local targetPed = GetPlayerPed(players[i])
        if targetPed ~= pPed and HasEntityClearLosToEntity(pPed, targetPed, 17) then
            local tCoords = GetEntityCoords(targetPed)
            local dist3D = #(GetEntityCoords(pPed) - tCoords)
            if dist3D < 8.0 then
                -- Check multiple points on the body (feet, chest, head)
                local offsets = {0.2, 0.9, 1.6}
                local pointMinDist = 999.0
                
                for _, zOffset in ipairs(offsets) do
                    local checkCoords = tCoords + vector3(0.0, 0.0, zOffset)
                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(checkCoords.x, checkCoords.y, checkCoords.z)
                    if onScreen then
                        local dx = (screenX - normX) * aspect
                        local dy = screenY - normY
                        local sDist = math.sqrt(dx^2 + dy^2)
                        if sDist < pointMinDist then pointMinDist = sDist end
                    end
                end
                
                local threshold = math.max(0.04, 0.15 - (dist3D * 0.012))
                
                if pointMinDist < threshold and pointMinDist < minScreenDist then
                    minScreenDist = pointMinDist
                    hoveredPlayer = players[i]
                end
            end
        end
    end
    return hoveredPlayer
end

RegisterNUICallback("confirmDraggingOut", function(data, cb)
    -- Priorité : entité monde enregistrée (ex: plante)
    if targetDragEntity then
        local target = dragTargets[targetDragEntity]
        if target and target.callback then
            target.callback(data)
        end
        if DoesEntityExist(targetDragEntity) then SetEntityDrawOutline(targetDragEntity, false) end
        targetDragEntity = nil
        isDraggingOut = false
        isDragItem    = nil
        if cb then cb({success = true}) end
        return
    end

    -- Fallback : don à un joueur
    if targetPlayer then
        local targetServerId = GetPlayerServerId(targetPlayer)
        if targetServerId > 0 then
            TriggerServerEvent('pop_inventory:server:giveItem', targetServerId, data.fromContainerId, data.fromSlot, data.item, data.fromType)
            isDraggingOut = false
            isDragItem    = nil
            if targetPlayer then
                local p = GetPlayerPed(targetPlayer)
                SetEntityDrawOutline(p, false)
                ResetEntityAlpha(p)
            end
            targetPlayer = nil
            if cb then cb({success = true}) end
            return
        end
    end
    isDraggingOut = false
    isDragItem    = nil
    if targetPlayer then
        local p = GetPlayerPed(targetPlayer)
        SetEntityDrawOutline(p, false)
        ResetEntityAlpha(p)
    end
    targetPlayer = nil
    TriggerEvent('pop_inventory:client:notify', "Don annulé : aucun joueur ciblé")
    if cb then cb({success = false}) end
end)

CreateThread(function()
    while true do
        if isDraggingOut then
            -- Entités monde enregistrées (plantes, etc.)
            local hoveredEntity = GetHoveredDragTarget()
            if hoveredEntity ~= targetDragEntity then
                if targetDragEntity and DoesEntityExist(targetDragEntity) then
                    SetEntityDrawOutline(targetDragEntity, false)
                end
                targetDragEntity = hoveredEntity
                if targetDragEntity and DoesEntityExist(targetDragEntity) then
                    SetEntityDrawOutline(targetDragEntity, true)
                    SetEntityDrawOutlineColor(0, 150, 255, 255)
                end
            end

            -- Joueurs proches (uniquement si pas de cible monde)
            local hovered = not targetDragEntity and GetHoveredPlayer() or nil
            if hovered then
                if targetPlayer and targetPlayer ~= hovered then
                    local p = GetPlayerPed(targetPlayer)
                    SetEntityDrawOutline(p, false)
                    ResetEntityAlpha(p)
                end
                targetPlayer = hovered
                local targetPed = GetPlayerPed(hovered)
                SetEntityAlpha(targetPed, 100, false)
                SetEntityDrawOutline(targetPed, true)
                SetEntityDrawOutlineColor(0, 255, 0, 255)
            else
                if targetPlayer then
                    local p = GetPlayerPed(targetPlayer)
                    SetEntityDrawOutline(p, false)
                    ResetEntityAlpha(p)
                end
                targetPlayer = nil
            end
            Wait(0)
        else
            if targetPlayer then
                local p = GetPlayerPed(targetPlayer)
                SetEntityDrawOutline(p, false)
                ResetEntityAlpha(p)
                targetPlayer = nil
            end
            Wait(250)
        end
    end
end)

local failedModels = {}

--[ Optimization: Non-blocking Model Loader ]--
local modelLoadRequests = {}
local function ensureModelLoaded(modelName)
  local modelHash = GetHashKey(modelName)
  if HasModelLoaded(modelHash) then return true end
  if failedModels[modelHash] then return false end
  
  if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
    failedModels[modelHash] = true
    return false
  end
  
  if not modelLoadRequests[modelHash] then
    RequestModel(modelHash)
    modelLoadRequests[modelHash] = true
  end
  
  -- On ne bloque PLUS avec une boucle while. 
  -- On retourne false et on laisse le tick suivant retenter.
  return false 
end

-- Les props des items au sol sont gérés par utility_lib (UtilityNet).
-- utility_lib crée/supprime les entités côté client via son render loop.


RegisterNetEvent('pop_inventory:client:state', function(state)
  if state and state._seq and state._seq <= lastStateSeq then
    return
  end
  if state and state._seq then
    lastStateSeq = state._seq
  end
  
  currentState = state
  
  SendNUIMessage({ action = 'state', state = state })
  -- updateDropMarkers(state and state.groundDrops) -- Removed: Handled by optimized proximity event
end)

-- Casier (Config.LockerRooms) : ce n'est pas votre casier -> le serveur demande le
-- code (pop_management). Affiché tant que la NUI inventaire est ouverte (la salle de
-- casiers y est déjà visible comme conteneur standby).
RegisterNetEvent('pop_inventory:client:requestLockerCode', function(containerId)
  SendNUIMessage({ action = 'requestLockerCode', containerId = containerId })
end)

RegisterNetEvent('pop_inventory:client:openShop', function(shopId, items)
    openUi()
    local currency = nil
    local cfg = Config and Config.ShopCurrency
    local is80s = (GlobalState.style80s == true)
    if is80s and cfg and cfg.PesosShops and cfg.PesosShops[shopId] then
        currency = { pesos = true, rate = cfg.PesosPerDollar or 1 }
    end
    SendNUIMessage({ action = 'shop_mode', shopId = shopId, items = items, currency = currency })
end)

exports('getItemCount', function(itemDefId)
  if not currentState then return 0 end
  local count = 0
  
  -- Check equipment
  for _, item in pairs(currentState.equipment or {}) do
    if item.defId == itemDefId then
      count = count + (item.qty or 1)
    end
  end
  
  -- Check all containers
  for _, container in pairs(currentState.containers or {}) do
    for _, item in pairs(container.items or {}) do
      if item.defId == itemDefId then
        count = count + (item.qty or 1)
      end
    end
  end

  return count
end)

exports('GetPlayerItems', function(itemDefId)
  if not currentState then return {} end
  local results = {}
  
  -- Check equipment
  for _, item in pairs(currentState.equipment or {}) do
    if not itemDefId or item.defId == itemDefId then
      table.insert(results, item)
    end
  end
  
  -- Check all containers
  for _, container in pairs(currentState.containers or {}) do
    for _, item in pairs(container.items or {}) do
      if not itemDefId or item.defId == itemDefId then
        table.insert(results, item)
      end
    end
  end

  return results
end)

-- Définition (label + icône) d'un item à partir de son defId.
-- Renvoie nil si l'item n'existe pas (l'appelant peut alors afficher un '?').
-- 'icon' est le chemin tel que stocké (ex: 'img/wheel.png'), relatif à html/.
exports('GetItemDef', function(defId)
  local d = Config.Items and Config.Items[defId]
  if not d then return nil end
  return { label = d.label, icon = d.icon }
end)

RegisterNetEvent('pop_inventory:client:notify', function(message)
  local notifType = (Config.Notifications and Config.Notifications.Type) or 'notification'

  if notifType == 'notification' and GetResourceState('pop_notify') == 'started' then
      local data = {
          message = message,
          icon = 'fas fa-info',
          duration = 4000
      }
      exports['pop_notify']:ShowNotify(data)
  elseif notifType == 'esx' and ESX and ESX.ShowNotification then
      ESX.ShowNotification(message)
  elseif Config.Framework == 'qbcore' and QBCore then
      QBCore.Functions.Notify(message)
  else
      TriggerEvent('chat:addMessage', { args = { '[POP_INVENTORY]', message } })
  end
end)

local remoteContainerMarkers = {}

RegisterNetEvent('pop_inventory:client:updateRemoteContainers', function(containers)
  local seen = {}
  if containers and type(containers) == 'table' then
    for containerId, container in pairs(containers) do
      if container and container.coords and container.coords.x and container.coords.y and container.coords.z then
        local propModel = container.propModel or 'prop_paper_box_02'
        if not remoteContainerMarkers[containerId] or not DoesEntityExist(remoteContainerMarkers[containerId]) then
          if ensureModelLoaded(propModel) then
            local modelHash = GetHashKey(propModel)
            local entity = CreateObjectNoOffset(modelHash, container.coords.x, container.coords.y, container.coords.z, false, false, false)
            SetEntityAsMissionEntity(entity, true, true)
            -- On place l'objet au sol tant qu'il a encore ses collisions
            if container.coords.h then
              SetEntityHeading(entity, container.coords.h)
            end
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, true, true)
            SetModelAsNoLongerNeeded(modelHash)
            remoteContainerMarkers[containerId] = entity
          end
        else
          local entity = remoteContainerMarkers[containerId]
          if DoesEntityExist(entity) then
            FreezeEntityPosition(entity, false)
            SetEntityCollision(entity, true, true)
            SetEntityCoordsNoOffset(entity, container.coords.x, container.coords.y, container.coords.z, true, true, true)
            if container.coords.h then
              SetEntityHeading(entity, container.coords.h)
            else
              PlaceObjectOnGroundProperly(entity)
            end
            FreezeEntityPosition(entity, true)
            SetEntityCollision(entity, true, true)
          end
        end
        seen[containerId] = true
      end
    end
  end
  for containerId in pairs(remoteContainerMarkers) do
    if not seen[containerId] then
      local entity = remoteContainerMarkers[containerId]
      if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
      end
      remoteContainerMarkers[containerId] = nil
    end
  end
end)

CreateThread(function()
  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    if Config.StaticChests then
      for _, chest in ipairs(Config.StaticChests) do
        local dist = #(coords - chest.coords)
        if dist < (chest.marker and chest.marker.drawDistance or 20.0) then
          if chest.marker and chest.marker.enabled then
            sleep = 0 -- par frame uniquement si un marqueur est réellement dessiné
            local color = chest.marker.color or { r = 255, g = 255, b = 255, a = 180 }
            DrawMarker(
              chest.marker.type or 1,
              chest.coords.x, chest.coords.y, chest.coords.z - 1.0,
              0, 0, 0, 0, 0, 0,
              chest.radius or 2.0, chest.radius or 2.0, 1.0,
              color.r, color.g, color.b, color.a,
              false, true, 2, false, nil, nil, false
            )
          end
        end
      end
    end
    Wait(sleep)
  end
end)


local function applyComponents(ped, components)
  for compId, data in pairs(components or {}) do
    SetPedComponentVariation(ped, tonumber(compId), data.drawable or 0, data.texture or 0, data.palette or 0)
  end
end

local function applyProps(ped, props)
  for propId, data in pairs(props or {}) do
    local drawable = data.drawable
    if drawable == nil or drawable < 0 then
      ClearPedProp(ped, tonumber(propId))
    else
      SetPedPropIndex(ped, tonumber(propId), drawable, data.texture or 0, true)
    end
  end
end

local function getGender()
  local model = GetEntityModel(PlayerPedId())
  if model == GetHashKey('mp_f_freemode_01') then
    return 'female'
  end
  return 'male'
end

applyNude = function()
  local ped = PlayerPedId()
  local gender = getGender()
  local nude = Config.Nude and Config.Nude[gender]
  if not nude then
    return
  end
  
  -- Si on n'a pas encore de customTorso, on essaie de le récupérer depuis le ped actuel (pour garder la synchro skinchanger)
  if customTorso == nil then
    customTorso = GetPedDrawableVariation(ped, 3)
  end

  local components = {}
  for k,v in pairs(nude.components) do components[k] = v end
  
  -- On force le torse choisi (ou celui du skin actuel) au lieu de celui par défaut de Config.Nude
  if customTorso ~= nil then
    components[3] = { drawable = customTorso, texture = 0, palette = 0 }
  end

  applyComponents(ped, components)
  applyProps(ped, nude.props)
end

applyClothing = function(equipment)
  local ped = PlayerPedId()
  applyNude()

  for _, item in pairs(equipment or {}) do
    local defId = item
    local meta = {}
    
    if type(item) == 'table' then
        defId = item.defId
        meta = item.meta or {}
    end
    
    if meta and (meta.components or meta.props) then
        if meta.components then applyComponents(ped, meta.components) end
        if meta.props then applyProps(ped, meta.props) end
    else
        local config = Config.Clothing and Config.Clothing[defId]
        if config then
          local gender = getGender()
          local data = config[gender]
          if data then
            applyComponents(ped, data.components)
            applyProps(ped, data.props)
          end
        end
    end
  end

  -- LES BRAS DOIVENT ÊTRE PERSISTANTS :
  -- Après l'application de TOUS les vêtements de l'inventaire, on écrase de force 
  -- l'éventuelle texture de bras (component 3) chargée par un t-shirt pour garder
  -- 100% des bras choisis par l'utilisateur dans son menu inventaire.
  if customTorso ~= nil then
    SetPedComponentVariation(ped, 3, customTorso, 0, 0)
  end
end

local function applyWeapons(equipment)
  CreateThread(function()
    local ped = PlayerPedId()
    local managedHashes = {}
    for _, itemDef in pairs(Config.Items or {}) do
      if itemDef.weaponHash then
        managedHashes[GetHashKey(itemDef.weaponHash)] = true
      end
    end

    local desiredHashes = {}
    local desiredAmmo = {}
    local desiredComponents = {}

    local briefcaseHash = GetHashKey('WEAPON_BRIEFCASE_02')
    managedHashes[briefcaseHash] = nil

    if equipment then
      for slot, item in pairs(equipment) do
        local defId = (type(item) == 'table' and item.defId) or item
        local itemDef = Config.Items and Config.Items[defId]
        if itemDef and itemDef.weaponHash then
          local hash = GetHashKey(itemDef.weaponHash)
          if hash ~= briefcaseHash then
            desiredHashes[hash] = true
            local hasMagWell = (type(item) == 'table' and item.containerId ~= nil)
            desiredAmmo[hash] = hasMagWell and 0 or 9999
            desiredComponents[hash] = {}
            local meta = type(item) == 'table' and item.meta or nil
            local attachments = meta and meta.attachments or nil
            local mapping = Config.WeaponAttachments and Config.WeaponAttachments[itemDef.weaponHash] or nil
            if attachments and mapping then
              for slotName, accessoryDefId in pairs(attachments) do
                local slotDef = mapping[slotName]
                if slotDef and slotDef.item == accessoryDefId and slotDef.componentHash then
                  desiredComponents[hash][GetHashKey(slotDef.componentHash)] = true
                end
              end
            end
          end
        end
      end
    end

    -- 1. Supprimer les armes gérées que le joueur ne devrait plus avoir
    for hash, _ in pairs(managedHashes) do
      if HasPedGotWeapon(ped, hash, false) and not desiredHashes[hash] then
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        Wait(50)
        RemoveWeaponFromPed(ped, hash)
        Wait(50)
        if HasPedGotWeapon(ped, hash, false) then
          RemoveWeaponFromPed(ped, hash)
        end
        if GetSelectedPedWeapon(ped) == hash then
          SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        end
      end
    end

    -- 2. Donner les armes que le joueur doit avoir + synchroniser leurs accessoires
    for hash, _ in pairs(desiredHashes) do
      if not HasPedGotWeapon(ped, hash, false) then
        local isHeavyWeapon = false
        if equipment and equipment['weapon_long'] then
          local hItem = equipment['weapon_long']
          local hDefId = (type(hItem) == 'table' and hItem.defId) or hItem
          local hDef = Config.Items and Config.Items[hDefId]
          if hDef and hDef.weaponHash and GetHashKey(hDef.weaponHash) == hash then
            isHeavyWeapon = true
          end
        end

        GiveWeaponToPed(ped, hash, desiredAmmo[hash] or 9999, false, isHeavyWeapon)
        managedHashes[hash] = true
      end
      
      local wanted = desiredComponents[hash] or {}
      local mapping = nil
      for _, itemDef in pairs(Config.Items or {}) do
        if itemDef.weaponHash and GetHashKey(itemDef.weaponHash) == hash then
          mapping = Config.WeaponAttachments and Config.WeaponAttachments[itemDef.weaponHash]
          break
        end
      end
      if mapping then
        for _, slotDef in pairs(mapping) do
          if slotDef.componentHash then
            local cHash = GetHashKey(slotDef.componentHash)
            if HasPedGotWeaponComponent(ped, hash, cHash) and not wanted[cHash] then
              RemoveWeaponComponentFromPed(ped, hash, cHash)
            end
          end
        end
      end
      for cHash, _ in pairs(wanted) do
        if not HasPedGotWeaponComponent(ped, hash, cHash) then
          GiveWeaponComponentToPed(ped, hash, cHash)
        end
      end
    end

    -- Auto-équipe l'arme lourde
    if equipment and equipment['weapon_long'] then
      local defId = (type(equipment['weapon_long']) == 'table' and equipment['weapon_long'].defId) or equipment['weapon_long']
      local itemDef = Config.Items and Config.Items[defId]
      if itemDef and itemDef.weaponHash then
        local hash = GetHashKey(itemDef.weaponHash)
        if IsWeaponValid(hash) then
          if HasPedGotWeapon(ped, hash, false) then
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            Wait(50)
            SetCurrentPedWeapon(ped, hash, true)
            -- Double vérification
            if GetSelectedPedWeapon(ped) ~= hash then
              SetCurrentPedWeapon(ped, hash, true)
            end
          end
        end
      end
    end
  end)
end

RegisterNetEvent('pop_inventory:client:applyEquipment', function(equipment)
  currentEquipment = equipment or {}
  applyClothing(equipment)
  applyWeapons(equipment)
end)

exports('RefreshEquipment', function()
    if currentEquipment then
        applyClothing(currentEquipment)
        applyWeapons(currentEquipment)
    end
end)

local function playerReady()
  CreateThread(function()
    Wait(4000) -- Délai de sécurité rallongé pour laisser le temps au charcreator et skinchanger de finir
    applyNude()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pop_inventory:server:playerReady', { x = coords.x, y = coords.y, z = coords.z })
  end)
end

AddEventHandler('playerSpawned', function()
  playerReady()
end)

RegisterNetEvent('esx:playerLoaded', function()
  playerReady()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  playerReady()
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  playerReady()
end)

CreateThread(function()
  while true do
    if isOpen then
      local coords = GetEntityCoords(PlayerPedId())
      TriggerServerEvent('pop_inventory:server:requestState', { x = coords.x, y = coords.y, z = coords.z })
      Wait(1000)
    else
      Wait(500)
    end
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  SetNuiFocus(false, false)
  if clearAllDropMarkers then
    clearAllDropMarkers()
  end
end)

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
  if not isOpen then
    openUi()
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
      local msg = 'Appuyez sur ~INPUT_CONTEXT~ pour accéder à ' .. (zoneInRange.label or "l'établi")

      if notifType == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
        if not craftPromptId then
          craftPromptId = exports['pop_v3dui']:Create({
            coords = zoneInRange.coords,
            type = 'prompt',
            content = {
              label = 'Ouvrir ' .. (zoneInRange.label or "l'établi"),
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
    
    local currency = nil
    local cfg = Config and Config.ShopCurrency
    if cfg and cfg.PesosShops and cfg.PesosShops[shopId] then
        currency = { pesos = true, rate = cfg.PesosPerDollar or 1 }
    end

    if not isOpen then
        openUi()
    end
    SendNUIMessage({ action = 'shop_mode', shopId = shopId, items = enrichedItems, currency = currency })
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
              label = 'OUVRIR ' .. (zoneInRange.label or "LA BOUTIQUE"),
              icon = 'fas fa-shopping-cart',
              key = 'E',
            },
          })
        end
        if IsControlJustReleased(0, 38) then
          openShopMode(zoneInRange.shopId, shopItems)
        end
      else
        local msg = 'Appuyez sur ~INPUT_CONTEXT~ pour ouvrir ' .. (zoneInRange.label or "la boutique")
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
end)

RegisterNUICallback('craft', function(data, cb)
  if data and data.recipeId then
    TriggerServerEvent('pop_inventory:server:craft', data.recipeId)
  end
  cb('ok')
end)
