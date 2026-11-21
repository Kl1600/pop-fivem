-- =====================================================================
--  LAMPE UV DE POCHE (uvpocketlight)  -  Client
--  - Clic droit (onUse) -> toggle ON/OFF
--  - DrawLightWithRangeAndShadow chaque frame depuis la position du ped
-- =====================================================================

local WEAPON_HASH = GetHashKey('WEAPON_POCKETLIGHT')
local COMP_UV     = GetHashKey('COMPONENT_PLIGHT_UV')
local COMP_WHITE  = GetHashKey('COMPONENT_PLIGHT_W')
local COMP_RED    = GetHashKey('COMPONENT_PLIGHT_RED')

local lightOn = false

-- ------------------------------------------------------------------
--  Notification
-- ------------------------------------------------------------------
local function notify(msg, kind)
  local badgeColor = kind == 'off' and '#555' or '#7b2fff'
  local icon = kind == 'off' and 'fas fa-moon' or 'fas fa-lightbulb'
  if GetResourceState('pop_notify') == 'started' then
    exports['pop_notify']:ShowNotify({
      title = 'Lampe UV', message = msg, icon = icon,
      badge = 'LAMPE UV', badgeColor = badgeColor, duration = 3000,
    })
  end
end

-- ------------------------------------------------------------------
--  Force le composant UV (retire blanc/rouge)
-- ------------------------------------------------------------------
local function applyUVComponent()
  local ped = PlayerPedId()
  if not HasPedGotWeapon(ped, WEAPON_HASH, false) then return end
  if HasPedGotWeaponComponent(ped, WEAPON_HASH, COMP_WHITE) then
    RemoveWeaponComponentFromPed(ped, WEAPON_HASH, COMP_WHITE)
  end
  if HasPedGotWeaponComponent(ped, WEAPON_HASH, COMP_RED) then
    RemoveWeaponComponentFromPed(ped, WEAPON_HASH, COMP_RED)
  end
  if not HasPedGotWeaponComponent(ped, WEAPON_HASH, COMP_UV) then
    GiveWeaponComponentToPed(ped, WEAPON_HASH, COMP_UV)
  end
end

-- ------------------------------------------------------------------
--  Toggle ON / OFF via clic droit (onUse)
-- ------------------------------------------------------------------
RegisterNetEvent('pop_inventory:client:toggleUVLight')
AddEventHandler('pop_inventory:client:toggleUVLight', function()
  local ped = PlayerPedId()
  if not HasPedGotWeapon(ped, WEAPON_HASH, false) then
    notify('Equipe la lampe UV d\'abord.')
    return
  end

  lightOn = not lightOn

  if lightOn then
    SetCurrentPedWeapon(ped, WEAPON_HASH, true)
    applyUVComponent()
    TriggerEvent('pop_uvlight:toggled', true)  -- notifie douilles_client
    notify('Lampe UV allumée.')
  else
    TriggerEvent('pop_uvlight:toggled', false) -- notifie douilles_client
    notify('Lampe UV éteinte.', 'off')
  end
end)

-- ------------------------------------------------------------------
--  Thread lumière UV dynamique — automatique quand l'arme est en main
-- ------------------------------------------------------------------
CreateThread(function()
  while true do
    local ped = PlayerPedId()

    -- Vérifie si l'arme ACTUELLE du joueur est la lampe UV ET qu'il vise (clic droit)
    if GetSelectedPedWeapon(ped) == WEAPON_HASH and IsControlPressed(0, 25) then
      if not lightOn then
        lightOn = true
        applyUVComponent()
        TriggerEvent('pop_uvlight:toggled', true)
      end

      -- Position de la main droite via GetPedBoneIndex + GetEntityBoneCoords
      local boneIdx = GetPedBoneIndex(ped, 57005) -- PH_R_Hand (right hand)
      local bonePos = GetWorldPositionOfEntityBone(ped, boneIdx)

      local x = bonePos.x
      local y = bonePos.y
      local z = bonePos.z + 0.05

      -- Lueur UV locale aux pieds du joueur (très faible)
      DrawLightWithRangeAndShadow(x, y, z, 90, 0, 255, 0.2, 10.0, 0.0)

      -- Faisceau directionnel (1.5m devant, diamètre de 1m)
      local fwd = GetEntityForwardVector(ped)
      DrawLightWithRangeAndShadow(
        x + fwd.x * 1.5,
        y + fwd.y * 1.5,
        z - 0.4,
        75, 0, 255, 0.5, 50.0, 0.0
      )

      Wait(0) -- chaque frame, obligatoire pour DrawLight
    else
      -- Si l'arme n'est pas en main ou si on ne vise pas, on s'assure de l'éteindre
      if lightOn then
        lightOn = false
        TriggerEvent('pop_uvlight:toggled', false)
      end
      -- Arme en main : réactivité au clic droit ; sinon pas besoin de vérifier souvent
      Wait(GetSelectedPedWeapon(ped) == WEAPON_HASH and 0 or 500)
    end
  end
end)

-- ------------------------------------------------------------------
--  Force UV component lors du rechargement de l'équipement
-- ------------------------------------------------------------------
RegisterNetEvent('pop_inventory:client:applyEquipment')
AddEventHandler('pop_inventory:client:applyEquipment', function(equipment)
  local hasLight = false
  for _, item in pairs(equipment or {}) do
    local defId = (type(item) == 'table' and item.defId) or item
    if defId == 'uvpocketlight' then hasLight = true; break end
  end

  if hasLight then
    CreateThread(function()
      Wait(350)
      applyUVComponent()
    end)
  else
    lightOn = false -- éteindre si item retiré
  end
end)

-- ------------------------------------------------------------------
--  Recharge resource
-- ------------------------------------------------------------------
AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  CreateThread(function()
    Wait(2000)
    applyUVComponent()
  end)
end)

exports('isUVLightOn', function() return lightOn end)

