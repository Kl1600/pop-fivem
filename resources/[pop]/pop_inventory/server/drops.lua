-- pop_inventory : dépôts au sol (SPEC §11.2.3). Jamais sauvegardés.

Containers = Containers or {}
Containers.Types = Containers.Types or {}

local TOLERANCE = 1.0            -- m : marge serveur (latence)
local DROP_MERGE_DISTANCE = 1.5  -- m : réutiliser un dépôt proche
local DROP_MAX = 300             -- dépôts simultanés
local DROP_PER_PLAYER = 10       -- dépôts actifs créés par un même personnage
local EXPIRE_CHECK = 60000       -- ms : minuterie des expirations (active seulement s'il existe des dépôts)
local EMPTY_CHECK = 1000         -- ms : un dépôt créé mais jamais rempli (déplacement refusé) est supprimé
local GROUND_OFFSET = 0.98       -- m : du centre du ped au sol

local Drops = {}      -- [id] = { id, coords, expires, announced, owner }
local dropCount = 0
local lastId = 0
local timerOn = false

local function invKey(id)
    return 'drop:' .. id
end

local function dropIdOf(inv)
    return math.tointeger(tonumber(tostring(inv.id):match('^drop:(%d+)$')))
end

-- expired : les spectateurs sont fermés (client:close) ; sinon (vidé) ils passent sur le panneau Sol vide.
local function removeDrop(id, expired)
    local d = Drops[id]
    if not d then return end
    Drops[id] = nil
    dropCount = dropCount - 1
    local inv = Inventory.Get(invKey(id))
    if inv then
        local viewers = {}
        for v in pairs(inv.viewers or {}) do viewers[#viewers + 1] = v end
        for _, v in ipairs(viewers) do Containers.Detach(v, inv, not expired) end
        if expired and not Inventory.IsEmpty(inv) then
            Containers.Log('drop %d expired with items', id)
        end
        Inventory.Remove(inv.id, false)
    end
    if d.announced then TriggerClientEvent('pop_inventory:client:removeDrop', -1, id) end
end

local function checkExpired()
    local now = os.time()
    local expired = {}
    for id, d in pairs(Drops) do
        if d.expires <= now then expired[#expired + 1] = id end
    end
    for _, id in ipairs(expired) do removeDrop(id, true) end
    if dropCount > 0 then
        SetTimeout(EXPIRE_CHECK, checkExpired)
    else
        timerOn = false
    end
end

local function ensureTimer()
    if timerOn then return end
    timerOn = true
    SetTimeout(EXPIRE_CHECK, checkExpired)
end

--- Dépôt à la position serveur du joueur (réutilise un dépôt à DROP_MERGE_DISTANCE) ; met la session dessus.
function Containers.CreateDrop(src)
    if not Containers.PlayerInv(src) then return nil, 'not_loaded' end
    local pos = Bridge.GetCoords(src)
    if not pos then return nil, 'error' end
    local ground = vector3(pos.x, pos.y, pos.z - GROUND_OFFSET)

    local inv, best
    for id, d in pairs(Drops) do
        local dist = #(d.coords - ground)
        if dist <= DROP_MERGE_DISTANCE and (not best or dist < best) then
            local candidate = Inventory.Get(invKey(id))
            if candidate and not candidate.closing then inv, best = candidate, dist end
        end
    end

    if not inv then
        if dropCount >= DROP_MAX then return nil, 'cannot_now' end
        local owner = Bridge.GetIdentifier(src) or src
        local mine = 0
        for _, d in pairs(Drops) do
            if d.owner == owner then mine = mine + 1 end
        end
        if mine >= DROP_PER_PLAYER then return nil, 'cannot_now' end
        lastId = lastId + 1
        local id = lastId
        inv = Inventory.Create(invKey(id), {
            type = 'drop', label = L('inv_ground'),
            slots = Config.Drops.Slots, maxWeight = Config.Drops.MaxWeight,
            coords = ground, persist = false,
        })
        if not inv then return nil, 'error' end
        Drops[id] = { id = id, coords = ground, expires = os.time() + Config.Drops.Lifetime, announced = false, owner = owner }
        dropCount = dropCount + 1
        ensureTimer()
        -- Annoncé aux clients seulement quand il contient quelque chose (Types.drop.changed).
        SetTimeout(EMPTY_CHECK, function()
            if not Drops[id] then return end
            local cur = Inventory.Get(invKey(id))
            if not cur or Inventory.IsEmpty(cur) then removeDrop(id, false) end
        end)
    end

    Containers.Attach(src, { forced = false }, inv)
    return inv
end

--- Dépôts visibles (annoncés) : { { id, coords = { x, y, z } }, ... }.
function Containers.DropPoints()
    local list = {}
    for id, d in pairs(Drops) do
        if d.announced then list[#list + 1] = { id = id, coords = Containers.Plain(d.coords) } end
    end
    return list
end

Containers.Types.drop = {
    open = function(_, request)
        local id = request.id
        if math.type(id) ~= 'integer' or not Drops[id] then return nil, 'error' end
        local inv = Inventory.Get(invKey(id))
        if not inv then return nil, 'error' end
        return inv
    end,

    access = function(src, inv, s)
        local id = dropIdOf(inv)
        local d = id and Drops[id]
        if not d then return false, 'error' end
        if s.forced then return true end
        if not Bridge.IsNear(src, d.coords, Config.Drops.Distance + TOLERANCE) then return false, 'too_far' end
        return true
    end,

    watch = function(_, inv)
        local id = dropIdOf(inv)
        local d = id and Drops[id]
        if not d then return nil end
        return { coords = Containers.Plain(d.coords), distance = Config.Drops.Distance + 1.0 }
    end,

    -- Vide : suppression ; premier contenu : annonce à tous.
    changed = function(inv)
        local id = dropIdOf(inv)
        local d = id and Drops[id]
        if not d then return end
        if Inventory.IsEmpty(inv) then
            removeDrop(id, false)
        elseif not d.announced then
            d.announced = true
            TriggerClientEvent('pop_inventory:client:addDrop', -1, { id = id, coords = Containers.Plain(d.coords) })
        end
    end,

    -- data = id (nombre) ou 'drop:<id>'.
    forceRequest = function(data)
        local n = tonumber(data)
        if not n and type(data) == 'string' then n = tonumber(data:match('^drop:(%d+)$')) end
        local id = n and math.tointeger(n)
        return id and { id = id } or nil
    end,
}
