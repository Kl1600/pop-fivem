function mysqlFetch(query, params)
  if not MySQL then
    return nil
  end
  local ok, result = pcall(MySQL.query.await, query, params)
  if not ok then
    print('[POP_INVENTORY] ^1MySQL fetch error:^7', result)
    return 'ERROR'
  end
  return result
end

hasAddonAccountTable = false
hasAddonAccountDataTable = false
hasJobsTable = false
hasJobGradesTable = false

function checkRequiredTables(cb)
  if not MySQL then
    if cb then cb() end
    return
  end

  CreateThread(function()
    local ok1 = pcall(function()
      MySQL.query.await("SELECT 1 FROM addon_account LIMIT 1")
    end)
    hasAddonAccountTable = ok1

    local ok2 = pcall(function()
      MySQL.query.await("SELECT 1 FROM addon_account_data LIMIT 1")
    end)
    hasAddonAccountDataTable = ok2

    local ok3 = pcall(function()
      MySQL.query.await("SELECT 1 FROM jobs LIMIT 1")
    end)
    hasJobsTable = ok3

    local ok4 = pcall(function()
      MySQL.query.await("SELECT 1 FROM job_grades LIMIT 1")
    end)
    hasJobGradesTable = ok4

    if Config.Debug then
      print(('[POP_INVENTORY] Verification base de donnees: addon_account=%s, addon_account_data=%s, jobs=%s, job_grades=%s'):format(
        tostring(hasAddonAccountTable),
        tostring(hasAddonAccountDataTable),
        tostring(hasJobsTable),
        tostring(hasJobGradesTable)
      ))
    end
    if cb then cb() end
  end)
end


function autoRepairMissingJobGrades(cb)
  if not MySQL or not hasJobsTable or not hasJobGradesTable then
    if cb then cb() end
    return
  end

  CreateThread(function()
    -- Fetch all jobs and all job grades
    local dbJobs = mysqlFetch("SELECT name FROM jobs", {})
    local dbGrades = mysqlFetch("SELECT job_name FROM job_grades", {})

    if dbJobs and dbJobs ~= 'ERROR' and type(dbJobs) == 'table' then
      local jobsWithGrades = {}
      if dbGrades and dbGrades ~= 'ERROR' and type(dbGrades) == 'table' then
        for _, grade in ipairs(dbGrades) do
          local jName = grade.job_name or ''
          if jName ~= '' then
            jobsWithGrades[jName] = true
          end
        end
      end

      local missingGradesJobs = {}
      for _, job in ipairs(dbJobs) do
        local jName = job.name or ''
        if jName ~= '' and not jobsWithGrades[jName] then
          table.insert(missingGradesJobs, jName)
        end
      end

      if #missingGradesJobs > 0 then
        if Config.Debug then print(('[POP_INVENTORY] Reparation de %d jobs sans grades...'):format(#missingGradesJobs)) end
        local completed = 0
        for _, jName in ipairs(missingGradesJobs) do
          mysqlUpdate("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, 0, 'recrue', 'Recrue', 100, '{}', '{}') ON DUPLICATE KEY UPDATE name = name", {jName}, function()
            completed = completed + 1
            if completed == #missingGradesJobs then
              if Config.Debug then print('[POP_INVENTORY] Reparation des grades terminee !') end
              if type(ESX.RefreshJobs) == 'function' then
                pcall(ESX.RefreshJobs)
              end
              if cb then cb() end
            end
          end)
        end
      else
        if cb then cb() end
      end
    else
      if cb then cb() end
    end
  end)
end

function mysqlSingle(query, params)
  if not MySQL then
    return nil
  end
  local ok, result = pcall(MySQL.single.await, query, params)
  if not ok then
    print('[POP_INVENTORY] ^1MySQL single error:^7', result)
    return 'ERROR'
  end
  return result
end

function mysqlUpdate(query, params, cb)
  if not MySQL then
    if cb then cb(nil) end
    return
  end
  -- Optimized: Non-blocking update to avoid server lag during DB slow downs
  MySQL.update(query, params, function(affectedRows)
    if cb then cb(affectedRows) end
  end)
end

function tableCount(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

function saveRemoteContainers()
  if not Config.Persistence.UseDatabase then return end
  local data = json.encode(RemoteContainers)
  mysqlUpdate("INSERT INTO " .. Config.Persistence.GroundTable .. " (id, data) VALUES ('remote_containers', ?) ON DUPLICATE KEY UPDATE data = ?", { data, data })
end


function loadRemoteContainers()
  if not Config.Persistence.UseDatabase then return end
  local results = mysqlFetch("SELECT data FROM " .. Config.Persistence.GroundTable .. " WHERE id = 'remote_containers'", {})
  if results and results[1] and results[1].data then
    local data = json.decode(results[1].data)
    if data then
      RemoteContainers = data
      if Config.Debug then print('[POP_INVENTORY] ' .. tableCount(RemoteContainers) .. ' conteneurs distants chargés.') end
    end
  end
end

-- Startup
CreateThread(function()
  Wait(1000)
  loadRemoteContainers()
end)

-- Diagnostic au demarrage (Config.Debug) : dump le schema de job_grades pour identifier
-- les colonnes NOT NULL qu'on doit obligatoirement renseigner.
CreateThread(function()
  Wait(2500)
  if not MySQL or not Config.Debug then return end
  MySQL.query("SHOW COLUMNS FROM job_grades", {}, function(cols)
    if type(cols) ~= 'table' then
      print('[POP_INVENTORY][SCHEMA] job_grades: impossible de lire les colonnes (' .. tostring(cols) .. ')')
      return
    end
    print('[POP_INVENTORY][SCHEMA] job_grades has ' .. #cols .. ' colonnes :')
    for i = 1, #cols do
      local c = cols[i]
      print(('  - %s | type=%s | null=%s | default=%s | extra=%s'):format(
        tostring(c.Field), tostring(c.Type), tostring(c.Null), tostring(c.Default), tostring(c.Extra)
      ))
    end
  end)
end)

-- Ancien « backfill » retiré : il ajoutait un grade 0 et un grade 4 à TOUS les
-- jobs à chaque démarrage (police, unemployed…). La création de job depuis
-- l'admin insère déjà ses propres grades.
