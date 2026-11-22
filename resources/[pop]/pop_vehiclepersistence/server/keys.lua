-- pop_vehiclepersistence — serveur : propriétaire (owner_id) et vérification des clés.
-- Exports : GetIdentifier, playerHasKeyCached, PlayerHasKey, OnKeyGranted (utilisés par pop_inventory).

local P = Persist
local normalPlate = P.normalPlate

-- ── Propriétaire des véhicules ───────────────────────────────────────────────
local function licenseOf(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

--- owner_id d'un joueur : license Rockstar par défaut, identifier du framework si Config.OwnerKey = 'framework'.
function P.GetIdentifier(src)
    -- Override total possible via config (cas exotiques)
    if Config.CustomIdentifier then
        return Config.CustomIdentifier(src)
    end
    if (Config.OwnerKey or 'license') == 'framework' then
        local ok, ident = pcall(Bridge.GetIdentifier, src)
        if ok and ident then return ident end
    end
    return licenseOf(src)   -- défaut universel + fallback si framework indisponible
end

exports('GetIdentifier', function(src) return P.GetIdentifier(src) end)

-- ── Clés (item 'carkeys' de pop_inventory, ou Config.HasVehicleKey) ──────────
local playerKeyCache     = {}  -- [pid] = { [plate] = true }
local playerKeyCacheTime = {}  -- [pid] = timestamp (ms)
local KEY_CACHE_TTL_MS   = 10000

local function refreshPlayerKeys(pid)
    if not Config.UseTabInventory then
        playerKeyCache[pid] = nil
        playerKeyCacheTime[pid] = GetGameTimer()
        return
    end
    -- pop_inventory direct : clés nominatives (meta.plate)
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

P.PlayerHasKeyCached = playerHasKeyCached
exports('playerHasKeyCached', function(pid, plate) return playerHasKeyCached(pid, plate) end)
exports('PlayerHasKey', function(src, plate) return PlayerHasKey(src, plate) end)
exports('OnKeyGranted', function(pid, plate) OnKeyGranted(pid, plate) end)

-- ── Raccourcis sûrs (pcall) utilisés par les évènements ─────────────────────
function P.getIdentifier(pid)
    local ok, id = pcall(P.GetIdentifier, pid)
    return ok and id or nil
end

function P.hasKey(pid, plate)
    local ok, res = pcall(playerHasKeyCached, pid, plate)
    if not ok then return true end
    return res == true
end

P.Debug("owner_id='%s'", Config.OwnerKey or 'license')
