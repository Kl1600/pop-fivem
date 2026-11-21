-- Actions joueur : callbacks init / move / give / use / reload, armes, argent physique, items utilisables, /giveitem.
-- Le client n'envoie que des slots, quantités et server ids : tout le reste est relu côté serveur.

InvPlayers = InvPlayers or {}

local RES = GetCurrentResourceName()

local HOTBAR = 5                      -- slots 1 à 5 du joueur = hotbar (référence, utilisée côté client)
local TOLERANCE = 1.0                 -- marge serveur sur toute distance (latence), mètres
local USE_COOLDOWN = 500              -- ms entre deux utilisations, par joueur
local WEAPON_UPDATE_THROTTLE = 500    -- ms entre deux remontées de munitions
local PLAYER_LOAD_TIMEOUT = 10        -- s d'attente de l'inventaire dans init
local GIVEITEM_MAX = 10000            -- quantité max de /giveitem

local Equipped = {}     -- [src] = { slot, name, serial } : arme en main suivie par le serveur
local Usable = {}       -- [name] = { cb, resource }
local lastUse = {}      -- [src] = GetGameTimer()
local lastWeapon = {}   -- [src] = GetGameTimer() (throttle updateWeapon)
local lastCash = {}     -- [src] = total de l'item d'argent connu
local syncing = {}      -- [src] = true pendant une synchro d'argent
local pendingAmmo = {}  -- [src] = dernière valeur de munitions reçue pendant la fenêtre du throttle
local ammoTimer = {}    -- [src] = true : application de pendingAmmo programmée

local toInt = Inventory.ToInt

local function debug(msg, ...)
    if Config.Debug then print(('[%s] ' .. msg):format(RES, ...)) end
end

local function log(msg, ...)
    print(('[%s] ' .. msg):format(RES, ...))
end

-- Inventaire du joueur s'il est chargé et utilisable, sinon nil, 'not_loaded'.
local function playerInv(src)
    if not Bridge.GetPlayer(src) then return nil, 'not_loaded' end
    local inv = Inventory.Get(src)
    if not inv or inv.closing then return nil, 'not_loaded' end
    return inv
end

--- Statebag invBusy (compatibilité ox). Partagée avec les conteneurs.
local function isBusy(src)
    local ok, busy = pcall(function() return Player(src).state.invBusy end)
    return ok and busy == true
end
InvPlayers.IsBusy = isBusy

local function holster(src)
    pendingAmmo[src] = nil
    if Equipped[src] then
        Equipped[src] = nil
        TriggerClientEvent('pop_inventory:client:holster', src)
    end
end

------------------------------------------------------------------------
-- Argent physique (Config.CashItem)
------------------------------------------------------------------------

local cashChecked, cashName = false, nil

-- Nom de l'item d'argent s'il est valide, sinon nil (avertissement unique).
local function cashItem()
    if not cashChecked then
        cashChecked = true
        if Config.CashItem then
            if Items.Get(Config.CashItem) then
                cashName = Config.CashItem:lower()
            else
                log('warning: Config.CashItem "%s" is not a registered item, option ignored', tostring(Config.CashItem))
            end
        end
    end
    return cashName
end

--- Framework → inventaire : ajuste l'item d'argent (sans contrôle de poids) au compte 'cash'.
function ReconcileCash(src)
    local name = cashItem()
    if not name or Bridge.Framework == 'standalone' then return end
    local inv = Inventory.Get(src)
    if not inv or inv.closing then return end
    syncing[src] = true
    local ok, err = pcall(function()
        local money = math.min(math.max(0, math.floor(Bridge.GetMoney(src, 'cash'))), Inventory.COUNT_MAX)
        local total = Inventory.GetItemCount(inv, name)
        if money > total then
            Inventory.AddItem(inv, name, money - total, nil, nil, true)
        elseif money < total then
            Inventory.RemoveItem(inv, name, total - money)
        end
        lastCash[src] = Inventory.GetItemCount(inv, name)
    end)
    syncing[src] = nil
    if not ok then log('cash reconcile error for %s: %s', src, tostring(err)) end
