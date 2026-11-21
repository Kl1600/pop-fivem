-- Compatibilité framework : surcharges ESX / QBCore pour les scripts tiers, miroir PlayerData.items,
-- items utilisables du framework (repli de l'utilisation).
-- NOTE: API des frameworks à vérifier en jeu selon les versions ; tout est protégé par pcall.

FrameworkCompat = FrameworkCompat or {}

local RES = GetCurrentResourceName()

local ESX, QBCore
local warned = {}
local mirrorPending = {} -- [src] = true : miroir QBCore programmé

local MIRROR_DELAY = 250 -- ms : regroupe les mises à jour de PlayerData.items

local function warnOnce(key, msg, ...)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s] warning: ' .. msg .. '^7'):format(RES, ...))
end

if Bridge.Framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end) -- NOTE: ancien ESX
    end
elseif Bridge.Framework == 'qbcore' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = obj end
end

------------------------------------------------------------------------
-- Formats
------------------------------------------------------------------------

-- Item au format QBCore (info = metadata).
local function toQb(it)
    local def = Items.Get(it.name)
    if not def then return nil end
    return {
        name = it.name,
        amount = it.count,
        count = it.count,
        info = Inventory.Copy(it.metadata),
        label = Items.Label(it.name),
        slot = it.slot,
        weight = def.weight,
        type = def.weapon and 'weapon' or 'item',
        unique = not def.stack,
        useable = true,
        image = (def.image or it.name) .. '.png',
        shouldClose = def.close,
        description = Items.Description(it.name) or '',
    }
end

-- Item au format ESX (agrégé par nom).
local function toEsx(inv, name)
    local def = Items.Get(name)
    if not def then return nil end
    return {
        name = def.name,
        label = Items.Label(def.name),
        count = Inventory.GetItemCount(inv, def.name),
        weight = def.weight / 1000, -- NOTE: ESX exprime les poids en kg
        usable = ESX ~= nil and ESX.GetUsableItems ~= nil and ESX.GetUsableItems()[def.name] ~= nil or false,
        rare = false,
        canRemove = true,
    }
end

------------------------------------------------------------------------
-- ESX Legacy : surcharges des méthodes de xPlayer
------------------------------------------------------------------------

