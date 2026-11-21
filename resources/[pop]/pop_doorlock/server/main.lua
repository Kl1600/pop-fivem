-- TAB Doorlock | Doorbuilder edition --

local resName = GetCurrentResourceName()

local doors      = {}   -- doorId -> { model, coords{x,y,z}, distance, item, key, jobs }
local doorState  = {}   -- doorId -> bool (true = verrouillée)
local groupsById = {}   -- gid -> { label, item, key, distance, locked, jobs, source, configIndex, doorIds = {} }
local nextDoorId = 1
local nextGid    = 1

-- =====================================================================
--  OVERRIDES DES GROUPES "config.lua" (on ne modifie jamais config.lua)
--  [configIndex] = { disabled, label, distance, locked, key, removedDoors = { [doorKey]=true } }
-- =====================================================================
local configOverrides = {}

local function doorKey(model, coords)
    return tostring(model) .. ':' .. math.floor(coords.x * 100) .. ':' .. math.floor(coords.y * 100) .. ':' .. math.floor(coords.z * 100)
end

local function loadOverrides()
    local raw = LoadResourceFile(resName, 'overrides.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for idx, ov in pairs(decoded) do
                configOverrides[tonumber(idx)] = ov
            end
        end
    end
end

local function persistOverrides()
    SaveResourceFile(resName, 'overrides.json', json.encode(configOverrides, { indent = true }), -1)
end

local function getOverride(configIndex)
    if not configIndex then return nil end
    local ov = configOverrides[configIndex]
    if not ov then
        ov = { removedDoors = {} }
        configOverrides[configIndex] = ov
    end
    if not ov.removedDoors then ov.removedDoors = {} end
    return ov
end

-- =====================================================================
--  ENREGISTREMENT D'UN GROUPE  (format Config.Doors : champs capitalisés)
-- =====================================================================
local function registerGroup(group, source, configIndex)
    local ov = (source == 'config') and configOverrides[configIndex] or nil
    if ov and ov.disabled then return nil end

    local gid = nextGid
    nextGid = nextGid + 1

    local locked = group.Locked
    if locked == nil then locked = true end
    if ov and ov.locked ~= nil then locked = ov.locked end

    local g = {
        label    = (ov and ov.label) or group.Label or group.Item or ('Groupe ' .. gid),
        item     = group.Item or false,                       -- (legacy) item simple via getItemCount
        key      = (ov and ov.key) or group.Key or false,      -- id stable -> meta.doorgroup de l'item 'cle'
        distance = (ov and ov.distance) or group.Distance or 2.5,
        locked   = locked,
        jobs     = group.Jobs,
        source   = source,          -- 'config' (issu de config.lua) | 'json' (créé au builder)
        configIndex = configIndex,
        doorIds  = {},
    }

    local removedDoors = ov and ov.removedDoors or {}

    for _, door in ipairs(group.Doors or {}) do
        local c = door.Coords
        local coords = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
        if not removedDoors[doorKey(door.Model, coords)] then
            local id = nextDoorId
            nextDoorId = nextDoorId + 1
            doors[id] = {
                model    = door.Model,
                coords   = coords,
                distance = g.distance,
                item     = g.item,
                key      = g.key,
                jobs     = g.jobs,
            }
            doorState[id] = locked
            g.doorIds[#g.doorIds + 1] = id
        end
    end

    groupsById[gid] = g
    return gid
end

-- =====================================================================
--  PERSISTANCE (groupes 'json' uniquement ; les groupes 'config' passent
--  par configOverrides pour ne jamais toucher config.lua)
-- =====================================================================
local function persist()
    local out = {}
    for _, g in pairs(groupsById) do
        if g.source == 'json' then
            local entry = {
                Label    = g.label,
                Item     = g.item,
                Key      = g.key,
                Distance = g.distance,
                Locked   = g.locked,
                Jobs     = false,
                Doors    = {},
            }
            for _, id in ipairs(g.doorIds) do
                local d = doors[id]
                entry.Doors[#entry.Doors + 1] = { Model = d.model, Coords = d.coords }
            end
            out[#out + 1] = entry
        end
    end
    SaveResourceFile(resName, 'doors.json', json.encode(out, { indent = true }), -1)
end

-- =====================================================================
--  INIT : Config.Doors (statique + overrides) puis doors.json (builder)
-- =====================================================================
CreateThread(function()
    loadOverrides()
    for i, group in ipairs(Config.Doors) do
        registerGroup(group, 'config', i)
    end

    local raw = LoadResourceFile(resName, 'doors.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for _, group in ipairs(decoded) do
                registerGroup(group, 'json')
            end
        end
    end

    print(('[pop_doorlock] %s porte(s) chargée(s) sur %s groupe(s).'):format(nextDoorId - 1, nextGid - 1))
end)

-- =====================================================================
--  PERMISSIONS ADMIN (logique pop_admin)
-- =====================================================================
local function isIdentifierListed(src)
    if type(Config.AdminIdentifiers) ~= 'table' or #Config.AdminIdentifiers == 0 then
        return false
    end
    local lookup = {}
    for _, id in ipairs(Config.AdminIdentifiers) do
        lookup[string.lower(tostring(id))] = true
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if lookup[string.lower(id)] then return true end
    end
    return false
end

local function isAdmin(src)
    if src == 0 then return true end

    -- 1) On réutilise le check de pop_admin (même liste d'admins) si dispo.
    if GetResourceState('pop_admin') == 'started' then
        local ok, res = pcall(function() return exports.pop_admin:IsAdmin(src) end)
        if ok and res ~= nil then return res == true end
    end

    -- 2) Fallback : config locale pop_doorlock.
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

-- =====================================================================
--  CONTRÔLE D'ACCÈS (serveur autoritaire)
-- =====================================================================
-- le joueur possède-t-il une clé ('cle') dont la métadonnée vise ce groupe ?
local function hasDoorKey(src, keyId)
    local ok, items = pcall(function()
        return exports.pop_inventory:GetPlayerItems(src, Config.KeyItem)
    end)
    if not ok or type(items) ~= 'table' then return false end
    for _, item in ipairs(items) do
        if item.meta and item.meta.doorgroup == keyId then
            return true
        end
    end
    return false
end

local function playerHasAccess(src, doorId)
    local d = doors[doorId]
    if not d then return false end

    -- 1) Clé à métadonnée (item 'cle' + meta.doorgroup) : système Doorbuilder
    if d.key and d.key ~= '' then
        return hasDoorKey(src, d.key)
    end

    -- 2) Item simple (legacy, via getItemCount)
    if d.item and d.item ~= '' then
        local count = exports.pop_inventory:getItemCount(src, d.item) or 0
        return count > 0
    end

    -- 3) Jobs
    local jobs = d.jobs
    if jobs == false or jobs == nil then return true end
    if jobs == true then return false end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
    if not job then return false end

    if type(jobs) == 'table' then
        for _, j in ipairs(jobs) do
            if job.name == j then return true end
        end
        return false
    end
    return job.name == jobs
end

-- =====================================================================
--  RUNTIME : liste des portes + changement d'état
-- =====================================================================
ESX.RegisterServerCallback('pop_doorlock:getDoors', function(source, cb)
    local list = {}
    for id, d in pairs(doors) do
        list[#list + 1] = {
            id       = id,
            model    = d.model,
            coords   = d.coords,
            distance = d.distance,
            item     = d.item,
            key      = d.key,
            jobs     = d.jobs,
            state    = doorState[id],
        }
    end
    cb(list)
end)

RegisterServerEvent('pop_doorlock:changeState')
AddEventHandler('pop_doorlock:changeState', function(doorId, state)
    local src = source
    if type(state) ~= 'boolean' or type(doorId) ~= 'number' then return end
    if doorState[doorId] == nil then return end
    -- Vérification de distance : le joueur doit être près de la porte
    local d = doors[doorId]
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vector3(d.coords.x, d.coords.y, d.coords.z)) > (d.distance or 2.5) + 5.0 then return end
    if not playerHasAccess(src, doorId) then
        TriggerClientEvent('pop_doorlock:denied', src)
        return
    end

    doorState[doorId] = state
    TriggerClientEvent('pop_doorlock:changeDoorState', -1, doorId, state)
    TriggerClientEvent('pop_doorlock:toggled', src, state)
end)

