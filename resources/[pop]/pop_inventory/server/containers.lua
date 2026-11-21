-- pop_inventory : sessions d'ouverture des inventaires secondaires (SPEC §11.2.1, §11.2.2, §12).
-- Chaque type (drop, trunk, glovebox, stash, shop, player) s'enregistre dans Containers.Types depuis son fichier :
--   open(src, request, s)        -> inv | nil, reason   (peut attendre : chargement SQL)
--                                   boutique (isShop) : ShopView | nil, reason
--   access(src, inv, s)          -> bool, reason        (aucune attente ; s.forced = sans distance ni job)
--   watch(src, inv, s)           -> watch | nil          (boutique : watch(src, s))
--   view(view, inv, s), opened(src, inv, s), changed(inv), unloadable(inv), keep(inv), forceRequest(data) : facultatifs
-- Les fonctions des autres fichiers ne sont appelées qu'à l'exécution (jamais au chargement).

Containers = Containers or {}
Containers.Types = Containers.Types or {}

local CONTAINER_UNLOAD_DELAY = 600 -- s : coffre / stash par personnage sans spectateur avant déchargement
local READY_TIMEOUT = 30000        -- ms : attente max de la base du LOT 1 (Database.ready)
local FORCE_WAIT_TRIES = 100       -- x 100 ms : attente d'une ouverture en cours avant une ouverture forcée
local POINT_ID_MAX = 64            -- longueur max d'un id de stash / boutique reçu du client
local FORCED_RANGE = 15.0          -- m : session forcée refusée au-delà de cette distance du point d'ouverture
local TOLERANCE = 1.0              -- m : marge serveur (latence)

local RES = GetCurrentResourceName()

local Sessions = {}     -- [src] = { kind = 'inv'|'newdrop'|'shop', inv, shopId, shop, articles, forced, netId, plate, target, stashId }
local opening = {}      -- [src] = true pendant une ouverture (verrou anti-doublon)
local unloadTimers = {} -- [invId] = jeton de la minuterie de déchargement en cours

------------------------------------------------------------------------
-- Utilitaires partagés par les fichiers du LOT 2
------------------------------------------------------------------------

--- Log console (anglais) des actions sensibles, si Config.Debug.
function Containers.Log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

--- Avertissement console toujours affiché (configuration invalide).
function Containers.Warn(msg, ...)
    print(('[%s] ^3warning:^7 ' .. msg):format(RES, ...))
end

--- vector3 depuis un vector3/vector4 ou une table { x, y, z } / { [1], [2], [3] } ; nil si invalide.
function Containers.ToVec(c)
    local t = type(c)
    if t == 'vector3' or t == 'vector4' then return vector3(c.x, c.y, c.z) end
    if t == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y and z then return vector3(x, y, z) end
    end
    return nil
end

--- Coordonnées au format réseau { x, y, z }.
function Containers.Plain(v)
    return { x = v.x, y = v.y, z = v.z }
end

--- Attend que la base du LOT 1 soit prête (tables créées, définitions importées), au plus READY_TIMEOUT.
-- NOTE: Database.ready est décrit au §11.1.4 (LOT 1) ; absent, on continue après le délai.
function Containers.WaitReady()
    local waited = 0
    while not (Database and Database.ready) and waited < READY_TIMEOUT do
        Wait(250)
        waited = waited + 250
    end
end

--- Inventaire joueur chargé et utilisable, sinon nil.
function Containers.PlayerInv(src)
    local inv = Inventory.Get(src)
    if not inv or inv.closing then return nil end
    return inv
end

function Containers.HasViewers(inv)
    return type(inv.viewers) == 'table' and next(inv.viewers) ~= nil
end

function Containers.GetSession(src)
    return Sessions[src]
end

--- Session forcée : le joueur doit rester à FORCED_RANGE du point où elle a été ouverte (sinon false, 'too_far').
function Containers.ForcedInRange(src, s)
    if not s or not s.forced or not s.origin then return true end
    local pos = Bridge.GetCoords(src)
    if not pos or #(pos - s.origin) > FORCED_RANGE + TOLERANCE then return false, 'too_far' end
    return true
end

local playerInv = Containers.PlayerInv
local hasViewers = Containers.HasViewers

------------------------------------------------------------------------
-- Déchargement différé et fermeture
------------------------------------------------------------------------

local function scheduleUnload(inv)
    local id, token = inv.id, {}
    unloadTimers[id] = token
    SetTimeout(CONTAINER_UNLOAD_DELAY * 1000, function()
        if unloadTimers[id] ~= token then return end
        unloadTimers[id] = nil
        if Inventory.Get(id) ~= inv or inv.closing or hasViewers(inv) then return end
        local t = Containers.Types[inv.type]
        if t and t.keep and t.keep(inv) then return scheduleUnload(inv) end
        Inventory.Remove(id, true)
        Containers.Log('unloaded %s', tostring(id))
    end)
end