local function registerEsxOverrides()
    if not ESX then return warnOnce('esx', 'ESX shared object not found, framework hooks disabled') end
    if not ESX.RegisterPlayerFunctionOverrides or not ESX.SetPlayerFunctionOverride then
        return warnOnce('esx_old', 'this ESX version has no player function overrides: third-party scripts using xPlayer inventory functions will not see pop_inventory items (use exports or the Bridge)')
    end

    local function invOf(self) return Inventory.Get(tonumber(self.source)) end

    local overrides = {
        getInventory = function(self)
            return function(minimal)
                local inv = invOf(self)
                if not inv then return {} end
                local seen, out = {}, {}
                for _, it in pairs(inv.items) do
                    if not seen[it.name] then
                        seen[it.name] = true
                        if minimal then
                            out[it.name] = Inventory.GetItemCount(inv, it.name)
                        else
                            out[#out + 1] = toEsx(inv, it.name)
                        end
                    end
                end
                return out
            end
        end,
        getInventoryItem = function(self)
            return function(name)
                local inv = invOf(self)
                if not inv then return nil end
                return toEsx(inv, name)
            end
        end,
        addInventoryItem = function(self)
            return function(name, count, metadata)
                local inv = invOf(self)
                local md = Inventory.NormalizeMetadata(metadata)
                if inv and md then Inventory.AddItem(inv, name, count, md) end
            end
        end,
        removeInventoryItem = function(self)
            return function(name, count, metadata)
                local inv = invOf(self)
                if inv then Inventory.RemoveItem(inv, name, count, type(metadata) == 'table' and metadata or nil) end
            end
        end,
        setInventoryItem = function(self)
            return function(name, count)
                local inv = invOf(self)
                count = Inventory.ToInt(count)
                if not inv or not count or count < 0 or not Items.Get(name) then return end
                local current = Inventory.GetItemCount(inv, name)
                if count > current then
                    Inventory.AddItem(inv, name, count - current)
                elseif count < current then
                    Inventory.RemoveItem(inv, name, current - count)
                end
            end
        end,
        canCarryItem = function(self)
            return function(name, count)
                local inv = invOf(self)
                return inv ~= nil and Inventory.CanCarry(inv, name, count or 1)
            end
        end,
        canSwapItem = function()
            return function() return false end
        end,
        hasItem = function(self)
            return function(name)
                local inv = invOf(self)
                if not inv then return false end
                local item = toEsx(inv, name)
                if not item or item.count <= 0 then return false end
                return item, item.count
            end
        end,
        getWeight = function(self)
            return function()
                local inv = invOf(self)
                return inv and inv.weight / 1000 or 0
            end
        end,
        getMaxWeight = function(self)
            return function()
                local inv = invOf(self)
                return (inv and inv.maxWeight or Config.MaxWeight) / 1000
            end
        end,
    }

    local ok, err = pcall(function()
        ESX.RegisterPlayerFunctionOverrides(RES, overrides)
        ESX.SetPlayerFunctionOverride(RES)
    end)
    if not ok then warnOnce('esx_fail', 'ESX overrides failed: %s', tostring(err)) end
end

------------------------------------------------------------------------
-- QBCore : méthodes du joueur + miroir PlayerData.items
------------------------------------------------------------------------

local function qbPlayer(src)
    if Bridge.Framework ~= 'qbcore' and Bridge.Framework ~= 'qbox' then return nil end
    local ok, p = pcall(Bridge.GetPlayer, src)
    return ok and p or nil
end

local function itemsQb(inv)
    local out = {}
    for s, it in pairs(inv.items) do out[s] = toQb(it) end
    return out
end

local function addQbMethods(src)
    if not QBCore or not QBCore.Functions or not QBCore.Functions.AddPlayerMethod then
        return warnOnce('qb_methods', 'QBCore.Functions.AddPlayerMethod not found: Player.Functions inventory methods are not redirected')
    end
    local function inv() return Inventory.Get(src) end
    local methods = {
        AddItem = function(item, amount, slot, info)
            local i = inv()
            local md = Inventory.NormalizeMetadata(info)
            if not i or not md then return false end
            return (Inventory.AddItem(i, item, amount or 1, md, slot))
        end,
        RemoveItem = function(item, amount, slot)
            local i = inv()
            if not i then return false end
            return (Inventory.RemoveItem(i, item, amount or 1, nil, slot or nil))
        end,
        GetItemByName = function(item)
            local i = inv()
            local found = i and Inventory.FindSlots(i, item)[1]
            return found and toQb(found) or nil
        end,
        GetItemsByName = function(item)
            local out = {}
            local i = inv()
            if not i then return out end
            for _, it in ipairs(Inventory.FindSlots(i, item)) do out[#out + 1] = toQb(it) end
            return out
        end,
        GetItemBySlot = function(slot)
            local i = inv()
            local it = i and i.items[Inventory.ToInt(slot) or -1]
            return it and toQb(it) or nil
        end,
        ClearInventory = function()
            local i = inv()
            if i then Inventory.Clear(i) end
        end,
    }
    local ok, err = pcall(function()
        for name, fn in pairs(methods) do QBCore.Functions.AddPlayerMethod(src, name, fn) end
    end)
    if not ok then warnOnce('qb_methods_fail', 'QBCore AddPlayerMethod failed: %s', tostring(err)) end
end

local function flushMirror(src)
    mirrorPending[src] = nil
    local inv = Inventory.Get(src)
    local p = qbPlayer(src)
    if not inv or not p then return end
    local ok, err = pcall(function() p.Functions.SetPlayerData('items', itemsQb(inv)) end)
    if not ok then warnOnce('qb_mirror', 'PlayerData.items mirror failed: %s', tostring(err)) end
end

------------------------------------------------------------------------
-- API interne
------------------------------------------------------------------------

--- Après le chargement de l'inventaire d'un joueur.
function FrameworkCompat.OnPlayerLoaded(src)
    if not Config.FrameworkHooks then return end
    if Bridge.Framework == 'qbcore' then addQbMethods(src) end
    FrameworkCompat.Mirror(src)
end

--- Programme la mise à jour de PlayerData.items (QBCore / Qbox), au plus une fois / MIRROR_DELAY.
-- NOTE: appliqué aussi à Qbox pour garder PlayerData.items juste (sans effet si la fonction n'existe pas).
function FrameworkCompat.Mirror(src)
    if not Config.FrameworkHooks or mirrorPending[src] then return end
    if Bridge.Framework ~= 'qbcore' and Bridge.Framework ~= 'qbox' then return end
    mirrorPending[src] = true
    SetTimeout(MIRROR_DELAY, function() flushMirror(src) end)
end

function FrameworkCompat.Cleanup(src)
    mirrorPending[src] = nil
end

--- Repli de l'utilisation : items utilisables du framework. Renvoie true si un callback a été appelé.
function FrameworkCompat.UseItem(src, item)
    if Bridge.Framework == 'esx' and ESX then
        local ok, used = pcall(function()
            local usable = ESX.GetUsableItems and ESX.GetUsableItems() or nil
            if not usable or not usable[item.name] then return false end
            ESX.UseItem(src, item.name, { metadata = Inventory.Copy(item.metadata), slot = item.slot })
            return true
        end)
        return ok and used == true
    elseif Bridge.Framework == 'qbcore' and QBCore then
        local ok, used = pcall(function()
            if not QBCore.Functions.CanUseItem(item.name) then return false end
            QBCore.Functions.UseItem(src, toQb(item))
            return true
        end)
        return ok and used == true
    elseif Bridge.Framework == 'qbox' then
        -- NOTE: Qbox délègue normalement les items utilisables à ox_inventory (remplacé ici via `provide`).
        -- Repli : items créés par exports.qbx_core:CreateUseableItem, lus via CanUseItem (API à vérifier selon la version).
        local ok, used = pcall(function()
            local usable = exports.qbx_core:CanUseItem(item.name)
            local fn = usable
            if type(usable) == 'table' and not (getmetatable(usable) or {}).__call then
                fn = usable.cb or usable.func or usable.callback
            end
            local callable = type(fn) == 'function' or (type(fn) == 'table' and (getmetatable(fn) or {}).__call ~= nil)
            if not callable then return false end
            fn(src, toQb(item))
            return true
        end)
        if not ok then warnOnce('qbox_usable', 'Qbox usable items fallback failed: %s', tostring(used)) end
        return ok and used == true
    end
    return false
end

-- Enregistrement des surcharges ESX au démarrage.
if Config.FrameworkHooks and Bridge.Framework == 'esx' then
    registerEsxOverrides()
end

-- ESX Legacy : sans Config.CustomInventory, es_extended gère (et sauvegarde) aussi son propre inventaire.
-- NOTE: champ présent sur ESX Legacy récent ; absent (ancien ESX) → aucun avertissement.
if Bridge.Framework == 'esx' then
    CreateThread(function()
        Wait(1000) -- ancien ESX : objet partagé reçu par event
        if not ESX or not ESX.GetConfig then return end
        local ok, cfg = pcall(ESX.GetConfig)
        if ok and type(cfg) == 'table' and not cfg.CustomInventory then
            print(('^1[%s] WARNING: es_extended Config.CustomInventory is false. ESX keeps loading and saving its own inventory next to pop_inventory. Set Config.CustomInventory = true in es_extended (see README).^7'):format(RES))
        end
    end)
end
