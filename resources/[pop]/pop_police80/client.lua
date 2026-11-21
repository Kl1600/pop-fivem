local ESX = exports['es_extended']:getSharedObject()

local isPolice = false
local onDuty = false
local uiOpen = false
local muted = false

-- ============================
-- DÉCLARATION DES TABLES (Globales au fichier)
-- ============================
local vehicleBlips = {}
local callBlips = {}
local callRadiusBlips = {} -- [NOUVEAU] Stocke les zones rouges des tirs
local patrolVehicleBlips = {}
local activeCalls = {} -- [NOUVEAU] Stocke les appels actifs pour les rendre dynamiques
local globalOfficerStates = {}
local routeCallId = nil
local currentPatrolVehNet = nil
local lastPatrolVehCoords = nil -- [NOUVEAU] Stocke la dernière position connue de la voiture
local createCallBlip -- déclaration anticipée (utilisée par fullSync)

local PlayerPedId, GetEntityCoords, DoesBlipExist, SetBlipCoords = PlayerPedId, GetEntityCoords, DoesBlipExist, SetBlipCoords
local DisableControlAction, Wait = DisableControlAction, Wait

-- ============================
-- NETTOYAGE DES BLIPS
-- ============================
local function ClearAllPoliceBlips()
  for _, b in pairs(vehicleBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  for _, b in pairs(patrolVehicleBlips) do if b and b.blip and DoesBlipExist(b.blip) then RemoveBlip(b.blip) end end
  for _, b in pairs(callBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  -- [NOUVEAU] Nettoyage des zones de tir
  for _, b in pairs(callRadiusBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end

  vehicleBlips = {}
  patrolVehicleBlips = {}
  callBlips = {}
  callRadiusBlips = {}
  activeCalls = {}
  
  if globalOfficerStates then globalOfficerStates = {} end
end

local function ClearPatrolKVPs()
  DeleteResourceKvp('pop_police:patrolType')
  DeleteResourceKvp('pop_police:patrolSector')
  DeleteResourceKvp('pop_police:patrolRadio')
  currentPatrolVehNet = nil
end

-- ============================
-- VÉRIFICATION DU JOB
-- ============================
local function isPoliceJob(name)
  if Config.DevMode then return true end
  local pd = ESX.GetPlayerData()
  if pd and pd.group and (pd.group == 'admin' or pd.group == 'superadmin') then return true end
  if not name then return false end
  for _, j in ipairs(Config.PoliceJobs) do
    if name == j then return true end
  end
  return false
end

local function refreshJob()
  local pd = ESX.GetPlayerData()
  isPolice = pd and pd.job and isPoliceJob(pd.job.name) or false
  if not isPolice then
    onDuty = false
    ClearAllPoliceBlips() -- [SÉCURITÉ] Nettoyage de la carte
    SetNuiFocus(false, false)
    uiOpen = false
    SendNUIMessage({ action = 'close' })
  end
end

-- ============================
-- INITIALISATION ESX (Connexion & Reboot)
-- ============================
RegisterNetEvent('esx:playerLoaded', function(_, pd)
  isPolice = isPoliceJob(pd and pd.job and pd.job.name)
end)

RegisterNetEvent('esx:setJob', function(job)
  isPolice = isPoliceJob(job.name)
  if not isPolice then 
    onDuty = false 
    ClearAllPoliceBlips()
  end
end)

-- Thread de sécurité pour les redémarrages de script "à chaud" (ensure)
CreateThread(function()
  Wait(500)
  local pd = ESX.GetPlayerData()
  if pd and pd.job then
    isPolice = isPoliceJob(pd.job.name)
  elseif Config.DevMode then
    isPolice = true
  end
end)

-- ============================
-- UI OPEN / CLOSE
-- ============================
local function openUI()
  if not isPolice then return end
  uiOpen = true
  local pd = ESX.GetPlayerData() or {}
  local jobName = (Config.DevMode and Config.DevJob) or (pd.job and pd.job.name) or ''
  local deptName = (Config.DeptNames and (Config.DeptNames[jobName] or Config.DeptNames['default'])) or 'LSPD'
  
  local me = {
    id        = GetPlayerServerId(PlayerId()),
    name      = (pd.firstName or '') .. ' ' .. (pd.lastName or ''),
    callsign  = GetResourceKvpString('pop_police:callsign') or '',
    situation = GetResourceKvpString('pop_police:situation') or 'N/A',
    matricule = GetResourceKvpString('pop_police:matricule') or '',
    grade     = (function()
      local actualJob = pd.job and pd.job.name or ''
      for _, j in ipairs(Config.PoliceJobs) do
        if actualJob == j then return pd.job.grade_label or pd.job.grade_name or '' end
      end
      return (Config.DevMode and Config.DevGrade) or ''
    end)(),
    patrol    = nil,
  }

  local pt = GetResourceKvpString('pop_police:patrolType')
  -- [CORRECTION] Ne charge le KVP que si le joueur est activement en service
  if onDuty and pt and pt ~= '' then 
    me.patrol = {
      type     = pt,
      sector   = GetResourceKvpString('pop_police:patrolSector') or '',
      callsign = me.callsign,
    }
  end

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(true)
  SendNUIMessage({
    action      = 'open',
    duty        = onDuty,
    muted       = muted,
    situations  = Config.SituationCodes,
    levels      = Config.BackupLevels,
    backupKey   = GetResourceKvpString('pop_police:backupKey') or Config.DefaultBackupKey,
    deptName    = deptName,
    grades      = Config.Grades,
    theme       = Config.Theme,
    me          = me,
  })
  TriggerServerEvent('pop_police:requestSync')
end

local function closeUI()
  uiOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ action = 'close' })
end

RegisterCommand('police', function()
  if uiOpen then closeUI() else openUI() end
end, false)
RegisterKeyMapping('police', 'Ouvrir Dispatch Police', 'keyboard', Config.OpenKey)

CreateThread(function()
  while true do
    if uiOpen then
      DisableControlAction(0, 1, true)   -- LookLeftRight
      DisableControlAction(0, 2, true)   -- LookUpDown
      DisableControlAction(0, 24, true)  -- Attack
      DisableControlAction(0, 25, true)  -- Aim
      DisableControlAction(0, 257, true) -- Attack 2
      DisableControlAction(0, 263, true) -- Melee Attack 1
      DisableControlAction(0, 140, true) -- Melee Attack light
      DisableControlAction(0, 142, true) -- Melee Attack alt
      DisableControlAction(0, 143, true) -- Melee block
      DisableControlAction(0, 37, true)  -- Select Weapon
      DisableControlAction(0, 44, true)  -- Cover
      DisableControlAction(0, 14, true)  -- Weapon wheel next
      DisableControlAction(0, 15, true)  -- Weapon wheel prev
      DisableControlAction(0, 16, true)  -- Select next weapon
      DisableControlAction(0, 17, true)  -- Select prev weapon
      DisableControlAction(0, 81, true)  -- Next Radio
      DisableControlAction(0, 82, true)  -- Prev Radio
      DisableControlAction(0, 99, true)  -- Vehicle Select Next Weapon
      DisableControlAction(0, 100, true) -- Vehicle Select Prev Weapon
      DisableControlAction(0, 115, true) -- Vehicle Gun Next
      DisableControlAction(0, 116, true) -- Vehicle Gun Prev
      DisableControlAction(0, 261, true) -- Prev Weapon in vehicle
      DisableControlAction(0, 262, true) -- Next Weapon in vehicle
      DisableControlAction(0, 85, true)  -- Veh radio wheel
      Wait(0)
    else
      Wait(500)
    end
  end
end)

-- ============================
-- NUI CALLBACKS
-- ============================
RegisterNUICallback('addWantedVehicle', function(data, cb)
  TriggerServerEvent('pop_police:addWantedVehicle', data)
  cb(1)
end)

RegisterNUICallback('removeWantedVehicle', function(data, cb)
  TriggerServerEvent('pop_police:removeWantedVehicle', data.id)
  cb(1)
end)

RegisterNUICallback('addWantedCitizen', function(data, cb)
  TriggerServerEvent('pop_police:addWantedCitizen', data)
  cb(1)
end)

RegisterNUICallback('removeWantedCitizen', function(data, cb)
  TriggerServerEvent('pop_police:removeWantedCitizen', data.id)
  cb(1)
end)

RegisterNUICallback('close', function(_, cb)
  closeUI(); cb({ ok = true })
end)

RegisterNUICallback('keepInput', function(data, cb)
  SetNuiFocusKeepInput(data.keep)
  cb({ ok = true })
end)

RegisterNUICallback('toggleDuty', function(data, cb)
  onDuty = data and data.state == true
  TriggerServerEvent('pop_police:setDuty', onDuty)
  cb({ ok = true, duty = onDuty })
end)

RegisterNUICallback('toggleMute', function(data, cb)
  muted = data and data.state == true
  cb({ ok = true, muted = muted })
end)

RegisterNUICallback('setCallsign', function(data, cb)
  local cs = (data and data.callsign) or ''
  SetResourceKvp('pop_police:callsign', cs)
  TriggerServerEvent('pop_police:setCallsign', cs)
  cb({ ok = true })
end)

RegisterNUICallback('setSituation', function(data, cb)
  local code = (data and data.code) or '10-8'
  SetResourceKvp('pop_police:situation', code)
  TriggerServerEvent('pop_police:setSituation', code)
  cb({ ok = true })
end)

RegisterNetEvent('pop_police:syncSituation', function(code)
  SetResourceKvp('pop_police:situation', code)
  SendNUIMessage({ action = 'syncSituation', code = code })
end)

RegisterNUICallback('setRadio', function(data, cb)
  local radio = (data and data.radio) or ''
  SetResourceKvp('pop_police:patrolRadio', radio)
  TriggerServerEvent('pop_police:setRadio', radio)
  cb({ ok = true })
end)

RegisterNetEvent('pop_police:syncRadio', function(radio)
  SetResourceKvp('pop_police:patrolRadio', radio)
  SendNUIMessage({ action = 'syncRadio', radio = radio })
end)

RegisterNUICallback('setMatricule', function(data, cb)
  local mat = (data and data.matricule) or ''
  SetResourceKvp('pop_police:matricule', mat)
  TriggerServerEvent('pop_police:setMatricule', mat)
  cb({ ok = true })
end)

RegisterNUICallback('editAgent', function(data, cb)
  TriggerServerEvent('pop_police:editAgent', data)
  cb({ ok = true })
end)

RegisterNUICallback('startPatrol', function(data, cb)
  local cs    = (data and data.callsign) or ''
  local radio = (data and data.radio)    or ''
  SetResourceKvp('pop_police:callsign',    cs)
  SetResourceKvp('pop_police:patrolType',  data and data.type   or 'Solo')
  SetResourceKvp('pop_police:patrolSector',data and data.sector or '')
  SetResourceKvp('pop_police:patrolRadio', radio)
  TriggerServerEvent('pop_police:setCallsign', cs)
  
  TriggerServerEvent('pop_police:setPatrol', {
    type     = data and data.type or 'Solo',
    callsign = cs,
    sector   = data and data.sector or '',
    radio    = radio,
    members  = data and data.members or {},
    vehNet   = data and data.vehNet or nil, 
  })
  cb({ ok = true })
end)

RegisterNUICallback('endPatrol', function(_, cb)
  local oldCs = GetResourceKvpString('pop_police:callsign')
  
  DeleteResourceKvp('pop_police:patrolType')
  DeleteResourceKvp('pop_police:patrolSector')
  currentPatrolVehNet = nil 
  
  if oldCs and patrolVehicleBlips[oldCs] then
    if DoesBlipExist(patrolVehicleBlips[oldCs].blip) then
      RemoveBlip(patrolVehicleBlips[oldCs].blip)
    end
    patrolVehicleBlips[oldCs] = nil
  end

  TriggerServerEvent('pop_police:endPatrol')
  cb({ ok = true })
end)

RegisterNUICallback('pingLocation', function(_, cb)
  local p = PlayerPedId()
  local c = GetEntityCoords(p)
  TriggerServerEvent('pop_police:pingLocation', { x = c.x, y = c.y, z = c.z })
  cb({ ok = true })
end)

RegisterNUICallback('requestBackup', function(data, cb)
  local lvl = tonumber(data and data.level) or 1
  local label = data and data.label or ''
  local p = PlayerPedId()
  local c = GetEntityCoords(p)
  TriggerServerEvent('pop_police:requestBackup', lvl, label, { x = c.x, y = c.y, z = c.z })
  cb({ ok = true })
end)

RegisterNUICallback('acceptCall', function(data, cb)
  TriggerServerEvent('pop_police:acceptBackup', data and data.id)
  cb({ ok = true })
end)

RegisterNUICallback('assignAll', function(data, cb)
  TriggerServerEvent('pop_police:assignAllToCall', data and data.id)
  cb({ ok = true })
end)

RegisterNUICallback('removeCall', function(data, cb)
  TriggerServerEvent('pop_police:removeCall', data and data.id)
  cb({ ok = true })
end)

RegisterNUICallback('clearAll', function(_, cb)
  TriggerServerEvent('pop_police:clearAllCalls')
  cb({ ok = true })
end)

RegisterNUICallback('saveBackupKey', function(data, cb)
  local key = (data and data.key and #data.key > 0) and data.key or Config.DefaultBackupKey
  SetResourceKvp('pop_police:backupKey', key)
  cb({ ok = true, key = key })
end)

-- ============================
-- RECHERCHE BDD
-- ============================
RegisterNUICallback('searchVehicleDB', function(data, cb)
  TriggerServerEvent('pop_police:searchVehicle', data and data.query or '')
  cb({ ok = true })
end)

RegisterNUICallback('searchCitizenDB', function(data, cb)
  TriggerServerEvent('pop_police:searchCitizen', data and data.query or '')
  cb({ ok = true })
end)

-- ============================
-- ASSIGNATION VEHICULE
-- ============================
RegisterNUICallback('getVehicle', function(_, cb)
  local ped = PlayerPedId()
  local veh = GetVehiclePedIsIn(ped, false)
  if veh ~= 0 then
    if not NetworkGetEntityIsNetworked(veh) then
      NetworkRegisterEntityAsNetworked(veh)
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local model = GetEntityModel(veh)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if name == 'NULL' then name = 'Véhicule' end
    local plate = GetVehicleNumberPlateText(veh)
    cb({ netId = netId, name = name .. ' [' .. (plate or '') .. ']' })
  else
    cb({})
  end
end)


-- ============================
-- EVENTS SERVEUR -> CLIENT
-- ============================
RegisterNetEvent('pop_police:dutyState', function(state)
  onDuty = state == true
  SendNUIMessage({ action = 'duty', duty = onDuty })
  
  if onDuty then
    if not LocalPlayer.state.tabPoliceDuty then
      LocalPlayer.state:set('tabPoliceDuty', true, true)
    end
    -- [CORRECTION] Force la synchronisation immédiate pour récupérer les appels/tirs et les afficher sur la map
    TriggerServerEvent('pop_police:requestSync')
  else
    LocalPlayer.state:set('tabPoliceDuty', false, true)
    LocalPlayer.state:set('tabPolicePos', nil, true)
    ClearAllPoliceBlips() -- Nettoyage immédiat
  end
end)

RegisterNetEvent('pop_police:units', function(units, count)
  SendNUIMessage({ action = 'units', units = units, count = count })
end)

RegisterNetEvent('pop_police:myProfile', function(profile)
  if profile.matricule and profile.matricule ~= '' then
    SetResourceKvp('pop_police:matricule', profile.matricule)
  end
  SendNUIMessage({ action = 'myProfile', matricule = profile.matricule, grade = profile.grade, identifier = profile.identifier })
end)

RegisterNetEvent('pop_police:citizenResults', function(results)
  SendNUIMessage({ action = 'citizenResults', results = results })
end)

RegisterNetEvent('pop_police:vehicleResults', function(results)
  SendNUIMessage({ action = 'vehicleResults', results = results })
end)

RegisterNetEvent('pop_police:syncWanted', function(vehList, citList)
  SendNUIMessage({ action = 'syncWanted', vehicles = vehList, citizens = citList })
end)

RegisterNetEvent('pop_police:calls', function(list)
  SendNUIMessage({ action = 'calls', calls = list })
  for _, c in ipairs(list) do
    if activeCalls[c.id] then
      activeCalls[c.id] = c
    end
  end
end)

RegisterNetEvent('pop_police:fullSync', function(units, list)
  SendNUIMessage({ action = 'sync', units = units, calls = list })
  
  -- Nettoyage des anciens blips
  for id, b in pairs(callBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  -- [CORRECTION] Nettoyage des anciennes zones rouges de tirs
  for id, b in pairs(callRadiusBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end 
  
  callBlips = {}
  callRadiusBlips = {}
  activeCalls = {}
  
  -- Création des nouveaux (createCallBlip bloquera tout seul si onDuty est false)
  for _, c in ipairs(list) do
    activeCalls[c.id] = c
    createCallBlip(c)
  end
end)

function createCallBlip(c)
  -- [SÉCURITÉ] Si l'agent n'est pas en service, on bloque la création du blip sur la carte
  if not onDuty then return end 

  if not c or not c.coords then return end
  local b = AddBlipForCoord(c.coords.x + 0.0, c.coords.y + 0.0, c.coords.z + 0.0)
  
  -- Gestion de l'icône et de la couleur
  if c.isGunshot then
      SetBlipSprite(b, 432) 
      SetBlipColour(b, 1) -- Rouge
  else
      local lvl = Config.BackupLevels[c.level] or Config.BackupLevels[1]
      SetBlipSprite(b, lvl.sprite or 161)
      SetBlipColour(b, c.level == 1 and 3 or c.level == 2 and 47 or 1)
  end
  
  SetBlipScale(b, 1.0)
  SetBlipAsShortRange(b, false)
  BeginTextCommandSetBlipName('STRING')
  
  -- Gestion du texte du blip
  if c.isGunshot then
      AddTextComponentString('Alerte : Coups de feu')
  else
      local lvl = Config.BackupLevels[c.level] or Config.BackupLevels[1]
      AddTextComponentString(('Renfort %s — %s'):format(lvl.label, c.callsign or ''))
  end
  EndTextCommandSetBlipName(b)
  PulseBlip(b)
  callBlips[c.id] = b

  if c.isGunshot then
      local rb = AddBlipForRadius(c.coords.x + 0.0, c.coords.y + 0.0, c.coords.z + 0.0, 100.0)
      SetBlipHighDetail(rb, true)
      SetBlipColour(rb, 1) -- Rouge
      SetBlipAlpha(rb, 128)
      -- On suppose que tu as bien ajouté la table 'callRadiusBlips' au début de ton fichier !
      if callRadiusBlips then callRadiusBlips[c.id] = rb end
  end
end

RegisterNetEvent('pop_police:newBackup', function(c)
  activeCalls[c.id] = c
  createCallBlip(c)
  if not muted then
      PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
  end
  SendNUIMessage({ action = 'newBackup', call = c })
end)

RegisterNetEvent('pop_police:callRemoved', function(id)
  activeCalls[id] = nil
  -- Nettoyage de l'icône
  if callBlips[id] and DoesBlipExist(callBlips[id]) then
    RemoveBlip(callBlips[id])
  end
  callBlips[id] = nil
  
  -- Nettoyage de la zone rouge
  if callRadiusBlips[id] and DoesBlipExist(callRadiusBlips[id]) then
    RemoveBlip(callRadiusBlips[id])
  end
  callRadiusBlips[id] = nil

  if routeCallId == id then
    routeCallId = nil
  end
end)

RegisterNetEvent('pop_police:backupAccepted', function(c)
  if not c or not c.coords then return end
  routeCallId = c.id
  SetNewWaypoint(c.coords.x + 0.0, c.coords.y + 0.0)
end)

RegisterNetEvent('pop_police:notifyAcceptance', function(c, accepterName)
  SendNUIMessage({ action = 'notifyAcceptance', call = c, accepterName = accepterName })
end)

RegisterNetEvent('pop_police:toast', function(text)
  -- Envoie la notification proprement dans l'UI de la tablette (même si elle est fermée)
  SendNUIMessage({ action = 'toast', text = text })
end)

RegisterNetEvent('pop_police:locationPing', function(data)
  if not data or not data.coords then return end
  local b = AddBlipForCoord(data.coords.x + 0.0, data.coords.y + 0.0, data.coords.z + 0.0)
  SetBlipSprite(b, 162); SetBlipColour(b, 5); SetBlipScale(b, 1.1)
  BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Position ' .. (data.callsign or '')); EndTextCommandSetBlipName(b)
  SetBlipAsShortRange(b, false)
  SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
  SetTimeout(20000, function() if DoesBlipExist(b) then RemoveBlip(b) end end)
end)


-- ============================
-- POSITION JOUEUR + VEHICULE (statebag)
-- ============================
CreateThread(function()
    while true do
        if onDuty then
            local ped  = PlayerPedId()
            local c    = GetEntityCoords(ped)
            local h    = GetEntityHeading(ped)
            local kind = 'foot'
            local entNet = NetworkGetNetworkIdFromEntity(ped)

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                c = GetEntityCoords(veh)
                h = GetEntityHeading(veh)
                kind = 'veh'
            end

            local pType = GetResourceKvpString('pop_police:patrolType')
            local pCs   = GetResourceKvpString('pop_police:callsign')
            local csName = nil
            if pType and pType ~= '' and pCs and pCs ~= '' then
                csName = pCs
            end

            local mat = GetResourceKvpString('pop_police:matricule')

            local hasRealVeh = false
            if currentPatrolVehNet then
                local pVeh = NetToVeh(currentPatrolVehNet)
                if pVeh ~= 0 and DoesEntityExist(pVeh) then
                    lastPatrolVehCoords = GetEntityCoords(pVeh)
                    hasRealVeh = true
                end
            else
                lastPatrolVehCoords = nil
            end

            local pVehX, pVehY, pVehZ = nil, nil, nil
            if lastPatrolVehCoords then
                pVehX, pVehY, pVehZ = lastPatrolVehCoords.x, lastPatrolVehCoords.y, lastPatrolVehCoords.z
            end

            TriggerServerEvent('pop_police:updatePos', {
                net = entNet,
                kind = kind,
                pVehNet = currentPatrolVehNet,
                x = c.x, y = c.y, z = c.z, h = h,
                pVehX = pVehX, pVehY = pVehY, pVehZ = pVehZ,
                hasRealVeh = hasRealVeh,
                cs = csName,
                mat = mat
            })
            Wait(Config.VehicleSyncInterval)
        else
            Wait(1000) 
        end
    end
end)

-- Synchronisation des positions depuis le serveur (Bypass OneSync)
RegisterNetEvent('pop_police:syncPositions', function(states)
  if not isPolice or not onDuty then return end
  globalOfficerStates = states
end)

-- ============================
-- GESTIONNAIRE UNIFIÉ DES BLIPS (Temps réel)
-- ============================
CreateThread(function()
  while true do
    Wait((isPolice and onDuty) and 500 or 1000) -- Actualisation "en direct" synchronisée avec le VehicleSyncInterval
    if isPolice and onDuty then
      
      -- 1. AGENTS ET PATROUILLES
      local activePatrols = {}
      local myServerId = GetPlayerServerId(PlayerId())

      for plyIdStr, pos in pairs(globalOfficerStates) do
        local plyId = tonumber(plyIdStr)
        if pos and plyId then
          
          -- MAJ BLIP AGENT
          if plyId ~= myServerId then
            local b = vehicleBlips[plyId]
            if not b or not DoesBlipExist(b) then
              b = AddBlipForCoord(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
              vehicleBlips[plyId] = b
              SetBlipSprite(b, 1)           
              SetBlipScale(b, 0.75)
              SetBlipCategory(b, 7)
              SetBlipColour(b, pos.cs and 38 or 3)
              SetBlipAsShortRange(b, false)
              ShowHeadingIndicatorOnBlip(b, true)
              BeginTextCommandSetBlipName('STRING')
              if pos.cs then
                if pos.mat and pos.mat ~= '' then AddTextComponentString('Unité ' .. pos.mat .. ' | ' .. pos.cs)
                else AddTextComponentString('Unité ' .. plyId .. ' | ' .. pos.cs) end
              elseif pos.mat and pos.mat ~= '' then AddTextComponentString('Unité ' .. pos.mat)
              else AddTextComponentString('Unité ' .. plyId) end
              EndTextCommandSetBlipName(b)
            else
              SetBlipCoords(b, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
              SetBlipRotation(b, math.floor(pos.h or 0.0))
              SetBlipColour(b, pos.cs and 38 or 3)
            end
          end

          -- RECUP POUR PATROUILLE
          if pos.cs and pos.pVehNet then
            local existing = activePatrols[pos.cs]
            -- Si on n'a pas encore de données, ou si ce joueur a l'entité du véhicule chargée (donc position plus précise/récente)
            if not existing or (pos.hasRealVeh and not existing.hasRealVeh) then
              activePatrols[pos.cs] = {
                vehNet = pos.pVehNet,
                x = pos.pVehX or pos.x, 
                y = pos.pVehY or pos.y, 
                z = pos.pVehZ or pos.z,
                hasRealVeh = pos.hasRealVeh
              }
            end
          end
        end
      end

      -- Nettoyage blips agents hors service ou déconnectés
      for plyIdStr, b in pairs(vehicleBlips) do
        local plyId = tonumber(plyIdStr)
        if not globalOfficerStates[plyId] and not globalOfficerStates[tostring(plyId)] then
          if DoesBlipExist(b) then RemoveBlip(b) end
          vehicleBlips[plyIdStr] = nil
        end
      end

      -- 2. BLIPS PATROUILLES
      for cs, data in pairs(patrolVehicleBlips) do
        if not activePatrols[cs] then
          if DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
          patrolVehicleBlips[cs] = nil
        end
      end

      for cs, req in pairs(activePatrols) do
        local pData = patrolVehicleBlips[cs]

        if not pData or not DoesBlipExist(pData.blip) then
          if pData and DoesBlipExist(pData.blip) then RemoveBlip(pData.blip) end
          
          local b = AddBlipForCoord(req.x + 0.0, req.y + 0.0, req.z + 0.0)
          SetBlipSprite(b, 137)       
          SetBlipColour(b, 38)        
          SetBlipScale(b, 0.85)
          SetBlipAsShortRange(b, false)
          BeginTextCommandSetBlipName('STRING')
          AddTextComponentString('Patrouille ' .. tostring(cs))
          EndTextCommandSetBlipName(b)
          
          patrolVehicleBlips[cs] = { blip = b }
        else
          SetBlipCoords(pData.blip, req.x + 0.0, req.y + 0.0, req.z + 0.0)
        end
      end

      -- 3. SUIVI DYNAMIQUE DES APPELS DE RENFORT
      for cid, call in pairs(activeCalls) do
        if not call.isGunshot and call.requesterSrc then
          local rSrc = tonumber(call.requesterSrc)
          local pos = globalOfficerStates[rSrc] or globalOfficerStates[tostring(rSrc)]
          if pos then
            local b = callBlips[cid]
            if b and DoesBlipExist(b) then
              SetBlipCoords(b, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
            end
          end
        end
      end

    end
  end
end)

-- Nettoyage blips quand on quitte le service ou job
AddEventHandler('onResourceStop', function(r)
  if r ~= GetCurrentResourceName() then return end
  ClearAllPoliceBlips()
end)

-- Réception de l'assignation ou de la dissolution d'une patrouille par un collègue
RegisterNetEvent('pop_police:assignedToPatrol', function(patrolData)
  local oldCs = GetResourceKvpString('pop_police:callsign')

  if patrolData then
    SetResourceKvp('pop_police:callsign', patrolData.callsign)
    SetResourceKvp('pop_police:patrolType', patrolData.type)
    SetResourceKvp('pop_police:patrolSector', patrolData.sector)
    SetResourceKvp('pop_police:patrolRadio', patrolData.radio)
    currentPatrolVehNet = patrolData.vehNet
  else
    DeleteResourceKvp('pop_police:patrolType')
    DeleteResourceKvp('pop_police:patrolSector')
    currentPatrolVehNet = nil
    
    if oldCs and patrolVehicleBlips[oldCs] then
      if DoesBlipExist(patrolVehicleBlips[oldCs].blip) then
        RemoveBlip(patrolVehicleBlips[oldCs].blip)
      end
      patrolVehicleBlips[oldCs] = nil
    end
  end

  SendNUIMessage({
    action   = 'myProfile',
    patrol   = patrolData or false,
    callsign = patrolData and patrolData.callsign or false
  })
end)

-- ============================
-- DÉTECTION DES COUPS DE FEU (Client)
-- ============================
local lastGunshotTime = 0

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()

        -- Vérifie si le joueur a une arme à feu en main (exclut le corps à corps)
        if IsPedArmed(ped, 4) then
            sleep = 0 -- Arme sortie, on écoute les tirs
            
            if IsPedShooting(ped) then
                -- On ignore les silencieux
                if not IsPedCurrentWeaponSilenced(ped) then
                    local now = GetGameTimer()
                    
                    -- Cooldown client de 15 secondes pour éviter le spam réseau
                    if now - lastGunshotTime > 15000 then 
                        lastGunshotTime = now
                        local coords = GetEntityCoords(ped)
                        
                        -- Ne déclenche pas l'alerte si c'est un policier en service
                        
                        TriggerServerEvent('pop_police:gunshotDetected', {x = coords.x, y = coords.y, z = coords.z})
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ============================
-- EXPORTS & API EXTERNE (CLIENT)
-- ============================

exports('createCall', function(level, label, coords, requesterName, callsign)
    -- Si les coords ne sont pas fournies, on prend la position actuelle du joueur
    if not coords then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        coords = { x = pos.x, y = pos.y, z = pos.z }
    end

    -- On relaie au serveur (qui gère la BDD et l'anti-spam)
    TriggerServerEvent('pop_police:server:createExternalCall', level, label, coords, requesterName, callsign)
end)