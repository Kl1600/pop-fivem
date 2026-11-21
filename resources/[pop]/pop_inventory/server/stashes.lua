-- pop_inventory : stockages (Config.Stashes + export RegisterStash) (SPEC §11.2.3, §12).

Containers = Containers or {}
Containers.Types = Containers.Types or {}

local TOLERANCE = 1.0      -- m : marge serveur (latence)
local POINT_DISTANCE = 2.0 -- m : portée d'un stockage (serveur : + TOLERANCE)
local ID_MAX_LENGTH = 40   -- 'stash:' + id + ':' + identifiant doit tenir dans VARCHAR(100)
local LOAD_RETRY_DELAY = 10000 -- ms : nouvel essai du chargement d'un stockage partagé après une erreur SQL

local Stashes = {} -- [id] = { id, label, slots, weight, owner, groups, coords }

-- Entier >= min (Inventory.ToInt), sinon nil.
local function intAtLeast(n, min)
    n = Inventory.ToInt(tonumber(n))
    if not n or n < min then return nil end
    return n
end

local function stashData(def, identifier)
    return {
        type = 'stash', label = def.label, slots = def.slots, maxWeight = def.weight,
        owner = identifier, coords = def.coords, groups = def.groups, persist = true,
    }
end

--- Enregistre (ou remplace) un stockage. owner = true : un stockage par personnage.
-- NOTE: un owner texte (ox) est traité comme owner = true : chaque personnage n'ouvre que le sien (option la plus sûre).
-- NOTE: les ids contenant ':' sont refusés (collision possible avec 'stash:<id>:<identifiant>').
-- NOTE: un stockage enregistré après le démarrage n'apparaît (zone) qu'aux clients qui se chargent ensuite.
-- NOTE: asynchrone : un stockage partagé est chargé en tâche de fond ; tant qu'il ne l'est pas, les exports
-- (AddItem, GetItemCount…) sur ce stockage renvoient not_loaded / 0. Une ouverture par un joueur le charge à la demande.
function Containers.RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
    if type(id) == 'string' then id = (id:gsub('^stash:', '')) end
    if type(id) ~= 'string' or id == '' or #id > ID_MAX_LENGTH or id:find(':', 1, true) then
        Containers.Warn('RegisterStash: invalid id "%s"', tostring(id))
        return false
    end
    slots, maxWeight = intAtLeast(slots, 1), intAtLeast(maxWeight, 0)
    if not slots or not maxWeight then
        Containers.Warn('RegisterStash: invalid slots or weight for "%s"', id)
        return false
    end
    local vec = nil
    if coords ~= nil then
        vec = Containers.ToVec(coords)
        if not vec then
            Containers.Warn('RegisterStash: invalid coords for "%s"', id)
            return false
        end
    end
    if groups ~= nil and type(groups) ~= 'string' and type(groups) ~= 'table' then
        Containers.Warn('RegisterStash: invalid groups for "%s"', id)
        return false
    end

    local def = {
        id = id,
        label = LabelOf(type(label) == 'string' and label ~= '' and label or 'inv_stash'),
        slots = slots, weight = maxWeight,
        owner = owner and true or nil,
        groups = groups, coords = vec,
    }
    Stashes[id] = def

    if not def.owner then
        local key = 'stash:' .. id
        local inv = Inventory.Get(key)
        if inv then
            -- Déjà chargé : mise à jour sans perte (les slots ne diminuent jamais).
            inv.label, inv.groups, inv.coords, inv.maxWeight = def.label, def.groups, def.coords, def.weight
            if def.slots > inv.slots then inv.slots = def.slots end
        else
            -- Partagé : chargé en tâche de fond (nouvel essai après une erreur SQL), jamais déchargé.
            CreateThread(function()
                Containers.WaitReady()
                while Stashes[id] == def and not Inventory.Get(key) do
                    if Inventory.Load(key, stashData(def, nil)) then break end
                    Containers.Warn('stash "%s" could not be loaded, retrying in %d s', id, LOAD_RETRY_DELAY // 1000)
                    Wait(LOAD_RETRY_DELAY)
                end
            end)
        end
    end
    Containers.Log('stash registered: %s', id)
    return true
end

--- Stockages avec coords : { { id, label, coords = { x, y, z } }, ... } (jamais les jobs).
function Containers.StashPoints()
    local list = {}
    for id, def in pairs(Stashes) do
        if def.coords then
            list[#list + 1] = { id = id, label = def.label, coords = Containers.Plain(def.coords) }
        end
    end
    return list
end

-- Job puis distance ; un stockage sans coords n'est jamais ouvrable par un client.
local function checkPoint(src, def, s)
    if s.forced then return true end
    if not def.coords then return false, 'error' end
    if def.groups and not Bridge.HasJob(src, def.groups) then return false, 'wrong_job' end
    if not Bridge.IsNear(src, def.coords, POINT_DISTANCE + TOLERANCE) then return false, 'too_far' end
    return true
end

Containers.Types.stash = {
    open = function(src, request, s)
        local def = type(request.id) == 'string' and Stashes[request.id]
        if not def then return nil, 'error' end
        s.stashId = def.id
        local ok, why = checkPoint(src, def, s)
        if not ok then return nil, why end

        local identifier
        if def.owner then
            -- L'owner fourni n'est accepté que pour une ouverture forcée (script serveur).
            if s.forced and type(request.owner) == 'string' and request.owner ~= '' then
                identifier = request.owner
            else
                identifier = Bridge.GetIdentifier(src)
            end
            if not identifier then return nil, 'not_loaded' end
        end

        local key = 'stash:' .. def.id .. (identifier and (':' .. identifier) or '')
        return Inventory.Get(key) or Inventory.Load(key, stashData(def, identifier))
    end,

    access = function(src, inv, s)
        local def = Stashes[s.stashId]
        if not def then return false, 'error' end
        if def.owner and not s.forced and inv.owner ~= Bridge.GetIdentifier(src) then return false, 'error' end
        return checkPoint(src, def, s)
    end,

    watch = function(_, _, s)
        local def = Stashes[s.stashId]
        if not def or not def.coords then return nil end
        return { coords = Containers.Plain(def.coords), distance = POINT_DISTANCE + 1.0 }
    end,

    -- Stockage par personnage : sauvegardé puis déchargé après CONTAINER_UNLOAD_DELAY sans spectateur.
    unloadable = function(inv) return inv.owner ~= nil end,

    -- data = id, 'stash:<id>' ou { id, owner }.
    forceRequest = function(data)
        if type(data) == 'string' then return { id = (data:gsub('^stash:', '')) } end
        if type(data) == 'table' and type(data.id) == 'string' then
            return { id = (data.id:gsub('^stash:', '')), owner = data.owner }
        end
        return nil
    end,
}

-- Stockages de la config (après le chargement de tous les fichiers).
CreateThread(function()
    Wait(0)
    for i, st in ipairs(Config.Stashes or {}) do
        if type(st) ~= 'table'
            or not Containers.RegisterStash(st.id, st.label, st.slots, st.weight, st.owner, st.jobs, st.coords) then
            Containers.Warn('Config.Stashes[%d] ignored', i)
        end
    end
end)
