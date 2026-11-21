-- =====================================================================
--  PISTOLET A PEINTURE  -  Client (integre a pop_inventory)
--  - Selecteur de couleur via la NUI de l'inventaire (paint_picker.js)
--  - Detection de l'arme equipee + lecture du reservoir/couleur
--  - Jet de peinture colore qui sort de la buse
--  - Couleur du vehicule qui apparait progressivement
-- =====================================================================

local weaponHash = GetHashKey(PaintGun.WeaponHash)

-- itemId du pistolet en cours de configuration (passe a la NUI).
local configItemId = nil

-- Etat du pistolet actuellement equipe (pousse par le serveur).
local gun = nil -- { itemId, color, r, g, b, reservoir }

-- Suivi de la peinture en cours par vehicule.
local paintJobs = {} -- [veh] = { sr, sg, sb, progress }

-- Particule de jet active.
local jetHandle = nil

-- Drain a synchroniser avec le serveur.
local pendingDrain = 0.0
local lastDrainSync = 0

-- ------------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------------
local function notify(msg, kind)
  local badgeColor = "#3498db"
  local badge = "INFO"
  local icon = "fas fa-paint-roller"
  
  if kind == 'success' then
    badgeColor = "#2ecc71"
    badge = "SUCCÈS"
    icon = "fas fa-check-circle"
  elseif kind == 'error' then
    badgeColor = "#e74c3c"
    badge = "ERREUR"
    icon = "fas fa-exclamation-triangle"
  end

  exports["pop_notify"]:ShowNotify({
    title = "Pistolet à peinture",
    message = msg,
    icon = icon,
    badge = badge,
    badgeColor = badgeColor,
    duration = 5000
  })
end

local function rotationToDirection(rot)
  local z = math.rad(rot.z)
  local x = math.rad(rot.x)
  local num = math.abs(math.cos(x))
  return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function loadPtfxDict(dict)
  if HasNamedPtfxAssetLoaded(dict) then return true end
  RequestNamedPtfxAsset(dict)
  local t = GetGameTimer() + 3000
  while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < t do
    Wait(0)
  end
  return HasNamedPtfxAssetLoaded(dict)
end

-- Liste d'essais : spray paint GTA configure, puis fallbacks "core" garantis,
-- pour qu'un effet teinte s'affiche TOUJOURS, quel que soit le serveur.
local jetTries = {
  { dict = PaintGun.ParticleDict, name = PaintGun.ParticleName, scale = PaintGun.ParticleScale },
  { dict = 'core', name = 'ent_sht_steam', scale = 1.0 },
  { dict = 'core', name = 'ent_sht_water', scale = 1.0 },
}

-- ------------------------------------------------------------------
--  Selecteur de couleur (overlay NUI : paint_picker.js)
-- ------------------------------------------------------------------
RegisterNetEvent('vg_paint:client:openConfig', function(itemId, meta)
  configItemId = itemId

  local colors = {}
  for _, c in ipairs(PaintGun.Colors) do
    local cost = PaintGun.GetPotCost(c.r, c.g, c.b)
    colors[#colors + 1] = {
      index = c.index, name = c.name,
      r = c.r, g = c.g, b = c.b,
      cr = cost.rouge, cj = cost.jaune, cb = cost.bleu,
    }
  end

  -- Le sélecteur s'affiche DANS l'inventaire. S'il n'est pas ouvert, on l'ouvre
  -- (avec focus) sinon l'overlay reste bloqué sans focus -> écran figé.
  local ok, isOpen = pcall(function() return exports.pop_inventory:IsInventoryOpen() end)
  if not (ok and isOpen) then
    TriggerEvent('pop_inventory:client:openInventory')
    paintOpenedInventory = true -- on fermera nous-mêmes (sinon focus bloqué)
  else
    paintOpenedInventory = false
  end
  SendNUIMessage({ action = 'paintOpen', colors = colors })
end)

-- Si le pistolet a ouvert l'inventaire, on le referme à la fin du choix/fermeture
-- pour relâcher le focus (la caméra retourne au joueur).
local function closeIfPaintOpened()
  if paintOpenedInventory then
    paintOpenedInventory = false
    TriggerEvent('pop_inventory:client:forceClose')
  end
end

-- La NUI renvoie la couleur choisie
RegisterNUICallback('paintSelect', function(data, cb)
  if data and data.index ~= nil and configItemId ~= nil then
    TriggerServerEvent('vg_paint:server:selectColor', configItemId, data.index)
  else
  end
  closeIfPaintOpened()
  cb('ok')
end)

