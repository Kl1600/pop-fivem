-- Persistance oxmysql : tables, chargement / sauvegarde, migration des anciens inventaires, arrêt.
-- Requêtes paramétrées uniquement (?).

Database = Database or {}
Database.ready = false

local RES = GetCurrentResourceName()

local pendingSaves = {} -- [clé] = promise résolue à la fin de l'écriture
local loadToken = {}    -- [src] = compteur : un chargement de joueur s'annule si le joueur part entre-temps

local SAVE_FALLBACK = 30000    -- ms : une écriture sans réponse libère quand même la clé (log)
local SAVE_RETRY_DELAY = 5000  -- ms : nouvel essai d'une écriture échouée d'un inventaire déjà déchargé
local READY_RETRY_DELAY = 10000 -- ms : nouvel essai de création des tables
local HOT_START_DELAY = 1500   -- ms : démarrage à chaud, laisse finir les écritures de l'instance précédente

local function debug(msg, ...)
    if Config.Debug then print(('[%s] database: ' .. msg):format(RES, ...)) end
end

local function warn(msg, ...)
    print(('[%s] ' .. msg):format(RES, ...))
end

------------------------------------------------------------------------
-- Encodage
------------------------------------------------------------------------

-- Liste JSON triée par slot, metadata omise si vide.
local function encodeItems(inv)
    local list = {}
    for _, it in pairs(inv.items) do
        local entry = { slot = it.slot, name = it.name, count = it.count }
        if next(it.metadata) then entry.metadata = Inventory.Copy(it.metadata) end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return json.encode(list), #list
end

