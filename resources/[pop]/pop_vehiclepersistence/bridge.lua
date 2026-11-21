-- bridge.lua — Couche de compatibilité multi-framework (shared : serveur + client)
--
-- Détection automatique, surchargeable depuis config.lua. Aucune dépendance dure :
-- le script fonctionne en standalone si aucun framework n'est présent.
--   • Serveur : Bridge.GetIdentifier(src)  -> owner_id des véhicules
--   • Client  : Bridge.Notify(msg, type)   -> notification au joueur
-- Exposés aussi en exports : exports['pop_vehiclepersistence']:GetIdentifier / :Notify

Bridge = {}

local IS_SERVER = IsDuplicityVersion()

-- ── Détection ────────────────────────────────────────────────────────────────
local function detectFramework()
    if GetResourceState('es_extended') == 'started' then return 'esx'  end
    if GetResourceState('qbx_core')    == 'started' then return 'qbox' end
    if GetResourceState('qb-core')     == 'started' then return 'qb'   end
    return 'standalone'
end

local cfgFw = (Config and Config.Framework) or 'auto'
Bridge.framework = (cfgFw ~= 'auto') and cfgFw or detectFramework()

local function detectNotif()
    if GetResourceState('ox_lib') == 'started' then return 'ox_lib' end
    if Bridge.framework == 'esx' then return 'esx' end
    if Bridge.framework == 'qb' or Bridge.framework == 'qbox' then return 'qb' end
    return 'chat'
end

local cfgNotif = (Config and Config.Notification) or 'auto'
Bridge.notif = (cfgNotif ~= 'auto') and cfgNotif or detectNotif()

-- ── Serveur : identité du joueur (owner_id) ──────────────────────────────────
if IS_SERVER then
    local function licenseOf(src)
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id:sub(1, 8) == 'license:' then return id end
        end
        return nil
    end

    function Bridge.GetIdentifier(src)
        -- Override total possible via config (cas exotiques)
        if Config and Config.CustomIdentifier then
            return Config.CustomIdentifier(src)
        end
        if ((Config and Config.OwnerKey) or 'license') == 'framework' then
            local ok, ident = pcall(function()
                if Bridge.framework == 'esx' then
                    local xP = exports['es_extended']:GetPlayerFromId(src)
                    return xP and xP.identifier
                elseif Bridge.framework == 'qb' then
                    local QBCore = exports['qb-core']:GetCoreObject()
                    local P = QBCore and QBCore.Functions.GetPlayer(src)
                    return P and P.PlayerData.citizenid
                elseif Bridge.framework == 'qbox' then
                    local P = exports.qbx_core:GetPlayer(src)
                    return P and P.PlayerData.citizenid
                end
            end)
            if ok and ident then return ident end
        end
        return licenseOf(src)   -- défaut universel + fallback si framework indisponible
    end

    exports('GetIdentifier', function(src) return Bridge.GetIdentifier(src) end)

    local playerKeyCache        = {}  -- [pid]      = { [plate] = true }
    local playerKeyCacheTime    = {}  -- [pid]      = timestamp (ms)
    local KEY_CACHE_TTL_MS       = 10000

    local function normalPlate(plate)
        return string.upper(string.gsub(tostring(plate or ''), '%s+', ''))
    end

    local function refreshPlayerKeys(pid)
        if not Config.UseTabInventory then
            playerKeyCache[pid] = nil
            playerKeyCacheTime[pid] = GetGameTimer()
            return
        end
        local ok, items = pcall(function()
            return exports['pop_inventory']:GetPlayerItems(pid, 'carkeys')
        end)
        local plates = {}
        if ok and items then
            for _, item in ipairs(items) do
                if item.meta and item.meta.plate then
                    plates[normalPlate(item.meta.plate)] = true
                end
            end
        end
        playerKeyCache[pid]     = plates
        playerKeyCacheTime[pid] = GetGameTimer()
    end

    local function playerHasKeyCached(pid, plate)
        if Config.HasVehicleKey then
            local ok, res = pcall(Config.HasVehicleKey, pid, normalPlate(plate))
            return ok and res == true
        end
        if not Config.UseTabInventory then return true end
        local last = playerKeyCacheTime[pid]
        if not last or (GetGameTimer() - last) > KEY_CACHE_TTL_MS then
            refreshPlayerKeys(pid)
        end
        local cache = playerKeyCache[pid]
        return cache and cache[normalPlate(plate)] == true
    end

    local function PlayerHasKey(src, plate)
        if not plate then return false end
        if Config.HasVehicleKey then
            local ok, res = pcall(Config.HasVehicleKey, src, normalPlate(plate))
            return ok and res == true
        end
        if not Config.UseTabInventory then return true end
        refreshPlayerKeys(src)
        local cache = playerKeyCache[src]
        return cache and cache[normalPlate(plate)] == true
    end

    local function OnKeyGranted(pid, plate)
        if not pid or not plate then return end
        playerKeyCache[pid]     = nil
        playerKeyCacheTime[pid] = nil
        TriggerClientEvent("pop_vehiclepersistence:forceResync", pid)
    end

    Bridge.PlayerHasKeyCached = playerHasKeyCached
    exports('playerHasKeyCached', function(pid, plate) return playerHasKeyCached(pid, plate) end)
    exports('PlayerHasKey', function(src, plate) return PlayerHasKey(src, plate) end)
    exports('OnKeyGranted', function(pid, plate) OnKeyGranted(pid, plate) end)

    print(("[Persistence] Bridge: framework='%s', owner_id='%s'"):format(
        Bridge.framework, (Config and Config.OwnerKey) or 'license'))
end

-- ── Client : notifications ───────────────────────────────────────────────────
if not IS_SERVER then
    function Bridge.Notify(msg, ntype)
        -- Override total possible via config (cas exotiques)
        if Config and Config.CustomNotify then
            return Config.CustomNotify(msg, ntype)
        end
        local m = Bridge.notif
        if m == 'ox_lib' then
            exports.ox_lib:notify({ description = msg, type = ntype or 'inform' })
        elseif m == 'esx' then
            TriggerEvent('esx:showNotification', msg)
        elseif m == 'qb' then
            TriggerEvent('QBCore:Notify', msg, ntype or 'primary')
        else
            TriggerEvent('chat:addMessage', { color = { 120, 200, 130 }, args = { '[Persistence]', msg } })
        end
    end

    RegisterNetEvent('pop_vehiclepersistence:notify', function(msg, ntype)
        Bridge.Notify(msg, ntype)
    end)

    exports('Notify', function(msg, ntype) Bridge.Notify(msg, ntype) end)
end