-- Appelée quand un spectateur quitte inv (ou après une ouverture refusée sur un inventaire chargé).
local function afterViewerLeft(inv)
    if hasViewers(inv) or inv.closing or Inventory.Get(inv.id) ~= inv then return end
    local t = Containers.Types[inv.type]
    if not t then return end
    if t.changed then t.changed(inv) end -- drop vide / coffre non possédé vide : suppression immédiate
    if Inventory.Get(inv.id) ~= inv then return end
    if t.unloadable and t.unloadable(inv) then
        Inventory.Save(inv)
        scheduleUnload(inv)
    end
end

-- Supprime la session de src ; notify = envoyer client:close (fermeture décidée par le serveur).
local function closeSession(src, notify)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    -- Fin d'une session : l'inventaire joueur modifié est écrit tout de suite (pas d'attente de l'autosave).
    local pinv = Inventory.Get(src)
    if pinv and pinv.dirty and not pinv.closing then Inventory.Save(pinv) end
    if s.inv then
        Inventory.RemoveViewer(s.inv, src)
        TriggerEvent('pop_inventory:closedInventory', src, s.inv.id)
        afterViewerLeft(s.inv)
    end
    if notify then TriggerClientEvent('pop_inventory:client:close', src) end
end

Containers.EndSession = closeSession

--- Ouvre la session de src sur inv (le contrôle d'accès est déjà fait par l'appelant).
function Containers.Attach(src, s, inv)
    s.kind = 'inv'
    s.inv = inv
    Sessions[src] = s
    unloadTimers[inv.id] = nil
    Inventory.AddViewer(inv, src)
    TriggerEvent('pop_inventory:openedInventory', src, inv.id)
    local t = Containers.Types[inv.type]
    if t and t.opened then t.opened(src, inv, s) end
end

--- Retire src de inv : session basculée sur le panneau Sol vide (toNewdrop) ou supprimée avec client:close.
function Containers.Detach(src, inv, toNewdrop)
    local s = Sessions[src]
    if not s or s.inv ~= inv then
        Inventory.RemoveViewer(inv, src)
        return
    end
    if toNewdrop then
        -- Rien à envoyer : le panneau « Sol » vide affiché par le client reste juste (§11.2.2).
        Inventory.RemoveViewer(inv, src)
        TriggerEvent('pop_inventory:closedInventory', src, inv.id)
        Sessions[src] = { kind = 'newdrop' }
    else
        closeSession(src, true)
    end
end

------------------------------------------------------------------------
-- Ouverture
------------------------------------------------------------------------

local function newdropView()
    return {
        type = 'newdrop', label = L('inv_ground'),
        slots = Config.Drops.Slots, maxWeight = Config.Drops.MaxWeight, weight = 0,
        items = {},
    }
end

-- Ne garde que les champs autorisés d'une demande client (jamais d'id d'inventaire, de plaque ni d'owner).
-- Entiers : Inventory.ToInt (un flottant entier venu de JSON est accepté).
local function sanitize(request)
    if request == nil then return nil, true end
    if type(request) ~= 'table' then return nil, false end
    local t = request.type
    if t == 'glovebox' or t == 'trunk' then
        local netId = Inventory.ToInt(request.netId)
        if netId then return { type = t, netId = netId }, true end
    elseif t == 'drop' then
        local id = Inventory.ToInt(request.id)
        if id then return { type = t, id = id }, true end
    elseif t == 'stash' or t == 'shop' then
        if type(request.id) == 'string' and #request.id <= POINT_ID_MAX then return { type = t, id = request.id }, true end
    elseif t == 'player' then
        local target = Inventory.ToInt(request.target)
        if target then return { type = t, target = target }, true end
    end
    return nil, false
end

local function doOpen(src, request, forced)
    if not Bridge.GetPlayer(src) or not playerInv(src) then return false, 'not_loaded' end
    if Bridge.IsDead(src) or InvPlayers.IsBusy(src) then return false, 'cannot_now' end
    closeSession(src, false)

    -- Inventaire seul + panneau Sol vide.
    if request == nil then
        Sessions[src] = { kind = 'newdrop' }
        ReconcileCash(src)
        return true, { player = Inventory.View(playerInv(src)), secondary = newdropView() }
    end

    local t = Containers.Types[request.type]
    if not t then return false, 'error' end
    local s = { forced = forced == true }
    if s.forced then s.origin = Bridge.GetCoords(src) end

    if t.isShop then
        local view, reason = t.open(src, request, s)
        if not view then return false, reason or 'error' end
        s.kind = 'shop'
        Sessions[src] = s
        ReconcileCash(src)
        local pinv = playerInv(src)
        if not pinv then
            Sessions[src] = nil
            return false, 'not_loaded'
        end
        local watch = not s.forced and t.watch(src, s) or nil
        return true, { player = Inventory.View(pinv), secondary = view, watch = watch }
    end

    local inv, reason = t.open(src, request, s) -- peut attendre (chargement)
    if not inv then return false, reason or 'error' end

    -- Après une éventuelle attente : tout revérifier avant d'ouvrir.
    if not Bridge.GetPlayer(src) or not playerInv(src) then return false, 'not_loaded' end
    if inv.closing or Inventory.Get(inv.id) ~= inv then return false, 'error' end
    if Bridge.IsDead(src) or InvPlayers.IsBusy(src) then return false, 'cannot_now' end
    local ok, why = t.access(src, inv, s)
    if not ok then
        afterViewerLeft(inv) -- chargé pour rien : déchargement différé
        return false, why or 'error'
    end

    Containers.Attach(src, s, inv)
    ReconcileCash(src)

    local view = Inventory.View(inv)
    if t.view then t.view(view, inv, s) end
    local watch = not s.forced and t.watch and t.watch(src, inv, s) or nil
    return true, { player = Inventory.View(playerInv(src)), secondary = view, watch = watch }
