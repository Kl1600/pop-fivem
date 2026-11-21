local ESX = exports['es_extended']:getSharedObject()

-- ============================
-- ETAT
-- ============================
-- onDuty[src] = { job, grade, callsign, situation }
local onDuty = {}
local calls = {}
local nextCallId = 1
local globalOfficerStates = {} -- [NOUVEAU] Stocke les positions côté serveur pour contourner le culling OneSync
local globalAlertCounter = 0
local lastGunshotAlerts = {}
local lastExternalCalls = {}

local GetPlayerPed, GetEntityCoords, TriggerClientEvent = GetPlayerPed, GetEntityCoords, TriggerClientEvent

-- Coordonnées envoyées par le client : on ne garde que x/y/z numériques
local function sanitizeCoords(c)
  if type(c) ~= 'table' or type(c.x) ~= 'number' or type(c.y) ~= 'number' or type(c.z) ~= 'number' then return nil end
  return { x = c.x, y = c.y, z = c.z }
end

-- Le joueur est-il à moins de maxDist de ces coordonnées ? (OneSync)
local function isNear(src, c, maxDist)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return true end
  local pc = GetEntityCoords(ped)
  if pc.x == 0.0 and pc.y == 0.0 then return true end
  return #(pc - vector3(c.x, c.y, c.z)) <= maxDist
end

local function str(v, max)
  if v == nil then return '' end
  return tostring(v):sub(1, max)
end

-- wantedVehicles[id] = { id, plate, model, note }
local wantedVehicles = {}
-- wantedCitizens[id] = { id, name, reason, desc }
local wantedCitizens = {}

-- Création des tables SQL, nettoyage des patrouilles et chargement des avis de recherche au démarrage
-- Création des tables SQL, nettoyage des patrouilles et chargement des données au démarrage
MySQL.ready(function()
  local queries = {
    [[
      CREATE TABLE IF NOT EXISTS `tab_police_officers` (
        `identifier` varchar(64) NOT NULL,
        `job` varchar(32) NOT NULL,
        `firstname` varchar(64) DEFAULT NULL,
        `lastname` varchar(64) DEFAULT NULL,
        `grade` varchar(32) DEFAULT NULL,
        `matricule` varchar(8) DEFAULT '',
        `on_duty` tinyint(1) DEFAULT 0,
        PRIMARY KEY (`identifier`,`job`)
      );
    ]],
    [[
      CREATE TABLE IF NOT EXISTS `tab_police_patrols` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `job` varchar(32) NOT NULL,
        `callsign` varchar(32) DEFAULT NULL,
        `type` varchar(16) DEFAULT NULL,
        `sector` varchar(64) DEFAULT NULL,
        `radio` varchar(16) DEFAULT NULL,
        `leader_identifier` varchar(64) DEFAULT NULL,
        PRIMARY KEY (`id`)
      );
    ]],
    [[
      CREATE TABLE IF NOT EXISTS `tab_police_patrol_members` (
        `patrol_id` int(11) NOT NULL,
        `identifier` varchar(64) NOT NULL,
        UNIQUE KEY `unique_member` (`patrol_id`,`identifier`)
      );
    ]],
    [[
      CREATE TABLE IF NOT EXISTS `tab_wanted_vehicles` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `plate` varchar(16) DEFAULT NULL,
        `model` varchar(64) DEFAULT NULL,
        `note` text DEFAULT NULL,
        PRIMARY KEY (`id`)
      );
    ]],
    [[
      CREATE TABLE IF NOT EXISTS `tab_wanted_citizens` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `name` varchar(64) DEFAULT NULL,
        `reason` varchar(255) DEFAULT NULL,
        `desc` text DEFAULT NULL,
        PRIMARY KEY (`id`)
      );
    ]],
    -- [NOUVEAU] Table pour la persistance des notifications (Appels / Tirs)
    [[
      CREATE TABLE IF NOT EXISTS `tab_police_calls` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `level` int(11) DEFAULT 1,
        `label` varchar(64) DEFAULT NULL,
        `requesterName` varchar(64) DEFAULT NULL,
        `callsign` varchar(32) DEFAULT NULL,
        `patrol` longtext DEFAULT NULL,
        `coords` longtext DEFAULT NULL,
        `accepted` longtext DEFAULT NULL,
        `createdAt` bigint(20) DEFAULT NULL,
        `isGunshot` tinyint(1) DEFAULT 0,
        `allAssigned` tinyint(1) DEFAULT 0,
        PRIMARY KEY (`id`)
      );
    ]]
  }

  for _, query in ipairs(queries) do
    MySQL.query.await(query)
  end
  print('^2[pop_police] Tables SQL vérifiées/créées avec succès.^0')
  
  MySQL.query.await('DELETE FROM tab_police_patrols')
  MySQL.query.await('DELETE FROM tab_police_patrol_members')
  print('^3[pop_police] Patrouilles précédentes effacées.^0')

  -- Chargement des Avis de recherche
  local vRows = MySQL.query.await('SELECT * FROM tab_wanted_vehicles')
  if vRows then
    for _, r in ipairs(vRows) do
      wantedVehicles[tostring(r.id)] = { id = r.id, plate = r.plate, model = r.model, note = r.note }
    end
  end

  local cRows = MySQL.query.await('SELECT * FROM tab_wanted_citizens')
  if cRows then
    for _, r in ipairs(cRows) do
      wantedCitizens[tostring(r.id)] = { id = r.id, name = r.name, reason = r.reason, desc = r.desc }
    end
  end

  -- Nettoyage des appels de renforts classiques au redémarrage (on garde les tirs)
  MySQL.query.await('DELETE FROM tab_police_calls WHERE isGunshot = 0 OR isGunshot = false')

  -- [NOUVEAU] Chargement des Notifications persistantes
  local callRows = MySQL.query.await('SELECT * FROM tab_police_calls ORDER BY id ASC')
  if callRows then
    globalAlertCounter = 0
    for _, r in ipairs(callRows) do
      globalAlertCounter = globalAlertCounter + 1
      calls[r.id] = {
        id            = r.id,
        level         = r.level,
        label         = r.label,
        requesterName = r.requesterName,
        callsign      = r.callsign,
        patrol        = r.patrol and json.decode(r.patrol) or nil,
        coords        = r.coords and json.decode(r.coords) or nil,
        accepted      = r.accepted and json.decode(r.accepted) or {},
        createdAt     = r.createdAt,
        isGunshot     = r.isGunshot == 1 or r.isGunshot == true,
        allAssigned   = r.allAssigned == 1 or r.allAssigned == true,
        alertNum      = globalAlertCounter
      }
    end
    print("^2[pop_police] Chargé " .. #callRows .. " notifications en attente.^0")
  end
end)

