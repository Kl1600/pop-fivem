-- Exports serveur (noms et comportement d'ox_inventory pour les fonctions courantes, SPEC §7.1).
-- Aucun chargement SQL dans un export : seuls les inventaires déjà en mémoire sont accessibles.
-- Copie profonde des données en entrée et en sortie.

local RES = GetCurrentResourceName()

local PREFIXES = { 'stash:', 'trunk:', 'glovebox:', 'drop:' }

local function debug(msg, ...)
    if Config.Debug then print(('[%s] export: ' .. msg):format(RES, ...)) end
end

-- inv = src | id complet | nom de stash | { id, owner } → id interne.
local function resolveId(ref)
    local t = type(ref)
    if t == 'number' then return math.tointeger(ref) end
    if t == 'string' then
        for _, p in ipairs(PREFIXES) do
            if ref:sub(1, #p) == p then return ref end
        end
        return 'stash:' .. ref
    end
    if t == 'table' and type(ref.id) == 'string' then
        local base = ref.id:sub(1, 6) == 'stash:' and ref.id or ('stash:' .. ref.id)
        local owner = ref.owner
        if type(owner) == 'number' then owner = Bridge.GetIdentifier(owner) end
        if type(owner) == 'string' and owner ~= '' then return base .. ':' .. owner end
        return base
    end
    return nil
end

local function getInv(ref)
    local id = resolveId(ref)
    local inv = id ~= nil and Inventory.Get(id) or nil
    if not inv or inv.closing then return nil end
    return inv
end

local function itemName(item)
    return type(item) == 'string' and item:lower() or nil
end

-- Filtre metadata : chaîne → { type = chaîne }.
local function filterOf(metadata)
    if type(metadata) == 'string' then return { type = metadata } end
    if type(metadata) == 'table' then return metadata end
    return nil
end

-- Copie publique d'une pile, avec label et poids de la pile.
local function publicItem(it)
    local def = Items.Get(it.name)
    return {
        slot = it.slot,
        name = it.name,
        count = it.count,
        metadata = Inventory.Copy(it.metadata),
        label = type(it.metadata.label) == 'string' and it.metadata.label or Items.Label(it.name),
        weight = (def and def.weight or 0) * it.count,
    }
end

local function positiveInt(n)
    n = Inventory.ToInt(n)
    if not n or n < 1 then return nil end
    return n
end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------

exports('Items', function(name)
    if name ~= nil then return Items.Public(name) end
    local out = {}
    for n in pairs(Items.All()) do out[n] = Items.Public(n) end
    return out
end)

------------------------------------------------------------------------
-- Contrat Bridge + compatibilité ox
------------------------------------------------------------------------

exports('AddItem', function(ref, item, count, metadata, slot)
    local inv = getInv(ref)
    if not inv then return false, 'not_loaded' end
    local name = itemName(item)
    if not name or not Items.Get(name) then return false, 'invalid_item' end
    count = positiveInt(count)
    if not count then return false, 'invalid_item' end
    local md = Inventory.NormalizeMetadata(metadata)
    if not md then return false, 'invalid_metadata' end
    local ok, reason = Inventory.AddItem(inv, name, count, md, slot)
    if ok then debug('AddItem %s %dx %s (%s)', tostring(inv.id), count, name, tostring(GetInvokingResource())) end
    return ok, reason
end)

exports('RemoveItem', function(ref, item, count, metadata, slot)
    local inv = getInv(ref)
    if not inv then return false, 'not_loaded' end
    local name = itemName(item)
    count = positiveInt(count)
    if not name or not count then return false, 'item_not_found' end
    local ok, reason = Inventory.RemoveItem(inv, name, count, filterOf(metadata), slot)
    if ok then debug('RemoveItem %s %dx %s (%s)', tostring(inv.id), count, name, tostring(GetInvokingResource())) end
    return ok, reason
end)

exports('GetItemCount', function(ref, item, metadata, strict)
    local inv = getInv(ref)
    local name = itemName(item)
    if not inv or not name then return 0 end
    return Inventory.GetItemCount(inv, name, filterOf(metadata), strict == true)
end)

exports('CanCarryItem', function(ref, item, count, metadata)
    local inv = getInv(ref)
    local name = itemName(item)
    if not inv or not name then return false end
    return Inventory.CanCarry(inv, name, positiveInt(count) or 0, type(metadata) == 'table' and metadata or filterOf(metadata))
end)

exports('CanCarryWeight', function(ref, weight)
    local inv = getInv(ref)
    return inv ~= nil and Inventory.CanCarryWeight(inv, weight)
end)

-- Search(inv, 'count' | 'slots', items, metadata?) : items chaîne → résultat ; table de noms → { [name] = résultat }.
exports('Search', function(ref, search, items, metadata)
    local inv = getInv(ref)
    local filter = filterOf(metadata)
    local function one(name)
        name = itemName(name)
        if search == 'count' then
            return (inv and name) and Inventory.GetItemCount(inv, name, filter) or 0
        end
        local list = {}
        if inv and name then
            for _, it in ipairs(Inventory.FindSlots(inv, name, filter)) do list[#list + 1] = publicItem(it) end
        end
        return list
    end
    if search ~= 'count' and search ~= 'slots' then return false end
    if type(items) == 'table' then
        local out = {}
        for _, name in pairs(items) do
            if type(name) == 'string' then out[name] = one(name) end
        end
        return out
    end
    return one(items)
end)

exports('GetItem', function(ref, item, metadata, returnsCount)
    local inv = getInv(ref)
    local name = itemName(item)
    local def = name and Items.Get(name)
    if not inv or not def then return nil end
    local filter = filterOf(metadata)
    local count = Inventory.GetItemCount(inv, name, filter)
    if returnsCount then return count end
    return {
        name = def.name,
        label = Items.Label(def.name),
        weight = def.weight,
        count = count,
        metadata = filter and Inventory.Copy(filter) or {},
    }
end)

exports('GetSlot', function(ref, slot)
    local inv = getInv(ref)
    slot = Inventory.ToInt(slot)
    local it = inv and slot and inv.items[slot]
    return it and publicItem(it) or nil
end)

exports('GetSlotWithItem', function(ref, item, metadata, strict)
    local inv = getInv(ref)
    local name = itemName(item)
    if not inv or not name then return nil end
    local it = Inventory.FindSlots(inv, name, filterOf(metadata), strict == true)[1]
    return it and publicItem(it) or nil
end)

exports('GetSlotsWithItem', function(ref, item, metadata, strict)
    local out = {}
    local inv = getInv(ref)
    local name = itemName(item)
    if not inv or not name then return out end
    for _, it in ipairs(Inventory.FindSlots(inv, name, filterOf(metadata), strict == true)) do
        out[#out + 1] = publicItem(it)
    end
    return out
end)

exports('SetMetadata', function(ref, slot, metadata)
    local inv = getInv(ref)
    if not inv then return false end
    local md = Inventory.NormalizeMetadata(metadata)
    if not md then return false end
    return Inventory.SetMetadata(inv, slot, md)
end)

exports('SetDurability', function(ref, slot, durability)
    local inv = getInv(ref)
    slot = Inventory.ToInt(slot)
    durability = tonumber(durability)
    local it = inv and slot and inv.items[slot]
    if not it or not durability or durability ~= durability then return false end
    local md = Inventory.Copy(it.metadata)
    md.durability = math.max(0, math.min(100, durability))
    return Inventory.SetMetadata(inv, slot, md)
end)

exports('GetInventory', function(ref)
    local inv = getInv(ref)
    if not inv then return nil end
    return {
        id = inv.id,
        type = inv.type,
        label = inv.label,
        slots = inv.slots,
        maxWeight = inv.maxWeight,
        weight = inv.weight,
        owner = inv.owner,
    }
end)

exports('GetInventoryItems', function(ref)
    local out = {}
    local inv = getInv(ref)
    if not inv then return out end
    for s = 1, inv.slots do
        local it = inv.items[s]
        if it then out[#out + 1] = publicItem(it) end
    end
    return out
end)

exports('ClearInventory', function(ref, keep)
    local inv = getInv(ref)
    if not inv then return false end
    local ok = Inventory.Clear(inv, keep)
    if ok then debug('ClearInventory %s (%s)', tostring(inv.id), tostring(GetInvokingResource())) end
    return ok
end)

--- Arme en main du joueur : item (comme GetSlot) | nil. Le ped doit tenir cette arme.
exports('GetCurrentWeapon', function(src)
    local it = InvPlayers.GetCurrentWeapon(src)
    return it and publicItem(it) or nil
end)

------------------------------------------------------------------------
-- Conteneurs (délégués au LOT 2)
------------------------------------------------------------------------

exports('RegisterStash', function(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) ~= 'string' or id == '' then return false end
    if not Containers or not Containers.RegisterStash then return false end
    return Containers.RegisterStash(id, label, slots, maxWeight, owner, groups, coords) == true
end)

exports('RegisterShop', function(id, data)
    if type(id) ~= 'string' or id == '' or type(data) ~= 'table' then return false end
    if not Containers or not Containers.RegisterShop then return false end
    return Containers.RegisterShop(id, data) == true
end)

exports('forceOpenInventory', function(src, invType, data)
    src = Inventory.ToInt(src)
    if not src or type(invType) ~= 'string' then return false end
    if not Containers or not Containers.ForceOpen then return false end
    return Containers.ForceOpen(src, invType, data) == true
end)

------------------------------------------------------------------------
-- Items utilisables : cb(src, item, metadata, slot), retiré à l'arrêt de la ressource appelante.
------------------------------------------------------------------------

exports('RegisterUsableItem', function(item, cb)
    local name = itemName(item)
    if not name or cb == nil then return false end
    local resource = GetInvokingResource() or RES
    InvPlayers.RegisterUsable(name, cb, resource)
    debug('usable item %s registered by %s', name, resource)
    return true
end)