-- Fermeture de l'overlay sans choix
RegisterNUICallback('paintClose', function(data, cb)
  closeIfPaintOpened()
  cb('ok')
end)

-- ------------------------------------------------------------------
--  Synchro de l'etat du pistolet equipe
-- ------------------------------------------------------------------
RegisterNetEvent('vg_paint:client:syncState', function(state)
  gun = state
end)

-- ------------------------------------------------------------------
--  Detection de l'arme equipee -> demande l'etat au serveur
-- ------------------------------------------------------------------
CreateThread(function()
  local wasEquipped = false
  while true do
    Wait(500)
    local ped = PlayerPedId()
    local equipped = GetSelectedPedWeapon(ped) == weaponHash
    if equipped and not wasEquipped then
      -- Au degainage : chargeur VIDE le temps de l'anim de sortie d'arme -> aucune
      -- balle chambree, donc aucun coup au depart. Une fois l'arme sortie, on
      -- recharge le chargeur pour que le clic soit lu en continu (un chargeur vide
      -- forcerait un rechargement au lieu d'un tir maintenu -> spray jamais declenche).
      SetPedAmmo(ped, weaponHash, 100)
      SetAmmoInClip(ped, weaponHash, 0)
      CreateThread(function()
        Wait(500) -- laisse passer l'animation de degainage
        local p = PlayerPedId()
        if GetSelectedPedWeapon(p) == weaponHash then
          SetAmmoInClip(p, weaponHash, 100)
        end
      end)
      TriggerServerEvent('vg_paint:server:requestState')
    elseif not equipped and wasEquipped then
      gun = nil
    end
    wasEquipped = equipped
  end
end)

-- ------------------------------------------------------------------
--  Jet de peinture : demarre/arrete la particule coloree a la buse
-- ------------------------------------------------------------------
local function startJet(ped)
  if jetHandle then return end
  if not gun then return end
  local weaponObj = GetCurrentPedWeaponEntityIndex(ped)
  if weaponObj == 0 then return end
  local boneIndex = GetEntityBoneIndexByName(weaponObj, 'gun_muzzle')
  if boneIndex == -1 then boneIndex = 0 end

  for _, try in ipairs(jetTries) do
    if loadPtfxDict(try.dict) then
      UseParticleFxAsset(try.dict)
      local h = StartParticleFxLoopedOnEntityBone(
        try.name, weaponObj,
        0.0, 0.2, 0.0, 0.0, 90.0, 0.0,
        boneIndex, try.scale, false, false, false
      )
      if h and h ~= 0 and DoesParticleFxLoopedExist(h) then
        jetHandle = h
        SetParticleFxLoopedColour(jetHandle, gun.r / 255.0, gun.g / 255.0, gun.b / 255.0, false)
        SetParticleFxLoopedAlpha(jetHandle, 1.0)
        return
      end
      if h and h ~= 0 then StopParticleFxLooped(h, 0) end
    end
  end
end

local function stopJet()
  if jetHandle then
    StopParticleFxLooped(jetHandle, 0)
    jetHandle = nil
  end
end

-- ------------------------------------------------------------------
--  Application progressive de la couleur sur le vehicule vise
-- ------------------------------------------------------------------
local function captureStartColor(veh)
  if GetIsVehiclePrimaryColourCustom(veh) then
    local r, g, b = GetVehicleCustomPrimaryColour(veh)
    return r, g, b
  end
  local p = GetVehicleColours(veh)
  local c = PaintGun.ColorByIndex[p]
  if c then return c.r, c.g, c.b end
  return 120, 120, 120
end

local function paintVehicle(veh, dt)
  local job = paintJobs[veh]
  -- Nouveau job si aucun en cours OU si la couleur du pistolet a change (nouvelle
  -- couche) : on repart de la couleur actuelle du vehicule vers la nouvelle teinte.
  if not job or job.targetColor ~= gun.color then
    local sr, sg, sb = captureStartColor(veh)
    job = { sr = sr, sg = sg, sb = sb, progress = 0.0, targetColor = gun.color }
    paintJobs[veh] = job
    NetworkRequestControlOfEntity(veh)
  end

  if job.progress >= 100.0 then return 0.0 end

  -- Demande de controle reseau (au cas ou un autre client soit owner).
  if not NetworkHasControlOfEntity(veh) then
    NetworkRequestControlOfEntity(veh)
  end

  local before = job.progress
  job.progress = math.min(100.0, job.progress + PaintGun.PaintRatePerSec * dt)
  local delta = job.progress - before

  local t = job.progress / 100.0
  local r = math.floor(job.sr + (gun.r - job.sr) * t + 0.5)
  local g = math.floor(job.sg + (gun.g - job.sg) * t + 0.5)
  local b = math.floor(job.sb + (gun.b - job.sb) * t + 0.5)

  SetVehicleModKit(veh, 0)
  SetVehicleCustomPrimaryColour(veh, r, g, b)
  SetVehicleCustomSecondaryColour(veh, r, g, b)

  -- Finition authentique GTA une fois la couleur "remplie".
  if job.progress >= 100.0 and gun.color then
    SetVehicleColours(veh, gun.color, gun.color)
    local colorName = PaintGun.ColorByIndex[gun.color] and PaintGun.ColorByIndex[gun.color].name or "peinture"
    notify(('Véhicule entièrement repeint en <span style="color:#f2b4d9; font-weight:bold;">%s</span>.'):format(colorName), 'success')
  end

  return delta -- = conso de reservoir (1 point de % = 1 unite)
end

-- ------------------------------------------------------------------
--  Boucle principale de spray
-- ------------------------------------------------------------------
CreateThread(function()
  while true do
    local ped = PlayerPedId()
    local equipped = GetSelectedPedWeapon(ped) == weaponHash

    if equipped then
      -- L'arme garde des munitions (sinon elle se range et le clic n'est plus lu),
      -- mais on bloque TOUT tir : DisablePlayerFiring + desactivation du controle
      -- d'attaque. Le clic est lu via IsDisabledControlPressed. Le coup de degainage
      -- est evite par le chargeur vide pose a l'equipement.
      DisablePlayerFiring(PlayerId(), true)
      DisableControlAction(0, 24, true)  -- Attaque / tir
      DisableControlAction(0, 257, true) -- Attaque 2
      DisableControlAction(0, 140, true) -- Coup leger
      DisableControlAction(0, 141, true)
      DisableControlAction(0, 142, true)

      local spraying = gun and IsDisabledControlPressed(0, 24) and (gun.reservoir or 0) > 0

      if spraying then
        startJet(ped)

        -- Raycast depuis la buse, dans la direction visee (camera).
        local weaponObj = GetCurrentPedWeaponEntityIndex(ped)
        local origin = GetEntityCoords(ped)
        if weaponObj ~= 0 then
          local mb = GetEntityBoneIndexByName(weaponObj, 'gun_muzzle')
          if mb ~= -1 then origin = GetWorldPositionOfEntityBone(weaponObj, mb) end
        end
        local dir = rotationToDirection(GetGameplayCamRot(2))
        local dest = origin + dir * PaintGun.SprayRange

        local ray = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, dest.x, dest.y, dest.z, 2, ped, 7)
        local _, hit, _, _, entityHit = GetShapeTestResult(ray)

        if hit == 1 and entityHit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
          local dt = GetFrameTime()
          local used = paintVehicle(entityHit, dt)
          if used > 0 then
            gun.reservoir = math.max(0.0, (gun.reservoir or 0) - used)
            pendingDrain = pendingDrain + used
          end
        end

        -- Synchro periodique du drain vers le serveur.
        if pendingDrain > 0 and (GetGameTimer() - lastDrainSync) > 800 then
          TriggerServerEvent('vg_paint:server:drain', gun.itemId, pendingDrain)
          pendingDrain = 0.0
          lastDrainSync = GetGameTimer()
        end
      else
        stopJet()
        -- Flush du drain restant quand on arrete de pulveriser.
        if pendingDrain > 0 then
          TriggerServerEvent('vg_paint:server:drain', gun.itemId, pendingDrain)
          pendingDrain = 0.0
          lastDrainSync = GetGameTimer()
        end
      end

      Wait(0)
    else
      stopJet()
      -- Boucle serree seulement si le joueur possede l'arme : des qu'on equipe,
      -- DisablePlayerFiring s'applique immediatement -> aucun coup au tout debut.
      -- Sans l'arme sur soi, inutile de tourner chaque frame.
      if HasPedGotWeapon(ped, weaponHash, false) then
        Wait(0)
      else
        Wait(500)
      end
    end
  end
end)

-- Nettoyage des jobs termines de temps en temps (vehicules supprimes).
CreateThread(function()
  while true do
    Wait(10000)
    for veh in pairs(paintJobs) do
      if not DoesEntityExist(veh) then paintJobs[veh] = nil end
    end
  end
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then stopJet() end
end)
