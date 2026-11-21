-- pop_chargeurs : serveur. Utiliser un chargeur recharge l'arme en main.
-- Aucune boucle : tout se passe à l'utilisation de l'item puis dans le callback de rechargement.

local RES = GetCurrentResourceName()

-- Anti-abus : au plus un rechargement par intervalle et par joueur.
local MIN_INTERVAL = math.max(0, (tonumber(Config.ReloadTime) or 0) - 200)
-- NOTE: fenêtre pendant laquelle le callback est accepté après l'utilisation de l'item
-- (barre de progression + latence). Plus sûr : sans utilisation préalable de l'item, le callback est refusé.
local USE_WINDOW = (tonumber(Config.ReloadTime) or 0) + 5000

local busy = {}       -- [src] = true pendant le traitement
local lastReload = {} -- [src] = GetGameTimer() du dernier rechargement réussi
local pending = {}    -- [src] = { item, at } : item utilisé, en attente du callback

local function debug(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

-- NOTE: les hashes peuvent arriver signés (joaat) ou non signés (natives serveur) : on compare en non signé.
local function norm(hash)
    hash = math.tointeger(tonumber(hash))
    return hash and (hash & 0xFFFFFFFF) or 0
end

local UNARMED = norm(joaat('WEAPON_UNARMED'))

-- compatible[item][hash] = true, construit une fois au démarrage.
local compatible = {}
for item, mag in pairs(Config.Magazines) do
    compatible[item] = {}
    for _, weapon in ipairs(mag.weapons or {}) do
        compatible[item][norm(joaat(weapon))] = true
    end
end

-- Arme en main lue côté serveur (hash non signé, 0 si aucune).
local function selectedWeapon(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 0 end
    return norm(GetSelectedPedWeapon(ped))
end

-- Vérifie l'arme en main pour ce chargeur : hash ou nil, reason.
local function checkWeapon(src, item)
    local hash = selectedWeapon(src)
    if hash == 0 or hash == UNARMED then return nil, 'no_weapon' end
    if not compatible[item][hash] then return nil, 'wrong_weapon' end
    return hash
end

------------------------------------------------------------------------
-- Items utilisables : pré-contrôle, puis barre de progression côté client
------------------------------------------------------------------------

-- Mode metadata : l'arme-item en main doit être lisible avant la barre (sinon raison notifiée tout de suite).
local function checkMetadataWeapon(src, hash)
    local w, why = Weapons.GetCurrent(src)
    if not w then return why or 'no_weapon' end
    if norm(joaat(w.name)) ~= hash then return 'wrong_weapon' end
    if w.ammo >= Config.MaxAmmo then return 'ammo_full' end
    return nil
end

local function onUse(src, item)
    src = tonumber(src)
    if not src or not Config.Magazines[item] then return end
    local hash, reason = checkWeapon(src, item)
    if not reason and Weapons.Mode == 'metadata' then
        reason = checkMetadataWeapon(src, hash)
    end
    if reason then
        return Bridge.Notify(src, L(reason), 'error')
    end
    pending[src] = { item = item, at = GetGameTimer() }
    TriggerClientEvent('pop_chargeurs:client:reload', src, item)
end

for item in pairs(Config.Magazines) do
    Bridge.RegisterUsableItem(item, onUse)
end

------------------------------------------------------------------------
-- Rechargement
------------------------------------------------------------------------

-- Mode metadata : munitions écrites dans la métadonnée de l'arme-item par le serveur.
local function reloadMetadata(src, item, mag, hash)
    local w, why = Weapons.GetCurrent(src)
    if not w then return false, why or 'no_weapon' end
    if norm(joaat(w.name)) ~= hash then return false, 'wrong_weapon' end
    if w.ammo >= Config.MaxAmmo then return false, 'ammo_full' end

    local amount = math.min(mag.ammo, Config.MaxAmmo - w.ammo)
    -- Le chargeur est retiré avant tout ajout de munitions.
    if not Bridge.RemoveItem(src, item, 1) then
        return false, 'missing_item', L('item_magazine')
    end
    local total = w.ammo + amount
    local written, attempted = Weapons.SetAmmo(src, w.slot, total)
    if not written then
        -- Échec d'écriture : on ne rend le chargeur que si l'arme n'a sûrement pas reçu les munitions
        -- (rien envoyé à l'inventaire, ou relecture : même slot, munitions inchangées).
        local after = attempted and Weapons.GetCurrent(src) or nil
        if not attempted or (after and after.slot == w.slot and after.ammo == w.ammo) then
            if not Bridge.AddItem(src, item, 1) then
                print(('[%s] could not give back %s to %s after a failed reload'):format(RES, item, src))
            end
        else
            print(('[%s] reload write unconfirmed for %s (%s, slot %s): ammo before=%s, read back=%s; magazine not given back')
                :format(RES, src, item, w.slot, w.ammo, after and after.ammo or 'unreadable'))
        end
        return false, 'error'
    end
    return true, nil, amount, total
end

-- Mode native : le client ajoute les munitions au ped (plafond basé sur la valeur qu'il envoie, voir README).
local function reloadNative(src, item, mag, currentAmmo)
    currentAmmo = type(currentAmmo) == 'number' and math.tointeger(currentAmmo) or nil
    if not currentAmmo or currentAmmo < 0 then currentAmmo = 0 end
    if currentAmmo >= Config.MaxAmmo then return false, 'ammo_full' end

    local amount = math.min(mag.ammo, Config.MaxAmmo - currentAmmo)
    if not Bridge.RemoveItem(src, item, 1) then
        return false, 'missing_item', L('item_magazine')
    end
    return true, nil, amount, nil
end

local function reload(src, item, mag, currentAmmo)
    local hash, reason = checkWeapon(src, item)
    if not hash then return false, reason end
    if not Bridge.HasItem(src, item) then
        return false, 'missing_item', L('item_magazine')
    end
    if Weapons.Mode == 'metadata' then
        return reloadMetadata(src, item, mag, hash)
    end
    return reloadNative(src, item, mag, currentAmmo)
end

Callback.Register('pop_chargeurs:reload', function(src, item, currentAmmo)
    local mag = type(item) == 'string' and Config.Magazines[item] or nil
    if not mag then return false, 'error' end
    if busy[src] then return false, 'busy' end

    local now = GetGameTimer()
    if lastReload[src] and now - lastReload[src] < MIN_INTERVAL then return false, 'busy' end

    -- L'item doit avoir été utilisé juste avant (pré-contrôle serveur passé).
    local p = pending[src]
    if not p or p.item ~= item or now - p.at > USE_WINDOW then return false, 'error' end
    pending[src] = nil

    busy[src] = true
    local ok, success, why, amount, total = pcall(reload, src, item, mag, type(currentAmmo) == 'number' and currentAmmo or nil)
    busy[src] = nil

    if not ok then
        print(('[%s] reload error for %s: %s'):format(RES, src, tostring(success)))
        return false, 'error'
    end
    if not success then
        debug('reload refused src=%s item=%s reason=%s', src, item, tostring(why))
        return false, why, amount
    end

    lastReload[src] = now
    debug('reload src=%s item=%s amount=%s total=%s mode=%s', src, item, amount, tostring(total), Weapons.Mode)
    Bridge.Notify(src, L('reloaded', amount), 'success')
    return true, nil, amount, total
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

local function clear(src)
    busy[src] = nil
    lastReload[src] = nil
    pending[src] = nil
end

Bridge.OnPlayerDropped(clear)
Bridge.OnPlayerUnloaded(clear)

debug('mode=%s inventory=%s', Weapons.Mode, Bridge.Inventory)
