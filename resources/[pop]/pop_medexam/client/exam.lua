-- pop_medexam : examen des blessures (exécuté par l'EMS).

local examining = false

local function hasEmsJob()
  if Config.DevMode then return true end
  local job = Bridge.GetJob()
  return job ~= nil and Config.EmsJobs[job.name] == true
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
    Bridge.Notify(L('invalid_target'))
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

      -- Données live (relit le statebag au cas où ça change)
      data = Player(serverId).state.medInjuries or data or {}

      do
        local parts = {}
        for i = 1, #bodyParts do
          local def = bodyParts[i]
          local coords = GetPedBoneCoords(targetPed, def.boneTag, 0.0, 0.0, 0.0)
          local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
          local hp = data[def.key]
          if hp == nil then hp = 100 end
          parts[#parts + 1] = {
            key      = def.key,
            label    = L('part_' .. def.key),
            hp       = hp,
            severity = partColor(hp),
            onScreen = onScreen,
            x        = sx,
            y        = sy,
          }
        end

        SendNUIMessage({ action = 'update', parts = parts })
      end
      Wait(0)
      ::continue::
    end
    stopExam()
  end)
end

-- Cible sur tous les joueurs. ox_target direct : le bridge n'a pas encore d'équivalent
-- « tous les joueurs » (addGlobalPlayer).
CreateThread(function()
  exports.ox_target:addGlobalPlayer({
    {
      name        = 'pop_medexam_examine',
      icon        = 'fas fa-heart-pulse',
      label       = L('target_examine'),
      distance    = Config.TargetDistance,
      canInteract = function() return hasEmsJob() and not examining end,
      onSelect    = function(data)
        startExam(data.entity)
      end,
    },
    {
      name        = 'pop_medexam_treat',
      icon        = 'fas fa-briefcase-medical',
      label       = L('target_treat'),
      distance    = Config.TargetDistance,
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
  if res ~= GetCurrentResourceName() then return end
  stopExam()
  pcall(function() exports.ox_target:removeGlobalPlayer({ 'pop_medexam_examine', 'pop_medexam_treat' }) end)
end)
