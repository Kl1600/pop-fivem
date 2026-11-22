-- Roue façon GTA (TAB maintenu) et blocage de la roue d'armes native.

-- =====================================================================
--  TAB : appui court = inventaire, maintenu = roue façon GTA
--  (armes équipées + objets utilisables : nourriture, boisson, soins…)
-- =====================================================================
local TAP_MAX_MS = 220
local WHEEL_WEAPON_SLOTS = {
  { slot = 'weapon_long',   label = L('wheel_heavy') },
  { slot = 'weapon_pistol', label = L('wheel_pistol') },
  { slot = 'weapon_tazer',  label = L('wheel_tazer') },
  { slot = 'weapon_misc',   label = L('wheel_melee') },
  { slot = 'weapon_tool',   label = L('wheel_tool') },
}
local WHEEL_ITEM_TAGS = { food = true, drink = true, drug = true, drugs = true, ems = true, medical = true, consumable = true }
Inv.wheelOpen = false
local tabHeld, tabDownAt = false, 0

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
    local _, def = defOf(Inv.currentEquipment[w.slot])
    entries[#entries + 1] = {
      kind = 'weapon', slot = w.slot,
      label = def and def.label or w.label, icon = def and def.icon or nil,
      empty = def == nil,
    }
  end
  entries[#entries + 1] = { kind = 'unarmed', label = L('wheel_unarmed'), empty = false }
  -- 2. Objets utilisables du joueur (regroupés par type)
  local byDef, order = {}, {}
  local st = Inv.currentState
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
  if Inv.wheelOpen or Inv.isOpen then return end
  Inv.wheelOpen = true
  setWheelFocus(true)
  SendNUIMessage({ action = 'wheelOpen', entries = buildWheelEntries() })
  -- Rafraîchit le contenu (quantités à jour)
  local c = GetEntityCoords(PlayerPedId())
  TriggerServerEvent('pop_inventory:server:requestState', { x = c.x, y = c.y, z = c.z })
  SetTimeout(350, function()
    if Inv.wheelOpen then SendNUIMessage({ action = 'wheelUpdate', entries = buildWheelEntries() }) end
  end)
  CreateThread(function()
    while Inv.wheelOpen do
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
  if not Inv.wheelOpen then return end
  Inv.wheelOpen = false
  SendNUIMessage({ action = 'wheelClose' }) -- la NUI répond avec wheelPick
  setWheelFocus(false)
end

RegisterNUICallback('wheelPick', function(data, cb)
  cb('ok')
  if Inv.wheelOpen then -- choix au clic : on ferme ici
    Inv.wheelOpen = false
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
      local _, def = defOf(Inv.currentEquipment[e.slot])
      -- Déjà en main : on ne range pas (la roue sert à choisir)
      if def and def.weaponHash and GetSelectedPedWeapon(ped) == GetHashKey(def.weaponHash) then return end
      Inv.switchToWeaponSlot(e.slot)
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
  if Inv.isOpen or Inv.wheelOpen or IsNuiFocused() then return end
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
  if Inv.wheelOpen then
    closeWheel()
  elseif GetGameTimer() - tabDownAt < TAP_MAX_MS then
    Inv.toggleInventory()
  end
end, false)

RegisterKeyMapping('+pop_inventory_key', L('key_inventory'), 'keyboard', 'TAB')

CreateThread(function()
  -- Natives localisées : boucle obligatoirement par frame (DisableControlAction ne vaut que pour la frame courante)
  local Wait, HudWeaponWheelIgnoreSelection, DisableControlAction = Wait, HudWeaponWheelIgnoreSelection, DisableControlAction
  local HideHudAndRadarThisFrame, DisplayRadar = HideHudAndRadarThisFrame, DisplayRadar
  while true do
    Wait(0)
    -- La roue native de GTA est remplacée par la roue « maison » (TAB maintenu)
    HudWeaponWheelIgnoreSelection()
    DisableControlAction(0, 37, true)

    if Inv.isOpen then
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
