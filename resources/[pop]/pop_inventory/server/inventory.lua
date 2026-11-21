-- Objet Inventory : slots, poids, ajout / retrait / déplacement, metadata, synchronisation, état modifié.
-- Règle anti-duplication : aucune attente (Wait, Await, SQL) entre la vérification et l'écriture d'une opération.

Inventory = Inventory or {}

local RES = GetCurrentResourceName()

local METADATA_MAX_LENGTH = 4096 -- caractères max du JSON d'une metadata
local COUNT_MAX = 1000000000     -- quantité max d'une pile (et d'un ajout)

local Inventories = {} -- [id] = inv (id = src pour un joueur, chaîne sinon)
local loading = {}     -- [id] = promise de chargement en cours (Inventory.Load)

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = deepcopy(val) end
    return out
end
Inventory.Copy = deepcopy

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end
Inventory.Equal = deepEqual

--- Filtre metadata : toutes les clés du filtre égales dans md ; strict = égalité complète.
local function matches(md, filter, strict)
    if filter == nil then return true end
    if type(filter) ~= 'table' then return false end
    if strict then return deepEqual(md, filter) end
    for k, v in pairs(filter) do
        if not deepEqual(md[k], v) then return false end
    end
    return true
end
Inventory.Matches = matches

--- Entier (accepte un flottant entier venu de JSON), sinon nil.
-- NOTE: un flottant entier (3.0) est accepté comme 3 : JSON côté NUI peut en produire, aucun risque supplémentaire.
local function toInt(v)
    if math.type(v) == 'integer' then return v end
    if math.type(v) == 'float' and v == math.floor(v) and v > -2^31 and v < 2^31 then
        return math.tointeger(v)
    end
    return nil
end
Inventory.ToInt = toInt
Inventory.COUNT_MAX = COUNT_MAX

local function newSerial()
    return ('POP%06d'):format(math.random(0, 999999))
end

--- Metadata d'entrée : nil → {}, chaîne → { type = chaîne }, table → copie (JSON < METADATA_MAX_LENGTH).
--- Renvoie la table, ou nil si invalide.
function Inventory.NormalizeMetadata(md)
    if md == nil then return {} end
    if type(md) == 'string' then md = { type = md } end
    if type(md) ~= 'table' then return nil end
    local ok, encoded = pcall(json.encode, md)
    if not ok or type(encoded) ~= 'string' or #encoded >= METADATA_MAX_LENGTH then return nil end
    return deepcopy(md)
end

-- Armes : série, munitions et durabilité ajoutées si absentes (modifie md).
local function prepareWeapon(def, md)
    if not def.weapon then return md end
    if md.serial == nil then md.serial = newSerial() end
    if md.ammo == nil and def.ammo then md.ammo = 0 end -- armes sans munitions (couteau, batte) : pas de champ ammo
    if md.durability == nil then md.durability = 100 end
    return md
end

local function stackWeight(name, count)
    local def = Items.Get(name)
    return (def and def.weight or 0) * count
end

local function computeWeight(inv)
    local w = 0
    for _, it in pairs(inv.items) do w = w + stackWeight(it.name, it.count) end
    return w
end

-- Raison « plein » selon l'inventaire concerné.
local function fullReason(inv)
    return inv.type == 'player' and 'inventory_full' or 'container_full'
end
Inventory.FullReason = fullReason

local function validSlot(inv, slot)
    slot = toInt(slot)
    if not slot or slot < 1 or slot > inv.slots then return nil end
    return slot
end

local function firstFree(inv, exclude)
    for s = 1, inv.slots do
        if not inv.items[s] and not (exclude and exclude[s]) then return s end
    end
    return nil
end

local function firstCompatible(inv, name, md, exceptSlot, count)
    for s = 1, inv.slots do
        local it = inv.items[s]
        if it and s ~= exceptSlot and it.name == name and it.count + (count or 0) <= COUNT_MAX and deepEqual(it.metadata, md) then return s end
    end
    return nil
end

local function itemPayload(it)
    if not it then return false end
    return { slot = it.slot, name = it.name, count = it.count, metadata = deepcopy(it.metadata) }
end

------------------------------------------------------------------------
-- Synchronisation : un message par destinataire, regroupant les inventaires touchés.
------------------------------------------------------------------------

