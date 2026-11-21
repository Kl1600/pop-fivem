-- pop_radio : le serveur décide de tout (item, job, service, canal).
-- Le canal est posé via l'export serveur pma-voice setPlayerRadio, et chaque canal reçoit un
-- addChannelCheck : impossible de rejoindre un canal sans l'item (ou sans le job), même en appelant pma-voice.

local RES = GetCurrentResourceName()
local VOICE = 'pma-voice'

local voice = false   -- pma-voice lancé
local channels = {}   -- [src] = fréquence (int), joueurs connectés via ce script

local function log(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

local MAX = math.tointeger(tonumber(Config.MaxFrequency)) or 999

--- Liste de jobs de la première plage réservée contenant freq, ou nil.
local function reservedJobs(freq)
    for _, r in ipairs(Config.Reserved or {}) do
        if freq >= r.min and freq <= r.max then return r.jobs end
    end
    return nil
end

--- nil si le joueur peut utiliser freq, sinon la clé de locale du refus.
local function check(src, freq)
    if not Bridge.HasItem(src, Config.Item) then return 'radio_lost' end
    local jobs = reservedJobs(freq)
    if jobs then
        local job = Bridge.GetJob(src)
        if not (job and job.onDuty and Bridge.HasJob(src, jobs)) then return 'reserved_frequency' end
    end
    return nil
end

local function canUse(src, freq)
    return check(src, freq) == nil
end

--- Place le joueur sur un canal pma-voice (0 = aucun). Protégé si pma-voice est arrêté.
local function setRadio(src, freq)
    if not voice then return false end
    local ok, err = pcall(function() exports[VOICE]:setPlayerRadio(src, freq) end)
    if not ok then log('setPlayerRadio failed for %s: %s', src, tostring(err)) end
    return ok
end

--- Coupe la radio d'un joueur côté serveur et prévient son client (reason = clé de locale).
local function forceOff(src, reason)
    if not channels[src] then return false end
    log('radio off for %s (freq %s, %s)', src, channels[src], reason)
    setRadio(src, 0)
    channels[src] = nil
    TriggerClientEvent('pop_radio:client:forceOff', src, reason)
    return true
end

------------------------------------------------------------------------
-- pma-voice : détection et contrôles par canal
------------------------------------------------------------------------

local function registerChecks()
    voice = GetResourceState(VOICE) == 'started'
    if not voice then
        print(('[%s] pma-voice is not started: radio connections are refused. Ensure pma-voice before [pop].'):format(RES))
        return
    end
    local ok, err = pcall(function()
        for ch = 1, MAX do
            exports[VOICE]:addChannelCheck(ch, function(source) return canUse(source, ch) end)
        end
    end)
    if not ok then
        print(('[%s] pma-voice addChannelCheck failed: %s'):format(RES, tostring(err)))
        voice = false
    end
end

registerChecks()

-- Démarrage (ou redémarrage) : pma-voice garde le canal de chaque joueur dans son state bag. On reprend ceux qui
-- y ont encore droit, les autres sont sortis (aucune radio active hors du contrôle de ce script).
CreateThread(function()
    Wait(1000) -- laisse le framework et l'inventaire répondre au bridge
    if not voice then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ch = src and math.tointeger(tonumber(Player(src).state.radioChannel))
        if ch and ch > 0 then
            if ch <= MAX and canUse(src, ch) then
                channels[src] = ch
                log('%s restored on frequency %s', src, ch)
            else
                setRadio(src, 0)
            end
        end
    end
end)

-- NOTE: si pma-voice redémarre, ses contrôles de canaux sont perdus : on les repose.
-- S'il s'arrête, toutes les radios sont coupées (plus de voix possible).
AddEventHandler('onResourceStart', function(res)
    if res == VOICE then registerChecks() end
end)

AddEventHandler('onResourceStop', function(res)
    -- Arrêt de ce script : plus aucun contrôle, donc toutes les radios sont coupées.
    if res == RES then
        for src in pairs(channels) do setRadio(src, 0) end
        channels = {}
        return
    end
    if res ~= VOICE then return end
    for src in pairs(channels) do
        channels[src] = nil
        TriggerClientEvent('pop_radio:client:forceOff', src, 'voice_missing')
    end
    voice = false
end)

------------------------------------------------------------------------
-- Item et callbacks
------------------------------------------------------------------------

-- Utiliser l'item ouvre l'interface (aucun retrait).
Bridge.RegisterUsableItem(Config.Item, function(src)
    src = tonumber(src)
    if not src then return end
    TriggerClientEvent('pop_radio:client:open', src)
end)

Callback.Register('pop_radio:canOpen', function(src)
    if not voice then return false, 'voice_missing' end
    if not Bridge.HasItem(src, Config.Item) then return false, 'missing_item', L('item_radio') end
    return true, nil, channels[src] or 0
end)

Callback.Register('pop_radio:join', function(src, freq)
    if not voice then return false, 'voice_missing' end

    -- 1. Fréquence entière dans les bornes (jamais de float ni de chaîne).
    if math.type(freq) ~= 'integer' or freq < 1 or freq > MAX then
        return false, 'invalid_frequency', MAX
    end

    -- 2. Item.
    if not Bridge.HasItem(src, Config.Item) then
        return false, 'missing_item', L('item_radio')
    end

    -- 3. Plage réservée : job et en service.
    if check(src, freq) == 'reserved_frequency' then
        log('reserved frequency %s refused for %s', freq, src)
        return false, 'reserved_frequency'
    end

    -- 4. Placement par le serveur.
    if not setRadio(src, freq) then return false, 'error' end
    channels[src] = freq
    log('%s joined frequency %s', src, freq)
    Bridge.Notify(src, L('joined', freq), 'success')
    return true
end)

Callback.Register('pop_radio:leave', function(src)
    if not voice then return false, 'voice_missing' end
    setRadio(src, 0)
    if channels[src] then log('%s left frequency %s', src, channels[src]) end
    channels[src] = nil
    Bridge.Notify(src, L('left'), 'info')
    return true
end)

------------------------------------------------------------------------
-- Vérification périodique (seuls les joueurs en radio)
------------------------------------------------------------------------

CreateThread(function()
    local interval = math.max(1, tonumber(Config.CheckInterval) or 15) * 1000
    while true do
        Wait(interval)
        if next(channels) then
            -- Copie : forceOff modifie la table pendant le parcours.
            local list = {}
            for src, freq in pairs(channels) do list[#list + 1] = { src, freq } end
            for _, e in ipairs(list) do
                local src, freq = e[1], e[2]
                if channels[src] == freq then
                    local reason = check(src, freq)
                    if reason then forceOff(src, reason) end
                end
            end
        end
    end
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

Bridge.OnPlayerDropped(function(src)
    channels[src] = nil
end)

-- NOTE: SPEC §12 demande setPlayerRadio(src, 0) puis nil ; on prévient aussi le client (forceOff 'left')
-- pour qu'il coupe radioEnabled et remette son état à 0 (export GetFrequency exact pour les HUD).
Bridge.OnPlayerUnloaded(function(src)
    forceOff(src, 'left')
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('GetFrequency', function(src)
    return channels[tonumber(src)] or 0
end)

--- Coupe la radio d'un joueur (menottes, mort…). false s'il n'était pas en radio.
exports('TurnOff', function(src)
    src = tonumber(src)
    if not src then return false end
    return forceOff(src, 'left')
end)
