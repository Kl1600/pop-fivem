-- pop_doorlock : callbacks de l'éditeur admin. Bridge.IsAdmin est vérifié à chaque appel :
-- la commande client ne prouve rien. Le cache n'est modifié qu'après une écriture SQL réussie.

local Doorlock = Doorlock

local RES = GetCurrentResourceName()

-- Valeurs par défaut d'un nouveau groupe (rappel, la NUI part du même état) :
-- locked = true, distance = 2.0, security = 2, alert = false, jobs = {}, key = false
local ADMIN_RANGE     = 15.0 -- portée max de l'admin autour du centre pour addDoor
local MAX_DOORS       = 50   -- portes max par groupe
local MAX_LEAF_GAP    = 4.0  -- écart max entre les 2 battants d'une porte double
local MAX_CENTER_GAP  = 3.0  -- distance max entre le centre et chaque battant
local DUPLICATE_RANGE = 0.5  -- battant de même modèle à moins de 0.5 m = doublon
local LABEL_MAX       = 32
local JOBS_MAX        = 10
local GRADE_MAX       = 50

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

-- Journal des actions admin réussies : [pop_doorlock] <nom> (<src>) <action> group #<id>
local function logAction(src, action, groupId)
    print(('[%s] %s (%s) %s group #%s'):format(RES, tostring(GetPlayerName(src) or '?'), src, action, groupId))
end

local function getGroup(groupId)
    return Doorlock.groups[Doorlock.ToInt(groupId)]
end

local function leafPos(l)
    return vector3(l.x, l.y, l.z)
end

-- data = { id = int|nil, label, locked, distance, security, alert, jobs, key } → table validée ou nil.
local function validateGroup(data)
    if type(data) ~= 'table' then return nil end

    -- NOTE: un id non numérique (nil, null JSON) signifie « création » ; un nombre doit être un entier valide.
    local id
    if type(data.id) == 'number' then
        id = Doorlock.ToInt(data.id)
        if not id or id < 1 then return nil end
    end

    if type(data.label) ~= 'string' then return nil end
    local label = data.label:match('^%s*(.-)%s*$')
    local len = utf8.len(label)
    if not len or len < 1 or len > LABEL_MAX or label:find('%c') then return nil end

    if type(data.locked) ~= 'boolean' or type(data.alert) ~= 'boolean' or type(data.key) ~= 'boolean' then return nil end
    if not Doorlock.IsFinite(data.distance) then return nil end

    local security = Doorlock.ToInt(data.security)
    if security ~= 0 and security ~= 1 and security ~= 2 then return nil end

    local jobs = {}
    if data.jobs ~= nil then
        if type(data.jobs) ~= 'table' then return nil end
        local count = 0
        for name, grade in pairs(data.jobs) do
            count = count + 1
            if count > JOBS_MAX then return nil end
            if type(name) ~= 'string' or #name < 1 or #name > 32 or not name:match('^[%w_%-]+$') then return nil end
            local g = Doorlock.ToInt(grade)
            if not g or g < 0 or g > GRADE_MAX then return nil end
            jobs[name] = g
        end
    end

    return {
        id = id, label = label, locked = data.locked, alert = data.alert, key = data.key,
        distance = Doorlock.ClampDistance(data.distance), security = security, jobs = jobs,
    }
end

-- door = { center = {x,y,z}, leaves = { {model,x,y,z}, ... } } → center (vector3), leaves ; ou nil, raison.
local function validateDoor(door)
    if type(door) ~= 'table' or type(door.center) ~= 'table' or type(door.leaves) ~= 'table' then
        return nil, 'editor_invalid'
    end
    local c = door.center
    if not Doorlock.IsFinite(c.x) or not Doorlock.IsFinite(c.y) or not Doorlock.IsFinite(c.z) then
        return nil, 'editor_invalid'
    end
    local center = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)

    -- Exactement les clés 1 (et 2) : pas de trou ni de clé étrangère.
    local count = 0
    for k in pairs(door.leaves) do
        if k ~= 1 and k ~= 2 then return nil, 'editor_invalid' end
        count = count + 1
    end
    if count < 1 or door.leaves[count] == nil then return nil, 'editor_invalid' end

    local leaves = {}
    for i = 1, count do
        local l = door.leaves[i]
        if type(l) ~= 'table' then return nil, 'editor_invalid' end
        local model = Doorlock.ToInt(l.model)
        if not model or model == 0 or model < -2147483648 or model > 4294967295 then return nil, 'editor_invalid' end
        if not Doorlock.IsFinite(l.x) or not Doorlock.IsFinite(l.y) or not Doorlock.IsFinite(l.z) then
            return nil, 'editor_invalid'
        end
        local leaf = { model = model, x = l.x + 0.0, y = l.y + 0.0, z = l.z + 0.0 }
        if #(center - leafPos(leaf)) > MAX_CENTER_GAP then return nil, 'editor_invalid' end
        leaves[i] = leaf
    end

    if count == 2 then
        local gap = #(leafPos(leaves[1]) - leafPos(leaves[2]))
        if gap > MAX_LEAF_GAP then return nil, 'editor_leaves_far' end
        if leaves[1].model == leaves[2].model and gap < DUPLICATE_RANGE then return nil, 'editor_invalid' end
    end
    return center, leaves
