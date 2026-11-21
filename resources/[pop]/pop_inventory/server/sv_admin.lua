lastBroadcastTime = 0
isBroadcasting = false
function broadcastGroundDrops()
  if isBroadcasting then return end
  local now = GetGameTimer()
  if now - lastBroadcastTime < 2500 then return end -- Échelonnage à 2.5s pour soulager le réseau
  
  isBroadcasting = true
  lastBroadcastTime = now

  -- Obtenir le snapshot depuis le cache
  if not CachedGroundSnapshot or groundDirty then
      CachedGroundSnapshot = getGroundDropSnapshot()
  end
  
  local drops = CachedGroundSnapshot
  local players = GetPlayers()
  
  -- Diffusion échelonnée (Staggered) pour éviter les micro-freezes
  CreateThread(function()
      for i=1, #players do
          local src = tonumber(players[i])
          if DoesPlayerExist(src) then
              local pCoords = getPlayerCoords(src)
              
              if pCoords then
                  local filteredDrops = {}
                  for j=1, #drops do
                      local drop = drops[j]
                      -- Fast Distance Squared check
                      local dx = pCoords.x - drop.coords.x
                      local dy = pCoords.y - drop.coords.y
                      local distSquared = (dx*dx) + (dy*dy)
                      
                      if distSquared < 10000.0 then -- 100m range suffit largement
                          table.insert(filteredDrops, drop)
                      end
                  end
                  
                  TriggerClientEvent('pop_inventory:client:updateGroundDrops', src, filteredDrops)
              end
          end
          
          -- Pause de 20ms tous les 5 joueurs pour étaler la charge CPU
          if i % 5 == 0 then Wait(20) end
      end
      isBroadcasting = false
  end)

  return drops
end

-- =============================================
--  ADMIN : Sélecteur d'items (permission ACE: pop_inventory.admin)
-- =============================================
function isAdminAllowed(src)
  if src == 0 then return true end
  -- 1) Liste configurée dans config.lua (Config.AdminIdentifiers)
  if type(Config.AdminIdentifiers) == 'table' and #Config.AdminIdentifiers > 0 then
    local lookup = {}
    for _, ident in ipairs(Config.AdminIdentifiers) do
      lookup[string.lower(tostring(ident))] = true
    end
    local ids = GetPlayerIdentifiers(src) or {}
    for _, id in ipairs(ids) do
      if lookup[string.lower(id)] then return true end
    end
  end
  -- 2) ACE permission en fallback
  if IsPlayerAceAllowed(src, 'pop_inventory.admin') == true then return true end
  -- 3) Délégation à pop_admin : tout admin du menu (groupe ESX, ACE ou identifiant
  --    listé dans pop_admin) obtient aussi l'accès au sélecteur d'items.
  if GetResourceState('pop_admin') == 'started' then
    local ok, allowed = pcall(function() return exports['pop_admin']:IsAdmin(src) end)
    if ok and allowed == true then return true end
  end
  return false
end

function buildAdminItemsList()
  local list = {}
  if type(Config.Items) ~= 'table' then return list end
  for id, def in pairs(Config.Items) do
    list[#list + 1] = {
      id = id,
      label = (type(def) == 'table' and def.label) or id,
      icon = (type(def) == 'table' and def.icon) or '',
      tags = (type(def) == 'table' and def.tags) or {},
    }
  end
  table.sort(list, function(a, b)
    return (a.label or ''):lower() < (b.label or ''):lower()
  end)
  return list
end

RegisterNetEvent('pop_inventory:server:adminCheck', function()
  local src = source
  local allowed = isAdminAllowed(src)
  TriggerClientEvent('pop_inventory:client:setAdminAllowed', src, allowed)
  if allowed then
    local list = buildAdminItemsList()
    TriggerClientEvent('pop_inventory:client:setAdminItems', src, list)
  end
end)

