-- pop_weed : serveur. Source de vérité des plantes (mémoire + oxmysql).
-- Le client n'envoie que des coordonnées / un heading (plantation) ou un id : tout le reste
-- (items, quantités, qualité, temps) vient de la config et de l'horloge serveur.

local RES = GetCurrentResourceName()

local plants = {}    -- [id] = PlantData + owner
local loaded = false -- vrai quand la base est chargée
local busy = {}      -- [src] = true pendant le traitement d'une action
local reserved = {}  -- [src] = { x, y, z } : emplacement en cours d'insertion SQL (espacement)
local nextAction = {} -- [src] = ms (GetGameTimer) de la dernière action acceptée (cooldown)
local lastGet = {}    -- [src] = ms : dernier pop_weed:getPlants servi

local CLEANUP_INTERVAL = 300000 -- ms
local GET_DELAY = 5000          -- ms entre deux pop_weed:getPlants d'un même joueur
-- Tolérance du cooldown (latence, horloges) : une action doit suivre la précédente d'au moins
-- 80 % de sa propre durée de progression (Config.Durations), sinon 'busy'.
local COOLDOWN_RATIO = 0.8

-- NOTE: SPEC n'ajoute aucune clé de webhook ("Aucune autre clé") : les actions sensibles sont
-- journalisées en console uniquement si Config.Debug est actif. Messages console en anglais.
local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

-- Copie envoyée aux clients : jamais de propriétaire.
local function toClient(p)
    return {
        id = p.id, x = p.x, y = p.y, z = p.z, heading = p.heading,
        plantedAt = p.plantedAt, water = p.water, waterAt = p.waterAt,
        dry = p.dry, fertilized = p.fertilized,
    }
end

-- Copie complète (exports) : avec propriétaire, jamais la référence interne.
local function copyFull(p)
    local c = toClient(p)
    c.owner = p.owner
    return c
end

