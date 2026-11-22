-- Doorbuilder (admins) : ouverture depuis pop_admin, groupes, portes, clés.

local function NewKeyId()
    return ('grp_%d_%d'):format(os.time(), math.random(1000, 9999))
end

local function HasKey(g)
    return g.key ~= false and g.key ~= nil and g.key ~= ''
end

-- Ouverture (admin only) — déclenchée par pop_admin
RegisterNetEvent('pop_doorlock:builder:request', function()
    local src = source
    if not Doorlock.IsAdmin(src) then
        TriggerClientEvent('pop_doorlock:builder:denied', src)
        return
    end
    TriggerClientEvent('pop_doorlock:builder:open', src)
end)

-- Liste des groupes (hub de gestion)
Callback.Register('pop_doorlock:getGroups', function(source)
    if not Doorlock.IsAdmin(source) then return {} end
    local list = {}
    for gid, g in pairs(Doorlock.groupsById) do
        list[#list + 1] = {
            gid    = gid,
            label  = g.label,
            item   = g.item or '',
            key    = g.key or '',
            count  = #g.doorIds,
            source = g.source,
            hasKey = HasKey(g),
        }
    end
    table.sort(list, function(a, b) return a.gid < b.gid end)
    return list
end)

-- Détail d'un groupe (panneau de configuration)
Callback.Register('pop_doorlock:getGroupDetail', function(source, gid)
    if not Doorlock.IsAdmin(source) then return nil end
    gid = tonumber(gid)
    local g = Doorlock.groupsById[gid]
    if not g then return nil end

    local doorList = {}
    for _, id in ipairs(g.doorIds) do
        local d = Doorlock.doors[id]
        doorList[#doorList + 1] = { doorId = id, model = d.model, state = Doorlock.doorState[id] }
    end

    return {
        gid      = gid,
        label    = g.label,
        distance = g.distance,
        locked   = g.locked,
        source   = g.source,
        hasKey   = HasKey(g),
        doors    = doorList,
    }
end)

-- Créer un groupe
RegisterNetEvent('pop_doorlock:builder:save', function(payload)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    if type(payload) ~= 'table' or type(payload.doors) ~= 'table' or #payload.doors == 0 then return end

    local label = tostring(payload.label or ''):gsub('^%s*(.-)%s*$', '%1')
    if label == '' then label = L('group_default_label') end

    local group = {
        Label    = label,
        Doors    = {},
        Locked   = payload.locked ~= false,
        Distance = tonumber(payload.distance) or 2.5,
        Jobs     = false,
        Item     = false,
        Key      = NewKeyId(), -- id stable -> meta.doorgroup de l'item 'cle'
    }
    for _, d in ipairs(payload.doors) do
        if type(d) ~= 'table' or type(d.coords) ~= 'table' or tonumber(d.coords.x) == nil or tonumber(d.coords.y) == nil or tonumber(d.coords.z) == nil then return end
        group.Doors[#group.Doors + 1] = {
            Model  = d.model,
            Coords = { x = d.coords.x + 0.0, y = d.coords.y + 0.0, z = d.coords.z + 0.0 },
        }
    end

    local gid = Doorlock.RegisterGroup(group, 'json')
    Doorlock.Persist()

    -- Nouvelles portes poussées à tous les clients (sans restart)
    local created = {}
    for _, id in ipairs(Doorlock.groupsById[gid].doorIds) do
        created[#created + 1] = Doorlock.DoorPayload(id)
    end
    TriggerClientEvent('pop_doorlock:addDoors', -1, created)
    TriggerClientEvent('pop_doorlock:builder:saved', src, label, #created)
end)

-- Modifier un groupe (label / distance / verrouillage par défaut)
RegisterNetEvent('pop_doorlock:builder:updateGroup', function(payload)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    if type(payload) ~= 'table' then return end
    local gid = tonumber(payload.gid)
    local g = Doorlock.groupsById[gid]
    if not g then return end

    local label = tostring(payload.label or ''):gsub('^%s*(.-)%s*$', '%1')
    if label == '' then label = g.label end
    local distance = tonumber(payload.distance) or g.distance
    local locked = payload.locked ~= false

    g.label = label
    g.distance = distance
    g.locked = locked

    for _, id in ipairs(g.doorIds) do
        Doorlock.doors[id].distance = distance
    end

    if g.source == 'json' then
        Doorlock.Persist()
    elseif g.source == 'config' and g.configIndex then
        local ov = Doorlock.GetOverride(g.configIndex)
        ov.label = label
        ov.distance = distance
        ov.locked = locked
        Doorlock.PersistOverrides()
    end

    -- Distance à jour chez tous les clients (addDoors écrase les champs)
    local updated = {}
    for _, id in ipairs(g.doorIds) do
        updated[#updated + 1] = Doorlock.DoorPayload(id)
    end
    TriggerClientEvent('pop_doorlock:addDoors', -1, updated)
    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
end)

-- Retirer une porte précise d'un groupe
RegisterNetEvent('pop_doorlock:builder:removeDoor', function(payload)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    if type(payload) ~= 'table' then return end
    local gid = tonumber(payload.gid)
    local doorId = tonumber(payload.doorId)
    local g = Doorlock.groupsById[gid]
    if not g or not Doorlock.doors[doorId] then return end

    local idx
    for i, id in ipairs(g.doorIds) do
        if id == doorId then idx = i break end
    end
    if not idx then return end

    local d = Doorlock.doors[doorId]
    if g.source == 'config' and g.configIndex then
        local ov = Doorlock.GetOverride(g.configIndex)
        ov.removedDoors[Doorlock.DoorKey(d.model, d.coords)] = true
    end

    table.remove(g.doorIds, idx)
    Doorlock.doors[doorId] = nil
    Doorlock.doorState[doorId] = nil

    local emptied = (#g.doorIds == 0)
    if emptied then
        Doorlock.groupsById[gid] = nil
        if g.source == 'config' and g.configIndex then
            Doorlock.GetOverride(g.configIndex).disabled = true
        end
    end

    if g.source == 'json' then
        Doorlock.Persist()
    elseif g.source == 'config' and g.configIndex then
        Doorlock.PersistOverrides()
    end

    TriggerClientEvent('pop_doorlock:removeDoors', -1, { doorId })
    TriggerClientEvent('pop_doorlock:builder:doorRemoved', src, gid, emptied)
end)

-- Attribuer / régénérer la clé d'un groupe
local function SetGroupKey(g, keyId)
    g.key = keyId
    for _, id in ipairs(g.doorIds) do
        Doorlock.doors[id].key = keyId
    end
    if g.source == 'json' then
        Doorlock.Persist()
    elseif g.source == 'config' and g.configIndex then
        Doorlock.GetOverride(g.configIndex).key = keyId
        Doorlock.PersistOverrides()
    end
end

RegisterNetEvent('pop_doorlock:builder:assignkey', function(gid)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    gid = tonumber(gid)
    local g = Doorlock.groupsById[gid]
    if not g then return end
    SetGroupKey(g, NewKeyId())
    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
end)

RegisterNetEvent('pop_doorlock:builder:regenkey', function(gid)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    gid = tonumber(gid)
    local g = Doorlock.groupsById[gid]
    if not g or not g.key then return end
    SetGroupKey(g, NewKeyId())
    TriggerClientEvent('pop_doorlock:builder:updated', src, gid)
    TriggerClientEvent('pop_doorlock:keyResult', src, g.label, true)
end)

-- Donner la clé d'un groupe à l'admin (item 'cle' + meta), pop_inventory direct (métadonnée)
RegisterNetEvent('pop_doorlock:builder:givekey', function(gid)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    gid = tonumber(gid)
    local g = Doorlock.groupsById[gid]
    if not g or not g.key then
        TriggerClientEvent('pop_doorlock:keyResult', src, false)
        return
    end

    local meta = {
        doorgroup   = g.key,
        label       = g.label,
        description = L('key_description', g.label or g.key),
    }
    local ok, result = pcall(function()
        return exports.pop_inventory:GiveItem(src, Config.KeyItem, 1, meta)
    end)
    TriggerClientEvent('pop_doorlock:keyResult', src, (ok and result == true) and g.label or false)
end)

-- Supprimer / désactiver un groupe entier
RegisterNetEvent('pop_doorlock:builder:delete', function(gid)
    local src = source
    if not Doorlock.IsAdmin(src) then return end
    gid = tonumber(gid)
    local g = Doorlock.groupsById[gid]
    if not g then
        TriggerClientEvent('pop_doorlock:builder:deleted', src, false)
        return
    end

    local removed = {}
    for _, id in ipairs(g.doorIds) do
        removed[#removed + 1] = id
        Doorlock.doors[id] = nil
        Doorlock.doorState[id] = nil
    end
    local label = g.label
    Doorlock.groupsById[gid] = nil

    if g.source == 'json' then
        Doorlock.Persist()
    elseif g.source == 'config' and g.configIndex then
        -- config.lua n'est jamais modifié : l'index est marqué désactivé (persisté)
        Doorlock.GetOverride(g.configIndex).disabled = true
        Doorlock.PersistOverrides()
    end

    TriggerClientEvent('pop_doorlock:removeDoors', -1, removed)
    TriggerClientEvent('pop_doorlock:builder:deleted', src, label)
end)
