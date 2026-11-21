-- pop_douilles : serveur. Les douilles vivent uniquement en mémoire, ici.
-- Rien n'est diffusé aux joueurs, sauf la liste { id, x, y, z } envoyée à un policier qui fouille
-- et l'id d'une douille retirée (event removed).

local RES = GetCurrentResourceName()

local EV_REMOVED = 'pop_douilles:client:removed'
local EV_REPORT  = 'pop_douilles:client:report'

local casings = {}       -- [id] = { id, x, y, z, weapon, count, createdAt, signature }
local total = 0          -- nombre de douilles en mémoire
local lastId = 0

local lastShot = {}      -- [src] = GetGameTimer() du dernier signalement accepté
local lastWeapon = {}    -- [src] = { hash, t } : dernière arme valide lue côté serveur (GetGameTimer)
local searchCooldown = {} -- [src] = os.time() de la dernière fouille
local busy = {}          -- [src] = true pendant un ramassage

local function debug(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

-- Hash signé 32 bits : GetHashKey et GetSelectedPedWeapon peuvent renvoyer signé ou non signé.
local function normHash(h)
    h = math.tointeger(h)
    if not h then return nil end
    h = h & 0xFFFFFFFF
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

local function hashOf(name)
    return normHash(GetHashKey(name))
end

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

-- Accepte vector3 ou table { x, y, z } ; renvoie x, y, z ou nil.
local function readCoords(c)
    local t = type(c)
    if t ~= 'table' and t ~= 'vector3' and t ~= 'vector4' then return nil end
    local x, y, z = c.x, c.y, c.z
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return x + 0.0, y + 0.0, z + 0.0
end

local function round1(n)
    return math.floor(n * 10 + 0.5) / 10
end

local function dist(c, x, y, z)
    local dx, dy, dz = c.x - x, c.y - y, c.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Signature balistique : djb2(identifier .. ':' .. weapon) % 2^32, affichée sur 6 caractères hexadécimaux.
-- NOTE: 6 hex = 24 bits : on garde les 24 bits de poids faible du hash 32 bits.
local function signatureOf(identifier, weapon)
    local s = tostring(identifier) .. ':' .. tostring(weapon)
    local h = 5381
    for i = 1, #s do
        h = ((h * 33) + s:byte(i)) & 0xFFFFFFFF
    end
    return ('%06X'):format(h & 0xFFFFFF)
end

-- Format de date propre à la langue ; un format invalide ne doit pas casser le ramassage.
local function formatTime(t)
    local ok, s = pcall(os.date, L('time_format'), t)
    if ok and type(s) == 'string' then return s end
    return os.date('%Y-%m-%d %H:%M', t)
end

------------------------------------------------------------------------
-- Tables par hash (construites une fois)
------------------------------------------------------------------------

local UNARMED = hashOf('WEAPON_UNARMED')
local ignored = {}   -- [hash] = true
local caliberOf = {} -- [hash] = '9mm'

for _, name in ipairs(Config.IgnoredWeapons or {}) do
    ignored[hashOf(name)] = true
end
for label, list in pairs(Config.Calibers or {}) do
    for _, name in ipairs(list) do
        caliberOf[hashOf(name)] = label
    end
end

------------------------------------------------------------------------
-- Gestion des douilles
------------------------------------------------------------------------

local function removeCasing(id)
    if not casings[id] then return end
    casings[id] = nil
    total = total - 1
    TriggerClientEvent(EV_REMOVED, -1, id)
end

-- Supprime la plus ancienne douille (createdAt le plus petit, puis id le plus petit).
-- signature optionnelle : seulement parmi les tas de cette signature.
local function removeOldest(signature)
    local oldest
    for _, c in pairs(casings) do
        if (not signature or c.signature == signature) and (not oldest or c.createdAt < oldest.createdAt
            or (c.createdAt == oldest.createdAt and c.id < oldest.id)) then
            oldest = c
        end
    end
    if oldest then removeCasing(oldest.id) end
end

local function countSignature(signature)
    local n = 0
    for _, c in pairs(casings) do
        if c.signature == signature then n = n + 1 end
    end
    return n
end

-- Ajoute des douilles au tas proche (même signature, donc même arme et même tireur) ou crée un tas.
-- NOTE: SPEC dit « même arme » ; on exige aussi la même signature pour ne jamais mélanger deux tireurs
-- dans une même preuve. Fusion = l'heure du tas devient celle du dernier tir.
local function addCasing(x, y, z, weapon, count, identifier)
    local signature = signatureOf(identifier, weapon)
    local now = os.time()

    for _, c in pairs(casings) do
        if c.weapon == weapon and c.signature == signature and dist(c, x, y, z) <= Casing.MERGE_DISTANCE then
            c.count = math.min(c.count + count, Casing.MAX_COUNT)
            c.createdAt = now
            return c.id
        end
    end

    -- Plafond par signature d'abord : un seul tireur ne peut pas vider le plafond global.
    while countSignature(signature) >= Casing.MAX_PER_SIGNATURE do removeOldest(signature) end

    lastId = lastId < 2147483647 and lastId + 1 or 1
    local id = lastId
    casings[id] = {
        id = id,
        x = x, y = y, z = z,
        weapon = weapon,
        count = math.min(count, Casing.MAX_COUNT),
        createdAt = now,
        signature = signature,
    }
    total = total + 1

    while total > 0 and total > (tonumber(Config.MaxCasings) or 150) do removeOldest() end
    return casings[id] and id or nil
end

local function isPolice(src)
    if not Bridge.HasJob(src, Config.PoliceJobs) then return false end
    local job = Bridge.GetJob(src)
    return job ~= nil and job.onDuty == true
end

------------------------------------------------------------------------
-- Signalement de tirs (net event, sans réponse)
------------------------------------------------------------------------

-- previous = true : tirs faits avec l'arme tenue avant un changement (le client vient de ranger / changer).
RegisterNetEvent('pop_douilles:server:shot', function(coords, shots, previous)
    local src = source
    if not src or src <= 0 or not GetPlayerName(src) then return end

    -- 1. Throttle (le timer est posé même si la suite échoue : un spam reste limité).
    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < Casing.REPORT_INTERVAL - 200 then return end
    lastShot[src] = now

    -- 2. Validation des données.
    local x, y, z = readCoords(coords)
    if not x then return end
    shots = math.tointeger(shots)
    if not shots or shots < 1 then return end
    shots = math.min(shots, Casing.MAX_SHOTS)

    -- 3. Position signalée proche de la position serveur.
    if not Bridge.IsNear(src, { x = x, y = y, z = z }, Casing.REPORT_DISTANCE) then
        debug('shot ignored (too far) from %s', src)
        return
    end

    -- 4. Arme lue côté serveur, jamais envoyée par le client. Arme rangée ou changée juste avant l'envoi :
    --    dernière arme valide lue ici, si elle date de moins de 1,5 s.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local weapon = normHash(GetSelectedPedWeapon(ped))
    local valid = weapon and weapon ~= UNARMED and not ignored[weapon]
    local last = lastWeapon[src]
    if last and now - last.t < 1500 and (not valid or (previous == true and weapon ~= last.hash)) then
        weapon = last.hash
    elseif valid then
        lastWeapon[src] = { hash = weapon, t = now }
    else
        return
    end

    -- 5. Création ou fusion.
    local identifier = Bridge.GetIdentifier(src) or ('src:' .. src)
    local id = addCasing(x, y, z, weapon, shots, identifier)
    debug('shot src=%s weapon=%s shots=%d casing=%s', src, weapon, shots, tostring(id))
end)

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

-- Mort ou en véhicule : ni fouille ni ramassage.
local function canAct(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetEntityHealth(ped) > 0 and GetVehiclePedIsIn(ped, false) == 0
end

Callback.Register('pop_douilles:search', function(src)
    if not isPolice(src) then return false, 'wrong_job' end
    if not canAct(src) then return false, 'error' end

    local now = os.time()
    local last = searchCooldown[src]
    if last and now - last < Casing.SEARCH_COOLDOWN then
        return false, 'cooldown', Casing.SEARCH_COOLDOWN - (now - last)
    end
    searchCooldown[src] = now

    -- Centre = position serveur, jamais une position envoyée par le client.
    local pos = Bridge.GetCoords(src)
    if not pos then return false, 'error' end

    local list = {}
    for _, c in pairs(casings) do
        if dist(c, pos.x, pos.y, pos.z) <= Config.SearchRadius then
            list[#list + 1] = { id = c.id, x = c.x, y = c.y, z = c.z }
        end
    end
    debug('search src=%s found=%d', src, #list)
    return true, nil, list
end)

local function pickup(src, id)
    local c = casings[id]
    if not c then return false, 'casing_not_found' end
    if not Bridge.IsNear(src, c, Casing.PICKUP_DISTANCE) then return false, 'too_far' end
    if not Bridge.CanCarry(src, Config.Item, 1) then return false, 'inventory_full' end

    local caliber = caliberOf[c.weapon]
    local time = formatTime(c.createdAt)
    local metadata = {
        caliber = caliber,
        signature = c.signature,
        shotAt = c.createdAt,
        time = time,
        x = round1(c.x), y = round1(c.y), z = round1(c.z),
        count = c.count,
        description = L('casing_description', caliber or L('caliber_unknown'), time),
    }

    -- Retirée de la mémoire avant l'ajout : deux ramassages simultanés ne peuvent pas la dupliquer.
    casings[id] = nil
    total = total - 1

    if not Bridge.AddItem(src, Config.Item, 1, metadata) then
        casings[id] = c
        total = total + 1
        return false, 'inventory_full'
    end

    TriggerClientEvent(EV_REMOVED, -1, id)
    Bridge.Notify(src, L('picked_up'), 'success')
    debug('pickup src=%s (%s) casing=%d signature=%s count=%d',
        src, tostring(Bridge.GetIdentifier(src)), id, c.signature, c.count)
    return true
end

Callback.Register('pop_douilles:pickup', function(src, id)
    if math.type(id) ~= 'integer' or not casings[id] then return false, 'casing_not_found' end
    if not isPolice(src) then return false, 'wrong_job' end
    if not canAct(src) then return false, 'error' end
    if busy[src] then return false, 'busy' end

    busy[src] = true
    local ok, res, reason = pcall(pickup, src, id)
    busy[src] = nil
    if not ok then
        print(('[%s] pickup error: %s'):format(RES, tostring(res)))
        return false, 'error'
    end
    return res, reason
end)

------------------------------------------------------------------------
-- Item utilisable : rapport balistique
------------------------------------------------------------------------

local function str(v, max)
    if type(v) ~= 'string' or v == '' then return nil end
    return v:sub(1, max)
end

Bridge.RegisterUsableItem(Config.Item, function(src, _, metadata)
    src = tonumber(src)
    if not src then return end
    if not isPolice(src) then
        Bridge.Notify(src, L('wrong_job'), 'error')
        return
    end
    if type(metadata) ~= 'table' then return end
    local signature = str(metadata.signature, 6)
    if not signature then return end

    -- Champs relus un par un : la métadonnée n'est jamais renvoyée telle quelle.
    local count = math.tointeger(metadata.count)
    if count and (count < 1 or count > Casing.MAX_COUNT) then count = nil end

    local data = {
        caliber = str(metadata.caliber, 16),
        signature = signature,
        time = str(metadata.time, 32) or '',
        count = count,
    }
    -- NOTE: x, y, z sont ajoutés pour que le client calcule la rue (SPEC §6) ; ils ne vont pas dans la NUI.
    local x, y, z = readCoords(metadata)
    if x then data.x, data.y, data.z = x, y, z end

    TriggerClientEvent(EV_REPORT, src, data)
end)

------------------------------------------------------------------------
-- Exports publics
------------------------------------------------------------------------

--- Crée une douille (scène de crime, PNJ...). Renvoie l'id du tas ou nil.
exports('AddCasing', function(coords, weaponHash, count, identifier)
    local x, y, z = readCoords(coords)
    if not x then return nil end
    local weapon = type(weaponHash) == 'string' and hashOf(weaponHash) or normHash(weaponHash)
    if not weapon or weapon == UNARMED or ignored[weapon] then return nil end
    count = count == nil and 1 or math.tointeger(count)
    if not count or count < 1 then return nil end
    if type(identifier) ~= 'string' or identifier == '' then identifier = 'npc' end
    local id = addCasing(x, y, z, weapon, count, identifier)
    debug('export AddCasing by %s casing=%s', GetInvokingResource() or '?', tostring(id))
    return id
end)

--- Supprime les douilles dans le rayon. Renvoie le nombre supprimé.
exports('ClearArea', function(coords, radius)
    local x, y, z = readCoords(coords)
    radius = tonumber(radius)
    if not x or not finite(radius) or radius <= 0 then return 0 end
    local ids = {}
    for id, c in pairs(casings) do
        if dist(c, x, y, z) <= radius then ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do removeCasing(id) end
    debug('export ClearArea by %s removed=%d', GetInvokingResource() or '?', #ids)
    return #ids
end)

------------------------------------------------------------------------
-- Purge et nettoyage
------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)
        local limit = os.time() - Config.Lifetime
        local expired = {}
        for id, c in pairs(casings) do
            if c.createdAt <= limit then expired[#expired + 1] = id end
        end
        for _, id in ipairs(expired) do removeCasing(id) end
        if #expired > 0 then debug('purge removed=%d', #expired) end
    end
end)

local function clearPlayer(src)
    lastShot[src] = nil
    lastWeapon[src] = nil
    searchCooldown[src] = nil
    busy[src] = nil
end

Bridge.OnPlayerDropped(clearPlayer)
Bridge.OnPlayerUnloaded(clearPlayer)
