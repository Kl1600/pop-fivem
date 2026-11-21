-- pop_inventory : dépôts au sol (props locaux streamés), zones des stockages et boutiques, blips.
-- Une seule boucle adaptative pour les drops, active seulement s'il en existe.

local POINT_DISTANCE = 2.0           -- portée d'interaction d'un stockage / d'une boutique
local DROP_STREAM_DISTANCE = 25.0    -- props créés en deçà
local DROP_DESPAWN_MARGIN = 5.0      -- props supprimés au-delà de DROP_STREAM_DISTANCE + marge
local DROP_NEAR_DISTANCE = 10.0      -- cadence rapide en deçà
local ZONE_SIZE = vec3(1.5, 1.5, 2.0)
local MODEL_TIMEOUT = 5000           -- ms

PopInv = PopInv or {}
PopInv.drops = PopInv.drops or {}    -- [id] = { id, coords = vector3, prop, target, spawning, removed }

local zones = {}     -- ids de zones target
local blips = {}
local dropLoop = false   -- une boucle active
local loopId = 0         -- identifiant de la boucle courante (ClearWorld l'invalide)
local dropQueue = nil    -- events addDrop / removeDrop reçus pendant pop_inventory:init (rejoués après SetupWorld)

------------------------------------------------------------------------
-- Ouverture depuis une interaction
------------------------------------------------------------------------

local function openFromWorld(request)
    CreateThread(function()
        if PopInv.open or not PopInv.CanAct() then return end
        PopInv.Open(request)
    end)
end

------------------------------------------------------------------------
-- Drops
------------------------------------------------------------------------

local function dropModel()
    local m = Config.Drops.Model
    return type(m) == 'number' and m or joaat(m)
end

local function loadModel(hash)
    if HasModelLoaded(hash) then return true end
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + MODEL_TIMEOUT
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash)
end

local function despawnProp(d)
    if d.target then
        Bridge.Target.Remove(d.target)
        d.target = nil
    end
    if d.prop then
        if DoesEntityExist(d.prop) then
            SetEntityAsMissionEntity(d.prop, true, true)
            DeleteObject(d.prop)
        end
        d.prop = nil
    end
end