-- =====================================================================
--  DOORBUILDER : ouverture (admin only) — déclenché par pop_admin
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:request')
AddEventHandler('pop_doorlock:builder:request', function()
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('pop_doorlock:builder:denied', src)
        return
    end
    TriggerClientEvent('pop_doorlock:builder:open', src)
end)

-- liste des groupes (pour le hub de gestion)
local function buildGroupSummary(gid, g)
    return {
        gid    = gid,
        label  = g.label,
        item   = g.item or '',
        key    = g.key or '',
        count  = #g.doorIds,
        source = g.source,
        hasKey = (g.key ~= false and g.key ~= nil and g.key ~= ''),
    }
end

ESX.RegisterServerCallback('pop_doorlock:getGroups', function(source, cb)
    if not isAdmin(source) then cb({}) return end
    local list = {}
    for gid, g in pairs(groupsById) do
        list[#list + 1] = buildGroupSummary(gid, g)
    end
    table.sort(list, function(a, b) return a.gid < b.gid end)
    cb(list)
end)

-- détail d'un groupe (pour le panneau de configuration)
ESX.RegisterServerCallback('pop_doorlock:getGroupDetail', function(source, cb, gid)
    if not isAdmin(source) then cb(nil) return end
    gid = tonumber(gid)
    local g = groupsById[gid]
    if not g then cb(nil) return end

    local doorList = {}
    for _, id in ipairs(g.doorIds) do
        local d = doors[id]
        doorList[#doorList + 1] = { doorId = id, model = d.model, state = doorState[id] }
    end

    cb({
        gid      = gid,
        label    = g.label,
        distance = g.distance,
        locked   = g.locked,
        source   = g.source,
        hasKey   = (g.key ~= false and g.key ~= nil and g.key ~= ''),
        doors    = doorList,
    })
end)

-- =====================================================================
--  DOORBUILDER : créer un groupe
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:save')
AddEventHandler('pop_doorlock:builder:save', function(payload)
    local src = source
    if not isAdmin(src) then return end
    if type(payload) ~= 'table' or type(payload.doors) ~= 'table' or #payload.doors == 0 then return end

    local label = tostring(payload.label or ''):gsub('^%s*(.-)%s*$', '%1')
    if label == '' then label = 'Groupe portes' end

    -- id stable unique du groupe (persisté) -> servira de meta.doorgroup sur l'item 'cle'
    local keyId = ('grp_%d_%d'):format(os.time(), math.random(1000, 9999))

    local group = {
        Label    = label,
        Doors    = {},
        Locked   = payload.locked ~= false,
        Distance = tonumber(payload.distance) or 2.5,
        Jobs     = false,
        Item     = false,
        Key      = keyId,
    }
    for _, d in ipairs(payload.doors) do
        if type(d) ~= 'table' or type(d.coords) ~= 'table' or tonumber(d.coords.x) == nil or tonumber(d.coords.y) == nil or tonumber(d.coords.z) == nil then return end
        group.Doors[#group.Doors + 1] = {
            Model  = d.model,
            Coords = { x = d.coords.x + 0.0, y = d.coords.y + 0.0, z = d.coords.z + 0.0 },
        }
    end

    local gid = registerGroup(group, 'json')
    persist()

    -- pousse les nouvelles portes à TOUS les clients (live, sans restart)
    local created = {}
    for _, id in ipairs(groupsById[gid].doorIds) do
        local d = doors[id]
        created[#created + 1] = {
            id = id, model = d.model, coords = d.coords, distance = d.distance,
            item = d.item, key = d.key, jobs = d.jobs, state = doorState[id],
        }
    end
    TriggerClientEvent('pop_doorlock:addDoors', -1, created)
    TriggerClientEvent('pop_doorlock:builder:saved', src, label, #created)
end)

-- =====================================================================
--  DOORBUILDER : modifier un groupe (label / distance / verrouillage par défaut)
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:updateGroup')
AddEventHandler('pop_doorlock:builder:updateGroup', function(payload)
    local src = source
    if not isAdmin(src) then return end
    if type(payload) ~= 'table' then return end
    local gid = tonumber(payload.gid)
    local g = groupsById[gid]
    if not g then return end

    local label = tostring(payload.label or ''):gsub('^%s*(.-)%s*$', '%1')
    if label == '' then label = g.label end
    local distance = tonumber(payload.distance) or g.distance
    local locked = payload.locked ~= false

    g.label = label
    g.distance = distance
    g.locked = locked

    -- distance live sur chaque porte du groupe (déjà créées)
    for _, id in ipairs(g.doorIds) do
        doors[id].distance = distance
    end

    if g.source == 'json' then
        persist()
    elseif g.source == 'config' and g.configIndex then
        local ov = getOverride(g.configIndex)
        ov.label = label
        ov.distance = distance
        ov.locked = locked
        persistOverrides()
    end

    -- pousse la distance à jour à tous les clients (réutilise addDoors : applyDoor écrase juste les champs)
    local updated = {}
    for _, id in ipairs(g.doorIds) do
        local d = doors[id]
        updated[#updated + 1] = {
            id = id, model = d.model, coords = d.coords, distance = d.distance,
            item = d.item, key = d.key, jobs = d.jobs, state = doorState[id],
        }
    end
    TriggerClientEvent('pop_doorlock:addDoors', -1, updated)
    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
end)

-- =====================================================================
--  DOORBUILDER : retirer une porte précise d'un groupe
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:removeDoor')
AddEventHandler('pop_doorlock:builder:removeDoor', function(payload)
    local src = source
    if not isAdmin(src) then return end
    if type(payload) ~= 'table' then return end
    local gid = tonumber(payload.gid)
    local doorId = tonumber(payload.doorId)
    local g = groupsById[gid]
    if not g or not doors[doorId] then return end

    -- la porte appartient-elle bien à ce groupe ?
    local idx
    for i, id in ipairs(g.doorIds) do
        if id == doorId then idx = i break end
    end
    if not idx then return end

    local d = doors[doorId]

    if g.source == 'config' and g.configIndex then
        local ov = getOverride(g.configIndex)
        ov.removedDoors[doorKey(d.model, d.coords)] = true
    end

    table.remove(g.doorIds, idx)
    doors[doorId] = nil
    doorState[doorId] = nil

    local emptied = (#g.doorIds == 0)
    if emptied then
        groupsById[gid] = nil
        if g.source == 'config' and g.configIndex then
            local ov = getOverride(g.configIndex)
            ov.disabled = true
        end
    end

    if g.source == 'json' then
        persist()
    elseif g.source == 'config' and g.configIndex then
        persistOverrides()
    end

    TriggerClientEvent('pop_doorlock:removeDoors', -1, { doorId })
    TriggerClientEvent('pop_doorlock:builder:doorRemoved', src, gid, emptied)
end)

-- =====================================================================
--  DOORBUILDER : attribuer / régénérer la clé d'un groupe
-- =====================================================================
local function setGroupKey(g, gid, keyId)
    g.key = keyId
    for _, id in ipairs(g.doorIds) do
        doors[id].key = keyId
    end

    if g.source == 'json' then
        persist()
    elseif g.source == 'config' and g.configIndex then
        local ov = getOverride(g.configIndex)
        ov.key = keyId
        persistOverrides()
    end
end

RegisterServerEvent('pop_doorlock:builder:assignkey')
AddEventHandler('pop_doorlock:builder:assignkey', function(gid)
    local src = source
    if not isAdmin(src) then return end
    gid = tonumber(gid)
    local g = groupsById[gid]
    if not g then return end

    local keyId = ('grp_%d_%d'):format(os.time(), math.random(1000, 9999))
    setGroupKey(g, gid, keyId)

    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
end)

RegisterServerEvent('pop_doorlock:builder:regenkey')
AddEventHandler('pop_doorlock:builder:regenkey', function(gid)
    local src = source
    if not isAdmin(src) then return end
    gid = tonumber(gid)
    local g = groupsById[gid]
    if not g or not g.key then return end

    local keyId = ('grp_%d_%d'):format(os.time(), math.random(1000, 9999))
    setGroupKey(g, gid, keyId)

    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
    TriggerClientEvent('pop_doorlock:keyResult', src, g.label, true)
end)

-- =====================================================================
--  DOORBUILDER : donner la clé d'un groupe à l'admin (item 'cle' + meta)
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:givekey')
AddEventHandler('pop_doorlock:builder:givekey', function(gid)
    local src = source
    if not isAdmin(src) then return end
    gid = tonumber(gid)
    local g = groupsById[gid]
    if not g or not g.key then
        TriggerClientEvent('pop_doorlock:keyResult', src, false)
        return
    end

    local meta = {
        doorgroup   = g.key,
        label       = g.label,
        description = 'Ouvre : ' .. (g.label or g.key),
    }
    local ok, result = pcall(function()
        return exports.pop_inventory:GiveItem(src, Config.KeyItem, 1, meta)
    end)

    if ok and result == true then
        TriggerClientEvent('pop_doorlock:keyResult', src, g.label)
    else
        TriggerClientEvent('pop_doorlock:keyResult', src, false)
    end
end)

-- =====================================================================
--  DOORBUILDER : supprimer / désactiver un groupe entier
-- =====================================================================
RegisterServerEvent('pop_doorlock:builder:delete')
AddEventHandler('pop_doorlock:builder:delete', function(gid)
    local src = source
    if not isAdmin(src) then return end
    gid = tonumber(gid)
    local g = groupsById[gid]
    if not g then
        TriggerClientEvent('pop_doorlock:builder:deleted', src, false)
        return
    end

    local removed = {}
    for _, id in ipairs(g.doorIds) do
        removed[#removed + 1] = id
        doors[id] = nil
        doorState[id] = nil
    end
    local label = g.label
    groupsById[gid] = nil

    if g.source == 'json' then
        persist()
    elseif g.source == 'config' and g.configIndex then
        -- on ne touche pas config.lua : on marque juste l'index comme désactivé, de façon persistée
        local ov = getOverride(g.configIndex)
        ov.disabled = true
        persistOverrides()
    end

    TriggerClientEvent('pop_doorlock:removeDoors', -1, removed)
    TriggerClientEvent('pop_doorlock:builder:deleted', src, label)
end)