end

--- Avant de faire sortir `amount` billets de l'inventaire de src : resynchronise puis vérifie le compte du framework.
--- true si l'opération peut continuer (pas d'item d'argent, standalone, ou solde suffisant).
function InvPlayers.CashGuard(src, name, amount)
    local cash = cashItem()
    if not cash or Bridge.Framework == 'standalone' or not amount or amount <= 0 then return true end
    if type(name) ~= 'string' or name:lower() ~= cash then return true end
    return Bridge.GetMoney(src, 'cash') >= amount
end

--- Nom de l'item d'argent actif (ou nil).
function InvPlayers.CashItem()
    return cashItem()
end

-- Inventaire → framework : répercute la variation de l'item sur le compte 'cash'.
local function syncCashToFramework(inv)
    local name = cashItem()
    local src = inv.id
    if not name or Bridge.Framework == 'standalone' or syncing[src] then return end
    local total = Inventory.GetItemCount(inv, name)
    local last = lastCash[src]
    if last == nil then
        lastCash[src] = total
        return
    end
    if total == last then return end
    syncing[src] = true
    local delta = total - last
    local ok
    if delta > 0 then
        ok = Bridge.AddMoney(src, 'cash', delta, RES)
    else
        ok = Bridge.RemoveMoney(src, 'cash', -delta, RES)
    end
    syncing[src] = nil
    if ok then
        lastCash[src] = total
    else
        -- Désaccord : le compte du framework fait foi.
        ReconcileCash(src)
    end
end

-- Changements d'argent faits par d'autres scripts.
-- NOTE: noms d'events à confirmer selon la version du framework.
local function onMoneyEvent(src, account)
    src = tonumber(src)
    if not src or syncing[src] or not cashItem() then return end
    if account ~= nil and account ~= 'money' and account ~= 'cash' then return end
    ReconcileCash(src)
end

if Bridge.Framework == 'esx' then
    AddEventHandler('esx:setAccountMoney', function(src, account) onMoneyEvent(src, type(account) == 'table' and account.name or account) end)
    AddEventHandler('esx:addAccountMoney', function(src, account) onMoneyEvent(src, type(account) == 'table' and account.name or account) end)
    AddEventHandler('esx:removeAccountMoney', function(src, account) onMoneyEvent(src, type(account) == 'table' and account.name or account) end)
elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
    AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType) onMoneyEvent(src, moneyType) end)
end

------------------------------------------------------------------------
-- Suivi après chaque changement de l'inventaire joueur (appelé par Inventory)
------------------------------------------------------------------------

function InvPlayers.OnInventoryChanged(inv)
    local src = inv.id
    -- Arme équipée : toujours au même slot, même nom et même série.
    local eq = Equipped[src]
    if eq then
        local it = inv.items[eq.slot]
        if not it or it.name ~= eq.name or it.metadata.serial ~= eq.serial then holster(src) end
    end
    syncCashToFramework(inv)
    if FrameworkCompat and FrameworkCompat.Mirror then FrameworkCompat.Mirror(src) end
end

--- Nettoyage des données par joueur (déchargement / déconnexion).
function InvPlayers.Cleanup(src)
    Equipped[src] = nil
    pendingAmmo[src] = nil
    lastUse[src] = nil
    lastWeapon[src] = nil
    lastCash[src] = nil
    syncing[src] = nil
end

--- Arme équipée au format { slot, name, ammo, durability } ou nil.
local function weaponInfo(src, inv)
    local eq = Equipped[src]
    local it = eq and inv.items[eq.slot]
    if not it or it.name ~= eq.name or it.metadata.serial ~= eq.serial then return nil end
    return { slot = eq.slot, name = it.name, ammo = toInt(tonumber(it.metadata.ammo)) or 0, durability = tonumber(it.metadata.durability) or 100 }
end

function InvPlayers.GetEquipped(src)
    return Equipped[src]
end

