-- pop_medexam : soin d'un joueur par l'EMS (part optionnel : soigne une seule zone).

RegisterNetEvent('pop_medexam:treat', function(targetId, part)
  local src = source

  -- Vérifie côté serveur que le soignant est bien EMS
  if not Config.DevMode then
    local job = Bridge.GetJob(src)
    if not job or not Config.EmsJobs[job.name] then return end
  end

  targetId = tonumber(targetId)
  if not targetId or not GetPlayerName(targetId) then return end
  if part ~= nil and type(part) ~= 'string' then return end

  -- Anti-abus : le soignant doit être à côté du patient.
  local targetCoords = Bridge.GetCoords(targetId)
  if not targetCoords or not Bridge.IsNear(src, targetCoords, Config.MaxTreatDistance) then return end

  if Config.Debug then print(('[pop_medexam] %s soigne %s (%s)'):format(src, targetId, part or 'tout')) end
  TriggerClientEvent('pop_medexam:treated', targetId, part)
end)