local function spawnProp(d)
    if d.prop or d.spawning or d.removed then return end
    d.spawning = true
    local hash = dropModel()
    local loaded = loadModel(hash)
    d.spawning = false
    if not loaded or d.removed or d.prop then return end

    local obj = CreateObject(hash, d.coords.x, d.coords.y, d.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if obj == 0 then return end
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    d.prop = obj

    local id = d.id
    d.target = Bridge.Target.AddLocalEntity(obj, {
        {
            label = L('target_drop'),
            icon = 'fa-solid fa-box-open',
            distance = Config.Drops.Distance,
            onSelect = function() openFromWorld({ type = 'drop', id = id }) end,
        },
    })
end

local function startDropLoop()
    if dropLoop or next(PopInv.drops) == nil then return end
    dropLoop = true
    loopId = loopId + 1
    local myId = loopId
    CreateThread(function()
        while loopId == myId and next(PopInv.drops) ~= nil do
            local pos = GetEntityCoords(PlayerPedId())
            local nearest = math.huge

            -- Copie : la table peut changer pendant le chargement d'un modèle.
            local list = {}
            for _, d in pairs(PopInv.drops) do list[#list + 1] = d end

            for i = 1, #list do
                local d = list[i]
                local dist = #(pos - d.coords)
                if dist < nearest then nearest = dist end
                if dist <= DROP_STREAM_DISTANCE then
                    if not d.prop then spawnProp(d) end
                elseif d.prop and dist > DROP_STREAM_DISTANCE + DROP_DESPAWN_MARGIN then
                    despawnProp(d)
                end
            end

            Wait(nearest < DROP_NEAR_DISTANCE and 500 or nearest <= DROP_STREAM_DISTANCE and 1000 or 2000)
        end
        if loopId == myId then dropLoop = false end
    end)
end

local function addDrop(drop)
    if type(drop) ~= 'table' then return end
    local id = math.tointeger(tonumber(drop.id) or 0)
    local coords = PopInv.ToVec3(drop.coords)
    if not id or not coords or PopInv.drops[id] then return end
    local d = { id = id, coords = coords }
    PopInv.drops[id] = d
    -- Proche : prop tout de suite (sans attendre la boucle).
    if #(GetEntityCoords(PlayerPedId()) - coords) <= DROP_STREAM_DISTANCE then
        CreateThread(function() spawnProp(d) end)
    end
    startDropLoop()
end

local function removeDrop(id)
    id = math.tointeger(tonumber(id) or 0)
    local d = id and PopInv.drops[id]
    if not d then return end
    PopInv.drops[id] = nil
    d.removed = true
    despawnProp(d)
end

--- Id du drop le plus proche à moins de maxDist (nil sinon).
function PopInv.NearestDrop(pos, maxDist)
    local best, bestDist = nil, maxDist
    for id, d in pairs(PopInv.drops) do
        local dist = #(pos - d.coords)
        if dist <= bestDist then best, bestDist = id, dist end
    end
    return best
end

--- Début de pop_inventory:init : les events de drops sont mis de côté.
function PopInv.BufferDrops()
    dropQueue = {}
end

--- Après SetupWorld : rejoue les events reçus pendant l'init, dans l'ordre.
function PopInv.FlushDrops()
    local queue = dropQueue
    dropQueue = nil
    if not queue then return end
    for i = 1, #queue do
        local e = queue[i]
        if e.add then addDrop(e.value) else removeDrop(e.value) end
    end
end

--- Init échoué : on abandonne la file.
function PopInv.CancelDropBuffer()
    dropQueue = nil
end

RegisterNetEvent('pop_inventory:client:addDrop', function(drop)
    if dropQueue then
        dropQueue[#dropQueue + 1] = { add = true, value = drop }
        return
    end
    addDrop(drop)
end)

RegisterNetEvent('pop_inventory:client:removeDrop', function(id)
    if dropQueue then
        dropQueue[#dropQueue + 1] = { add = false, value = id }
        return
    end
    removeDrop(id)
end)

------------------------------------------------------------------------
-- Stockages et boutiques
------------------------------------------------------------------------

local function addStash(stash)
    if type(stash) ~= 'table' or stash.id == nil then return end
    local coords = PopInv.ToVec3(stash.coords)
    if not coords then return end
    local stashId = stash.id
    local zoneId = 'pop_inventory_stash_' .. tostring(stashId)
    zones[#zones + 1] = Bridge.Target.AddBoxZone(zoneId, coords, ZONE_SIZE, 0.0, {
        {
            label = L('target_stash'),
            icon = 'fa-solid fa-box',
            distance = POINT_DISTANCE,
            onSelect = function() openFromWorld({ type = 'stash', id = stashId }) end,
        },
    })
end

local function addBlip(coords, blip, label)
    local handle = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(handle, tonumber(blip.sprite) or 1)
    SetBlipColour(handle, tonumber(blip.color) or 0)
    SetBlipScale(handle, 0.7)
    SetBlipAsShortRange(handle, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(handle)
    blips[#blips + 1] = handle
end

local function addShop(shop)
    if type(shop) ~= 'table' or shop.id == nil or type(shop.coords) ~= 'table' then return end
    local shopId = shop.id
    local label = type(shop.label) == 'string' and shop.label or L('inv_shop')
    for i, c in ipairs(shop.coords) do
        local coords = PopInv.ToVec3(c)
        if coords then
            local zoneId = 'pop_inventory_shop_' .. tostring(shopId) .. '_' .. i
            zones[#zones + 1] = Bridge.Target.AddBoxZone(zoneId, coords, ZONE_SIZE, 0.0, {
                {
                    label = L('target_shop'),
                    icon = 'fa-solid fa-cart-shopping',
                    distance = POINT_DISTANCE,
                    onSelect = function() openFromWorld({ type = 'shop', id = shopId }) end,
                },
            })
            if type(shop.blip) == 'table' then addBlip(coords, shop.blip, label) end
        end
    end
end

------------------------------------------------------------------------
-- Mise en place / nettoyage
------------------------------------------------------------------------

--- Supprime props, cibles, zones et blips.
function PopInv.ClearWorld()
    dropLoop = false
    loopId = loopId + 1
    for id, d in pairs(PopInv.drops) do
        d.removed = true
        despawnProp(d)
        PopInv.drops[id] = nil
    end
    for i = 1, #zones do Bridge.Target.Remove(zones[i]) end
    zones = {}
    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    blips = {}
end

--- data = réponse de pop_inventory:init (drops, stashes, shops). Idempotent.
function PopInv.SetupWorld(data)
    PopInv.ClearWorld()
    if type(data) ~= 'table' then return end
    if type(data.drops) == 'table' then
        for _, d in pairs(data.drops) do addDrop(d) end
    end
    if type(data.stashes) == 'table' then
        for _, s in pairs(data.stashes) do addStash(s) end
    end
    if type(data.shops) == 'table' then
        for _, s in pairs(data.shops) do addShop(s) end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    PopInv.ClearWorld()
end)
