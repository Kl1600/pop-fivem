-- =====================================================
--  tab_douilles - SERVER (autoritaire)
--  Stocke les douilles par id (en memoire), valide les tirs,
--  genere la signature balistique, gere recherche / ramassage / analyse.
-- =====================================================

local ESX = exports['es_extended']:getSharedObject()

local casings = {}   -- [id] = { id, coords, weapon, caliber, weaponLabel, signature, identifier, time, timeStr }
local seq = 0

-- Tables resolues par hash (construites au demarrage a partir des noms)
local IgnoredHash = {}
local WeaponByHash = {}

CreateThread(function()
    for _, name in ipairs(DouillesConfig.IgnoredByName or {}) do
        IgnoredHash[GetHashKey(name)] = true
    end
    for name, data in pairs(DouillesConfig.Weapons or {}) do
        WeaponByHash[GetHashKey(name)] = data
    end
end)

-- ---------- Helpers ----------

-- La ressource notification expose l'event 'notification:client:ShowNotify'
-- (et NON ':send', qui n'a pas de handler). Le style vient des champs (title+icon).
local NOTIF_ICONS = {
    success = 'fas fa-circle-check',
    error   = 'fas fa-triangle-exclamation',
    info    = 'fas fa-magnifying-glass',
}

local function notify(target, message, ntype)
    TriggerClientEvent('notification:client:ShowNotify', target, {
        title = 'Indices',
        message = message,
        icon = NOTIF_ICONS[ntype or 'info'] or NOTIF_ICONS.info,
        duration = 5000,
    })
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.identifier then return xPlayer.identifier end
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. tostring(src))
end

local function hasJob(src, jobs)
    if not jobs then return true end          -- nil = tout le monde
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job then return false end
    for _, j in ipairs(jobs) do
        if xPlayer.job.name == j then return true end
    end
    return false
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Signature balistique deterministe : meme tireur + meme type d'arme => meme code.
-- (djb2, arithmetique pure, sans operateur binaire -> portable.)
local function ballisticSignature(identifier, weapon)
    local str = tostring(identifier) .. ':' .. tostring(weapon)
    local h = 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % 4294967296
    end
    local code = string.format('%X', h)
    return string.sub('000000' .. code, -6)
end

local function weaponInfo(weapon)
    return WeaponByHash[weapon] or DouillesConfig.DefaultWeapon
end

-- ---------- Gestion des douilles ----------

local function removeCasing(id)
    if not casings[id] then return end
    casings[id] = nil
    TriggerClientEvent('pop_douilles:client:removeCasing', -1, id)
end

local function countCasings()
    local n = 0
    for _ in pairs(casings) do n = n + 1 end
    return n
end

local function enforceMax()
    while countCasings() > DouillesConfig.MaxCasings do
        local oldestId, oldestTime = nil, nil
        for id, c in pairs(casings) do
            if not oldestTime or c.time < oldestTime then
                oldestId, oldestTime = id, c.time
            end
        end
        if not oldestId then break end
        removeCasing(oldestId)
    end
end

-- ---------- Tir signale par le client ----------

local lastShotBySrc = {}
AddEventHandler('playerDropped', function() lastShotBySrc[source] = nil end)

RegisterNetEvent('pop_douilles:server:shotFired', function(weapon, x, y, z)
    local src = source
    -- Anti-spam : borne le nombre de douilles par tireur (meme cadence que le client)
    local nowMs = GetGameTimer()
    if lastShotBySrc[src] and nowMs - lastShotBySrc[src] < (DouillesConfig.Spawn.Cooldown or 40) then return end
    lastShotBySrc[src] = nowMs
    weapon = tonumber(weapon)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not weapon or not x or not y or not z then return end
    if IgnoredHash[weapon] then return end

    local pc = playerCoords(src)
    if pc and #(pc) > 1.0 and #(vector3(x, y, z) - pc) > DouillesConfig.Spawn.MaxDistance then
        return
    end

    seq = seq + 1
    local id = ('d%d_%d'):format(os.time(), seq)
    local identifier = getIdentifier(src)
    local info = weaponInfo(weapon)
    local t = os.time()

    casings[id] = {
        id         = id,
        coords     = vector3(x, y, z),
        weapon     = weapon,
        caliber    = info.caliber,
        weaponLabel= info.label,
        signature  = ballisticSignature(identifier, weapon),
        identifier = identifier,
        time       = t,
        timeStr    = os.date('%d/%m/%Y a %Hh%M', t),
    }

    enforceMax()

    -- Diffuse la douille a tous les clients pour qu'elle soit visible au sol
    -- (le visuel est public ; les metadonnees balistiques restent serveur-only).
    TriggerClientEvent('pop_douilles:client:revealCasing', -1, { id = id, x = x, y = y, z = z })
end)

-- ---------- CHERCHER : renvoie les douilles proches ----------