end

-- Verrou opening[src] + protection contre les erreurs.
local function guardedOpen(src, request, forced)
    if opening[src] then return false, 'busy' end
    opening[src] = true
    local ok, res, payload = pcall(doOpen, src, request, forced)
    opening[src] = nil
    if not ok then
        print(('[%s] open error for %s: %s'):format(RES, tostring(src), tostring(res)))
        return false, 'error'
    end
    return res, payload
end

--- Logique du callback pop_inventory:open (bloquante : charge si besoin).
function Containers.Open(src, request)
    local clean, valid = sanitize(request)
    if not valid then return false, 'error' end
    return guardedOpen(src, clean, false)
end

--- Ouverture forcée par un script serveur (sans distance ni job). true si la demande est valide.
function Containers.ForceOpen(src, invType, data)
    src = tonumber(src)
    if not src or not Bridge.GetPlayer(src) or not playerInv(src) then return false end
    local t = type(invType) == 'string' and Containers.Types[invType]
    if not t or not t.forceRequest then return false end
    local request = t.forceRequest(data)
    if type(request) ~= 'table' then return false end
    request.type = invType
    Containers.Log('forceOpenInventory %s for %s (by %s)', invType, src, GetInvokingResource() or RES)
    CreateThread(function()
        local tries = 0
        while opening[src] and tries < FORCE_WAIT_TRIES do
            Wait(100)
            tries = tries + 1
        end
        local ok, payload = guardedOpen(src, request, true)
        if ok then
            TriggerClientEvent('pop_inventory:client:open', src, payload)
        else
            Containers.Log('forceOpenInventory %s for %s failed: %s', invType, src, tostring(payload))
        end
    end)
    return true
end

------------------------------------------------------------------------
-- Accès pendant une session (appelé par le LOT 1 à chaque action)
------------------------------------------------------------------------

--- Ferme la session de src et celles des joueurs qui fouillent src (client:close pour eux).
function Containers.Close(src)
    src = tonumber(src)
    if not src then return end
    closeSession(src, false)
    for other, s in pairs(Sessions) do
        if s.inv and s.inv.id == src then closeSession(other, true) end
    end
end

--- inv | 'newdrop' | 'shop' | nil. Une session sur un inventaire déchargé est fermée.
function Containers.GetSecondary(src)
    local s = Sessions[src]
    if not s then return nil end
    if s.kind == 'newdrop' then return 'newdrop' end
    if s.kind == 'shop' then return 'shop' end
    local inv = s.inv
    if not inv or inv.closing or Inventory.Get(inv.id) ~= inv then
        closeSession(src, true)
        return nil
    end
    return inv
end

--- Revérifie les règles du type (§12). Un échec d'accès ferme la session (client:close).
function Containers.CanAccess(src, inv)
    local s = Sessions[src]
    if not inv or not s or s.inv ~= inv or inv.closing or Inventory.Get(inv.id) ~= inv then
        return false, 'error'
    end
    if Bridge.IsDead(src) or InvPlayers.IsBusy(src) then return false, 'cannot_now' end
    local inRange, rangeReason = Containers.ForcedInRange(src, s)
    if not inRange then
        closeSession(src, true)
        return false, rangeReason
    end
    local t = Containers.Types[inv.type]
    if not t then
        closeSession(src, true)
        return false, 'error'
    end
    local ok, reason = t.access(src, inv, s)
    if not ok then
        closeSession(src, true)
        return false, reason or 'error'
    end
    return true
end

--- Après chaque modification d'un inventaire non joueur (appelée par le LOT 1).
function Containers.OnChanged(inv)
    if not inv or Inventory.Get(inv.id) ~= inv then return end
    local t = Containers.Types[inv.type]
    if t and t.changed then t.changed(inv) end
end

--- Listes publiques envoyées par pop_inventory:init.
function Containers.GetPoints()
    return {
        drops = Containers.DropPoints(),
        stashes = Containers.StashPoints(),
        shops = Containers.ShopPoints(),
    }
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_inventory:open', function(src, request)
    return Containers.Open(src, request)
end)

Callback.Register('pop_inventory:close', function(src)
    closeSession(src, false)
    return true
end)

-- Filet de sécurité : le LOT 1 appelle aussi Containers.Close au déchargement (appel idempotent).
AddEventHandler('playerDropped', function()
    Containers.Close(source)
end)