local function decodeItems(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, data = pcall(json.decode, text)
    if ok and type(data) == 'table' then return data end
    return {}
end

-- Clé de sauvegarde : 'player:<identifier>' pour un joueur, l'id pour un conteneur.
local function saveKey(inv)
    if inv.type == 'player' then return 'player:' .. tostring(inv.owner) end
    return inv.id
end

------------------------------------------------------------------------
-- Écriture (une seule à la fois par clé, dans l'ordre)
------------------------------------------------------------------------

-- onFail(retry) : appelée si l'écriture échoue ; retry() relance la même écriture (une seule fois).
local function write(key, query, params, onFail)
    local prev = pendingSaves[key]
    local p = promise.new()
    pendingSaves[key] = p
    local done = false
    local function finish()
        if done then return end
        done = true
        p:resolve(true)
        if pendingSaves[key] == p then pendingSaves[key] = nil end
    end
    local function run()
        SetTimeout(SAVE_FALLBACK, function()
            if done then return end
            warn('^1save of %s got no answer after %d ms: key released, inventory marked as modified^7', tostring(key), SAVE_FALLBACK)
            if onFail then onFail(nil) end
            finish()
        end)
        CreateThread(function()
            local ok, err = pcall(MySQL.query.await, query, params)
            -- NOTE: selon la version d'oxmysql, une erreur lève une exception ou renvoie nil (INSERT / DELETE renvoient une table).
            if ok and err == nil then ok, err = false, 'no result' end
            if not ok and not done then
                warn('^1save of %s failed: %s^7', tostring(key), tostring(err))
                if onFail then
                    onFail(function()
                        Wait(SAVE_RETRY_DELAY)
                        if done then return end
                        local ok2, err2 = pcall(MySQL.query.await, query, params)
                        if ok2 and err2 == nil then ok2, err2 = false, 'no result' end
                        if not ok2 then warn('^1save of %s failed again, data not written: %s^7', tostring(key), tostring(err2)) end
                    end)
                end
            end
            finish()
        end)
    end
    if prev then
        CreateThread(function()
            Citizen.Await(prev)
            run()
        end)
    else
        run()
    end
end

--- Attend la fin d'une sauvegarde en cours pour cette clé (bloquant).
function Database.WaitSave(key)
    local p = pendingSaves[key]
    if p then Citizen.Await(p) end
end

--- Instantané immédiat (synchrone), dirty = false, puis écriture asynchrone.
function Database.Save(inv)
    if not inv or not inv.persist then return end
    if not Database.ready then return end -- tables absentes : aucune écriture (l'état reste dirty)
    local encoded, n = encodeItems(inv)
    inv.dirty = false
    local key = saveKey(inv)
    -- Échec : encore en mémoire → dirty (la prochaine sauvegarde réécrit l'état courant) ; déchargé → un nouvel essai.
    local function onFail(retry)
        if Inventory.Get(inv.id) == inv and not inv.closing then
            inv.dirty = true
        elseif retry then
            retry()
        end
    end
    if inv.type == 'player' then
        if not inv.owner then return end
        -- L'inventaire joueur vide est écrit [], jamais supprimé.
        write(key, 'INSERT INTO pop_inventory_players (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { inv.owner, encoded }, onFail)
    elseif n == 0 then
        write(key, 'DELETE FROM pop_inventory_stashes WHERE id = ?', { inv.id }, onFail)
    else
        write(key, 'INSERT INTO pop_inventory_stashes (id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
            { inv.id, encoded }, onFail)
    end
    debug('saved %s (%d stacks)', tostring(key), n)
end

--- Sauvegarde tout ce qui est modifié.
function Database.SaveAll()
    local n = 0
    for _, inv in pairs(Inventory.All()) do
        if inv.persist and inv.dirty then
            Database.Save(inv)
            n = n + 1
        end
    end
    if n > 0 then debug('%d inventories saved', n) end
end

--- Bloquant : items (liste au format SQL) d'un conteneur ; nil si aucune ligne ; false, err si erreur SQL.
function Database.LoadStash(id)
    if not Database.ready then return false, 'database not ready' end
    local ok, row = pcall(MySQL.single.await, 'SELECT items FROM pop_inventory_stashes WHERE id = ?', { id })
    if not ok then
        warn('^1cannot load %s: %s^7', tostring(id), tostring(row))
        return false, tostring(row)
    end
    if not row then return nil end
    return decodeItems(row.items)
end

------------------------------------------------------------------------
-- Migration des anciens inventaires du framework (une fois par personnage)
------------------------------------------------------------------------

local function migrateLog(identifier, name, count)
    warn('migration: unknown item ignored: player=%s item=%s count=%s', identifier, tostring(name), tostring(count))
end

-- Ajoute une entrée à la liste si l'item est connu.
local function pushItem(list, identifier, name, count, metadata, slot)
    if type(name) ~= 'string' then return end
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return end
    if not Items.Get(name) then return migrateLog(identifier, name, count) end
    list[#list + 1] = { name = name:lower(), count = count, metadata = type(metadata) == 'table' and metadata or {}, slot = tonumber(slot) }
end

-- Liste au format ox / QB (tableau d'objets) ou table indexée par slot.
local function pushList(list, identifier, data)
    for _, it in pairs(data) do
        if type(it) == 'table' then
            pushItem(list, identifier, it.name, it.count or it.amount, it.metadata or it.info, it.slot)
        end
    end
end

-- users.loadout : armes → items arme (munitions bornées au chargeur).
local function pushLoadout(list, identifier, text)
    for key, w in pairs(decodeItems(text)) do
        -- NOTE: Legacy = { WEAPON_PISTOL = { ammo } }, ancien ESX = { { name, ammo } }.
        local wname = type(key) == 'string' and key or (type(w) == 'table' and w.name)
        if type(wname) == 'string' then
            local def = Items.Get(wname)
            if def and def.weapon then
                local md = {}
                if def.ammo then
                    md.ammo = math.max(0, math.min(math.floor(tonumber(type(w) == 'table' and w.ammo) or 0), def.clip))
                end
                pushItem(list, identifier, wname, 1, md)
            else
                migrateLog(identifier, wname, 1)
            end
        end
    end
end

local function migrateEsx(identifier)
    local list = {}
    -- ESX Legacy : users.inventory (JSON { nom = quantité }) + users.loadout.
    local ok, row = pcall(MySQL.single.await, 'SELECT inventory, loadout FROM users WHERE identifier = ?', { identifier })
    if ok and row then
        local inv = decodeItems(row.inventory)
        if inv[1] ~= nil then
            pushList(list, identifier, inv) -- inventaire déjà au format liste (ancien ox_inventory)
        else
            for name, count in pairs(inv) do pushItem(list, identifier, name, count) end
        end
        pushLoadout(list, identifier, row.loadout)
        return list
    end
    -- Ancien ESX : table user_inventory (pas de colonne users.inventory) + users.loadout lu à part.
    local ok2, rows = pcall(MySQL.query.await, 'SELECT item, count FROM user_inventory WHERE identifier = ?', { identifier })
    if ok2 and type(rows) == 'table' then
        for _, r in ipairs(rows) do pushItem(list, identifier, r.item, r.count) end
    end
    local ok3, row3 = pcall(MySQL.single.await, 'SELECT loadout FROM users WHERE identifier = ?', { identifier })
    if ok3 and row3 then pushLoadout(list, identifier, row3.loadout) end
    return list
end

local function migrateQb(identifier)
    local list = {}
    local ok, row = pcall(MySQL.single.await, 'SELECT inventory FROM players WHERE citizenid = ?', { identifier })
    if ok and row then pushList(list, identifier, decodeItems(row.inventory)) end
    return list
end

local function migrate(identifier)
    local ok, list = pcall(function()
        if Bridge.Framework == 'esx' then return migrateEsx(identifier) end
        if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then return migrateQb(identifier) end
        return {}
    end)
    if not ok then
        warn('migration failed for %s: %s', identifier, tostring(list))
        return {}
    end
    if #list > 0 then debug('migrated %d stacks for %s', #list, identifier) end
    return list
end

------------------------------------------------------------------------
-- Cycle de vie des joueurs
------------------------------------------------------------------------

local function waitReady()
    local tries = 0
    while not Database.ready and tries < 600 do
        Wait(100)
        tries = tries + 1
    end
    return Database.ready
end

-- Décharge un joueur : fermeture des sessions, sauvegarde, retrait de la mémoire, nettoyage.
local function unloadPlayer(src, isUnload)
    loadToken[src] = (loadToken[src] or 0) + 1
    local inv = Inventory.Get(src)
    if inv then
        inv.closing = true
        if Containers and Containers.Close then
            local ok, err = pcall(Containers.Close, src)
            if not ok then warn('Containers.Close error for %s: %s', src, tostring(err)) end
        end
        -- NOTE: sécurité si une fouille vise encore ce joueur : on ferme l'interface des spectateurs restants.
        -- Leur session pointe alors vers un inventaire « closing » : toute opération y est refusée.
        for viewer in pairs(inv.viewers) do
            TriggerClientEvent('pop_inventory:client:close', viewer)
        end
        inv.viewers = {}
        inv.dirty = true -- toujours écrire l'état final au départ du joueur
        Database.Save(inv)
        Inventory.Remove(src, false)
        debug('player %s unloaded (%s)', src, tostring(inv.owner))
    end
    if InvPlayers and InvPlayers.Cleanup then InvPlayers.Cleanup(src) end
    if FrameworkCompat and FrameworkCompat.Cleanup then FrameworkCompat.Cleanup(src) end
    if isUnload then
        TriggerClientEvent('pop_inventory:client:reset', src)
    else
        -- Déconnexion : le chargement en cours est annulé (nil ~= jeton) et la table ne garde rien.
        loadToken[src] = nil
    end
end

-- Un seul inventaire par personnage : décharge (avec sauvegarde) un « fantôme » du même identifiant sous un autre src.
local function unloadGhosts(src, identifier)
    local ghosts = {}
    for id, inv in pairs(Inventory.All()) do
        if inv.type == 'player' and id ~= src and inv.owner == identifier then ghosts[#ghosts + 1] = id end
    end
    for _, id in ipairs(ghosts) do
        warn('player %s: inventory of %s was still loaded under id %s, unloading it first', src, identifier, tostring(id))
        unloadPlayer(id, false)
    end
end

local function loadPlayer(src)
    if not waitReady() then return warn('database not ready, cannot load player %s', src) end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return warn('no identifier for player %s', src) end

    local existing = Inventory.Get(src)
    if existing then
        if existing.owner == identifier and not existing.closing then
            ReconcileCash(src)
            return
        end
        unloadPlayer(src, false)
    end

    local token = (loadToken[src] or 0) + 1
    loadToken[src] = token
    local key = 'player:' .. identifier

    unloadGhosts(src, identifier)
    Database.WaitSave(key)
    local ok, row = pcall(MySQL.single.await, 'SELECT items FROM pop_inventory_players WHERE identifier = ?', { identifier })
    if not ok then return warn('cannot load player %s (%s): %s', src, identifier, tostring(row)) end

    local items
    if row then
        items = decodeItems(row.items)
    else
        items = Config.ImportFramework and migrate(identifier) or {}
        local encoded = json.encode(items)
        pcall(MySQL.insert.await, 'INSERT IGNORE INTO pop_inventory_players (identifier, items) VALUES (?, ?)', { identifier, encoded })
    end

    -- Le joueur est parti ou a changé de personnage pendant la lecture : abandon.
    if loadToken[src] ~= token or not GetPlayerName(src) or Bridge.GetIdentifier(src) ~= identifier then
        debug('load of %s cancelled', src)
        return
    end

    Inventory.Create(src, {
        type = 'player',
        label = L('inv_player'),
        slots = Config.Slots,
        maxWeight = Config.MaxWeight,
        owner = identifier,
        persist = true,
        items = items,
    })
    ReconcileCash(src)
    if FrameworkCompat and FrameworkCompat.OnPlayerLoaded then FrameworkCompat.OnPlayerLoaded(src) end
    debug('player %s loaded (%s)', src, identifier)
end

Bridge.OnPlayerLoaded(function(src)
    src = tonumber(src)
    if not src then return end
    CreateThread(function() loadPlayer(src) end)
end)

Bridge.OnPlayerUnloaded(function(src)
    src = tonumber(src)
    if src then unloadPlayer(src, true) end
end)

Bridge.OnPlayerDropped(function(src)
    src = tonumber(src)
    if src then unloadPlayer(src, false) end
end)

------------------------------------------------------------------------
-- Démarrage, sauvegarde périodique, arrêt
------------------------------------------------------------------------

local CONFLICTS = { 'ox_inventory', 'qs-inventory', 'qb-inventory', 'ps-inventory' }

CreateThread(function()
    -- Deux inventaires ne doivent pas tourner ensemble.
    -- NOTE: avec `provide 'ox_inventory'` (Qbox), l'alias peut être vu comme lancé : on ignore s'il pointe sur nous.
    for _, name in ipairs(CONFLICTS) do
        if GetResourceState(name) == 'started' and GetResourceMetadata(name, 'name', 0) ~= RES then
            print(('^1[%s] ERROR: %s is started. Two inventories must not run together: stop %s.^7'):format(RES, name, name))
        end
    end

    local function createTables()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `pop_inventory_players` (
  `identifier` VARCHAR(64) NOT NULL,
  `items` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `pop_inventory_stashes` (
  `id` VARCHAR(100) NOT NULL,
  `items` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    end

    -- Tables indispensables : sans elles, aucun chargement ni aucune écriture (Database.ready reste faux).
    local retried = false
    while true do
        local ok, err = pcall(createTables)
        if ok then break end
        retried = true
        print(('^1[%s] ERROR: cannot create the database tables (%s). Inventories are NOT loaded and NOTHING is saved. Check oxmysql / MySQL; retrying in %d s.^7')
            :format(RES, tostring(err), READY_RETRY_DELAY // 1000))
        Wait(READY_RETRY_DELAY)
    end

    local okImport, errImport = pcall(Items.Import)
    if not okImport then warn('item import failed: %s', tostring(errImport)) end

    -- Démarrage à chaud : les dernières écritures de l'instance précédente (onResourceStop) doivent arriver avant les SELECT.
    if #GetPlayers() > 0 then Wait(HOT_START_DELAY) end

    Database.ready = true
    debug('ready')

    -- Joueurs dont le chargement a abandonné pendant l'attente des tables.
    if retried then
        for _, s in ipairs(GetPlayers()) do
            local src = tonumber(s)
            if src and not Inventory.Get(src) and Bridge.GetPlayer(src) then
                CreateThread(function() loadPlayer(src) end)
            end
        end
    end
end)

-- Sauvegarde différée des inventaires modifiés.
local function autosave()
    Database.SaveAll()
    SetTimeout(math.max(30, tonumber(Config.SaveInterval) or 300) * 1000, autosave)
end
SetTimeout(math.max(30, tonumber(Config.SaveInterval) or 300) * 1000, autosave)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    Database.SaveAll()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    Database.SaveAll()
end)
