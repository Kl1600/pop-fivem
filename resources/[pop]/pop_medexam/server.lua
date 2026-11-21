local ESX = exports['es_extended']:getSharedObject()

-- Soin d'un joueur par l'EMS. (part optionnel : soigne une seule zone)
RegisterNetEvent('pop_medexam:treat', function(targetId, part)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)
  if not xPlayer then return end

  -- Vérifie côté serveur que le soignant est bien EMS
  if not Config.DevMode then
    local job = xPlayer.getJob().name
    if not Config.EmsJobs[job] then return end
  end

  targetId = tonumber(targetId)
  if not targetId or not GetPlayerName(targetId) then return end
  if part ~= nil and type(part) ~= 'string' then return end

  -- Anti-abus : le soignant doit être à côté du patient.
  local a, b = GetPlayerPed(src), GetPlayerPed(targetId)
  if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > 5.0 then return end

  TriggerClientEvent('pop_medexam:treated', targetId, part)
end)
