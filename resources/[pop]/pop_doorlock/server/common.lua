-- Fonctions communes du serveur pop_doorlock (chargé en premier, voir fxmanifest).
-- État des portes et des groupes, persistance (doors.json / overrides.json), droits et accès.

Doorlock = {
    resName    = GetCurrentResourceName(),
    doors      = {},   -- doorId -> { model, coords{x,y,z}, distance, item, key, jobs }
    doorState  = {},   -- doorId -> bool (true = verrouillée)
    groupsById = {},   -- gid -> { label, item, key, distance, locked, jobs, source, configIndex, doorIds = {} }
    nextDoorId = 1,
    nextGid    = 1,
    -- Overrides des groupes de config.lua (on ne modifie jamais config.lua)
    -- [configIndex] = { disabled, label, distance, locked, key, removedDoors = { [doorKey] = true } }
    configOverrides = {},
}

function Doorlock.Debug(msg)
    if Config.Debug then print(msg) end
end

function Doorlock.DoorKey(model, coords)
    return tostring(model) .. ':' .. math.floor(coords.x * 100) .. ':' .. math.floor(coords.y * 100) .. ':' .. math.floor(coords.z * 100)
end

function Doorlock.LoadOverrides()
    local raw = LoadResourceFile(Doorlock.resName, 'overrides.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for idx, ov in pairs(decoded) do
                Doorlock.configOverrides[tonumber(idx)] = ov
            end
        end
    end
end

function Doorlock.PersistOverrides()
    SaveResourceFile(Doorlock.resName, 'overrides.json', json.encode(Doorlock.configOverrides, { indent = true }), -1)
end

function Doorlock.GetOverride(configIndex)
    if not configIndex then return nil end
    local ov = Doorlock.configOverrides[configIndex]
    if not ov then
        ov = { removedDoors = {} }
        Doorlock.configOverrides[configIndex] = ov
    end
    if not ov.removedDoors then ov.removedDoors = {} end
    return ov
end

-- Enregistrement d'un groupe (format Config.Doors : champs capitalisés)
function Doorlock.RegisterGroup(group, source, configIndex)
    local ov = (source == 'config') and Doorlock.configOverrides[configIndex] or nil
    if ov and ov.disabled then return nil end

    local gid = Doorlock.nextGid
    Doorlock.nextGid = Doorlock.nextGid + 1

    local locked = group.Locked
    if locked == nil then locked = true end
    if ov and ov.locked ~= nil then locked = ov.locked end

    local g = {
        label    = (ov and ov.label) or group.Label or group.Item or L('group_numbered_label', gid),
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
        if not removedDoors[Doorlock.DoorKey(door.Model, coords)] then
            local id = Doorlock.nextDoorId
            Doorlock.nextDoorId = Doorlock.nextDoorId + 1
            Doorlock.doors[id] = {
                model    = door.Model,
                coords   = coords,
                distance = g.distance,
                item     = g.item,
                key      = g.key,
                jobs     = g.jobs,
            }
            Doorlock.doorState[id] = locked
            g.doorIds[#g.doorIds + 1] = id
        end
    end

    Doorlock.groupsById[gid] = g
    return gid
end

-- Persistance des groupes 'json' (les groupes 'config' passent par les overrides)
function Doorlock.Persist()
    local out = {}
    for _, g in pairs(Doorlock.groupsById) do
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
                local d = Doorlock.doors[id]
                entry.Doors[#entry.Doors + 1] = { Model = d.model, Coords = d.coords }
            end
            out[#out + 1] = entry
        end
    end
    SaveResourceFile(Doorlock.resName, 'doors.json', json.encode(out, { indent = true }), -1)
end

-- Porte au format envoyé aux clients
function Doorlock.DoorPayload(id)
    local d = Doorlock.doors[id]
    return {
        id = id, model = d.model, coords = d.coords, distance = d.distance,
        item = d.item, key = d.key, jobs = d.jobs, state = Doorlock.doorState[id],
    }
end

------------------------------------------------------------------------
-- Permissions admin (logique pop_admin)
------------------------------------------------------------------------
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

function Doorlock.IsAdmin(src)
    if src == 0 then return true end

    -- 1) Même check que pop_admin (même liste d'admins) s'il tourne.
    if GetResourceState('pop_admin') == 'started' then
        local ok, res = pcall(function() return exports.pop_admin:IsAdmin(src) end)
        if ok and res ~= nil then return res == true end
    end

    -- 2) Sinon : config locale pop_doorlock.
    if isIdentifierListed(src) then return true end
    for _, ace in ipairs(Config.AcePermissions or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    -- ESX direct : groupe du joueur (getGroup). À passer par le bridge au moment du multi-framework.
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if xPlayer and Config.AdminGroups[xPlayer.getGroup()] then
        return true
    end
    return false
end

------------------------------------------------------------------------
-- Contrôle d'accès (serveur autoritaire)
------------------------------------------------------------------------
-- pop_inventory direct : objets avec leur métadonnée `meta` (clé 'cle' + meta.doorgroup).
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

function Doorlock.PlayerHasAccess(src, doorId)
    local d = Doorlock.doors[doorId]
    if not d then return false end

    -- 1) Clé à métadonnée (item 'cle' + meta.doorgroup) : système Doorbuilder
    if d.key and d.key ~= '' then
        return hasDoorKey(src, d.key)
    end

    -- 2) Item simple (legacy, via getItemCount)
    if d.item and d.item ~= '' then
        local ok, count = pcall(function() return exports.pop_inventory:getItemCount(src, d.item) end)
        return ok and (tonumber(count) or 0) > 0
    end

    -- 3) Jobs
    local jobs = d.jobs
    if jobs == false or jobs == nil then return true end
    if jobs == true then return false end

    local job = Bridge.GetJob(src)
    if not job then return false end

    if type(jobs) == 'table' then
        for _, j in ipairs(jobs) do
            if job.name == j then return true end
        end
        return false
    end
    return job.name == jobs
end