end

-- Vrai si un des battants est déjà enregistré (même modèle à moins de 0.5 m).
local function isDuplicate(leaves)
    for _, d in pairs(Doorlock.doors) do
        for _, existing in ipairs(d.leaves) do
            local pos = leafPos(existing)
            for _, l in ipairs(leaves) do
                if l.model == existing.model and #(pos - leafPos(l)) < DUPLICATE_RANGE then return true end
            end
        end
    end
    return false
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_doorlock:admin:getGroups', function(src)
    if not Bridge.IsAdmin(src) then return nil end
    if not Doorlock.WaitReady() then return { groups = {}, keys = Doorlock.KeysSupported() } end
    local ids = {}
    for id in pairs(Doorlock.groups) do ids[#ids + 1] = id end
    table.sort(ids)
    local list = {}
    for i, id in ipairs(ids) do list[i] = Doorlock.AdminGroup(id) end
    return { groups = list, keys = Doorlock.KeysSupported() }
end)

Callback.Register('pop_doorlock:admin:saveGroup', function(src, data)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local v = validateGroup(data)
    if not v then return false, 'editor_invalid' end

    -- Chaînes vides converties en NULL par NULLIF : évite les nil (trous) dans la liste de paramètres.
    local jobsJson = next(v.jobs) and json.encode(v.jobs) or ''

    if not v.id then
        -- Création
        local keyId
        if v.key then
            -- NOTE: une clé est refusée si l'inventaire ne gère pas la metadata (elle serait inutilisable).
            if not Doorlock.KeysSupported() then return false, 'editor_key_unsupported' end
            keyId = Doorlock.NewKeyId()
            if not keyId then return false, 'error' end
        end
        local id = Doorlock.Sql(MySQL.insert.await,
            'INSERT INTO `pop_doorlock_groups` (`label`, `locked`, `distance`, `security`, `alert`, `jobs`, `key_id`) VALUES (?, ?, ?, ?, ?, NULLIF(?, \'\'), NULLIF(?, \'\'))',
            { v.label, v.locked and 1 or 0, v.distance, v.security, v.alert and 1 or 0, jobsJson, keyId or '' })
        id = Doorlock.ToInt(id)
        if not id or id < 1 then return false, 'error' end
        Doorlock.groups[id] = {
            id = id, label = v.label, locked = v.locked, distance = v.distance, security = v.security,
            alert = v.alert, jobs = v.jobs, keyId = keyId, doorIds = {},
        }
        Doorlock.SyncGroup(id)
        logAction(src, 'created', id)
        return true, Doorlock.AdminGroup(id)
    end

    -- Modification
    local g = Doorlock.groups[v.id]
    if not g then return false, 'editor_not_found' end
    local keyId -- nil si key = false : key_id passe à NULL
    if v.key then
        keyId = g.keyId
        if not keyId then
            if not Doorlock.KeysSupported() then return false, 'editor_key_unsupported' end
            keyId = Doorlock.NewKeyId()
            if not keyId then return false, 'error' end
        end
    end
    local res = Doorlock.Sql(MySQL.update.await,
        'UPDATE `pop_doorlock_groups` SET `label` = ?, `locked` = ?, `distance` = ?, `security` = ?, `alert` = ?, `jobs` = NULLIF(?, \'\'), `key_id` = NULLIF(?, \'\') WHERE `id` = ?',
        { v.label, v.locked and 1 or 0, v.distance, v.security, v.alert and 1 or 0, jobsJson, keyId or '', v.id })
    if res == nil then return false, 'error' end
    if Doorlock.groups[v.id] ~= g then return false, 'editor_not_found' end -- supprimé pendant l'écriture

    -- L'état courant des portes ne change pas : `locked` ne vaut qu'au démarrage et pour les nouvelles portes.
    g.label, g.locked, g.distance, g.security = v.label, v.locked, v.distance, v.security
    g.alert, g.jobs, g.keyId = v.alert, v.jobs, keyId
    Doorlock.SyncGroup(v.id)
    logAction(src, 'updated', v.id)
    return true, Doorlock.AdminGroup(v.id)
end)