-- touched = { { inv = inv, slots = { [slot] = true } }, ... }
local function sync(touched)
    local messages = {} -- [src] = Changes

    local function push(target, side, inv, slots)
        local msg = messages[target]
        if not msg then
            msg = { changes = {}, weights = {} }
            messages[target] = msg
        end
        for slot in pairs(slots) do
            msg.changes[#msg.changes + 1] = { side = side, slot = slot, item = itemPayload(inv.items[slot]) }
        end
        msg.weights[side] = inv.weight
    end

    for _, t in ipairs(touched) do
        local inv = t.inv
        inv.weight = computeWeight(inv)
        inv.dirty = true
        if inv.type == 'player' then push(inv.id, 'player', inv, t.slots) end
        for viewer in pairs(inv.viewers) do push(viewer, 'secondary', inv, t.slots) end
    end

    for target, msg in pairs(messages) do
        TriggerClientEvent('pop_inventory:client:update', target, msg)
    end

    -- Suites : conteneurs (LOT 2) ou joueur (arme, argent, miroir framework).
    for _, t in ipairs(touched) do
        local inv = t.inv
        if inv.type ~= 'player' then
            if Containers and Containers.OnChanged then Containers.OnChanged(inv) end
        elseif InvPlayers and InvPlayers.OnInventoryChanged then
            InvPlayers.OnInventoryChanged(inv)
        end
    end
end

local function syncOne(inv, slots)
    if next(slots) then sync({ { inv = inv, slots = slots } }) end
end

------------------------------------------------------------------------
-- Cycle de vie
------------------------------------------------------------------------

-- Place une liste d'items au format SQL dans inv.items (chargement : poids ignoré).
local function placeLoaded(inv, list)
    if type(list) ~= 'table' then return end
    local pending = {}
    for _, raw in pairs(list) do
        if type(raw) == 'table' and type(raw.name) == 'string' then
            local name = raw.name:lower()
            local def = Items.Get(name)
            local count = math.min(toInt(tonumber(raw.count)) or 0, COUNT_MAX)
            if not def then
                print(('[%s] unknown item ignored: inventory=%s item=%s count=%s'):format(RES, tostring(inv.id), name, count))
            elseif count > 0 then
                local md = type(raw.metadata) == 'table' and raw.metadata or {}
                if def.stack then
                    pending[#pending + 1] = { slot = toInt(tonumber(raw.slot)), name = name, count = count, metadata = md }
                else
                    -- Non empilable : une unité par slot.
                    for i = 1, count do
                        local m = i == 1 and md or deepcopy(md)
                        if def.weapon and i > 1 then m.serial = nil end
                        pending[#pending + 1] = { slot = i == 1 and toInt(tonumber(raw.slot)) or nil, name = name, count = 1, metadata = prepareWeapon(def, m) }
                    end
                end
            end
        end
    end
    -- D'abord les slots valides et libres, puis le reste dans les premiers slots libres.
    local rest = {}
    for _, it in ipairs(pending) do
        local s = it.slot
        if s and s >= 1 and s <= inv.slots and not inv.items[s] then
            it.slot = s
            inv.items[s] = it
        else
            rest[#rest + 1] = it
        end
    end
    -- Plus d'items que de slots (slots réduits dans la config) : inventaire agrandi temporairement, rien n'est perdu.
    local enlarged = false
    for _, it in ipairs(rest) do
        local s = firstFree(inv)
        if not s then
            inv.slots = inv.slots + 1
            s = inv.slots
            enlarged = true
        end
        it.slot = s
        inv.items[s] = it
    end
    if enlarged then
        print(('[%s] ^3warning:^7 inventory %s holds more stacks than its slots: temporarily enlarged to %d slots'):format(RES, tostring(inv.id), inv.slots))
    end
end

--- Crée (ou remplace) un inventaire en mémoire.
function Inventory.Create(id, data)
    data = data or {}
    local inv = {
        id = id,
        type = data.type or 'stash',
        label = data.label or '',
        slots = math.max(1, toInt(data.slots) or 1),
        maxWeight = math.max(0, toInt(data.maxWeight) or 0),
        weight = 0,
        items = {},
        owner = data.owner,
        persist = data.persist == true,
        dirty = false,
        viewers = {},
        coords = data.coords,
        netId = data.netId,
        plate = data.plate,
        groups = data.groups,
        closing = false,
    }
    placeLoaded(inv, data.items)
    inv.weight = computeWeight(inv)
    Inventories[id] = inv
    return inv
end

--- Inventaire en mémoire (ref = src ou id), jamais de chargement.
function Inventory.Get(ref)
    if ref == nil then return nil end
    return Inventories[ref]
end

--- Tous les inventaires en mémoire (lecture seule).
function Inventory.All()
    return Inventories
end

--- Bloquant : inventaire en mémoire, sinon lecture SQL (si data.persist) puis création.
--- Deux appels simultanés pour le même id attendent la même promesse.
function Inventory.Load(id, data)
    if Inventories[id] then return Inventories[id] end
    if loading[id] then
        Citizen.Await(loading[id])
        return Inventories[id]
    end
    data = data or {}
    local p = promise.new()
    loading[id] = p
    local ok, err = pcall(function()
        local items
        if data.persist then
            Database.WaitSave(id)
            items = Database.LoadStash(id)
        end
        if items == false then
            -- Erreur SQL : on ne crée rien (un inventaire vide écraserait le contenu réel à la sauvegarde).
            error('database error, inventory not created', 0)
        end
        if not Inventories[id] then
            local d = deepcopy(data)
            d.items = items or d.items
            Inventory.Create(id, d)
        end
    end)
    if not ok then print(('[%s] ^1load error for %s: %s^7'):format(RES, tostring(id), tostring(err))) end
    loading[id] = nil
    p:resolve(true)
    return Inventories[id]
end

--- Décharge un inventaire (sauvegarde d'abord si save et dirty). Refuse si des viewers restent.
function Inventory.Remove(id, save)
    local inv = Inventories[id]
    if not inv then return false end
    if next(inv.viewers) then return false end
    inv.closing = true
    if save and inv.dirty then Inventory.Save(inv) end
    Inventories[id] = nil
    return true
end

--- Sauvegarde si persist et dirty (instantané immédiat, écriture asynchrone).
function Inventory.Save(inv)
    if inv and inv.persist and inv.dirty then Database.Save(inv) end
end

function Inventory.AddViewer(inv, src)
    if inv then inv.viewers[src] = true end
end

function Inventory.RemoveViewer(inv, src)
    if inv then inv.viewers[src] = nil end
end

function Inventory.IsEmpty(inv)
    return next(inv.items) == nil
end

--- Vue réseau (InvView) : items en liste triée par slot.
function Inventory.View(inv)
    local list = {}
    for _, it in pairs(inv.items) do list[#list + 1] = itemPayload(it) end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return {
        type = inv.type,
        label = inv.label,
        slots = inv.slots,
        maxWeight = inv.maxWeight,
        weight = inv.weight,
        items = list,
    }
end

------------------------------------------------------------------------
-- Lecture
------------------------------------------------------------------------

function Inventory.GetItemCount(inv, name, metadata, strict)
    if not inv or type(name) ~= 'string' then return 0 end
    name = name:lower()
    local total = 0
    for _, it in pairs(inv.items) do
        if it.name == name and matches(it.metadata, metadata, strict) then total = total + it.count end
    end
    return total
end

--- Piles correspondantes triées par slot (références internes : copier avant de les exposer).
function Inventory.FindSlots(inv, name, metadata, strict)
    local out = {}
    if not inv or type(name) ~= 'string' then return out end
    name = name:lower()
    for s = 1, inv.slots do
        local it = inv.items[s]
        if it and it.name == name and matches(it.metadata, metadata, strict) then out[#out + 1] = it end
    end
    return out
end

-- Plan de placement sans écrire : liste { slot, count, metadata } ou nil, reason.
local function planAdd(inv, def, count, md, slot, ignoreWeight)
    if not ignoreWeight and inv.weight + def.weight * count > inv.maxWeight then
        return nil, fullReason(inv)
    end
    local plan = {}
    if def.stack then
        local s = validSlot(inv, slot)
        if s then
            local it = inv.items[s]
            if not it or (it.name == def.name and it.count + count <= COUNT_MAX and deepEqual(it.metadata, md)) then
                plan[1] = { slot = s, count = count, metadata = md }
                return plan
            end
            -- Slot demandé incompatible : placement automatique.
        end
        s = firstCompatible(inv, def.name, md, nil, count) or firstFree(inv)
        if not s then return nil, fullReason(inv) end
        plan[1] = { slot = s, count = count, metadata = md }
        return plan
    end
    -- Non empilable : une unité par slot libre.
    local used = {}
    local s = validSlot(inv, slot)
    if s and not inv.items[s] then
        used[s] = true
        plan[1] = { slot = s, count = 1, metadata = md }
    end
    while #plan < count do
        local free = firstFree(inv, used)
        if not free then return nil, fullReason(inv) end
        used[free] = true
        local m = md
        if #plan > 0 then
            m = deepcopy(md)
            if def.weapon then m.serial = nil end -- une série unique par arme
        end
        plan[#plan + 1] = { slot = free, count = 1, metadata = m }
    end
    return plan
end

function Inventory.CanCarry(inv, name, count, metadata)
    if not inv or inv.closing then return false end
    local def = Items.Get(name)
    count = toInt(count)
    if not def or not count or count < 1 or count > COUNT_MAX then return false end
    local md = type(metadata) == 'table' and metadata or {}
    return planAdd(inv, def, count, md, nil, false) ~= nil
end

function Inventory.CanCarryWeight(inv, weight)
    weight = tonumber(weight)
    if not inv or not weight then return false end
    return inv.weight + weight <= inv.maxWeight
end

------------------------------------------------------------------------
-- Écriture
------------------------------------------------------------------------

--- Ajoute count items. Piles compatibles d'abord, puis slots libres. Poids et place vérifiés avant d'écrire.
--- ignoreWeight (interne) : argent physique synchronisé avec le framework.
function Inventory.AddItem(inv, name, count, metadata, slot, ignoreWeight)
    if not inv or inv.closing then return false, 'not_loaded' end
    local def = Items.Get(name)
    if not def then return false, 'invalid_item' end
    count = toInt(count)
    if not count or count < 1 or count > COUNT_MAX then return false, 'error' end
    local md = type(metadata) == 'table' and deepcopy(metadata) or {}

    local plan, reason = planAdd(inv, def, count, md, slot, ignoreWeight)
    if not plan then return false, reason end

    local slots = {}
    for _, p in ipairs(plan) do
        local it = inv.items[p.slot]
        if it then
            it.count = it.count + p.count
        else
            inv.items[p.slot] = { name = def.name, count = p.count, slot = p.slot, metadata = prepareWeapon(def, p.metadata) }
        end
        slots[p.slot] = true
    end
    syncOne(inv, slots)
    return true
end

--- Retire count items (tout ou rien). slot : seulement ce slot. metadata : filtre.
function Inventory.RemoveItem(inv, name, count, metadata, slot)
    if not inv or inv.closing then return false, 'not_loaded' end
    if type(name) ~= 'string' then return false, 'item_not_found' end
    name = name:lower()
    count = toInt(count)
    if not count or count < 1 then return false, 'error' end

    local slots = {}
    if slot ~= nil then
        local s = validSlot(inv, slot)
        local it = s and inv.items[s]
        if not it or it.name ~= name or it.count < count or not matches(it.metadata, metadata) then
            return false, 'item_not_found'
        end
        it.count = it.count - count
        if it.count <= 0 then inv.items[s] = nil end
        slots[s] = true
    else
        local stacks = Inventory.FindSlots(inv, name, metadata)
        local total = 0
        for _, it in ipairs(stacks) do total = total + it.count end
        if total < count then return false, 'item_not_found' end
        local left = count
        for _, it in ipairs(stacks) do
            local take = math.min(left, it.count)
            it.count = it.count - take
            if it.count <= 0 then inv.items[it.slot] = nil end
            slots[it.slot] = true
            left = left - take
            if left <= 0 then break end
        end
    end
    syncOne(inv, slots)
    return true
end

--- Remplace la metadata d'un slot (copie). Synchro + dirty.
function Inventory.SetMetadata(inv, slot, metadata)
    if not inv or inv.closing then return false end
    local s = validSlot(inv, slot)
    local it = s and inv.items[s]
    if not it or type(metadata) ~= 'table' then return false end
    it.metadata = deepcopy(metadata)
    syncOne(inv, { [s] = true })
    return true
end

--- Vide l'inventaire. keep = nom ou liste de noms conservés.
function Inventory.Clear(inv, keep)
    if not inv or inv.closing then return false end
    local kept = {}
    if type(keep) == 'string' then
        kept[keep:lower()] = true
    elseif type(keep) == 'table' then
        for _, n in pairs(keep) do
            if type(n) == 'string' then kept[n:lower()] = true end
        end
    end
    local slots = {}
    for s, it in pairs(inv.items) do
        if not kept[it.name] then
            inv.items[s] = nil
            slots[s] = true
        end
    end
    syncOne(inv, slots)
    return true
end

--- Déplacement entre slots / inventaires (SPEC §11.1.3). Aucune attente entre vérification et écriture.
function Inventory.Move(src, fromInv, fromSlot, toInv, toSlot, count)
    if not fromInv or not toInv then return false, 'error' end
    if fromInv.closing or toInv.closing then return false, 'not_loaded' end

    fromSlot = validSlot(fromInv, fromSlot)
    if not fromSlot then return false, 'error' end
    local item = fromInv.items[fromSlot]
    if not item then return false, 'item_not_found' end
    local def = Items.Get(item.name)
    if not def then return false, 'invalid_item' end

    -- 1. Quantité.
    if count == nil then
        count = item.count
    else
        count = toInt(count)
        if not count or count < 1 or count > item.count then return false, 'error' end
    end
    if not def.stack then count = 1 end

    local same = fromInv == toInv

    -- 2. Destination automatique.
    if toSlot == nil then
        if def.stack then
            toSlot = firstCompatible(toInv, item.name, item.metadata, same and fromSlot or nil, count)
        end
        toSlot = toSlot or firstFree(toInv)
        if not toSlot then return false, fullReason(toInv) end
    else
        toSlot = validSlot(toInv, toSlot)
        if not toSlot then return false, 'error' end
    end

    -- 3. Même slot : rien à faire.
    if same and fromSlot == toSlot then return true end

    local dest = toInv.items[toSlot]
    local movedWeight = def.weight * count

    if not dest then
        -- 4. Slot vide : déplacement ou séparation.
        if not same and toInv.weight + movedWeight > toInv.maxWeight then return false, fullReason(toInv) end
        if count == item.count then
            fromInv.items[fromSlot] = nil
            item.slot = toSlot
            toInv.items[toSlot] = item
        else
            item.count = item.count - count
            toInv.items[toSlot] = { name = item.name, count = count, slot = toSlot, metadata = deepcopy(item.metadata) }
        end
    elseif dest.name == item.name and def.stack and deepEqual(dest.metadata, item.metadata) then
        -- 5. Fusion.
        if dest.count + count > COUNT_MAX then return false, 'error' end
        if not same and toInv.weight + movedWeight > toInv.maxWeight then return false, fullReason(toInv) end
        dest.count = dest.count + count
        item.count = item.count - count
        if item.count <= 0 then fromInv.items[fromSlot] = nil end
    else
        -- 6. Échange : seulement la pile entière.
        if count ~= item.count then return false, 'error' end
        if not same then
            local destWeight = stackWeight(dest.name, dest.count)
            if toInv.weight - destWeight + movedWeight > toInv.maxWeight then return false, fullReason(toInv) end
            if fromInv.weight - movedWeight + destWeight > fromInv.maxWeight then return false, fullReason(fromInv) end
        end
        fromInv.items[fromSlot] = dest
        dest.slot = fromSlot
        toInv.items[toSlot] = item
        item.slot = toSlot
    end

    if same then
        sync({ { inv = fromInv, slots = { [fromSlot] = true, [toSlot] = true } } })
    else
        sync({
            { inv = fromInv, slots = { [fromSlot] = true } },
            { inv = toInv, slots = { [toSlot] = true } },
        })
    end
    if Config.Debug then
        print(('[%s] move src=%s %s:%d -> %s:%d x%d %s'):format(RES, tostring(src), tostring(fromInv.id), fromSlot,
            tostring(toInv.id), toSlot, count, item.name))
    end
    return true
end