-- Hash de l'arme tenue par le ped (32 bits non signé), ou nil si inconnu (native indisponible / 0).
local function selectedWeapon(src)
    local okSel, selected = pcall(GetSelectedPedWeapon, GetPlayerPed(src))
    selected = okSel and math.tointeger(selected) or nil
    if not selected or selected == 0 then return nil end
    return selected & 0xFFFFFFFF
end

--- Pile de l'arme en main (référence interne : copier avant d'exposer), ou nil.
--- Le ped doit tenir cette arme (si le serveur connaît l'arme sélectionnée).
function InvPlayers.GetCurrentWeapon(src)
    src = toInt(tonumber(src))
    local inv = src and Inventory.Get(src)
    if not inv or inv.closing then return nil end
    local eq = Equipped[src]
    local it = eq and inv.items[eq.slot]
    if not it or it.name ~= eq.name or it.metadata.serial ~= eq.serial then return nil end
    local selected = selectedWeapon(src)
    if selected and selected ~= (joaat(it.name:upper()) & 0xFFFFFFFF) then return nil end
    return it
end

------------------------------------------------------------------------
-- Items utilisables (exports RegisterUsableItem)
------------------------------------------------------------------------

--- Un seul callback par item (le dernier remplace).
function InvPlayers.RegisterUsable(name, cb, resource)
    if type(name) ~= 'string' or cb == nil then return false end
    Usable[name:lower()] = { cb = cb, resource = resource }
    return true
end

AddEventHandler('onResourceStop', function(res)
    for name, u in pairs(Usable) do
        if u.resource == res then Usable[name] = nil end
    end
end)

------------------------------------------------------------------------
-- Rechargement
------------------------------------------------------------------------

local function reload(src, inv)
    local eq = Equipped[src]
    local it = eq and inv.items[eq.slot]
    if not it or it.name ~= eq.name or it.metadata.serial ~= eq.serial then return false, 'weapon_needed' end
    local def = Items.Get(it.name)
    if not def or not def.ammo then return false, 'weapon_needed' end
    local ammo = math.max(0, math.floor(tonumber(it.metadata.ammo) or 0))
    if ammo >= def.clip then return false, 'ammo_full' end
    local have = Inventory.GetItemCount(inv, def.ammo)
    if have <= 0 then return false, 'no_ammo' end
    local n = math.min(def.clip - ammo, have)
    if not Inventory.RemoveItem(inv, def.ammo, n) then return false, 'no_ammo' end
    -- Relire le slot : le retrait a pu déclencher un contrôle de l'arme.
    it = inv.items[eq.slot]
    if not it or Equipped[src] ~= eq then
        Inventory.AddItem(inv, def.ammo, n, nil, nil, true) -- restitution
        return false, 'weapon_needed'
    end
    local md = Inventory.Copy(it.metadata)
    md.ammo = ammo + n
    Inventory.SetMetadata(inv, eq.slot, md)
    TriggerClientEvent('pop_inventory:client:setAmmo', src, md.ammo)
    debug('reload %s %s +%d', src, it.name, n)
    return true
end

------------------------------------------------------------------------
-- Callbacks
------------------------------------------------------------------------

Callback.Register('pop_inventory:init', function(src)
    local waited = 0
    while not Inventory.Get(src) and waited < PLAYER_LOAD_TIMEOUT * 1000 do
        Wait(100)
        waited = waited + 100
    end
    local inv = playerInv(src)
    if not inv then return nil end
    ReconcileCash(src)
    local points = Containers and Containers.GetPoints and Containers.GetPoints() or {}
    return {
        items = Items.Defs(),
        inventory = Inventory.View(inv),
        drops = points.drops or {},
        stashes = points.stashes or {},
        shops = points.shops or {},
        weapon = weaponInfo(src, inv),
    }
end)

Callback.Register('pop_inventory:move', function(src, from, fromSlot, to, toSlot, count)
    local inv, reason = playerInv(src)
    if not inv then return false, reason end
    if (from ~= 'player' and from ~= 'secondary') or (to ~= 'player' and to ~= 'secondary') then return false, 'error' end
    fromSlot = toInt(fromSlot)
    if not fromSlot then return false, 'error' end
    if toSlot ~= nil then
        toSlot = toInt(toSlot)
        if not toSlot then return false, 'error' end
    end
    if count ~= nil then
        count = toInt(count)
        if not count or count < 1 then return false, 'error' end
    end
    -- NOTE: un joueur mort ou occupé (invBusy) ne déplace rien (option la plus sûre).
    if isBusy(src) or Bridge.IsDead(src) then return false, 'cannot_now' end

    -- Argent physique : item resynchronisé avec le framework, puis solde vérifié pour ce qui quitte l'inventaire.
    ReconcileCash(src)
    local cash = cashItem()
    if cash and from ~= to then
        local leaving
        if from == 'player' then
            local it = inv.items[fromSlot]
            if it and it.name == cash then leaving = count or it.count end
        elseif toSlot then
            local it = inv.items[toSlot] -- échange : la pile du joueur part dans le conteneur
            if it and it.name == cash then leaving = it.count end
        end
        if leaving and not InvPlayers.CashGuard(src, cash, leaving) then return false, 'not_enough_money' end
    end

    local secondary, createdDrop
    if from == 'secondary' or to == 'secondary' then
        if not Containers or not Containers.GetSecondary then return false, 'error' end
        local sec = Containers.GetSecondary(src)
        if sec == nil or sec == 'shop' then return false, 'error' end
        if sec == 'newdrop' then
            if from ~= 'player' or to ~= 'secondary' then return false, 'error' end
            if fromSlot < 1 or fromSlot > inv.slots or not inv.items[fromSlot] then return false, 'item_not_found' end
            local drop, dropReason = Containers.CreateDrop(src)
            if not drop then return false, dropReason or 'error' end
            sec, createdDrop = drop, true
            if toSlot and drop.items[toSlot] then toSlot = nil end
        end
        local ok, accessReason = Containers.CanAccess(src, sec)
        if not ok then return false, accessReason or 'error' end
        secondary = sec
    end

    local fromInv = from == 'player' and inv or secondary
    local toInv = to == 'player' and inv or secondary
    local ok, moveReason = Inventory.Move(src, fromInv, fromSlot, toInv, toSlot, count)
    -- Drop créé pour rien : le LOT 2 le supprime s'il est vide.
    if not ok and createdDrop and Inventory.IsEmpty(secondary) and Containers.OnChanged then
        Containers.OnChanged(secondary)
    end
    return ok, moveReason
end)

Callback.Register('pop_inventory:give', function(src, slot, count, target)
    local inv, reason = playerInv(src)
    if not inv then return false, reason end
    slot, target = toInt(slot), toInt(target)
    if not slot or not target then return false, 'error' end
    if count ~= nil then
        count = toInt(count)
        if not count or count < 1 then return false, 'error' end
    end
    if target == src then return false, 'error' end

    local tInv = Bridge.GetPlayer(target) and Inventory.Get(target)
    if not tInv or tInv.closing then return false, 'no_player_nearby' end

    local a, b = Bridge.GetCoords(src), Bridge.GetCoords(target)
    if not a or not b or #(a - b) > Config.GiveDistance + TOLERANCE then return false, 'too_far' end
    if isBusy(src) or isBusy(target) or Bridge.IsDead(src) or Bridge.IsDead(target) then return false, 'cannot_now' end

    ReconcileCash(src)
    local item = slot >= 1 and slot <= inv.slots and inv.items[slot]
    if not item then return false, 'item_not_found' end
    count = count or item.count
    if count > item.count then return false, 'error' end
    if not InvPlayers.CashGuard(src, item.name, count) then return false, 'not_enough_money' end

    local name, md = item.name, Inventory.Copy(item.metadata)
    if not Inventory.CanCarry(tInv, name, count, md) then return false, 'target_full' end

    -- Retrait puis ajout, sans attente ; échec de l'ajout → restauration.
    local removed = Inventory.RemoveItem(inv, name, count, nil, slot)
    if not removed then return false, 'item_not_found' end
    local added = Inventory.AddItem(tInv, name, count, md)
    if not added then
        Inventory.AddItem(inv, name, count, md, slot, true)
        return false, 'target_full'
    end

    local label = Items.Label(name)
    Bridge.Notify(src, L('gave_item', count, label), 'success')
    Bridge.Notify(target, L('received_item', count, label), 'success')
    debug('give %s -> %s %dx %s', src, target, count, name)
    return true
end)

Callback.Register('pop_inventory:use', function(src, slot)
    local inv, reason = playerInv(src)
    if not inv then return false, reason end
    slot = toInt(slot)
    if not slot or slot < 1 or slot > inv.slots then return false, 'error' end

    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < USE_COOLDOWN then return false, 'cooldown' end
    lastUse[src] = now

    if isBusy(src) or Bridge.IsDead(src) then return false, 'cannot_now' end

    local item = inv.items[slot]
    if not item then return false, 'item_not_found' end
    local name = item.name
    local def = Items.Get(name)
    if not def then return false, 'invalid_item' end

    local used = false

    if def.weapon then
        -- 1. Arme : équiper / ranger.
        local durability = tonumber(item.metadata.durability)
        if durability and durability <= 0 then return false, 'weapon_broken' end
        local eq = Equipped[src]
        local inHand = eq and eq.slot == slot and eq.name == name and eq.serial == item.metadata.serial
        if inHand then
            -- NOTE: après une mort, le client a rangé l'arme seul : si le ped ne la tient plus, on la rééquipe.
            local selected = selectedWeapon(src)
            if selected and selected ~= (joaat(name:upper()) & 0xFFFFFFFF) then inHand = false end
        end
        if inHand then
            holster(src)
        else
            pendingAmmo[src] = nil
            Equipped[src] = { slot = slot, name = name, serial = item.metadata.serial }
            TriggerClientEvent('pop_inventory:client:useWeapon', src, {
                slot = slot,
                name = name,
                ammo = math.max(0, math.floor(tonumber(item.metadata.ammo) or 0)),
                durability = durability or 100,
            })
        end
        used = true
    elseif Items.IsAmmo(name) then
        -- 2. Munitions : rechargement de l'arme en main.
        local ok, r = reload(src, inv)
        if not ok then return false, r end
        used = true
    elseif Usable[name] then
        -- 3. Callback enregistré par RegisterUsableItem.
        -- Consommation AVANT le cb (aucune attente entre la vérification et le retrait) : un cb qui attend ne peut pas
        -- être exploité en déplaçant l'item entre-temps. cb qui renvoie false ou plante → item rendu.
        local md = Inventory.Copy(item.metadata)
        local consumed = 0
        if def.consume > 0 then
            if item.count < def.consume or not Inventory.RemoveItem(inv, name, def.consume, nil, slot) then
                return false, 'item_not_found'
            end
            consumed = def.consume
        end
        local ok, res = pcall(Usable[name].cb, src, name, Inventory.Copy(md), slot)
        if not ok or res == false then
            if not ok then log('usable item "%s" error: %s', name, tostring(res)) end
            if consumed > 0 then
                local cur = Inventory.Get(src)
                if cur ~= inv or inv.closing or not Inventory.AddItem(inv, name, consumed, md, slot, true) then
                    log('usable item "%s": could not give back %d to %s', name, consumed, src)
                end
            end
            if not ok then return false, 'error' end
            -- NOTE: un cb qui renvoie false refuse l'utilisation : rien n'est consommé, pas d'event usedItem.
            return true, nil, false
        end
        used = true
    elseif FrameworkCompat and FrameworkCompat.UseItem and FrameworkCompat.UseItem(src, item) then
        -- 4. Items utilisables du framework.
        used = true
    end

    if not used then return false, 'item_not_usable' end
    TriggerEvent('pop_inventory:usedItem', src, name, slot, Inventory.Copy(item.metadata or {}))
    debug('use %s %s slot %d', src, name, slot)
    return true, nil, def.close
end)

Callback.Register('pop_inventory:reload', function(src)
    local inv, reason = playerInv(src)
    if not inv then return false, reason end
    if isBusy(src) or Bridge.IsDead(src) then return false, 'cannot_now' end
    return reload(src, inv)
end)

------------------------------------------------------------------------
-- Munitions et durabilité de l'arme en main (baisse uniquement)
------------------------------------------------------------------------

local function applyAmmo(src, ammo)
    local inv = Inventory.Get(src)
    local eq = Equipped[src]
    if not inv or inv.closing or not eq then return end
    local it = inv.items[eq.slot]
    if not it or it.name ~= eq.name or it.metadata.serial ~= eq.serial then return end
    local def = Items.Get(it.name)
    if not def or not def.ammo then return end

    local old = math.max(0, math.floor(tonumber(it.metadata.ammo) or 0))
    if ammo < 0 or ammo >= old then return end -- seulement en baisse

    local md = Inventory.Copy(it.metadata)
    md.ammo = ammo
    local durability = tonumber(md.durability) or 100
    durability = math.max(0, durability - (old - ammo) * def.degrade)
    md.durability = math.floor(durability * 100 + 0.5) / 100
    Inventory.SetMetadata(inv, eq.slot, md)
    if md.durability <= 0 then holster(src) end
end

-- Throttle : une valeur reçue pendant la fenêtre n'est pas jetée, la dernière est appliquée à la fin de la fenêtre.
RegisterNetEvent('pop_inventory:server:updateWeapon', function(ammo)
    local src = source
    ammo = toInt(ammo)
    if not ammo or ammo < 0 or not Equipped[src] then return end
    local now = GetGameTimer()
    local last = lastWeapon[src]
    if last and now - last < WEAPON_UPDATE_THROTTLE then
        pendingAmmo[src] = ammo
        if not ammoTimer[src] then
            ammoTimer[src] = true
            SetTimeout(WEAPON_UPDATE_THROTTLE - (now - last), function()
                ammoTimer[src] = nil
                local value = pendingAmmo[src]
                pendingAmmo[src] = nil
                if value == nil then return end
                lastWeapon[src] = GetGameTimer()
                applyAmmo(src, value)
            end)
        end
        return
    end
    lastWeapon[src] = now
    pendingAmmo[src] = nil
    applyAmmo(src, ammo)
end)

------------------------------------------------------------------------
-- Commande admin : /giveitem [id] [item] [count]
------------------------------------------------------------------------

local function reply(src, msg, kind)
    if src == 0 then print(msg) else Bridge.Notify(src, msg, kind) end
end

RegisterCommand('giveitem', function(src, args)
    if src ~= 0 and not Bridge.IsAdmin(src) then
        return Bridge.Notify(src, L('no_permission'), 'error')
    end
    local target = toInt(tonumber(args[1]))
    local name = type(args[2]) == 'string' and args[2]:lower() or nil
    local count = args[3] == nil and 1 or toInt(tonumber(args[3]))
    if not target or not name or not count or count < 1 or count > GIVEITEM_MAX then
        return reply(src, L('admin_usage'), 'error')
    end
    if not Items.Get(name) then return reply(src, L('invalid_item'), 'error') end
    local tInv = Bridge.GetPlayer(target) and Inventory.Get(target)
    if not tInv or tInv.closing then return reply(src, L('not_loaded'), 'error') end

    local ok, reason = Inventory.AddItem(tInv, name, count)
    if not ok then return reply(src, L(reason or 'error'), 'error') end

    reply(src, L('admin_given', count, Items.Label(name), target), 'success')
    Bridge.Notify(target, L('received_item', count, Items.Label(name)), 'success')
    log('%s gave %dx %s to %d', src == 0 and 'console' or (GetPlayerName(src) or tostring(src)), count, name, target)
end, false)

-- HOTBAR est documenté ici pour la cohérence avec le client (slots 1 à HOTBAR).
InvPlayers.HOTBAR = HOTBAR