Callback.Register('pop_doorlock:admin:deleteGroup', function(src, groupId)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local g = getGroup(groupId)
    if not g then return false, 'editor_not_found' end
    local id = g.id
    -- Portes supprimées explicitement, en plus du ON DELETE CASCADE (tables créées à la main sans clé étrangère).
    if Doorlock.Sql(MySQL.update.await, 'DELETE FROM `pop_doorlock_doors` WHERE `group_id` = ?', { id }) == nil then
        return false, 'error'
    end
    if Doorlock.Sql(MySQL.update.await, 'DELETE FROM `pop_doorlock_groups` WHERE `id` = ?', { id }) == nil then
        return false, 'error'
    end
    if Doorlock.groups[id] ~= g then return false, 'editor_not_found' end
    for _, doorId in ipairs(g.doorIds) do Doorlock.doors[doorId] = nil end
    Doorlock.groups[id] = nil
    TriggerClientEvent('pop_doorlock:client:removeGroup', -1, id)
    logAction(src, 'deleted', id)
    return true
end)

Callback.Register('pop_doorlock:admin:addDoor', function(src, groupId, door)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local g = getGroup(groupId)
    if not g then return false, 'editor_not_found' end
    local center, leaves = validateDoor(door)
    if not center then return false, leaves end -- leaves contient la raison
    if not Bridge.IsNear(src, center, ADMIN_RANGE) then return false, 'too_far' end
    if #g.doorIds >= MAX_DOORS then return false, 'editor_too_many_doors' end
    if isDuplicate(leaves) then return false, 'editor_door_exists' end

    local id = Doorlock.Sql(MySQL.insert.await,
        'INSERT INTO `pop_doorlock_doors` (`group_id`, `x`, `y`, `z`, `leaves`) VALUES (?, ?, ?, ?, ?)',
        { g.id, center.x, center.y, center.z, json.encode(leaves) })
    id = Doorlock.ToInt(id)
    if not id or id < 1 then return false, 'error' end
    -- Revérification après l'écriture : un autre ajout a pu passer pendant l'attente SQL.
    local reason
    if Doorlock.groups[g.id] ~= g then
        reason = 'editor_not_found'
    elseif #g.doorIds >= MAX_DOORS then
        reason = 'editor_too_many_doors'
    elseif isDuplicate(leaves) then
        reason = 'editor_door_exists'
    end
    if reason then
        Doorlock.Sql(MySQL.update.await, 'DELETE FROM `pop_doorlock_doors` WHERE `id` = ?', { id })
        return false, reason
    end

    Doorlock.doors[id] = { id = id, groupId = g.id, center = center, leaves = leaves, locked = g.locked }
    g.doorIds[#g.doorIds + 1] = id
    Doorlock.SyncGroup(g.id)
    logAction(src, ('added door #%d to'):format(id), g.id)
    return true, Doorlock.AdminGroup(g.id)
end)

Callback.Register('pop_doorlock:admin:removeDoor', function(src, doorId)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local door, g = Doorlock.GetDoor(doorId)
    if not door then return false, 'editor_not_found' end
    if Doorlock.Sql(MySQL.update.await, 'DELETE FROM `pop_doorlock_doors` WHERE `id` = ?', { door.id }) == nil then
        return false, 'error'
    end
    if Doorlock.doors[door.id] ~= door then return false, 'editor_not_found' end
    Doorlock.doors[door.id] = nil
    for i, id in ipairs(g.doorIds) do
        if id == door.id then table.remove(g.doorIds, i) break end
    end
    Doorlock.SyncGroup(g.id)
    logAction(src, ('removed door #%d from'):format(door.id), g.id)
    return true, Doorlock.AdminGroup(g.id)
end)

Callback.Register('pop_doorlock:admin:giveKey', function(src, groupId)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local g = getGroup(groupId)
    if not g then return false, 'editor_not_found' end
    local ok, reason = Doorlock.GiveKey(src, g)
    if not ok then return false, reason end
    logAction(src, 'received a key of', g.id)
    return true
end)

Callback.Register('pop_doorlock:admin:resetKey', function(src, groupId)
    if not Bridge.IsAdmin(src) then return false, 'no_permission' end
    if not Doorlock.WaitReady() then return false, 'error' end
    local g = getGroup(groupId)
    if not g then return false, 'editor_not_found' end
    if not g.keyId then return false, 'editor_no_key' end
    local keyId = Doorlock.NewKeyId()
    if not keyId then return false, 'error' end
    local res = Doorlock.Sql(MySQL.update.await,
        'UPDATE `pop_doorlock_groups` SET `key_id` = ? WHERE `id` = ?', { keyId, g.id })
    if res == nil then return false, 'error' end
    if Doorlock.groups[g.id] ~= g then return false, 'editor_not_found' end
    g.keyId = keyId -- les anciennes clés (ancien key_id) ne correspondent plus
    Doorlock.SyncGroup(g.id)
    logAction(src, 'reset the key of', g.id)
    return true, Doorlock.AdminGroup(g.id)
end)
