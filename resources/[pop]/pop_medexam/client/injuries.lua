-- pop_medexam : suivi des blessures par zone du corps (exécuté par tous les joueurs).
-- Santé par zone (0-100), répliquée via statebag pour que l'EMS puisse la lire.

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
