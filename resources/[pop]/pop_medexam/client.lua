-- ════════════════════════════════════════════════════════════════════════
--  pop_medexam - Examen médical par zone du corps
-- ════════════════════════════════════════════════════════════════════════

local ESX = exports['es_extended']:getSharedObject()

-- ─────────────────────────────────────────────
-- 1. SUIVI DES BLESSURES (exécuté par tous les joueurs)
-- ─────────────────────────────────────────────

-- Santé par zone (0-100). Répliquée via statebag pour que l'EMS puisse la lire.
local function freshInjuries()
  return {
    head = 100, torso = 100,
    leftArm = 100, rightArm = 100,
    leftLeg = 100, rightLeg = 100,
  }
end

local injuries = freshInjuries()
local lastHealth = 200

local function syncInjuries()
  LocalPlayer.state:set('medInjuries', injuries, true)
end

local function resetInjuries()
  injuries = freshInjuries()
  lastHealth = GetEntityHealth(PlayerPedId())
  syncInjuries()
end

CreateThread(function()
  while not LocalPlayer.state do Wait(100) end
  lastHealth = GetEntityHealth(PlayerPedId())
  resetInjuries()
end)

-- Réinitialise les blessures à la réapparition / réanimation
RegisterNetEvent('esx:onPlayerSpawn', resetInjuries)
AddEventHandler('playerSpawned', resetInjuries)

-- Détection des dégâts -> attribution à une zone du corps
AddEventHandler('gameEventTriggered', function(name, args)
  if name ~= 'CEventNetworkEntityDamage' then return end

  local ped = PlayerPedId()
  local victim = args[1]
  if victim ~= ped then return end

  local curHealth = GetEntityHealth(ped)
  local dmg = lastHealth - curHealth
  lastHealth = curHealth
  if dmg <= 0 then return end

  local _, boneId = GetPedLastDamageBone(ped)
  local part = Config.BoneToPart[boneId] or 'torso'

  injuries[part] = math.max(0, math.floor((injuries[part] or 100) - dmg))
  syncInjuries()
end)

-- Soin reçu (déclenché par l'EMS via le serveur)
RegisterNetEvent('pop_medexam:treated', function(part)
  if part and injuries[part] ~= nil then
    injuries[part] = 100
  else
    injuries = freshInjuries()
  end
  syncInjuries()
end)

-- ─────────────────────────────────────────────
-- 2. EXAMEN (exécuté par l'EMS)
-- ─────────────────────────────────────────────

local examining = false

local function hasEmsJob()
  if Config.DevMode then return true end
  local pd = ESX.GetPlayerData()
  return pd and pd.job and Config.EmsJobs[pd.job.name] == true
end

local function partColor(hp)
  if hp <= 0 then return 'crit'
  elseif hp <= 35 then return 'high'
  elseif hp <= 70 then return 'med'
  else return 'low' end
end

local function stopExam()
  if not examining then return end
  examining = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function startExam(targetPed)
  if examining then return end
  if not DoesEntityExist(targetPed) then return end

  local targetPlayer = NetworkGetPlayerIndexFromPed(targetPed)
  if targetPlayer == -1 then
    ESX.ShowNotification('Cible invalide.')
    return
  end

  local serverId = GetPlayerServerId(targetPlayer)
  local data = Player(serverId).state.medInjuries

  examining = true
  SendNUIMessage({ action = 'open' })

  CreateThread(function()
    local myPed = PlayerPedId()
    local bodyParts = Config.BodyParts
    local lastSend = 0
    while examining do
      if not DoesEntityExist(targetPed) then break end

      local dist = #(GetEntityCoords(myPed) - GetEntityCoords(targetPed))
      if dist > Config.MaxExamDistance then break end

      if IsControlJustReleased(0, Config.CloseControl) then break end

      -- Touche de fermeture lue à chaque frame, affichage envoyé toutes les ~33 ms
      local now = GetGameTimer()
      if now - lastSend < 33 then Wait(0) goto continue end
      lastSend = now

      -- Données live (relit le statebag à chaque frame au cas où ça change)
      data = Player(serverId).state.medInjuries or data or {}

      local parts = {}
      for i = 1, #bodyParts do
        local def = bodyParts[i]
        local coords = GetPedBoneCoords(targetPed, def.boneTag, 0.0, 0.0, 0.0)
        local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
        local hp = data[def.key]
        if hp == nil then hp = 100 end
        parts[#parts + 1] = {
          key      = def.key,
          label    = def.label,
          hp       = hp,
          severity = partColor(hp),
          onScreen = onScreen,
          x        = sx,
          y        = sy,
        }
      end

      SendNUIMessage({ action = 'update', parts = parts })
      Wait(0)
      ::continue::
    end
    stopExam()
  end)
end

-- Cible ox_target sur les joueurs
CreateThread(function()
  exports.ox_target:addGlobalPlayer({
    {
      name        = 'tab_medexam_examine',
      icon        = 'fas fa-heart-pulse',
      label       = 'Examiner les blessures',
      distance    = 2.5,
      canInteract = function() return hasEmsJob() and not examining end,
      onSelect    = function(data)
        startExam(data.entity)
      end,
    },
    {
      name        = 'tab_medexam_treat',
      icon        = 'fas fa-briefcase-medical',
      label       = 'Soigner les blessures',
      distance    = 2.5,
      canInteract = function() return hasEmsJob() end,
      onSelect    = function(data)
        local tp = NetworkGetPlayerIndexFromPed(data.entity)
        if tp ~= -1 then
          TriggerServerEvent('pop_medexam:treat', GetPlayerServerId(tp))
        end
      end,
    },
  })
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then stopExam() end
end)
