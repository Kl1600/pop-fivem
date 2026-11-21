function mysqlFetch(query, params)
  if not MySQL then
    return nil
  end
  local ok, result = pcall(MySQL.query.await, query, params)
  if not ok then
    print('[TAB_INVENTORY] ^1MySQL fetch error:^7', result)
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

    print(('[TAB_INVENTORY] Verification base de donnees: addon_account=%s, addon_account_data=%s, jobs=%s, job_grades=%s'):format(
      tostring(hasAddonAccountTable),
      tostring(hasAddonAccountDataTable),
      tostring(hasJobsTable),
      tostring(hasJobGradesTable)
    ))
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
        print(('[TAB_INVENTORY] Reparation de %d jobs sans grades...'):format(#missingGradesJobs))
        local completed = 0
        for _, jName in ipairs(missingGradesJobs) do
          mysqlUpdate("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, 0, 'recrue', 'Recrue', 100, '{}', '{}') ON DUPLICATE KEY UPDATE name = name", {jName}, function()
            completed = completed + 1
            if completed == #missingGradesJobs then
              print('[TAB_INVENTORY] Reparation des grades terminee !')
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
    print('[TAB_INVENTORY] ^1MySQL single error:^7', result)
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
      print('[TAB_INVENTORY] ' .. tableCount(RemoteContainers) .. ' conteneurs distants chargés.')
    end
  end
end

-- Startup
CreateThread(function()
  Wait(1000)
  loadRemoteContainers()
end)

-- Diagnostic au demarrage : dump le schema de job_grades pour identifier les colonnes
-- NOT NULL qu'on doit obligatoirement renseigner.
CreateThread(function()
  Wait(2500)
  if not MySQL then return end
  MySQL.query("SHOW COLUMNS FROM job_grades", {}, function(cols)
    if type(cols) ~= 'table' then
      print('[TAB_INVENTORY][SCHEMA] job_grades: impossible de lire les colonnes (' .. tostring(cols) .. ')')
      return
    end
    print('[TAB_INVENTORY][SCHEMA] job_grades has ' .. #cols .. ' colonnes :')
    for i = 1, #cols do
      local c = cols[i]
      print(('  - %s | type=%s | null=%s | default=%s | extra=%s'):format(
        tostring(c.Field), tostring(c.Type), tostring(c.Null), tostring(c.Default), tostring(c.Extra)
      ))
    end
  end)
end)

-- Backfill : s'assure que tous les jobs en DB ont au moins un grade 0 (Recrue) et un grade 4 (Boss).
-- Tourne une fois au démarrage du resource. Utilise la forme callback de MySQL.update.
CreateThread(function()
  Wait(3000) -- laisser MySQL/ESX se charger
  if not MySQL then print('[TAB_INVENTORY] Backfill grades : MySQL indispo'); return end

  MySQL.update([[
    INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female)
    SELECT j.name, 0, 'recrue', 'Recrue', 100, '{}', '{}'
    FROM jobs j
    WHERE NOT EXISTS (SELECT 1 FROM job_grades g WHERE g.job_name = j.name AND g.grade = 0)
  ]], {}, function(addedRecrue)
    print(('[TAB_INVENTORY] Backfill grades Recrue (grade 0) : affectedRows=%s'):format(tostring(addedRecrue)))

    MySQL.update([[
      INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female)
      SELECT j.name, 4, 'boss', 'Patron', 1000, '{}', '{}'
      FROM jobs j
      WHERE NOT EXISTS (SELECT 1 FROM job_grades g WHERE g.job_name = j.name AND g.grade = 4)
    ]], {}, function(addedBoss)
      print(('[TAB_INVENTORY] Backfill grades Boss (grade 4) : affectedRows=%s'):format(tostring(addedBoss)))
      if type(ESX) == 'table' and type(ESX.RefreshJobs) == 'function' then
        pcall(ESX.RefreshJobs)
      end
    end)
  end)
end)