local function isPoliceJob(job)
  if not job then return false end
  for _, j in ipairs(Config.PoliceJobs) do
    if job == j then return true end
  end
  return false
end

local function isPlayerAllowed(p)
  if Config.DevMode then return true end
  if not p then return false end
  local group = p.getGroup()
  if group == 'admin' or group == 'superadmin' then return true end
  return isPoliceJob(p.job and p.job.name)
end

local function getPoliceSources()
  local list = {}
  for src, _ in pairs(onDuty) do
    list[#list + 1] = src
  end
  return list
end

local function getAllUnits(targetJob, cb)
  local query = 'SELECT identifier, job, firstname, lastname, grade, matricule FROM tab_police_officers WHERE job = ?'
  local args = { targetJob }
  
  if Config.DevMode then
    query = 'SELECT identifier, job, firstname, lastname, grade, matricule FROM tab_police_officers'
    args = {}
  end

  exports.oxmysql:query(query, args, function(dbOfficers)
    local units = {}
    local usedIdentifiers = {}

    -- 1. Ajouter les agents en service (onDuty)
    for src, d in pairs(onDuty) do
      if Config.DevMode or d.job == targetJob then
        local p = ESX.GetPlayerFromId(src)
        if p then
          usedIdentifiers[p.identifier] = true
          units[#units + 1] = {
            src       = src,
            id        = src,
            name      = d.name or (p.getName and p.getName() or p.name),
            grade     = d.grade,
            callsign  = d.callsign,
            situation = d.situation,
            patrol    = d.patrol,
            matricule = d.matricule or '',
            duty      = true,
          }
        end
      end
    end

    -- 2. Ajouter les agents hors service (depuis la BDD)
    if dbOfficers then
      for _, row in ipairs(dbOfficers) do
        if not usedIdentifiers[row.identifier] then
          units[#units + 1] = {
            src       = row.identifier, -- utilise l'identifier pour les hors ligne
            id        = row.identifier,
            name      = (row.firstname or '') .. ' ' .. (row.lastname or ''),
            grade     = row.grade or '',
            callsign  = '',
            situation = '',
            patrol    = nil,
            matricule = row.matricule or '',
            duty      = false,
          }
          usedIdentifiers[row.identifier] = true
        end
      end
    end

    cb(units)
  end)
end

local function broadcastUnits(targetJob)
  getAllUnits(targetJob, function(units)
    for src, d in pairs(onDuty) do
      if Config.DevMode or d.job == targetJob then
        TriggerClientEvent('pop_police:units', src, units, #units)
      end
    end
  end)
end

local function broadcastCalls()
  local list = {}
  for _, c in pairs(calls) do
    list[#list + 1] = c
  end
  for _, src in ipairs(getPoliceSources()) do
    TriggerClientEvent('pop_police:calls', src, list)
  end
end

local function autoRemoveCalls(src, pId)
  local changed = false
  for cid, c in pairs(calls) do
    if (src and c.requesterSrc == src) or (pId and c.patrol and c.patrol.id == pId) then
      calls[cid] = nil
      exports.oxmysql:query('DELETE FROM tab_police_calls WHERE id = ?', { cid })
      for _, dst in ipairs(getPoliceSources()) do
        TriggerClientEvent('pop_police:callRemoved', dst, cid)
      end
      changed = true
    end
  end
  if changed then broadcastCalls() end
end

-- ============================
-- SYNCHRONISATION DES POSITIONS (Bypass OneSync)
-- ============================
RegisterNetEvent('pop_police:updatePos', function(pos)
  local src = source
  if not onDuty[src] or type(pos) ~= 'table' then return end
  if type(pos.x) ~= 'number' or type(pos.y) ~= 'number' or type(pos.z) ~= 'number' then return end
  local function num(v) return type(v) == 'number' and v or nil end
  globalOfficerStates[src] = {
    net = num(pos.net), kind = pos.kind == 'veh' and 'veh' or 'foot',
    pVehNet = num(pos.pVehNet),
    x = pos.x, y = pos.y, z = pos.z, h = num(pos.h),
    pVehX = num(pos.pVehX), pVehY = num(pos.pVehY), pVehZ = num(pos.pVehZ),
    hasRealVeh = pos.hasRealVeh == true,
    cs = type(pos.cs) == 'string' and pos.cs:sub(1, 32) or nil,
    mat = type(pos.mat) == 'string' and pos.mat:sub(1, 8) or nil,
  }
end)

CreateThread(function()
  while true do
    Wait(500)
    local pSrcs = getPoliceSources()
    if #pSrcs > 0 then
      for _, src in ipairs(pSrcs) do
        TriggerClientEvent('pop_police:syncPositions', src, globalOfficerStates)
      end
    end
  end
end)

-- ============================
-- PRISE DE SERVICE
-- ============================
RegisterNetEvent('pop_police:setDuty', function(state)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not p then return end
  if not isPlayerAllowed(p) then return end

  local job   = p.job.name
  local ident = p.identifier

  if state then
    local firstName = p.get('firstName') or ''
    local lastName  = p.get('lastName')  or ''
    -- Utiliser le grade réel ESX seulement si le joueur a vraiment un job police
    local actualJob = p.job and p.job.name or ''
    local isActualPolice = false
    for _, j in ipairs(Config.PoliceJobs) do
      if actualJob == j then isActualPolice = true; break end
    end
    local grade = isActualPolice and (p.job.grade_label or p.job.grade_name or '')
                  or (Config.DevMode and Config.DevGrade) or ''

    -- Récupérer le matricule sauvegardé (peu importe le job pour éviter les pertes)
    exports.oxmysql:query(
      'SELECT matricule FROM tab_police_officers WHERE identifier = ? AND matricule != "" LIMIT 1',
      { ident },
      function(rows)
        local mat = (rows and rows[1] and rows[1].matricule) or ''
        onDuty[src] = {
          job       = job,
          grade     = grade,
          callsign  = '#' .. src,
          situation = '10-8',
          matricule = mat,
          name      = firstName .. ' ' .. lastName
        }
        -- UPSERT profil agent
        exports.oxmysql:query(
          'INSERT INTO tab_police_officers (identifier, job, firstname, lastname, grade, on_duty) VALUES (?,?,?,?,?,1) '
          .. 'ON DUPLICATE KEY UPDATE firstname=VALUES(firstname), lastname=VALUES(lastname), grade=VALUES(grade), on_duty=1',
          { ident, job, firstName, lastName, grade }, function() end
        )
        -- Sync wanted list
        local vList = {}
        for _, v in pairs(wantedVehicles) do vList[#vList + 1] = v end
        local cList = {}
        for _, c in pairs(wantedCitizens) do cList[#cList + 1] = c end
        TriggerClientEvent('pop_police:syncWanted', src, vList, cList)
        TriggerClientEvent('pop_police:dutyState', src, true)
        TriggerClientEvent('pop_police:myProfile', src, { matricule = mat, grade = grade })
        broadcastUnits(job)
      end
    )
  else
    -- Nettoyer la patrouille si active
    local pId = onDuty[src] and onDuty[src].patrolId
    autoRemoveCalls(src, pId)
    if pId then
      exports.oxmysql:query('DELETE FROM tab_police_patrols WHERE id = ?', { pId }, function() end)
    end
    onDuty[src] = nil
    globalOfficerStates[src] = nil -- Nettoyage position
    -- Marquer hors service en BDD
    exports.oxmysql:query(
      'UPDATE tab_police_officers SET on_duty=0 WHERE identifier=? AND job=?',
      { ident, job }, function() end
    )
    TriggerClientEvent('pop_police:dutyState', src, false)
    broadcastUnits(job)
  end
end)

RegisterNetEvent('pop_police:setRadio', function(radio)
  local src = source
  if not onDuty[src] then return end
  local pId = onDuty[src].patrolId
  local newRadio = tostring(radio or ''):sub(1, 16)
  
  if pId then
    exports.oxmysql:query('UPDATE tab_police_patrols SET radio=? WHERE id=?', { newRadio, pId })
    for s, d in pairs(onDuty) do
      if d.patrolId == pId then
        if onDuty[s].patrol then onDuty[s].patrol.radio = newRadio end
        TriggerClientEvent('pop_police:syncRadio', s, newRadio)
      end
    end
    broadcastUnits(onDuty[src].job)
  end
end)

RegisterNetEvent('pop_police:setSituation', function(code)
  local src = source
  if not onDuty[src] then return end
  local newSit = tostring(code or ''):sub(1, 16)
  
  local pId = onDuty[src].patrolId
  if pId then
    for s, d in pairs(onDuty) do
      if d.patrolId == pId then
        onDuty[s].situation = newSit
        TriggerClientEvent('pop_police:syncSituation', s, newSit)
      end
    end
  else
    onDuty[src].situation = newSit
  end
  
  broadcastUnits(onDuty[src].job)
end)

RegisterNetEvent('pop_police:setCallsign', function(cs)
  local src = source
  if not onDuty[src] then return end
  onDuty[src].callsign = tostring(cs or ''):sub(1, 12)
  broadcastUnits(onDuty[src].job)
end)

RegisterNetEvent('pop_police:setMatricule', function(mat)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not p then return end 
  
  if not isPlayerAllowed(p) then return end
  
  mat = tostring(mat or ''):sub(1, 8)
  
  -- Si le joueur est en service, on met à jour la mémoire vive
  if onDuty[src] then
    onDuty[src].matricule = mat
  end

  local ident     = p.identifier
  local job       = onDuty[src] and onDuty[src].job or (p.job and p.job.name) or ''
  local firstName = p.get('firstName') or ''
  local lastName  = p.get('lastName') or ''
  local grade     = onDuty[src] and onDuty[src].grade or (p.job and (p.job.grade_label or p.job.grade_name)) or ''
  
  exports.oxmysql:query(
    'INSERT INTO tab_police_officers (identifier, job, firstname, lastname, grade, matricule, on_duty) VALUES (?,?,?,?,?,?,?) '
    .. 'ON DUPLICATE KEY UPDATE firstname=VALUES(firstname), lastname=VALUES(lastname), grade=VALUES(grade), matricule=VALUES(matricule)',
    { ident, job, firstName, lastName, grade, mat, onDuty[src] and 1 or 0 }, function() end
  )
  
  if onDuty[src] then
    broadcastUnits(onDuty[src].job)
  end
end)

RegisterNetEvent('pop_police:setPatrol', function(data)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not isPlayerAllowed(p) or not data then return end
  if not onDuty[src] then return end

  local job   = onDuty[src].job
  local ident = p.identifier
  local cs    = tostring(data.callsign or ''):sub(1, 32)
  local ptype = tostring(data.type     or 'Solo'):sub(1, 16)
  local sector= tostring(data.sector   or ''):sub(1, 64)
  local radio = tostring(data.radio    or ''):sub(1, 16)
  local vehNet = data.vehNet and tonumber(data.vehNet) or nil
  local members = type(data.members) == 'table' and data.members or {}

  -- SÉCURITÉ : Vérification de la cohérence du nombre de membres selon le type
  local expectedMembers = 0
  if ptype == 'Adam' or ptype == 'Henry-01' then expectedMembers = 1
  elseif ptype == 'William' then expectedMembers = 3
  elseif ptype == 'David' then expectedMembers = 4
  end

  if #members < expectedMembers then
    TriggerClientEvent('pop_police:toast', src, "Triche détectée ou erreur : Nombre d'agents insuffisant pour cette patrouille.")
    return
  end

  -- Supprimer l'ancienne patrouille du leader
  if onDuty[src].patrolId then
    exports.oxmysql:query('DELETE FROM tab_police_patrols WHERE id=?', { onDuty[src].patrolId }, function() end)
  end

  exports.oxmysql:insert(
    'INSERT INTO tab_police_patrols (job, callsign, type, sector, radio, leader_identifier) VALUES (?,?,?,?,?,?)',
    { job, cs, ptype, sector, radio, ident },
    function(id)
      if not id or id == 0 then return end
      
      -- Ajouter le leader
      exports.oxmysql:query('INSERT IGNORE INTO tab_police_patrol_members (patrol_id, identifier) VALUES (?,?)', { id, ident })

      onDuty[src].patrol = { type = ptype, callsign = cs, sector = sector, radio = radio, id = id, vehNet = vehNet }
      onDuty[src].patrolId = id
      onDuty[src].callsign = cs
      TriggerClientEvent('pop_police:assignedToPatrol', src, onDuty[src].patrol)


      -- Ajouter les membres sélectionnés (s'ils existent et sont en service)
      for _, memSrcStr in ipairs(members) do
        local memSrc = tonumber(memSrcStr)
        if memSrc and onDuty[memSrc] then
          local memP = ESX.GetPlayerFromId(memSrc)
          if memP then
            -- Insertion SQL
            exports.oxmysql:query('INSERT IGNORE INTO tab_police_patrol_members (patrol_id, identifier) VALUES (?,?)', { id, memP.identifier })
            
            -- Mise à jour de leur état en mémoire
            onDuty[memSrc].patrol = { type = ptype, callsign = cs, sector = sector, radio = radio, id = id, vehNet = vehNet }
            onDuty[memSrc].patrolId = id
            onDuty[memSrc].callsign = cs
            
            -- Force la tablette du membre à se mettre à jour
            TriggerClientEvent('pop_police:assignedToPatrol', memSrc, onDuty[memSrc].patrol)
            TriggerClientEvent('pop_police:toast', memSrc, ('Vous avez été assigné à la patrouille %s par %s'):format(cs, onDuty[src].callsign))
          end
        end
      end

      broadcastUnits(job)
    end
  )
end)

RegisterNetEvent('pop_police:editAgent', function(data)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not isPlayerAllowed(p) then return end
  if not onDuty[src] then return end

  if type(data) ~= 'table' then return end
  local targetSrc = data.targetSrc
  local grade = tostring(data.grade or ''):sub(1, 32)
  local validGrade = false
  for _, g in ipairs(Config.Grades or {}) do
    if g == grade then validGrade = true break end
  end
  if not validGrade then return end
  local mat = tostring(data.matricule or ''):sub(1,8)
  local targetSrcNum = tonumber(targetSrc)

  if targetSrcNum and targetSrcNum == src then
    -- Je me modifie
    if onDuty[src] then
      onDuty[src].grade = grade
      onDuty[src].matricule = mat
      exports.oxmysql:query('UPDATE tab_police_officers SET grade=?, matricule=? WHERE identifier=?', { grade, mat, p.identifier })
      broadcastUnits(onDuty[src].job)
    else
      exports.oxmysql:query('UPDATE tab_police_officers SET grade=?, matricule=? WHERE identifier=?', { grade, mat, p.identifier })
    end
  elseif targetSrcNum and onDuty[targetSrcNum] then
    -- Je modifie un collègue en service
    onDuty[targetSrcNum].grade = grade
    onDuty[targetSrcNum].matricule = mat
    local tPlayer = ESX.GetPlayerFromId(targetSrcNum)
    if tPlayer then
      exports.oxmysql:query('UPDATE tab_police_officers SET grade=?, matricule=? WHERE identifier=?', { grade, mat, tPlayer.identifier })
    end
    broadcastUnits(onDuty[targetSrcNum].job)
  else
    -- Je modifie un agent hors ligne / hors service (targetSrc = identifier)
    if type(targetSrc) ~= 'string' then return end
    if Config.DevMode then
      exports.oxmysql:query('UPDATE tab_police_officers SET grade=?, matricule=? WHERE identifier=?', { grade, mat, targetSrc })
    else
      exports.oxmysql:query('UPDATE tab_police_officers SET grade=?, matricule=? WHERE identifier=? AND job=?', { grade, mat, targetSrc, onDuty[src].job })
    end
    broadcastUnits(onDuty[src].job)
  end
end)

RegisterNetEvent('pop_police:endPatrol', function()
  local src = source
  if not onDuty[src] or not onDuty[src].patrolId then return end
  
  local pId = onDuty[src].patrolId
  autoRemoveCalls(nil, pId)
  exports.oxmysql:query('DELETE FROM tab_police_patrols WHERE id=?', { pId })
  
  -- Nettoyer tous les agents qui faisaient partie de cette patrouille
  for s, d in pairs(onDuty) do
    if d.patrolId == pId then
      onDuty[s].patrol = nil
      onDuty[s].patrolId = nil
      TriggerClientEvent('pop_police:assignedToPatrol', s, nil)
      if s ~= src then
        TriggerClientEvent('pop_police:toast', s, 'Votre patrouille a été dissoute.')
      end
    end
  end
  broadcastUnits(onDuty[src].job)
end)

-- ============================
-- DEMANDE DE RENFORT
-- ============================
RegisterNetEvent('pop_police:requestBackup', function(level, label, coords)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not isPlayerAllowed(p) or not onDuty[src] then return end

  -- [NOUVEAU] Filtre Anti-Spam (Appel déjà actif)
  local myPatrolId = onDuty[src].patrol and onDuty[src].patrol.id or nil
  for _, c in pairs(calls) do
    if not c.isGunshot then
      if c.requesterSrc == src then
        TriggerClientEvent('pop_police:toast', src, "Vous avez déjà une demande de renfort en cours.")
        return
      elseif myPatrolId and c.patrol and c.patrol.id == myPatrolId then
        TriggerClientEvent('pop_police:toast', src, "Votre patrouille a déjà une demande de renfort en cours.")
        return
      end
    end
  end

  coords = sanitizeCoords(coords)
  if not coords or not isNear(src, coords, 50.0) then return end

  level = tonumber(level) or 1
  if level < 1 then level = 1 elseif level > 3 then level = 3 end

  local reqName = ('%s %s'):format(p.get('firstName') or '', p.get('lastName') or '')
  local cSign = onDuty[src].callsign
  local pData = onDuty[src].patrol
  local now = os.time()

  -- Insertion BDD avant d'envoyer aux joueurs
  local actualJob = onDuty[src].job
  local jobName = (Config.DevMode and Config.DevJob) or actualJob
  local deptName = Config.DeptNames[jobName] or 'LSPD'
  
  globalAlertCounter = globalAlertCounter + 1
  local alertNum = globalAlertCounter
  
  exports.oxmysql:insert('INSERT INTO tab_police_calls (level, label, requesterName, callsign, patrol, coords, accepted, createdAt, isGunshot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
    level, tostring(label or ''):sub(1, 64), reqName, cSign, 
    pData and json.encode(pData) or nil, 
    json.encode(coords), json.encode({}), now, 0
  }, function(id)
    if id and id > 0 then
      local call = {
        id            = id,
        level         = level,
        label         = tostring(label or ''):sub(1, 64),
        requesterSrc  = src,
        requesterName = reqName,
        callsign      = cSign,
        patrol        = pData,
        coords        = coords,
        accepted      = {},
        createdAt     = now,
        isGunshot     = false,
        dept          = deptName,
        alertNum      = alertNum
      }
      calls[id] = call

      for _, dst in ipairs(getPoliceSources()) do
        TriggerClientEvent('pop_police:newBackup', dst, call)
      end
      broadcastCalls()
    end
  end)
end)

RegisterNetEvent('pop_police:acceptBackup', function(callId)
  local src = source
  local c = calls[callId]
  if not c or not onDuty[src] then return end

  if not onDuty[src].patrol then
    TriggerClientEvent('pop_police:toast', src, 'Action impossible : Vous n\'êtes dans aucune patrouille.')
    return
  end

  -- On sauvegarde le nom de la patrouille pour l'afficher sur les pastilles UI
  c.accepted[tostring(src)] = onDuty[src].patrol.callsign or onDuty[src].callsign or 'Unité'
  -- [NOUVEAU] Sauvegarde de l'acceptation
  exports.oxmysql:query('UPDATE tab_police_calls SET accepted = ? WHERE id = ?', { json.encode(c.accepted), callId })

  TriggerClientEvent('pop_police:backupAccepted', src, c)
  
  local accepterName = c.accepted[tostring(src)]
  for _, dst in ipairs(getPoliceSources()) do
    TriggerClientEvent('pop_police:notifyAcceptance', dst, c, accepterName)
  end
  
  broadcastCalls()
end)

RegisterNetEvent('pop_police:assignAllToCall', function(callId)
  local src = source
  local c = calls[callId]
  if not c or not onDuty[src] then return end
  
  c.allAssigned = true
  for _, dst in ipairs(getPoliceSources()) do
    c.accepted[tostring(dst)] = true
    TriggerClientEvent('pop_police:backupAccepted', dst, c)
  end
  
  -- [NOUVEAU] Sauvegarde de l'assignation globale
  exports.oxmysql:query('UPDATE tab_police_calls SET allAssigned = 1, accepted = ? WHERE id = ?', { json.encode(c.accepted), callId })
  broadcastCalls()
end)

RegisterNetEvent('pop_police:removeCall', function(callId)
  local src = source
  if not onDuty[src] then return end
  if calls[callId] then
    calls[callId] = nil
    -- [NOUVEAU] Suppression définitive BDD
    exports.oxmysql:query('DELETE FROM tab_police_calls WHERE id = ?', { callId })
    
    for _, dst in ipairs(getPoliceSources()) do
      TriggerClientEvent('pop_police:callRemoved', dst, callId)
    end
    broadcastCalls()
  end
end)

RegisterNetEvent('pop_police:clearAllCalls', function()
  local src = source
  if not onDuty[src] then return end
  for cid in pairs(calls) do
    for _, dst in ipairs(getPoliceSources()) do
      TriggerClientEvent('pop_police:callRemoved', dst, cid)
    end
  end
  calls = {}
  
  -- [NOUVEAU] On vide la table proprement
  exports.oxmysql:query('DELETE FROM tab_police_calls', {})
  broadcastCalls()
end)

-- Synchro initiale quand l'UI demande l'état complet (à l'ouverture de la tablette)
RegisterNetEvent('pop_police:requestSync', function()
  local src = source
  local p = ESX.GetPlayerFromId(src)
  
  -- SÉCURITÉ : On vérifie juste qu'il s'agit bien d'un policier ou d'un admin
  if not isPlayerAllowed(p) then return end

  local myJob = p.job.name

  getAllUnits(myJob, function(units)
    -- 2. Envoi des appels en cours
    local list = {}
    for _, c in pairs(calls) do list[#list + 1] = c end
    TriggerClientEvent('pop_police:fullSync', src, units, list)

    -- 3. Envoi des avis de recherche
    local vList = {}
    for _, v in pairs(wantedVehicles) do vList[#vList + 1] = v end
    local cList = {}
    for _, c in pairs(wantedCitizens) do cList[#cList + 1] = c end
    TriggerClientEvent('pop_police:syncWanted', src, vList, cList)

    -- 4. Récupération du profil BDD de l'agent
    exports.oxmysql:query('SELECT matricule, grade FROM tab_police_officers WHERE identifier = ? AND matricule != "" LIMIT 1', { p.identifier }, function(rows)
      local mat = ''
      local grade = p.job.grade_label or p.job.grade_name or ''

      if Config.DevMode and not isPoliceJob(p.job.name) then
          grade = Config.DevGrade
      end

      if rows and rows[1] then
        mat = rows[1].matricule or ''
        if rows[1].grade and rows[1].grade ~= '' then
          grade = rows[1].grade
        end
      end

      TriggerClientEvent('pop_police:myProfile', src, {
        matricule  = mat,
        grade      = grade,
        identifier = p.identifier
      })
    end)
  end)
end)

RegisterNetEvent('pop_police:pingLocation', function(coords)
  local src = source
  coords = sanitizeCoords(coords)
  if not onDuty[src] or not coords then return end
  local cs = onDuty[src].callsign or ('#' .. src)
  for _, dst in ipairs(getPoliceSources()) do
    TriggerClientEvent('pop_police:locationPing', dst, { callsign = cs, coords = coords })
  end
end)

AddEventHandler('playerDropped', function()
  local src = source
  if onDuty[src] then
    local job = onDuty[src].job
    local pId = onDuty[src].patrolId
    autoRemoveCalls(src, pId)
    if pId then
      exports.oxmysql:query('DELETE FROM tab_police_patrols WHERE id=?', { pId }, function() end)
    end
    local p = ESX.GetPlayerFromId(src)
    if p then
      exports.oxmysql:query('UPDATE tab_police_officers SET on_duty=0 WHERE identifier=? AND job=?', { p.identifier, job })
    end
    onDuty[src] = nil
    globalOfficerStates[src] = nil -- Nettoyage position
    broadcastUnits(job)
  end
  lastGunshotAlerts[src] = nil
  lastExternalCalls[src] = nil
end)

AddEventHandler('esx:setJob', function(playerId, job, lastJob)
  local p = ESX.GetPlayerFromId(playerId)
  if onDuty[playerId] and not isPlayerAllowed(p) then
    local oldJob = onDuty[playerId].job
    local pId = onDuty[playerId].patrolId
    autoRemoveCalls(playerId, pId)
    onDuty[playerId] = nil
    globalOfficerStates[playerId] = nil -- Nettoyage position
    TriggerClientEvent('pop_police:dutyState', playerId, false)
    broadcastUnits(oldJob)
  end
end)

-- ============================
-- RECHERCHE VÉHICULE
-- ============================
RegisterNetEvent('pop_police:searchVehicle', function(query)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not isPlayerAllowed(p) then return end
  if not onDuty[src] then return end

  -- Nettoyage de la saisie
  query = tostring(query or ''):match('^%s*(.-)%s*$') or ''
  if #query < 2 then
    TriggerClientEvent('pop_police:vehicleResults', src, {})
    return
  end
  query = query:sub(1, 32)

  local param = '%' .. query .. '%'
  exports.oxmysql:query('SELECT plate, vehicle FROM owned_vehicles WHERE plate LIKE ? LIMIT 10', { param }, function(rows)
    local results = {}
    if rows then
      for _, row in ipairs(rows) do
        local model = 'Inconnu'
        if row.vehicle then
          local ok, vehData = pcall(json.decode, row.vehicle)
          if ok and vehData and vehData.model then
            model = tostring(vehData.model)
          end
        end
        results[#results + 1] = { plate = row.plate, model = model }
      end
    end
    TriggerClientEvent('pop_police:vehicleResults', src, results)
  end)
end)

-- ============================
-- RECHERCHE CITOYEN
-- ============================
RegisterNetEvent('pop_police:searchCitizen', function(query)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  if not isPlayerAllowed(p) then return end
  if not onDuty[src] then return end

  -- Nettoyage de la saisie
  query = tostring(query or ''):match('^%s*(.-)%s*$') or ''
  if #query < 2 then
    TriggerClientEvent('pop_police:citizenResults', src, {})
    return
  end
  query = query:sub(1, 64)

  local param = '%' .. query .. '%'
  exports.oxmysql:query(
    'SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE CONCAT(firstname, \' \', lastname) LIKE ? OR lastname LIKE ? OR firstname LIKE ? LIMIT 10',
    { param, param, param },
    function(rows)
      local results = {}
      if rows then
        for _, row in ipairs(rows) do
          results[#results + 1] = {
            name       = ('%s %s'):format(row.firstname or '', row.lastname or ''),
            dob        = row.dateofbirth or '',
            identifier = row.identifier or '',
          }
        end
      end
      TriggerClientEvent('pop_police:citizenResults', src, results)
    end
  )
end)

-- ============================
-- AVIS DE RECHERCHE PERSISTANTS
-- ============================
local function broadcastWanted()
  local vList = {}
  for _, v in pairs(wantedVehicles) do vList[#vList + 1] = v end
  local cList = {}
  for _, c in pairs(wantedCitizens) do cList[#cList + 1] = c end
  
  -- On récupère tous les joueurs connectés sur le serveur
  local xPlayers = ESX.GetPlayers()
  for i=1, #xPlayers, 1 do
    local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
    -- Si le joueur est un policier ou admin (en service ou pas), on lui synchronise la liste
    if xPlayer and isPlayerAllowed(xPlayer) then
      TriggerClientEvent('pop_police:syncWanted', xPlayers[i], vList, cList)
    end
  end
end

RegisterNetEvent('pop_police:addWantedVehicle', function(data)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  
  -- SÉCURITÉ : On vérifie que le joueur est policier ou admin
  if not isPlayerAllowed(p) or type(data) ~= 'table' then return end
  local plate, model, note = str(data.plate, 16), str(data.model, 64), str(data.note, 1000)

  exports.oxmysql:insert('INSERT INTO tab_wanted_vehicles (plate, model, note) VALUES (?, ?, ?)', {
    plate, model, note
  }, function(id)
    if id and id > 0 then
      wantedVehicles[tostring(id)] = { id = id, plate = plate, model = model, note = note }
      broadcastWanted()
      -- TriggerClientEvent('pop_police:toast', src, 'Véhicule ajouté aux avis de recherche.')
    else
      TriggerClientEvent('pop_police:toast', src, 'Erreur DB: Impossible d\'ajouter le véhicule.')
    end
  end)
end)

RegisterNetEvent('pop_police:removeWantedVehicle', function(id)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  
  if not isPlayerAllowed(p) or not id then return end

  exports.oxmysql:query('DELETE FROM tab_wanted_vehicles WHERE id = ?', { id }, function(rowsChanged)
    wantedVehicles[tostring(id)] = nil
    broadcastWanted()
    -- TriggerClientEvent('pop_police:toast', src, 'Avis de recherche supprimé.')
  end)
end)

RegisterNetEvent('pop_police:addWantedCitizen', function(data)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  
  if not isPlayerAllowed(p) or type(data) ~= 'table' then return end
  local name, reason, desc = str(data.name, 64), str(data.reason, 255), str(data.desc, 1000)

  exports.oxmysql:insert('INSERT INTO tab_wanted_citizens (name, reason, `desc`) VALUES (?, ?, ?)', {
    name, reason, desc
  }, function(id)
    if id and id > 0 then
      wantedCitizens[tostring(id)] = { id = id, name = name, reason = reason, desc = desc }
      broadcastWanted()
      -- TriggerClientEvent('pop_police:toast', src, 'Citoyen ajouté aux avis de recherche.')
    else
      TriggerClientEvent('pop_police:toast', src, 'Erreur DB: Impossible d\'ajouter le citoyen.')
    end
  end)
end)

RegisterNetEvent('pop_police:removeWantedCitizen', function(id)
  local src = source
  local p = ESX.GetPlayerFromId(src)
  
  if not isPlayerAllowed(p) or not id then return end

  exports.oxmysql:query('DELETE FROM tab_wanted_citizens WHERE id = ?', { id }, function(rowsChanged)
    wantedCitizens[tostring(id)] = nil
    broadcastWanted()
  end)
end)

-- ============================
-- GESTION DES COUPS DE FEU (Serveur)
-- ============================

RegisterNetEvent('pop_police:gunshotDetected', function(coords)
  local src = source
  coords = sanitizeCoords(coords)
  if not coords or not isNear(src, coords, 50.0) then return end

  local now = os.time()
  if lastGunshotAlerts[src] and (now - lastGunshotAlerts[src]) < 10 then return end
  lastGunshotAlerts[src] = now

  -- Vérification des superpositions de zones
  local cv = vector3(coords.x, coords.y, coords.z)
  for _, call in pairs(calls) do
      if call.isGunshot and call.coords then
          if #(cv - vector3(call.coords.x + 0.0, call.coords.y + 0.0, call.coords.z + 0.0)) <= 85.0 then return end
      end
  end

  globalAlertCounter = globalAlertCounter + 1
  local alertNum = globalAlertCounter

  -- [NOUVEAU] Insertion de l'alerte de tir en BDD
  exports.oxmysql:insert('INSERT INTO tab_police_calls (level, label, requesterName, callsign, coords, accepted, createdAt, isGunshot) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
    3, 'Coups de feu en cours', 'Appel', 'LSPD', 
    json.encode(coords), json.encode({}), now, 1
  }, function(id)
    if id and id > 0 then
      local call = {
        id            = id,
        level         = 3,
        label         = 'Coups de feu en cours',
        requesterSrc  = 0,
        requesterName = 'Appel',
        callsign      = 'LSPD',
        patrol        = nil, 
        coords        = coords,
        accepted      = {},
        createdAt     = now,
        isGunshot     = true,
        alertNum      = alertNum
      }
      
      calls[id] = call

      for _, dst in ipairs(getPoliceSources()) do
        TriggerClientEvent('pop_police:newBackup', dst, call)
      end
      
      broadcastCalls()
    end
  end)
end)

-- ============================
-- EXPORTS & API EXTERNE
-- ============================

-- Fonction globale pour créer un appel depuis n'importe quel script
local function createExternalCall(level, label, coords, requesterName, callsign)
    -- Sécurisation et formatage des données entrantes
    level = tonumber(level) or 1
    if level < 1 then level = 1 elseif level > 3 then level = 3 end
    label = tostring(label or 'Alerte Système'):sub(1, 64)
    requesterName = tostring(requesterName or 'Centrale 911'):sub(1, 64)
    callsign = tostring(callsign or 'DISPATCH'):sub(1, 32)

    coords = sanitizeCoords(coords)
    if not coords then
        print("^1[pop_police] Erreur Export : Coordonnées invalides pour l'alerte '"..label.."'.^0")
        return false
    end

    local now = os.time()

    globalAlertCounter = globalAlertCounter + 1
    local alertNum = globalAlertCounter

    -- Insertion BDD
    exports.oxmysql:insert('INSERT INTO tab_police_calls (level, label, requesterName, callsign, coords, accepted, createdAt, isGunshot) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        level, label, requesterName, callsign, 
        json.encode(coords), json.encode({}), now, 0
    }, function(id)
        if id and id > 0 then
            local call = {
                id            = id,
                level         = level,
                label         = label,
                requesterSrc  = 0, -- 0 indique que c'est le système
                requesterName = requesterName,
                callsign      = callsign,
                patrol        = nil,
                coords        = coords,
                accepted      = {},
                createdAt     = now,
                isGunshot     = false,
                alertNum      = alertNum
            }
            calls[id] = call

            -- Diffusion à tous les policiers en service
            for _, dst in ipairs(getPoliceSources()) do
                TriggerClientEvent('pop_police:newBackup', dst, call)
            end
            broadcastCalls()
        end
    end)
    
    return true
end

-- Création de l'export Serveur (Méthode la plus sécurisée)
exports('createCall', createExternalCall)

-- Création de l'Event Net (Pour les scripts qui n'ont qu'une logique client)
RegisterNetEvent('pop_police:server:createExternalCall', function(level, label, coords, requesterName, callsign)
    local src = source
    local now = os.time()
    
    -- [SÉCURITÉ ANTI-CHEAT] Rate-limit de 5 secondes par joueur pour éviter qu'un modder spam la BDD
    if lastExternalCalls[src] and (now - lastExternalCalls[src]) < 5 then return end
    lastExternalCalls[src] = now

    createExternalCall(level, label, coords, requesterName, callsign)
end)