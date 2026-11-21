local ESX = exports['es_extended']:getSharedObject()
local resName = GetCurrentResourceName()

-- =====================================================================
--  PERMISSIONS
-- =====================================================================
-- Table de recherche construite une seule fois (au lieu de chaque appel)
local adminLookup = {}
for _, id in ipairs(type(Config.AdminIdentifiers) == 'table' and Config.AdminIdentifiers or {}) do
    adminLookup[string.lower(tostring(id))] = true
end

local function isIdentifierListed(src)
    local lookup = adminLookup
    if next(lookup) == nil then return false end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if lookup[string.lower(id)] then return true end
    end
    return false
end

local function IsAdmin(src)
    if src == 0 then return true end
    if isIdentifierListed(src) then return true end
    for _, ace in ipairs(Config.AcePermissions or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and Config.AdminGroups[xPlayer.getGroup()] then
        return true
    end
    return false
end

-- Permet aux autres ressources (ex: pop_doorlock) de réutiliser le MÊME check admin.
exports('IsAdmin', function(src)
    return IsAdmin(tonumber(src))
end)

local function notify(src, message, kind)
    TriggerClientEvent('pop_admin:notify', src, message, kind or 'info')
end

-- =====================================================================
--  BANS (persistés dans bans.json)
-- =====================================================================
local bans = {}

local function loadBans()
    local raw = LoadResourceFile(resName, 'bans.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then bans = decoded end
    end
end

local function saveBans()
    SaveResourceFile(resName, 'bans.json', json.encode(bans), -1)
end

loadBans()

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local b = bans[string.lower(id)]
        if b then
            if not b.expires or b.expires == 0 or b.expires > os.time() then
                deferrals.done(('Vous êtes banni : %s'):format(b.reason or 'aucune raison'))
                return
            else
                bans[string.lower(id)] = nil
                saveBans()
            end
        end
    end
    deferrals.done()
end)

-- =====================================================================
--  DOUBLE PERSONNAGE (STAFF) — persistés dans staff_characters.json
--  staffChars[<license>] = { { id, label, name, sex, skin, savedAt }, ... }
-- =====================================================================
local staffChars = {}

local function loadStaffChars()
    local raw = LoadResourceFile(resName, 'staff_characters.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then staffChars = decoded end
    end
end

local function saveStaffChars()
    SaveResourceFile(resName, 'staff_characters.json', json.encode(staffChars), -1)
end

loadStaffChars()

-- Identifiant principal (license:) servant de clé de stockage.
local function getMainIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getIdentifier then
        local id = xPlayer.getIdentifier()
        if id and id ~= '' then return id end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return nil
end

-- Version légère (sans la grosse data skin) envoyée à la NUI.
local function publicCharList(list)
    local out = {}
    for _, c in ipairs(list or {}) do
        out[#out + 1] = {
            id = c.id, label = c.label, name = c.name,
            sex = c.sex, savedAt = c.savedAt,
        }
    end
    return out
end

local function sendStaffChars(src)
    local id = getMainIdentifier(src)
    local list = (id and staffChars[id]) or {}
    TriggerClientEvent('pop_admin:chars:receive', src, publicCharList(list))
end

RegisterNetEvent('pop_admin:chars:request', function()
    local src = source
    if not IsAdmin(src) then return end
    sendStaffChars(src)
end)

RegisterNetEvent('pop_admin:chars:save', function(payload)
    local src = source
    if not IsAdmin(src) then return end
    if type(payload) ~= 'table' or type(payload.skin) ~= 'table' then return end
    local id = getMainIdentifier(src)
    if not id then notify(src, 'Identifiant introuvable', 'error'); return end

    local xPlayer = ESX.GetPlayerFromId(src)
    local label = tostring(payload.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    label = label:sub(1, 40)
    if label == '' then label = ('Perso %s'):format(os.date('%d/%m %H:%M')) end

    staffChars[id] = staffChars[id] or {}
    local nextId = 1
    for _, c in ipairs(staffChars[id]) do
        if tonumber(c.id) and c.id >= nextId then nextId = c.id + 1 end
    end

    staffChars[id][#staffChars[id] + 1] = {
        id      = nextId,
        label   = label,
        name    = xPlayer and xPlayer.getName() or nil,
        sex     = payload.skin.sex,
        skin    = payload.skin,
        savedAt = os.time(),
    }
    saveStaffChars()
    notify(src, ('Personnage « %s » sauvegardé'):format(label), 'success')
    sendStaffChars(src)
end)

RegisterNetEvent('pop_admin:chars:delete', function(charId)
    local src = source
    if not IsAdmin(src) then return end
    local id = getMainIdentifier(src)
    if not id or not staffChars[id] then return end
    charId = tonumber(charId)
    for i, c in ipairs(staffChars[id]) do
        if c.id == charId then
            table.remove(staffChars[id], i)
            break
        end
    end
    if #staffChars[id] == 0 then staffChars[id] = nil end
    saveStaffChars()
    notify(src, 'Personnage supprimé', 'success')
    sendStaffChars(src)
end)

RegisterNetEvent('pop_admin:chars:load', function(charId)
    local src = source
    if not IsAdmin(src) then return end
    local id = getMainIdentifier(src)
    if not id or not staffChars[id] then return end
    charId = tonumber(charId)
    for _, c in ipairs(staffChars[id]) do
        if c.id == charId then
            TriggerClientEvent('pop_admin:chars:apply', src, c.skin, c.label)
            return
        end
    end
end)

-- =====================================================================
--  LOGS DE DÉCONNEXION (pourquoi un joueur quitte : Alt+F4, timeout, kick…)
--  Persistés dans disconnect_logs.json (plus récent en premier).
-- =====================================================================
local discoLogs = {}
local MAX_LOGS = tonumber(Config.LogsMax) or 300

-- Marqueur temporaire posé lors d'un kick/ban admin pour enrichir le log.
local recentKickBan = {}

local function loadLogs()
    local raw = LoadResourceFile(resName, 'disconnect_logs.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then discoLogs = decoded end
    end
end

local function saveLogs()
    SaveResourceFile(resName, 'disconnect_logs.json', json.encode(discoLogs), -1)
end

loadLogs()

-- Catégorise la raison brute renvoyée par FiveM.
-- Retourne (clé, libellé). Alt+F4 / fermeture du jeu remontent en "quit".
local function categorizeDrop(reason)
    local r = string.lower(tostring(reason or ''))
    if r:find('banni') or r:find('banned') then return 'ban', 'Banni' end
    if r:find('expuls') or r:find('kick') then return 'kick', 'Expulsé' end
    if r:find('crash') then return 'crash', 'Crash' end
    if r:find('timed out') or r:find('timeout') or r:find('connection') then return 'timeout', 'Timeout' end
    if r:find('exiting') or r:find('disconnect') or r:find('quit') then return 'quit', 'Quitté (Alt+F4 / fermeture)' end
    return 'other', 'Autre'
end

-- Appelé par les actions kick/ban pour attribuer la déconnexion à un admin.
local function markKickBan(target, kind, by, reason)
    target = tonumber(target)
    if not target then return end
    recentKickBan[target] = { kind = kind, by = by, reason = reason, at = os.time() }
end

local function addLog(entry)
    table.insert(discoLogs, 1, entry)
    while #discoLogs > MAX_LOGS do
        table.remove(discoLogs, #discoLogs)
    end
    saveLogs()
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    local name = GetPlayerName(src) or ('Joueur ' .. src)
    local ident = getMainIdentifier(src)

    -- Position au moment du départ (best-effort, le ped peut déjà être parti).
    local x, y, z
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        if c and (c.x ~= 0.0 or c.y ~= 0.0) then x, y, z = c.x, c.y, c.z end
    end

    local cat, catLabel = categorizeDrop(reason)
    local by

    local mark = recentKickBan[src]
    if mark then
        recentKickBan[src] = nil
        if mark.kind == 'ban' then cat, catLabel = 'ban', 'Banni'
        elseif mark.kind == 'kick' then cat, catLabel = 'kick', 'Expulsé' end
        by = mark.by
        if mark.reason and mark.reason ~= '' then reason = mark.reason end
    end

    addLog({
        time     = os.time(),
        name     = name,
        id       = src,
        ident    = ident,
        category = cat,
        catLabel = catLabel,
        reason   = tostring(reason or ''),
        by       = by,
        x = x, y = y, z = z,
    })
end)

RegisterNetEvent('pop_admin:logs:request', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('pop_admin:logs:receive', src, discoLogs)
end)

RegisterNetEvent('pop_admin:logs:clear', function()
    local src = source
    if not IsAdmin(src) then return end
    discoLogs = {}
    saveLogs()
    notify(src, 'Logs de déconnexion vidés', 'success')
    TriggerClientEvent('pop_admin:logs:receive', src, discoLogs)
end)

-- =====================================================================
--  ACCÈS CLIENT
-- =====================================================================
RegisterNetEvent('pop_admin:requestAccess', function(openAfter)
    local src = source
    TriggerClientEvent('pop_admin:setAccess', src, IsAdmin(src), openAfter == true)
end)

-- Changement de groupe (menu admin, /setgroup ESX, txAdmin...) : on met à jour
-- l'accès du joueur tout de suite, sans qu'il ait à se reconnecter.
AddEventHandler('esx:setGroup', function(playerId)
    playerId = tonumber(playerId)
    if playerId then
        SetTimeout(200, function()
            TriggerClientEvent('pop_admin:setAccess', playerId, IsAdmin(playerId), false)
        end)
    end
end)

-- =====================================================================
--  LISTE DES JOUEURS
-- =====================================================================
RegisterNetEvent('pop_admin:requestPlayers', function()
    local src = source
    if not IsAdmin(src) then return end
    local list = {}
    local xPlayers = ESX.GetExtendedPlayers()
    for i = 1, #xPlayers do
        local xPlayer = xPlayers[i]
        local id = xPlayer.source
        local ped = GetPlayerPed(id)
        local coords = ped and GetEntityCoords(ped) or vector3(0, 0, 0)
        local job = xPlayer.getJob()
        list[#list + 1] = {
            id        = id,
            name      = xPlayer.getName(),
            job       = job.name,
            jobLabel  = job.label,
            grade     = job.grade_label,
            group     = xPlayer.getGroup(),
            ping      = GetPlayerPing(id),
            x = coords.x, y = coords.y, z = coords.z,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    TriggerClientEvent('pop_admin:receivePlayers', src, list)
end)

-- =====================================================================
--  ACTIONS SUR JOUEUR
-- =====================================================================
local function getTarget(data)
    local id = tonumber(data.target)
    if not id then return nil end
    return ESX.GetPlayerFromId(id)
end

RegisterNetEvent('pop_admin:playerAction', function(data)
    local src = source
    if not IsAdmin(src) then return end
    if type(data) ~= 'table' then return end
    local action = data.action
    local xAdmin = ESX.GetPlayerFromId(src)
    local xTarget = getTarget(data)

    if action == 'goto' then
        if not xTarget then return end
        local c = xTarget.getCoords(true)
        SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(xTarget.source))
        xAdmin.setCoords(c)
        notify(src, ('Téléporté vers %s'):format(xTarget.getName()), 'success')

    elseif action == 'bring' then
        if not xTarget then return end
        local c = xAdmin.getCoords(true)
        SetPlayerRoutingBucket(xTarget.source, GetPlayerRoutingBucket(src))
        xTarget.setCoords(c)
        notify(src, ('%s amené à vous'):format(xTarget.getName()), 'success')

    elseif action == 'freeze' then
        if not xTarget then return end
        xTarget.triggerEvent('esx:freezePlayer', 'freeze')
        notify(src, ('%s gelé'):format(xTarget.getName()), 'success')

    elseif action == 'unfreeze' then
        if not xTarget then return end
        xTarget.triggerEvent('esx:freezePlayer', 'unfreeze')
        notify(src, ('%s dégelé'):format(xTarget.getName()), 'success')

    elseif action == 'heal' then
        if not xTarget then return end
        TriggerClientEvent('pop_admin:heal', xTarget.source)
        notify(src, ('%s soigné'):format(xTarget.getName()), 'success')

    elseif action == 'revive' then
        if not xTarget then return end
        TriggerClientEvent('pop_admin:revive', xTarget.source)
        notify(src, ('%s réanimé'):format(xTarget.getName()), 'success')

    elseif action == 'kill' then
        if not xTarget then return end
        xTarget.triggerEvent('esx:killPlayer')
        notify(src, ('%s tué'):format(xTarget.getName()), 'success')

    elseif action == 'kick' then
        if not xTarget then return end
        local reason = tostring(data.reason or 'Expulsé par un administrateur')
        markKickBan(xTarget.source, 'kick', xAdmin and xAdmin.getName() or 'Admin', reason)
        DropPlayer(tostring(xTarget.source), reason)
        notify(src, ('%s expulsé'):format(xTarget.getName()), 'success')

    elseif action == 'ban' then
        if not xTarget then return end
        local reason = tostring(data.reason or 'Banni par un administrateur')
        local minutes = tonumber(data.minutes) or 0
        local expires = minutes > 0 and (os.time() + minutes * 60) or 0
        for _, id in ipairs(GetPlayerIdentifiers(xTarget.source) or {}) do
            bans[string.lower(id)] = {
                reason = reason, by = xAdmin.getName(),
                name = xTarget.getName(), expires = expires, date = os.time(),
            }
        end
        saveBans()
        markKickBan(xTarget.source, 'ban', xAdmin and xAdmin.getName() or 'Admin', ('Banni : %s'):format(reason))
        DropPlayer(tostring(xTarget.source), ('Banni : %s'):format(reason))
        notify(src, ('%s banni'):format(xTarget.getName()), 'success')

    elseif action == 'money' then
        if not xTarget then return end
        local account = tostring(data.account or 'money')
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount == 0 then return end
        -- Le cash est un objet de l'inventaire (pop_inventory), pas le compte ESX « money ».
        if account == 'money' and GetResourceState('pop_inventory') == 'started' then
            local ok
            if amount > 0 then
                ok = exports['pop_inventory']:GiveItem(xTarget.source, 'cash', amount)
            else
                ok = exports['pop_inventory']:removeItem(xTarget.source, 'cash', -amount)
            end
            notify(src, ok and ('%s : %s%s$ (cash)'):format(xTarget.getName(), amount > 0 and '+' or '', amount) or 'Pas assez de cash à retirer', ok and 'success' or 'error')
            return
        end
        if not xTarget.getAccount(account) then notify(src, 'Compte invalide', 'error'); return end
        if amount > 0 then
            xTarget.addAccountMoney(account, amount, 'pop_admin')
        else
            xTarget.removeAccountMoney(account, -amount, 'pop_admin')
        end
        notify(src, ('%s : %s%s%s'):format(xTarget.getName(), amount > 0 and '+' or '', amount, account), 'success')

    elseif action == 'setjob' then
        if not xTarget then return end
        local job = tostring(data.job or '')
        local grade = tonumber(data.grade) or 0
        if not ESX.DoesJobExist(job, grade) then
            notify(src, 'Job/grade invalide', 'error'); return
        end
        xTarget.setJob(job, grade)
        notify(src, ('%s → %s (%d)'):format(xTarget.getName(), job, grade), 'success')

    elseif action == 'setgroup' then
        if not xTarget then return end
        local group = tostring(data.group or 'user')
        xTarget.setGroup(group)
        -- Enregistré tout de suite en base : ESX ne sauvegarde qu'à la déconnexion
        -- ou toutes les 10 min, donc un restart juste après faisait perdre le groupe.
        MySQL.update('UPDATE `users` SET `group` = ? WHERE `identifier` = ?', { group, xTarget.identifier })
        TriggerClientEvent('pop_admin:setAccess', xTarget.source, IsAdmin(xTarget.source), false)
        notify(src, ('%s → groupe %s'):format(xTarget.getName(), group), 'success')

    elseif action == 'giveitem' then
        if not xTarget then return end
        local item = tostring(data.item or '')
        local qty = tonumber(data.qty) or 1
        if item == '' then return end
        if GetResourceState('pop_inventory') == 'started' then
            local ok = pcall(function()
                return exports['pop_inventory']:GiveItem(xTarget.source, item, qty)
            end)
            if ok then
                notify(src, ('Donné %dx %s à %s'):format(qty, item, xTarget.getName()), 'success')
            else
                notify(src, 'Échec du give (item invalide ?)', 'error')
            end
        else
            xTarget.addInventoryItem(item, qty)
            notify(src, ('Donné %dx %s'):format(qty, item), 'success')
        end
    end
end)

-- =====================================================================
--  GIVE ITEM À SOI-MÊME (menu rapide / onglet items)
-- =====================================================================
RegisterNetEvent('pop_admin:giveSelf', function(item, qty)
    local src = source
    if not IsAdmin(src) then return end
    item = tostring(item or '')
    qty = tonumber(qty) or 1
    if item == '' then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if GetResourceState('pop_inventory') == 'started' then
        pcall(function() exports['pop_inventory']:GiveItem(src, item, qty) end)
    else
        xPlayer.addInventoryItem(item, qty)
    end
    notify(src, ('Reçu %dx %s'):format(qty, item), 'success')
end)

-- =====================================================================
--  TEMPS & MÉTÉO (style easytime)
-- =====================================================================
local timeWeather = {
    hour    = Config.DefaultTime.hour or 12,
    minute  = Config.DefaultTime.minute or 0,
    frozen  = Config.DefaultTime.frozen == true,
    weather = Config.DefaultWeather or 'EXTRASUNNY',
    blackout = false,
}

local function broadcastTimeWeather()
    TriggerClientEvent('pop_admin:syncTimeWeather', -1, timeWeather)
end

RegisterNetEvent('pop_admin:requestTimeWeather', function()
    TriggerClientEvent('pop_admin:syncTimeWeather', source, timeWeather)
end)

RegisterNetEvent('pop_admin:setTime', function(hour, minute, frozen)
    local src = source
    if not IsAdmin(src) then return end
    timeWeather.hour = math.floor(tonumber(hour) or 12) % 24
    timeWeather.minute = math.floor(tonumber(minute) or 0) % 60
    if frozen ~= nil then timeWeather.frozen = frozen == true end
    broadcastTimeWeather()
    notify(src, ('Heure : %02d:%02d %s'):format(timeWeather.hour, timeWeather.minute,
        timeWeather.frozen and '(figée)' or '(réelle)'), 'success')
end)

RegisterNetEvent('pop_admin:freezeTime', function(frozen)
    local src = source
    if not IsAdmin(src) then return end
    timeWeather.frozen = frozen == true
    broadcastTimeWeather()
    notify(src, timeWeather.frozen and 'Temps figé' or 'Temps réel', 'success')
end)

RegisterNetEvent('pop_admin:setWeather', function(weather)
    local src = source
    if not IsAdmin(src) then return end
    weather = tostring(weather or ''):upper()
    local valid = false
    for _, w in ipairs(Config.Weathers) do if w == weather then valid = true break end end
    if not valid then return end
    timeWeather.weather = weather
    broadcastTimeWeather()
    notify(src, ('Météo : %s'):format(weather), 'success')
end)

RegisterNetEvent('pop_admin:setBlackout', function(state)
    local src = source
    if not IsAdmin(src) then return end
    timeWeather.blackout = state == true
    broadcastTimeWeather()
    notify(src, timeWeather.blackout and 'Blackout activé' or 'Blackout désactivé', 'success')
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    TriggerClientEvent('pop_admin:syncTimeWeather', playerId, timeWeather)
end)

-- Avance l'horloge serveur quand le temps n'est pas figé (1 min IG / ~2 s réelles).
-- Les clients avancent l'heure localement au même rythme : on ne resynchronise
-- tout le monde qu'une fois par minute réelle (au lieu de toutes les 2 s).
CreateThread(function()
    local ticks = 0
    while true do
        Wait(2000)
        if not timeWeather.frozen then
            timeWeather.minute = timeWeather.minute + 1
            if timeWeather.minute >= 60 then
                timeWeather.minute = 0
                timeWeather.hour = (timeWeather.hour + 1) % 24
            end
            ticks = ticks + 1
            if ticks >= 30 then
                ticks = 0
                broadcastTimeWeather()
            end
        end
    end
end)

-- =====================================================================
--  VÉHICULES PERSISTANTS
-- =====================================================================
RegisterNetEvent('pop_admin:requestVehicles', function()
    local src = source
    if not IsAdmin(src) then return end
    MySQL.query('SELECT plate, owner_id, vehicle_data, last_seen FROM persistent_vehicles', {}, function(rows)
        local list = {}
        if type(rows) == 'table' then
            for _, row in ipairs(rows) do
                local data = row.vehicle_data and json.decode(row.vehicle_data) or nil
                if data then
                    list[#list + 1] = {
                        plate = row.plate,
                        owner = row.owner_id,
                        model = data.model,
                        x = data.x, y = data.y, z = data.z,
                        lastSeen = tonumber(row.last_seen) or 0,
                    }
                end
            end
        end
        table.sort(list, function(a, b) return (a.plate or '') < (b.plate or '') end)
        TriggerClientEvent('pop_admin:receiveVehicles', src, list)
    end)
end)

RegisterNetEvent('pop_admin:deleteVehicle', function(plate)
    local src = source
    if not IsAdmin(src) then return end
    plate = string.upper(string.gsub(tostring(plate or ''), '%s+', ''))
    if plate == '' then return end
    MySQL.update('DELETE FROM persistent_vehicles WHERE plate = ?', { plate }, function()
        notify(src, ('Véhicule %s supprimé'):format(plate), 'success')
        TriggerClientEvent('pop_admin:vehicleDeleted', src, plate)
    end)
end)

-- =====================================================================
--  JOBS (catalogue, lu depuis la DB)
-- =====================================================================
local function sendJobs(target)
    MySQL.query('SELECT name, label FROM jobs ORDER BY label ASC', {}, function(jobsRows)
        local jobs, byName = {}, {}
        if type(jobsRows) == 'table' then
            for _, row in ipairs(jobsRows) do
                local j = { name = row.name, label = row.label or row.name, grades = {} }
                jobs[#jobs + 1] = j
                byName[row.name] = j
            end
        end
        MySQL.query('SELECT job_name, grade, label FROM job_grades ORDER BY grade ASC', {}, function(gradeRows)
            if type(gradeRows) == 'table' then
                for _, row in ipairs(gradeRows) do
                    local owner = byName[row.job_name]
                    if owner then
                        owner.grades[#owner.grades + 1] = {
                            grade = tonumber(row.grade) or 0,
                            label = row.label or tostring(row.grade),
                        }
                    end
                end
            end
            TriggerClientEvent('pop_admin:receiveJobs', target, jobs)
        end)
    end)
end

RegisterNetEvent('pop_admin:requestJobs', function()
    local src = source
    if not IsAdmin(src) then return end
    sendJobs(src)
end)

local function refreshJobsAndReply(src)
    if type(ESX.RefreshJobs) == 'function' then pcall(ESX.RefreshJobs) end
    SetTimeout(500, function() sendJobs(src) end)
end

RegisterNetEvent('pop_admin:jobSetSelf', function(jobName, grade)
    local src = source
    if not IsAdmin(src) then return end
    grade = tonumber(grade) or 0
    if not ESX.DoesJobExist(jobName, grade) then
        notify(src, 'Job/grade invalide', 'error'); return
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        xPlayer.setJob(jobName, grade)
        notify(src, ('Vous êtes : %s (%d)'):format(jobName, grade), 'success')
    end
end)

RegisterNetEvent('pop_admin:jobCreate', function(name, label)
    local src = source
    if not IsAdmin(src) then return end
    if type(name) ~= 'string' or name == '' or type(label) ~= 'string' or label == '' then return end
    name = name:gsub('%s+', ''):lower()
    MySQL.update('INSERT IGNORE INTO jobs (name, label) VALUES (?, ?)', { name, label }, function()
        MySQL.update("INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES (?, 0, 'recrue', 'Recrue', 100)", { name }, function()
            MySQL.update("INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES (?, 4, 'boss', 'Patron', 1000)", { name }, function()
                MySQL.update('INSERT IGNORE INTO addon_account (name, label, shared) VALUES (?, ?, 1)', { 'society_' .. name, label })
                MySQL.update('INSERT IGNORE INTO addon_account_data (account_name, money, owner) VALUES (?, 0, NULL)', { 'society_' .. name })
                if ESX.Jobs then
                    ESX.Jobs[name] = { label = label, grades = {
                        ['0'] = { job_name = name, grade = 0, name = 'recrue', label = 'Recrue', salary = 100, skin_male = {}, skin_female = {} },
                        ['4'] = { job_name = name, grade = 4, name = 'boss', label = 'Patron', salary = 1000, skin_male = {}, skin_female = {} },
                    } }
                end
                notify(src, ('Job créé : %s'):format(label), 'success')
                refreshJobsAndReply(src)
            end)
        end)
    end)
end)

RegisterNetEvent('pop_admin:jobAddGrade', function(jobName, level, gname, glabel, salary)
    local src = source
    if not IsAdmin(src) then return end
    if type(jobName) ~= 'string' or jobName == '' then return end
    level = tonumber(level) or 0
    salary = tonumber(salary) or 0
    if type(gname) ~= 'string' or gname == '' or type(glabel) ~= 'string' or glabel == '' then return end
    MySQL.update('DELETE FROM job_grades WHERE job_name = ? AND grade = ?', { jobName, level }, function()
        MySQL.update("INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, '{}', '{}')",
            { jobName, level, gname, glabel, salary }, function()
            if ESX.Jobs and ESX.Jobs[jobName] then
                ESX.Jobs[jobName].grades = ESX.Jobs[jobName].grades or {}
                ESX.Jobs[jobName].grades[tostring(level)] = {
                    job_name = jobName, grade = level, name = gname, label = glabel,
                    salary = salary, skin_male = {}, skin_female = {},
                }
            end
            notify(src, ('Grade ajouté : %s (%d)'):format(glabel, level), 'success')
            refreshJobsAndReply(src)
        end)
    end)
end)

RegisterNetEvent('pop_admin:jobSociety', function(jobName, amount)
    local src = source
    if not IsAdmin(src) then return end
    if type(jobName) ~= 'string' or jobName == '' then return end
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local accountName = 'society_' .. jobName
    local done = false
    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        if account then account.addMoney(amount); done = true end
    end)
    if not done then
        MySQL.update('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, ?, NULL) ON DUPLICATE KEY UPDATE money = money + ?',
            { accountName, amount, amount })
    end
    notify(src, ('+%d$ → %s'):format(amount, accountName), 'success')
end)

RegisterNetEvent('pop_admin:jobDelete', function(jobName)
    local src = source
    if not IsAdmin(src) then return end
    if type(jobName) ~= 'string' or jobName == '' then return end
    jobName = jobName:lower()
    if jobName == 'unemployed' then
        notify(src, "Le job 'unemployed' ne peut pas être supprimé", 'error'); return
    end
    local accountName = 'society_' .. jobName
    MySQL.update("UPDATE users SET job = 'unemployed', job_grade = 0 WHERE job = ?", { jobName }, function()
        MySQL.update("UPDATE users SET job2 = 'unemployed', job2_grade = 0 WHERE job2 = ?", { jobName })
        MySQL.update('DELETE FROM job_grades WHERE job_name = ?', { jobName }, function()
            MySQL.update('DELETE FROM jobs WHERE name = ?', { jobName }, function()
                MySQL.update('DELETE FROM addon_account_data WHERE account_name = ?', { accountName })
                MySQL.update('DELETE FROM addon_account WHERE name = ?', { accountName })
                if ESX.Jobs then ESX.Jobs[jobName] = nil end
                for _, pid in ipairs(GetPlayers()) do
                    local xp = ESX.GetPlayerFromId(tonumber(pid))
                    if xp and xp.job and xp.job.name == jobName then
                        pcall(function() xp.setJob('unemployed', 0) end)
                    end
                end
                notify(src, ('Job supprimé : %s'):format(jobName), 'success')
                refreshJobsAndReply(src)
            end)
        end)
    end)
end)

-- =====================================================================
--  DIAGNOSTIC « Cleaning stale player entry » (ESX bloqué à la connexion)
--  Si un joueur déconnecté est encore en mémoire ESX 20 s plus tard, c'est que
--  la sauvegarde ESX de fin de session échoue en boucle. On rejoue chaque étape
--  de cette sauvegarde pour trouver laquelle plante, et on l'écrit dans
--  diag_save.log (lisible depuis GitHub, outil serveur « logs »).
-- =====================================================================
local function diagWrite(lines)
    local old = LoadResourceFile(resName, 'diag_save.log') or ''
    local text = old .. table.concat(lines, '\n') .. '\n\n'
    if #text > 60000 then text = text:sub(-60000) end
    SaveResourceFile(resName, 'diag_save.log', text, -1)
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local identifier, name = xPlayer.identifier, xPlayer.getName()
    SetTimeout(20000, function()
        local stale = ESX.GetPlayerFromIdentifier(identifier)
        if not stale then return end
        local lines = { ('[%s] Joueur encore en mémoire ESX 20 s après sa déconnexion : %s (raison : %s)'):format(os.date('%Y-%m-%d %H:%M:%S'), tostring(name), tostring(reason)) }
        local steps = {
            { 'accounts', function() return json.encode(stale.getAccounts(true)) end },
            { 'job', function() return tostring(stale.job and stale.job.name) .. ' / ' .. tostring(stale.job and stale.job.grade) end },
            { 'group', function() return tostring(stale.group) end },
            { 'coords', function() return json.encode(stale.getCoords(false, true)) end },
            { 'inventory', function() return json.encode(stale.getInventory(true)) end },
            { 'loadout', function() return json.encode(stale.getLoadout(true)) end },
            { 'metadata', function() return json.encode(stale.getMeta()) end },
            { 'pendingOps', function() return tostring(stale.getPendingAccountOperations and stale.getPendingAccountOperations()) end },
        }
        for _, step in ipairs(steps) do
            local ok, res = pcall(step[2])
            local value = tostring(res)
            if #value > 300 then value = value:sub(1, 300) .. '…' end
            lines[#lines + 1] = ('  %s : %s %s'):format(step[1], ok and 'OK' or 'ERREUR', value)
        end
        print('^1[pop_admin] DIAG sauvegarde ESX bloquée :^7\n' .. table.concat(lines, '\n'))
        diagWrite(lines)
    end)
end)

-- Test de la sauvegarde ESX : 60 s après le chargement d'un joueur, on rejoue la
-- requête de sauvegarde d'ESX (mêmes valeurs) et on note le résultat ou l'erreur
-- SQL dans diag_save.log. Permet de voir si les sauvegardes ESX fonctionnent.
local SAVE_QUERY = 'UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ? WHERE `identifier` = ?'
AddEventHandler('esx:playerLoaded', function(playerId)
    SetTimeout(60000, function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        local okParams, params = pcall(function()
            return {
                json.encode(xPlayer.getAccounts(true)), xPlayer.job.name, xPlayer.job.grade, xPlayer.group,
                json.encode(xPlayer.getCoords(false, true)), json.encode(xPlayer.getInventory(true)),
                json.encode(xPlayer.getLoadout(true)), json.encode(xPlayer.getMeta()), xPlayer.identifier,
            }
        end)
        local line
        if not okParams then
            line = ('ERREUR en préparant la sauvegarde : %s'):format(tostring(params))
        else
            local ok, res = pcall(MySQL.update.await, SAVE_QUERY, params)
            line = ok and ('requête OK (lignes modifiées : %s)'):format(tostring(res)) or ('ERREUR SQL : %s'):format(tostring(res))
        end
        diagWrite({ ('[%s] Test sauvegarde ESX pour %s (groupe %s) : %s'):format(os.date('%Y-%m-%d %H:%M:%S'), xPlayer.getName(), tostring(xPlayer.group), line) })
    end)
end)