RegisterNetEvent('pop_inventory:server:adminRequestItems', function()
  local src = source
  if not isAdminAllowed(src) then return end
  TriggerClientEvent('pop_inventory:client:setAdminItems', src, buildAdminItemsList())
end)

RegisterNetEvent('pop_inventory:server:adminGiveItem', function(itemId, qty, meta)
  local src = source
  if not isAdminAllowed(src) then
    print(('[TAB_INVENTORY] adminGiveItem refusé: src=%s id=%s'):format(tostring(src), tostring(itemId)))
    return
  end
  if type(itemId) ~= 'string' or itemId == '' then return end
  qty = tonumber(qty) or 1
  if qty < 1 then qty = 1 end
  if qty > 1000 then qty = 1000 end
  if type(meta) ~= 'table' then meta = nil end

  local ok, err = GiveItem(src, itemId, qty, meta)
  print(('[TAB_INVENTORY] adminGiveItem src=%s id=%s qty=%d meta=%s ok=%s err=%s')
    :format(tostring(src), tostring(itemId), qty, meta and json.encode(meta) or 'nil', tostring(ok), tostring(err)))
end)

function sendUpdatedJobsList(src)

  if not MySQL then
    print('[TAB_INVENTORY] MySQL nil, envoi liste vide')
    TriggerClientEvent('pop_inventory:client:setAdminJobs', src, {})
    return
  end

  -- Forme callback (MySQL.query au lieu de MySQL.query.await pour eviter les soucis de yielding).
  MySQL.query("SELECT name, label FROM jobs ORDER BY label ASC", {}, function(dbJobs)
    local formattedJobs = {}
    local jobsByName = {}

    if type(dbJobs) == 'table' then
      for i = 1, #dbJobs do
        local row = dbJobs[i]
        if row and row.name then
          local jobData = {
            name  = tostring(row.name),
            label = tostring(row.label or row.name),
            grades = {}
          }
          formattedJobs[#formattedJobs + 1] = jobData
          jobsByName[tostring(row.name)] = jobData
        end
      end
    end

    MySQL.query("SELECT job_name, grade, label, name FROM job_grades ORDER BY grade ASC", {}, function(dbGrades)
      if type(dbGrades) == 'table' then
        for i = 1, #dbGrades do
          local row = dbGrades[i]
          if row and row.job_name then
            local owner = jobsByName[tostring(row.job_name)]
            local gradeNum = tonumber(row.grade)
            if owner and gradeNum then
              owner.grades[#owner.grades + 1] = {
                grade = gradeNum,
                label = tostring(row.label or row.name or gradeNum)
              }
            end
          end
        end
      end

      TriggerClientEvent('pop_inventory:client:setAdminJobs', src, formattedJobs)
    end)
  end)
end

RegisterNetEvent('pop_inventory:server:adminRequestJobs', function()
    local src = source
    if not isAdminAllowed(src) then return end
    -- Pas de checkRequiredTables / autoRepair / RefreshJobs ici : ces appels en
    -- cascade pouvaient bloquer la chaîne. sendUpdatedJobsList lit directement
    -- la DB et s'occupe de tout.
    sendUpdatedJobsList(src)
end)

RegisterNetEvent('pop_inventory:server:adminSetJob', function(jobName, grade)
    local src = source
    if not isAdminAllowed(src) then return end

    if Config.Framework == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.setJob(jobName, grade)
            notify(src, "Job défini sur : " .. jobName .. " (Grade: " .. tostring(grade) .. ")")
        end
    end
end)

RegisterNetEvent('pop_inventory:server:adminSetWeather', function(weather)
    local src = source
    if not isAdminAllowed(src) then return end
    TriggerClientEvent('pop_inventory:client:syncWeather', -1, weather)
    notify(src, "Météo changée en : " .. tostring(weather))
end)

-- ===== EASYTIME : heure imposée (onglet Météo admin) =====
-- État courant conservé pour rester cohérent entre réglage d'heure et gel,
-- et pour resynchroniser les joueurs qui se connectent ensuite.
local adminTimeState = { hour = 12, minute = 0, frozen = true }

RegisterNetEvent('pop_inventory:server:adminSetTime', function(hour, minute)
    local src = source
    if not isAdminAllowed(src) then return end
    hour = math.floor(tonumber(hour) or 0) % 24
    minute = math.floor(tonumber(minute) or 0) % 60
    adminTimeState.hour = hour
    adminTimeState.minute = minute
    adminTimeState.frozen = true -- régler une heure la fige
    TriggerClientEvent('pop_inventory:client:syncTime', -1, hour, minute, true)
    notify(src, ("Heure réglée sur %02d:%02d"):format(hour, minute))
end)

RegisterNetEvent('pop_inventory:server:adminFreezeTime', function(frozen)
    local src = source
    if not isAdminAllowed(src) then return end
    adminTimeState.frozen = (frozen ~= false)
    TriggerClientEvent('pop_inventory:client:syncTime', -1, adminTimeState.hour, adminTimeState.minute, adminTimeState.frozen)
    notify(src, adminTimeState.frozen and "Temps figé" or "Temps réel")
end)

-- Resync d'un client qui démarre (demande explicite, fiable).
RegisterNetEvent('pop_inventory:server:requestAdminTime', function()
    local src = source
    if adminTimeState.frozen then
        TriggerClientEvent('pop_inventory:client:syncTime', src, adminTimeState.hour, adminTimeState.minute, true)
    end
end)

RegisterNetEvent('pop_inventory:server:adminDumpSchema', function()
    local src = source
    if not isAdminAllowed(src) then return end
    if not MySQL then return end
    local function send(msg)
        print('[TAB_INVENTORY][SCHEMA] ' .. msg)
        TriggerClientEvent('pop_inventory:client:debugPrint', src, 'SCHEMA ' .. msg)
    end
    MySQL.query("SHOW COLUMNS FROM job_grades", {}, function(cols)
        if type(cols) ~= 'table' then send('job_grades : lecture impossible'); return end
        send(('job_grades a %d colonnes :'):format(#cols))
        for i = 1, #cols do
            local c = cols[i]
            send(('  - %s | type=%s | null=%s | default=%s | extra=%s'):format(
                tostring(c.Field), tostring(c.Type), tostring(c.Null), tostring(c.Default), tostring(c.Extra)
            ))
        end
    end)
    MySQL.query("SHOW COLUMNS FROM jobs", {}, function(cols)
        if type(cols) ~= 'table' then return end
        send(('jobs a %d colonnes :'):format(#cols))
        for i = 1, #cols do
            local c = cols[i]
            send(('  - %s | type=%s | null=%s | default=%s | extra=%s'):format(
                tostring(c.Field), tostring(c.Type), tostring(c.Null), tostring(c.Default), tostring(c.Extra)
            ))
        end
    end)
end)

RegisterNetEvent('pop_inventory:server:adminCreateJob', function(jobName, jobLabel)
    local src = source
    if not isAdminAllowed(src) then return end

    if type(jobName) ~= 'string' or jobName == '' or type(jobLabel) ~= 'string' or jobLabel == '' then return end
    jobName = jobName:gsub('%s+', ''):lower()

    if Config.Framework ~= 'esx' or not ESX then
        notify(src, "Incompatible avec ce framework")
        return
    end
    if not MySQL then
        notify(src, "MySQL indisponible")
        return
    end

    local function dbg(msg)
        print('[TAB_INVENTORY] ' .. msg)
        TriggerClientEvent('pop_inventory:client:debugPrint', src, msg)
    end
    dbg(('adminCreateJob START name=%s label=%s'):format(jobName, jobLabel))

    -- INSERT IGNORE pour eviter les soucis de ON DUPLICATE KEY UPDATE selon les versions MySQL/MariaDB.
    MySQL.update(
        'INSERT IGNORE INTO jobs (name, label) VALUES (?, ?)',
        { jobName, jobLabel },
        function(rowsJob)
            dbg(('INSERT jobs %s -> affectedRows=%s'):format(jobName, tostring(rowsJob)))

            MySQL.update(
                "INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES (?, 0, 'recrue', 'Recrue', 100)",
                { jobName },
                function(rowsG0)
                    dbg(('INSERT grade 0 (Recrue) %s -> affectedRows=%s'):format(jobName, tostring(rowsG0)))

                    MySQL.update(
                        "INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES (?, 4, 'boss', 'Patron', 1000)",
                        { jobName },
                        function(rowsG4)
                            dbg(('INSERT grade 4 (Patron) %s -> affectedRows=%s'):format(jobName, tostring(rowsG4)))

                            local accountName = 'society_' .. jobName
                            MySQL.update('INSERT IGNORE INTO addon_account (name, label, shared) VALUES (?, ?, 1)', { accountName, jobLabel }, function(rowsA)
                                dbg(('INSERT addon_account %s -> affectedRows=%s'):format(accountName, tostring(rowsA)))
                            end)
                            MySQL.update('INSERT IGNORE INTO addon_account_data (account_name, money, owner) VALUES (?, 0, NULL)', { accountName }, function(rowsAD)
                                dbg(('INSERT addon_account_data %s -> affectedRows=%s'):format(accountName, tostring(rowsAD)))
                            end)

                            -- Injection en mémoire ESX
                            if ESX.Jobs then
                                ESX.Jobs[jobName] = ESX.Jobs[jobName] or { label = jobLabel, grades = {} }
                                ESX.Jobs[jobName].label = jobLabel
                                ESX.Jobs[jobName].grades = ESX.Jobs[jobName].grades or {}
                                ESX.Jobs[jobName].grades['0'] = { job_name = jobName, grade = 0, name = 'recrue', label = 'Recrue', salary = 100, skin_male = {}, skin_female = {} }
                                ESX.Jobs[jobName].grades['4'] = { job_name = jobName, grade = 4, name = 'boss',   label = 'Patron', salary = 1000, skin_male = {}, skin_female = {} }
                            end

                            -- Refresh ESX puis envoi liste
                            if type(ESX.RefreshJobs) == 'function' then
                                pcall(ESX.RefreshJobs)
                            end

                            notify(src, "Job cree : " .. jobLabel .. " (" .. jobName .. ")")
                            dbg('adminCreateJob DONE: ' .. jobName)
                            sendUpdatedJobsList(src)
                        end
                    )
                end
            )
        end
    )
end)

RegisterNetEvent('pop_inventory:server:adminAddGrade', function(jobName, gradeLevel, gradeName, gradeLabel, salary)
    local src = source
    if not isAdminAllowed(src) then return end

    if type(jobName) ~= 'string' or jobName == '' then return end
    gradeLevel = tonumber(gradeLevel) or 0
    salary = tonumber(salary) or 0
    if type(gradeName) ~= 'string' or gradeName == '' or type(gradeLabel) ~= 'string' or gradeLabel == '' then return end

    if Config.Framework ~= 'esx' or not ESX then
        notify(src, "Incompatible avec ce framework")
        return
    end
    if not MySQL then
        notify(src, "MySQL indisponible")
        return
    end

    local function dbg(msg)
        print('[TAB_INVENTORY] ' .. msg)
        TriggerClientEvent('pop_inventory:client:debugPrint', src, msg)
    end
    dbg(('adminAddGrade START job=%s lvl=%s name=%s label=%s salary=%s'):format(jobName, tostring(gradeLevel), gradeName, gradeLabel, tostring(salary)))

    -- Strategie : DELETE existant + INSERT. On wrappe chaque call dans pcall et on
    -- ajoute un timeout de 3s pour ne PAS mourir si oxmysql ne fire jamais son callback
    -- (cas SQL error silencieuse).
    local function safeUpdate(query, params, label, cb)
        dbg(('SQL > ' .. label))
        local called = false
        local function once(rows, suffix)
            if called then return end
            called = true
            dbg(('SQL < %s affectedRows=%s%s'):format(label, tostring(rows), suffix or ''))
            if cb then cb(rows or 0) end
        end
        local ok, err = pcall(function()
            MySQL.update(query, params, function(affectedRows)
                once(affectedRows)
            end)
        end)
        if not ok then
            dbg(('SQL ! %s pcall ERROR: %s'):format(label, tostring(err)))
            once(0, ' (pcall err)')
            return
        end
        -- Timeout 3s
        SetTimeout(3000, function()
            if not called then
                dbg(('SQL ! %s TIMEOUT (callback jamais appele - SQL probablement en erreur cote serveur)'):format(label))
                once(0, ' (timeout)')
            end
        end)
    end

    safeUpdate(
        "DELETE FROM job_grades WHERE job_name = ? AND grade = ?",
        { jobName, gradeLevel },
        "DELETE existant",
        function(rowsDel)
            -- INSERT minimal : juste les colonnes ESX cœur. Si skin_male/skin_female sont
            -- NOT NULL sans default dans la table, faudra ajouter une migration. Pour l'instant
            -- on tente sans, plus tolerant.
            safeUpdate(
                "INSERT INTO job_grades (job_name, grade, name, label, salary) VALUES (?, ?, ?, ?, ?)",
                { jobName, gradeLevel, gradeName, gradeLabel, salary },
                "INSERT grade (minimal)",
                function(rowsIns)
                    if ESX.Jobs and ESX.Jobs[jobName] then
                        ESX.Jobs[jobName].grades = ESX.Jobs[jobName].grades or {}
                        ESX.Jobs[jobName].grades[tostring(gradeLevel)] = {
                            job_name = jobName, grade = gradeLevel, name = gradeName,
                            label = gradeLabel, salary = salary, skin_male = {}, skin_female = {}
                        }
                    end

                    if type(ESX.RefreshJobs) == 'function' then
                        pcall(ESX.RefreshJobs)
                    end

                    notify(src, "Grade ajoute : " .. gradeLabel .. " (" .. tostring(gradeLevel) .. ")")
                    dbg('adminAddGrade DONE: ' .. jobName .. ' | Level: ' .. tostring(gradeLevel))
                    sendUpdatedJobsList(src)
                end
            )
        end
    )
end)

RegisterNetEvent('pop_inventory:server:adminAddSocietyMoney', function(jobName, amount)
    local src = source
    if not isAdminAllowed(src) then return end

    if type(jobName) ~= 'string' or jobName == '' then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    if Config.Framework == 'esx' and ESX then
        checkRequiredTables(function()
            local accountName = 'society_' .. jobName
            local success = false
            
            -- Try esx_addonaccount shared account retrieval
            TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
                if account then
                    account.addMoney(amount)
                    success = true
                end
            end)
            
            -- Fallback: If not found or not active in memory, update DB directly
            if not success then
                if hasAddonAccountDataTable then
                    mysqlUpdate('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, NULL) ON DUPLICATE KEY UPDATE money = money + ?', 
                    {accountName, amount, amount}, function(affectedRows)
                        notify(src, "Montant de " .. tostring(amount) .. "$ ajouté au compte " .. accountName .. " (Database)")
                    end)
                else
                    notify(src, "Erreur : La table 'addon_account_data' est introuvable")
                end
            else
                notify(src, "Montant de " .. tostring(amount) .. "$ ajouté au compte " .. accountName)
            end
            print('[TAB_INVENTORY] Dynamic Society Account Funded: ' .. accountName .. ' | Amount: ' .. tostring(amount))
        end)
    else
        notify(src, "Incompatible avec ce framework")
    end
end)

RegisterNetEvent('pop_inventory:server:adminDeleteJob', function(jobName)
    local src = source
    if not isAdminAllowed(src) then return end
    if type(jobName) ~= 'string' or jobName == '' then return end
    jobName = jobName:lower()

    if jobName == 'unemployed' then
        notify(src, "Le job 'unemployed' ne peut pas etre supprime")
        return
    end

    if Config.Framework ~= 'esx' or not ESX then
        notify(src, "Incompatible avec ce framework")
        return
    end
    if not MySQL then
        notify(src, "MySQL indisponible")
        return
    end

    print(('[TAB_INVENTORY] adminDeleteJob START job=%s src=%s'):format(jobName, tostring(src)))
    local accountName = 'society_' .. jobName

    -- Chain de callbacks séquentiels
    MySQL.update("UPDATE users SET job = 'unemployed', job_grade = 0 WHERE job = ?", { jobName }, function(rR1)
        print(('[TAB_INVENTORY] adminDeleteJob: UPDATE users job -> affectedRows=%s'):format(tostring(rR1)))
        MySQL.update("UPDATE users SET job2 = 'unemployed', job2_grade = 0 WHERE job2 = ?", { jobName }, function(rR2)
            print(('[TAB_INVENTORY] adminDeleteJob: UPDATE users job2 -> affectedRows=%s'):format(tostring(rR2)))
            MySQL.update("DELETE FROM job_grades WHERE job_name = ?", { jobName }, function(rDG)
                print(('[TAB_INVENTORY] adminDeleteJob: DELETE job_grades -> affectedRows=%s'):format(tostring(rDG)))
                MySQL.update("DELETE FROM jobs WHERE name = ?", { jobName }, function(rDJ)
                    print(('[TAB_INVENTORY] adminDeleteJob: DELETE jobs -> affectedRows=%s'):format(tostring(rDJ)))
                    MySQL.update("DELETE FROM addon_account_data WHERE account_name = ?", { accountName }, function(rDAD)
                        print(('[TAB_INVENTORY] adminDeleteJob: DELETE addon_account_data -> affectedRows=%s'):format(tostring(rDAD)))
                        MySQL.update("DELETE FROM addon_account WHERE name = ?", { accountName }, function(rDA)
                            print(('[TAB_INVENTORY] adminDeleteJob: DELETE addon_account -> affectedRows=%s'):format(tostring(rDA)))

                            if ESX.Jobs then ESX.Jobs[jobName] = nil end

                            for _, playerId in ipairs(GetPlayers()) do
                                local xPlayer = ESX.GetPlayerFromId(tonumber(playerId))
                                if xPlayer then
                                    if xPlayer.job and xPlayer.job.name == jobName then
                                        pcall(function() xPlayer.setJob('unemployed', 0) end)
                                    end
                                    if xPlayer.job2 and xPlayer.job2.name == jobName and type(xPlayer.setJob2) == 'function' then
                                        pcall(function() xPlayer.setJob2('unemployed', 0) end)
                                    end
                                end
                            end

                            if type(ESX.RefreshJobs) == 'function' then
                                pcall(ESX.RefreshJobs)
                            end

                            notify(src, "Job supprime : " .. jobName)
                            print('[TAB_INVENTORY] adminDeleteJob DONE: ' .. jobName)
                            sendUpdatedJobsList(src)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

RegisterNetEvent('pop_inventory:server:adminDeleteVehicle', function(netId)
    local src = source
    if not isAdminAllowed(src) then return end
    if type(netId) ~= 'number' then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) and GetEntityType(veh) == 2 then
        DeleteEntity(veh)
        TriggerClientEvent('pop_inventory:client:adminDeleteVehicleResult', src, true)
    else
        TriggerClientEvent('pop_inventory:client:adminDeleteVehicleResult', src, false)
    end
end)