local function isFiniteNumber(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function isRotten(p, now)
    return now > p.plantedAt + Config.GrowTime + Config.RotTime
end

local function countOwned(identifier)
    local n = 0
    for _, p in pairs(plants) do
        if p.owner == identifier then n = n + 1 end
    end
    return n
end

local function dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Vrai si un emplacement est trop proche d'une plante existante ou en cours de création.
local function tooClose(coords)
    for _, p in pairs(plants) do
        if dist3(p, coords) < Config.MinSpacing then return true end
    end
    for _, r in pairs(reserved) do
        if dist3(r, coords) < Config.MinSpacing then return true end
    end
    return false
end

local function inVehicle(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
end

local function isPoliceOnDuty(src)
    if not Bridge.HasJob(src, Config.Police.jobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

-- Sauvegarde eau / engrais / temps à sec (asynchrone, paramétrée).
local function saveState(p)
    MySQL.update('UPDATE `pop_weed_plants` SET `water` = ?, `water_at` = ?, `dry` = ?, `fertilized` = ? WHERE `id` = ?',
        { p.water, p.waterAt, p.dry, p.fertilized and 1 or 0, p.id })
end

-- Supprime une plante (mémoire, SQL, clients).
local function deletePlant(id)
    plants[id] = nil
    MySQL.query('DELETE FROM `pop_weed_plants` WHERE `id` = ?', { id })
    TriggerClientEvent('pop_weed:client:plantRemoved', -1, id)
end

-- Vrai si le joueur a pu faire sa barre de progression depuis sa dernière action acceptée.
local function cooldownOk(src, action)
    local now = GetGameTimer()
    local last = nextAction[src]
    local duration = tonumber(Config.Durations[action]) or 0
    if last and now - last < duration * COOLDOWN_RATIO then return false end
    nextAction[src] = now
    return true
end

-- Exécute une action sous verrou joueur ; le verrou est libéré dans tous les cas.
local function locked(src, action, fn, ...)
    if busy[src] then return false, 'busy' end
    if not cooldownOk(src, action) then return false, 'busy' end
    busy[src] = true
    local r = table.pack(pcall(fn, src, ...))
    busy[src] = nil
    reserved[src] = nil
    if not r[1] then
        print(('[%s] action error: %s'):format(RES, tostring(r[2])))
        return false, 'error'
    end
    return table.unpack(r, 2, r.n)
end

-- Contrôles communs aux actions sur une plante existante. Renvoie p, identifier ou nil, reason.
local function checkPlant(src, id)
    if math.type(id) ~= 'integer' or not plants[id] then return nil, 'plant_not_found' end
    local p = plants[id]
    if not Bridge.IsNear(src, p, Plant.ACTION_DISTANCE) then return nil, 'too_far' end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return nil, 'error' end
    return p, identifier
end

------------------------------------------------------------------------
-- Chargement et nettoyage
------------------------------------------------------------------------

local function loadPlants()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pop_weed_plants` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `owner`      VARCHAR(64)  NOT NULL,
            `x`          FLOAT        NOT NULL,
            `y`          FLOAT        NOT NULL,
            `z`          FLOAT        NOT NULL,
            `heading`    FLOAT        NOT NULL DEFAULT 0,
            `planted_at` INT UNSIGNED NOT NULL,
            `water`      FLOAT        NOT NULL DEFAULT 0,
            `water_at`   INT UNSIGNED NOT NULL,
            `dry`        INT UNSIGNED NOT NULL DEFAULT 0,
            `fertilized` TINYINT(1)   NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `idx_owner` (`owner`)
        )
    ]])

    local rows = MySQL.query.await('SELECT * FROM `pop_weed_plants`') or {}
    local now = os.time()
    local rotten = 0
    for _, r in ipairs(rows) do
        local id = math.tointeger(tonumber(r.id))
        if id then
            local p = {
                id = id,
                owner = r.owner,
                x = tonumber(r.x) or 0.0,
                y = tonumber(r.y) or 0.0,
                z = tonumber(r.z) or 0.0,
                heading = tonumber(r.heading) or 0.0,
                plantedAt = math.tointeger(tonumber(r.planted_at)) or now,
                water = tonumber(r.water) or 0.0,
                waterAt = math.tointeger(tonumber(r.water_at)) or now,
                dry = math.tointeger(tonumber(r.dry)) or 0,
                -- oxmysql renvoie TINYINT(1) en booléen ; 1 accepté par sécurité.
                fertilized = r.fertilized == true or r.fertilized == 1,
            }
            if isRotten(p, now) then
                rotten = rotten + 1
                MySQL.query('DELETE FROM `pop_weed_plants` WHERE `id` = ?', { id })
            else
                plants[id] = p
            end
        end
    end
    log('loaded %d plants (%d rotten removed)', #rows - rotten, rotten)
end

CreateThread(function()
    -- Une erreur SQL ne doit pas bloquer les callbacks qui attendent `loaded`.
    local ok, err = pcall(loadPlants)
    if not ok then print(('[%s] ERROR: plants could not be loaded: %s'):format(RES, tostring(err))) end
    loaded = true

    if Bridge.Inventory == 'none' or (Bridge.Framework == 'standalone' and Bridge.Inventory == 'framework') then
        print(('[%s] WARNING: no inventory detected (%s / %s): planting is impossible without an inventory'):format(
            RES, Bridge.Framework, Bridge.Inventory))
    end
end)

-- Une seule boucle lente : plantes pourries.
CreateThread(function()
    while true do
        Wait(CLEANUP_INTERVAL)
        local t = os.time()
        for id, p in pairs(plants) do
            if isRotten(p, t) then
                deletePlant(id)
                log('plant %d rotted', id)
            end
        end
    end
end)

------------------------------------------------------------------------
-- Items utilisables : pré-contrôles de confort, tout est revérifié dans pop_weed:plant
------------------------------------------------------------------------

local function onUse(src)
    src = tonumber(src)
    if not src then return end
    if not loaded or busy[src] then
        return Bridge.Notify(src, L(loaded and 'busy' or 'error'), 'error')
    end
    if not Bridge.HasItem(src, Config.Items.pot) then
        return Bridge.Notify(src, L('missing_item', L('item_pot')), 'error')
    end
    if not Bridge.HasItem(src, Config.Items.seed) then
        return Bridge.Notify(src, L('missing_item', L('item_seed')), 'error')
    end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        return Bridge.Notify(src, L('error'), 'error')
    end
    if countOwned(identifier) >= Config.MaxPlants then
        return Bridge.Notify(src, L('max_plants', Config.MaxPlants), 'error')
    end
    if inVehicle(src) then
        return Bridge.Notify(src, L('in_vehicle'), 'error')
    end
    TriggerClientEvent('pop_weed:client:startPlacement', src)
end

Bridge.RegisterUsableItem(Config.Items.pot, onUse)
Bridge.RegisterUsableItem(Config.Items.seed, onUse)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

-- mine = true seulement pour les plantes du joueur (le propriétaire n'est jamais transmis).
-- Un appel par joueur toutes les 5 s : sinon nil (le client garde ses données).
Callback.Register('pop_weed:getPlants', function(src)
    local t = GetGameTimer()
    if lastGet[src] and t - lastGet[src] < GET_DELAY then return nil end
    lastGet[src] = t
    while not loaded do Wait(200) end
    local identifier = Bridge.GetIdentifier(src)
    local list = {}
    for _, p in pairs(plants) do
        local c = toClient(p)
        if identifier and p.owner == identifier then c.mine = true end
        list[#list + 1] = c
    end
    return list, os.time()
end)

Callback.Register('pop_weed:plant', function(playerId, coords, heading)
    return locked(playerId, 'plant', function(src)
        if not loaded then return false, 'error' end

        -- 1. Données du client : nombres finis et bornés.
        if type(coords) ~= 'table' then return false, 'error' end
        local x, y, z = coords.x, coords.y, coords.z
        if not (isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z) and isFiniteNumber(heading)) then
            return false, 'error'
        end
        if math.abs(x) > 10000 or math.abs(y) > 10000 or z < -200 or z > 2000 then return false, 'error' end
        heading = heading % 360.0
        local pos = { x = x, y = y, z = z }

        -- 2-5. Position, véhicule, espacement, limite.
        if not Bridge.IsNear(src, pos, Plant.ACTION_DISTANCE) then return false, 'too_far' end
        local identifier = Bridge.GetIdentifier(src)
        if not identifier then return false, 'error' end
        if inVehicle(src) then return false, 'in_vehicle' end
        if tooClose(pos) then return false, 'too_close_plant' end
        if countOwned(identifier) >= Config.MaxPlants then return false, 'max_plants', Config.MaxPlants end

        -- 6-7. Items (retrait, avec restitution en cas d'échec).
        if not Bridge.HasItem(src, Config.Items.pot) then return false, 'missing_item', L('item_pot') end
        if not Bridge.HasItem(src, Config.Items.seed) then return false, 'missing_item', L('item_seed') end
        if not Bridge.RemoveItem(src, Config.Items.pot) then return false, 'missing_item', L('item_pot') end
        if not Bridge.RemoveItem(src, Config.Items.seed) then
            Bridge.AddItem(src, Config.Items.pot)
            return false, 'error'
        end

        -- 8. Insertion SQL (emplacement réservé pendant l'attente).
        reserved[src] = pos
        local now = os.time()
        local id = MySQL.insert.await(
            'INSERT INTO `pop_weed_plants` (`owner`, `x`, `y`, `z`, `heading`, `planted_at`, `water`, `water_at`, `dry`, `fertilized`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { identifier, x, y, z, heading, now, 0, now, 0, 0 })
        id = math.tointeger(tonumber(id))
        if not id then
            Bridge.AddItem(src, Config.Items.pot)
            Bridge.AddItem(src, Config.Items.seed)
            print(('[%s] plant insert failed for %s'):format(RES, identifier))
            return false, 'error'
        end

        -- 9. Création et diffusion.
        local p = {
            id = id, owner = identifier, x = x, y = y, z = z, heading = heading,
            plantedAt = now, water = 0.0, waterAt = now, dry = 0, fertilized = false,
        }
        plants[id] = p
        TriggerClientEvent('pop_weed:client:plantAdded', -1, toClient(p), now)
        Bridge.Notify(src, L('planted'), 'success')
        log('%s (%s) planted %d at %.2f %.2f %.2f', GetPlayerName(src) or src, identifier, id, x, y, z)
        return true, id
    end)
end)

Callback.Register('pop_weed:water', function(playerId, id)
    return locked(playerId, 'water', function(src)
        local p, reason = checkPlant(src, id)
        if not p then return false, reason end
        local now = os.time()
        if Plant.IsReady(p, now) then return false, 'already_ready' end
        if Plant.Water(p, now) >= Plant.THIRSTY_BELOW then return false, 'plant_not_thirsty' end
        if not Bridge.RemoveItem(src, Config.Items.water) then return false, 'missing_item', L('item_water') end

        Plant.Settle(p, now)
        p.water = 100.0
        saveState(p)
        TriggerClientEvent('pop_weed:client:plantUpdated', -1, toClient(p), now)
        Bridge.Notify(src, L('watered'), 'success')
        log('%s watered plant %d', src, id)
        return true
    end)
end)

Callback.Register('pop_weed:fertilize', function(playerId, id)
    return locked(playerId, 'fertilize', function(src)
        local p, reason = checkPlant(src, id)
        if not p then return false, reason end
        local now = os.time()
        if Plant.IsReady(p, now) then return false, 'already_ready' end
        if p.fertilized then return false, 'already_fertilized' end
        if not Bridge.RemoveItem(src, Config.Items.fertilizer) then return false, 'missing_item', L('item_fertilizer') end

        Plant.Settle(p, now)
        p.fertilized = true
        saveState(p)
        TriggerClientEvent('pop_weed:client:plantUpdated', -1, toClient(p), now)
        Bridge.Notify(src, L('fertilized'), 'success')
        log('%s fertilized plant %d', src, id)
        return true
    end)
end)

Callback.Register('pop_weed:harvest', function(playerId, id)
    return locked(playerId, 'harvest', function(src)
        local p, identifier = checkPlant(src, id)
        if not p then return false, identifier end
        local now = os.time()
        if not Plant.IsReady(p, now) then return false, 'not_ready' end
        if Config.OwnerOnly and p.owner ~= identifier then return false, 'not_owner' end

        local quality = Plant.Quality(p, now)
        local amount = Plant.HarvestAmount(quality)
        if amount < 1 then
            -- Plante trop abîmée : rien à donner, elle disparaît.
            deletePlant(id)
            Bridge.Notify(src, L('harvest_nothing'), 'warning')
            log('%s (%s) harvested plant %d: nothing (quality %d)', GetPlayerName(src) or src, identifier, id, quality)
            return true
        end
        if not Bridge.CanCarry(src, Config.Items.harvest, amount) then return false, 'inventory_full' end

        -- Retrait de la mémoire avant l'ajout : empêche toute double récolte.
        plants[id] = nil
        if not Bridge.AddItem(src, Config.Items.harvest, amount, { quality = quality }) then
            plants[id] = p
            return false, 'inventory_full'
        end

        deletePlant(id)
        Bridge.Notify(src, L('harvested', amount, quality), 'success')
        log('%s (%s) harvested plant %d: x%d quality %d', GetPlayerName(src) or src, identifier, id, amount, quality)

        -- Odeur : alerte éventuelle des policiers en service.
        if math.random() < Config.Police.alertChance then
            local coords = { x = p.x, y = p.y, z = p.z }
            for _, cop in ipairs(Bridge.GetPlayers()) do
                if isPoliceOnDuty(cop) then
                    TriggerClientEvent('pop_weed:client:policeAlert', cop, coords)
                end
            end
        end
        return true
    end)
end)

Callback.Register('pop_weed:destroy', function(playerId, id)
    return locked(playerId, 'destroy', function(src)
        local p, identifier = checkPlant(src, id)
        if not p then return false, identifier end
        if not isPoliceOnDuty(src) then return false, 'wrong_job' end

        deletePlant(id)
        Bridge.Notify(src, L('destroyed'), 'success')
        log('%s (%s) destroyed plant %d (owner %s)', GetPlayerName(src) or src, identifier, id, p.owner)
        return true
    end)
end)

------------------------------------------------------------------------
-- Déconnexion
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src)
    busy[src] = nil
    reserved[src] = nil
    nextAction[src] = nil
    lastGet[src] = nil
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('GetPlants', function()
    local list = {}
    for _, p in pairs(plants) do list[#list + 1] = copyFull(p) end
    return list
end)

exports('GetPlayerPlantCount', function(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return 0 end
    return countOwned(identifier)
end)

exports('RemovePlant', function(id)
    id = math.tointeger(tonumber(id))
    if not id or not plants[id] then return false end
    deletePlant(id)
    log('plant %d removed by export (%s)', id, GetInvokingResource() or 'unknown')
    return true
end)