ESX.RegisterServerCallback('pop_douilles:search', function(src, cb, x, y, z)
    if not hasJob(src, DouillesConfig.Search.Jobs) then return cb({}) end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return cb({}) end

    -- Anti-triche : on borne la fouille pres du joueur, mais seulement si la position
    -- serveur du ped est fiable (sinon on laisse, cf. ped non synchro -> 0,0,0).
    local pc = playerCoords(src)
    if pc and #(pc) > 1.0 and #(vector3(x, y, z) - pc) > (DouillesConfig.Search.Radius + 8.0) then
        return cb({})
    end

    local origin = vector3(x, y, z)
    local out = {}
    for id, c in pairs(casings) do
        if #(c.coords - origin) <= DouillesConfig.Search.Radius then
            -- On ne renvoie QUE la position : aucune donnee balistique avant analyse.
            out[#out + 1] = { id = id, x = c.coords.x, y = c.coords.y, z = c.coords.z }
        end
    end
    cb(out)
end)

-- ---------- SYNC : envoie les douilles existantes au joueur (connexion / restart resource) ----------

RegisterNetEvent('pop_douilles:server:requestExisting', function()
    local src = source
    local out = {}
    for id, c in pairs(casings) do
        out[#out + 1] = { id = id, x = c.coords.x, y = c.coords.y, z = c.coords.z }
    end
    TriggerClientEvent('pop_douilles:client:syncExisting', src, out)
end)

-- ---------- ADMIN SHOW CASINGS ----------

RegisterNetEvent('pop_douilles:server:requestAllCasings', function()
    local src = source
    if not (isAdminAllowed and isAdminAllowed(src)) then return end
    local out = {}
    for id, c in pairs(casings) do
        out[#out + 1] = { id = id, x = c.coords.x, y = c.coords.y, z = c.coords.z }
    end
    TriggerClientEvent('pop_douilles:client:receiveAllCasings', src, out)
end)

-- ---------- RAMASSER : douille -> item ----------

RegisterNetEvent('pop_douilles:server:pickup', function(id)
    local src = source
    local c = casings[id]
    if not c then return end
    if not hasJob(src, DouillesConfig.Pickup.Jobs) then
        notify(src, "Vous ne pouvez pas ramasser ceci.", 'error')
        return
    end

    local pc = playerCoords(src)
    if pc and #(pc) > 1.0 and #(c.coords - pc) > 5.0 then
        notify(src, "Vous etes trop loin de la douille.", 'error')
        return
    end

    -- Chaque douille porte un id unique -> les items ne se stackent jamais (preuve distincte).
    local meta = {
        id          = c.id,
        customLabel = 'Douille (non analysee)',
        analyzed    = false,
        caliber     = c.caliber,
        weaponLabel = c.weaponLabel,
        weapon      = c.weapon,
        signature   = c.signature,
        time        = c.time,
        timeStr     = c.timeStr,
        sceneX      = c.coords.x,
        sceneY      = c.coords.y,
        sceneZ      = c.coords.z,
    }

    local ok = exports.pop_inventory:GiveItem(src, DouillesConfig.Pickup.Item, 1, meta)
    if not ok then
        notify(src, "Inventaire plein : impossible de ramasser.", 'error')
        return
    end

    removeCasing(id)
    notify(src, "Douille ramassee.", 'success')
end)

-- ---------- ANALYSER : utilisation de l'item douille ----------

local function nearLab(src)
    if not DouillesConfig.Analyze.RequireZone then return true end
    local pc = playerCoords(src)
    if not pc then return false end
    for _, z in ipairs(DouillesConfig.Analyze.Zones or {}) do
        if #(pc - z) <= DouillesConfig.Analyze.ZoneRadius then return true end
    end
    return false
end

-- Appele par pop_inventory quand le joueur "utilise" l'item douille
-- (champ `export = 'pop_douilles:onUseDouille'` dans la def de l'item).
-- Signature : (self, src, item, def). On renvoie false pour NE PAS consommer la douille.
exports('onUseDouille', function(_, src, item, def)
    local meta = (item and item.meta) or {}

    if not hasJob(src, DouillesConfig.Analyze.Jobs) then
        notify(src, "Vous n'avez pas l'expertise pour analyser une douille.", 'error')
        return false
    end
    if not nearLab(src) then
        notify(src, "Rendez-vous au laboratoire balistique pour analyser.", 'error')
        return false
    end

    -- Deja analysee : on reaffiche directement le rapport.
    if meta.analyzed then
        TriggerClientEvent('pop_douilles:client:showReport', src, meta)
        return false
    end

    -- Sinon on lance la barre d'analyse cote client, qui finalisera ensuite.
    TriggerClientEvent('pop_douilles:client:startAnalyze', src, item and item.id)
    return false
end)

RegisterNetEvent('pop_douilles:server:finalizeAnalyze', function(itemId)
    local src = source
    if not itemId then return end
    if not hasJob(src, DouillesConfig.Analyze.Jobs) then return end
    if not nearLab(src) then return end

    -- GetItemMetadata est scope au store du joueur : il ne peut analyser QUE ses propres items.
    local meta = exports.pop_inventory:GetItemMetadata(src, itemId)
    if not meta or not meta.signature then return end -- pas une douille valide

    if not meta.analyzed then
        meta.analyzed = true
        meta.customLabel = ('Douille %s [%s]'):format(meta.caliber or '?', meta.signature or '------')
        exports.pop_inventory:UpdateItemMetadata(src, itemId, meta)
    end

    TriggerClientEvent('pop_douilles:client:showReport', src, meta)
end)

-- ---------- Nettoyage periodique (duree de vie) ----------

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        local expired = {}
        for id, c in pairs(casings) do
            if now - c.time >= DouillesConfig.Lifetime then
                expired[#expired + 1] = id
            end
        end
        for _, id in ipairs(expired) do
            removeCasing(id)
        end
    end
end)
