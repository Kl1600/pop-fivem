-- Bridge serveur : une seule API (table globale Bridge) pour ESX, QBCore, Qbox et standalone,
-- et pour les inventaires pop_inventory, ox_inventory, qs-inventory, qb-inventory, ps-inventory.
-- Ne modifiez pas ce fichier dans un script : corrigez-le dans templates/pop_base.

Bridge = {}

local RES = GetCurrentResourceName()

local function started(name)
    return GetResourceState(name) == 'started'
end

local function debug(msg, ...)
    if Config.Debug then print(('[%s] bridge: ' .. msg):format(RES, ...)) end
end

-- Montant entier strictement positif, sinon nil.
local function validAmount(n)
    n = tonumber(n)
    if not n or n ~= n or n <= 0 or n == math.huge then return nil end
    return math.floor(n)
end

------------------------------------------------------------------------
-- Détection
------------------------------------------------------------------------

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbox' end -- avant qb-core : Qbox fournit aussi 'qb-core'
    if started('es_extended') then return 'esx' end
    if started('qb-core') then return 'qbcore' end
    return 'standalone'
end

local function detectInventory()
    if Config.Inventory ~= 'auto' then return Config.Inventory end
    for _, name in ipairs({ 'pop_inventory', 'ox_inventory', 'qs-inventory', 'qb-inventory', 'ps-inventory' }) do
        if started(name) then return name end
    end
    return 'framework'
end

Bridge.Framework = detectFramework()
Bridge.Inventory = detectInventory()

------------------------------------------------------------------------
-- Frameworks
-- Chaque adaptateur fournit : player, identifier, name, job, getMoney, addMoney, removeMoney,
-- isAdminGroup, players, usable, et `items` (inventaire du framework).
------------------------------------------------------------------------

local FW

-- Format commun d'un job : { name, label, grade, gradeLabel, onDuty }.
local NEUTRAL_JOB = { name = 'unemployed', label = 'Unemployed', grade = 0, gradeLabel = '', onDuty = false }

local function copyJob(j)
    return { name = j.name, label = j.label, grade = j.grade, gradeLabel = j.gradeLabel, onDuty = j.onDuty }
end

if Bridge.Framework == 'esx' then
    local ESX
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        -- NOTE: ancien ESX (avant Legacy) : l'objet partagé n'est fourni que par cet event.
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end)
    end
    if not ESX then print(('[%s] bridge: ESX shared object not found'):format(RES)) end

    -- Comptes ESX : 'cash' passe par getMoney/addMoney/removeMoney (Legacy et ancien ESX).
    local ACCOUNTS = { bank = 'bank', black = 'black_money' }
    local ADMIN_GROUPS = { admin = true, superadmin = true, god = true }

    local function xp(src) return ESX and ESX.GetPlayerFromId(src) end

    FW = {
        player = xp,
        identifier = function(src) local p = xp(src) return p and p.identifier end,
        name = function(src)
            local p = xp(src)
            return p and (p.getName and p.getName() or p.name)
        end,
        job = function(src)
            local p = xp(src)
            local j = p and p.job
            if not j then return nil end
            -- NOTE: job.onDuty n'existe que dans les ESX Legacy récents ; absent = en service.
            return { name = j.name, label = j.label, grade = tonumber(j.grade) or 0, gradeLabel = j.grade_label or '', onDuty = j.onDuty ~= false }
        end,
        getMoney = function(src, account)
            local p = xp(src)
            if not p then return 0 end
            if account == 'cash' then return p.getMoney() or 0 end
            local acc = ACCOUNTS[account] and p.getAccount(ACCOUNTS[account])
            return acc and acc.money or 0
        end,
        addMoney = function(src, account, amount, reason)
            local p = xp(src)
            if not p then return false end
            if account == 'cash' then p.addMoney(amount, reason) return true end
            if not ACCOUNTS[account] then return false end
            p.addAccountMoney(ACCOUNTS[account], amount, reason)
            return true
        end,
        removeMoney = function(src, account, amount, reason)
            local p = xp(src)
            if not p then return false end
            if account == 'cash' then p.removeMoney(amount, reason) return true end
            if not ACCOUNTS[account] then return false end
            p.removeAccountMoney(ACCOUNTS[account], amount, reason)
            return true
        end,
        isAdminGroup = function(src)
            local p = xp(src)
            return p ~= nil and p.getGroup ~= nil and ADMIN_GROUPS[p.getGroup()] == true
        end,
        players = function()
            local list = {}
            if ESX.GetExtendedPlayers then
                for _, p in pairs(ESX.GetExtendedPlayers()) do list[#list + 1] = p.source end
            else
                for _, src in pairs(ESX.GetPlayers()) do list[#list + 1] = src end -- NOTE: ancien ESX
            end
            return list
        end,
        usable = function(item, cb)
            ESX.RegisterUsableItem(item, function(src, _, data)
                cb(src, item, type(data) == 'table' and data.metadata or nil)
            end)
            return true
        end,
        items = {
            count = function(src, item)
                local p = xp(src)
                local it = p and p.getInventoryItem(item)
                return it and (it.count or it.amount) or 0
            end,
            add = function(src, item, count, metadata)
                local p = xp(src)
                if not p then return false end
                p.addInventoryItem(item, count, metadata)
                return true
            end,
            remove = function(src, item, count, metadata)
                local p = xp(src)
                if not p then return false end
                p.removeInventoryItem(item, count, metadata)
                return true
            end,
            canCarry = function(src, item, count)
                local p = xp(src)
                if not p then return false end
                if p.canCarryItem then return p.canCarryItem(item, count) == true end
                -- NOTE: ancien ESX : limite par item (-1 = illimité).
                local it = p.getInventoryItem(item)
                if not it then return false end
                return it.limit == nil or it.limit == -1 or (it.count + count) <= it.limit
            end,
        },
    }
elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
    local isQbox = Bridge.Framework == 'qbox'
    local QBCore = not isQbox and exports['qb-core']:GetCoreObject() or nil

    local function qp(src)
        if isQbox then return exports.qbx_core:GetPlayer(src) end
        return QBCore.Functions.GetPlayer(src)
    end

    -- NOTE: QBCore/Qbox n'ont pas d'argent sale par défaut (souvent l'item 'markedbills').
    -- 'black' utilise le compte 'black_money' s'il existe dans PlayerData.money, sinon 0 / false.
    local ACCOUNTS = { cash = 'cash', bank = 'bank', black = 'black_money' }

    local function account(p, name)
        local acc = ACCOUNTS[name]
        if acc and p.PlayerData.money[acc] ~= nil then return acc end
        return nil
    end

    FW = {
        player = qp,
        identifier = function(src) local p = qp(src) return p and p.PlayerData.citizenid end,
        name = function(src)
            local p = qp(src)
            local c = p and p.PlayerData.charinfo
            return c and ('%s %s'):format(c.firstname, c.lastname) or nil
        end,
        job = function(src)
            local p = qp(src)
            local j = p and p.PlayerData.job
            if not j then return nil end
            local g = type(j.grade) == 'table' and j.grade or { level = j.grade }
            return { name = j.name, label = j.label, grade = tonumber(g.level) or 0, gradeLabel = g.name or '', onDuty = j.onduty == true }
        end,
        getMoney = function(src, name)
            local p = qp(src)
            local acc = p and account(p, name)
            return acc and p.PlayerData.money[acc] or 0
        end,
        addMoney = function(src, name, amount, reason)
            local p = qp(src)
            local acc = p and account(p, name)
            return acc ~= nil and p.Functions.AddMoney(acc, amount, reason) ~= false
        end,
        removeMoney = function(src, name, amount, reason)
            local p = qp(src)
            local acc = p and account(p, name)
            return acc ~= nil and p.Functions.RemoveMoney(acc, amount, reason) ~= false
        end,
        isAdminGroup = function(src)
            if isQbox then
                -- NOTE: Qbox gère les groupes par ACE (group.admin).
                return IsPlayerAceAllowed(src, 'group.admin')
            end
            local ok, res = pcall(function()
                return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
            end)
            return ok and res == true
        end,
        players = function()
            local list = {}
            if isQbox then
                for src in pairs(exports.qbx_core:GetQBPlayers()) do list[#list + 1] = src end
            else
                for _, src in pairs(QBCore.Functions.GetPlayers()) do list[#list + 1] = src end
            end
            return list
        end,
        usable = function(item, cb)
            local wrap = function(src, data)
                cb(src, item, type(data) == 'table' and (data.info or data.metadata) or nil)
            end
            if isQbox then
                -- NOTE: Qbox délègue les items utilisables à ox_inventory ; cet export de compatibilité peut disparaître.
                return (pcall(function() exports.qbx_core:CreateUseableItem(item, wrap) end))
            end
            QBCore.Functions.CreateUseableItem(item, wrap)
            return true
        end,
        items = {
            -- PlayerData.items existe dans toutes les versions de QBCore (et Qbox via ox_inventory).
            count = function(src, item)
                local p = qp(src)
                if not p then return 0 end
                local total = 0
                for _, it in pairs(p.PlayerData.items or {}) do
                    if it and it.name == item then total = total + (it.amount or it.count or 0) end
                end
                return total
            end,
            add = function(src, item, count, metadata)
                local p = qp(src)
                return p ~= nil and p.Functions.AddItem(item, count, nil, metadata) == true
            end,
            remove = function(src, item, count)
                local p = qp(src)
                return p ~= nil and p.Functions.RemoveItem(item, count) == true
            end,
            -- NOTE: l'inventaire QBCore historique n'expose pas de test de poids ; AddItem renvoie false si plein.
            canCarry = function() return true end,
        },
    }
else
    -- Standalone : aucune donnée de personnage. Valeurs neutres :
    -- argent = 0, AddMoney/RemoveMoney = false, job = 'unemployed' grade 0 hors service.
    FW = {
        player = function(src) return GetPlayerName(src) and { source = src } or nil end,
        identifier = function(src)
            local ok, id = pcall(GetPlayerIdentifierByType, src, 'license')
            if ok and id then return id end
            for _, v in ipairs(GetPlayerIdentifiers(src)) do
                if v:sub(1, 8) == 'license:' then return v end
            end
            return nil
        end,
        name = function(src) return GetPlayerName(src) end,
        job = function(src) return GetPlayerName(src) and copyJob(NEUTRAL_JOB) or nil end,
        getMoney = function() return 0 end,
        addMoney = function() return false end,
        removeMoney = function() return false end,
        isAdminGroup = function() return false end,
        players = function()
            local list = {}
            for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
            return list
        end,
        usable = function() return false end,
        items = {
            count = function() return 0 end,
            add = function() return false end,
            remove = function() return false end,
            canCarry = function() return false end,
        },
    }
end

------------------------------------------------------------------------
-- Inventaires externes (sinon FW.items)
-- Chaque adaptateur : count, add, remove, canCarry, et usable (optionnel).
------------------------------------------------------------------------

-- Appelle fn protégé ; renvoie (true, résultat) ou (false).
local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return true, res end
    return false
end

local INVENTORIES = {
    -- NOTE: API attendue de pop_inventory (à aligner quand il sera écrit) : mêmes noms qu'ox_inventory
    -- + RegisterUsableItem(item, cb(source, item, metadata)).
    pop_inventory = {
        count = function(src, item) return exports.pop_inventory:GetItemCount(src, item) or 0 end,
        add = function(src, item, count, metadata) return exports.pop_inventory:AddItem(src, item, count, metadata) == true end,
        remove = function(src, item, count, metadata) return exports.pop_inventory:RemoveItem(src, item, count, metadata) == true end,
        canCarry = function(src, item, count) return exports.pop_inventory:CanCarryItem(src, item, count) == true end,
        usable = function(item, cb) exports.pop_inventory:RegisterUsableItem(item, cb) return true end,
    },
    ox_inventory = {
        count = function(src, item, metadata) return exports.ox_inventory:GetItemCount(src, item, metadata) or 0 end,
        add = function(src, item, count, metadata) return exports.ox_inventory:AddItem(src, item, count, metadata) == true end,
        remove = function(src, item, count, metadata) return exports.ox_inventory:RemoveItem(src, item, count, metadata) == true end,
        canCarry = function(src, item, count) return exports.ox_inventory:CanCarryItem(src, item, count) == true end,
        -- Avec ESX/QBCore/Qbox, ox_inventory reprend les items utilisables du framework (voir FW.usable).
        -- NOTE: en standalone, l'item doit être déclaré dans ox_inventory avec
        -- server = { export = '<ressource>.<item>' } pour que cet export soit appelé.
        usable = Bridge.Framework == 'standalone' and function(item, cb)
            exports(item, function(event, _, inventory, slot)
                if event == 'usingItem' then
                    local data = exports.ox_inventory:GetSlot(inventory.id, slot)
                    cb(inventory.id, item, data and data.metadata)
                end
            end)
            return true
        end or nil,
    },
    ['qs-inventory'] = {
        count = function(src, item) return exports['qs-inventory']:GetItemTotalAmount(src, item) or 0 end,
        add = function(src, item, count, metadata) return exports['qs-inventory']:AddItem(src, item, count, nil, metadata) == true end,
        remove = function(src, item, count) return exports['qs-inventory']:RemoveItem(src, item, count) == true end,
        canCarry = function(src, item, count) return exports['qs-inventory']:CanCarryItem(src, item, count) == true end,
        usable = function(item, cb)
            exports['qs-inventory']:CreateUsableItem(item, function(src, data)
                cb(src, item, type(data) == 'table' and data.info or nil)
            end)
            return true
        end,
    },
    -- qb-inventory v2 expose des exports ; les anciennes versions passent par les fonctions du joueur QBCore.
    ['qb-inventory'] = {
        count = function(src, item)
            local ok, n = try(function() return exports['qb-inventory']:GetItemCount(src, item) end)
            if ok and type(n) == 'number' then return n end
            return FW.items.count(src, item)
        end,
        add = function(src, item, count, metadata)
            local ok, res = try(function() return exports['qb-inventory']:AddItem(src, item, count, false, metadata, RES) end)
            if ok then return res == true end
            return FW.items.add(src, item, count, metadata)
        end,
        remove = function(src, item, count)
            local ok, res = try(function() return exports['qb-inventory']:RemoveItem(src, item, count, false, RES) end)
            if ok then return res == true end
            return FW.items.remove(src, item, count)
        end,
        canCarry = function(src, item, count)
            local ok, res = try(function() return exports['qb-inventory']:CanAddItem(src, item, count) end)
            if ok then return res == true end
            return FW.items.canCarry(src, item, count)
        end,
    },
    -- NOTE: ps-inventory (fork de l'ancien qb-inventory) est piloté par les fonctions du joueur QBCore.
    ['ps-inventory'] = 'framework',
    framework = 'framework',
    none = {
        count = function() return 0 end,
        add = function() return false end,
        remove = function() return false end,
        canCarry = function() return false end,
    },
}

local Inv = INVENTORIES[Bridge.Inventory]
if Inv == nil then
    print(('[%s] bridge: unknown Config.Inventory "%s", using framework inventory'):format(RES, Bridge.Inventory))
    Inv = 'framework'
end
if Inv == 'framework' then Inv = FW.items end

debug('framework=%s inventory=%s', Bridge.Framework, Bridge.Inventory)

------------------------------------------------------------------------
-- API joueur
------------------------------------------------------------------------

--- Objet joueur brut du framework (xPlayer, Player QBCore/Qbox, ou { source } en standalone).
function Bridge.GetPlayer(src)
    return FW.player(tonumber(src))
end

--- Identifiant persistant : identifier ESX, citizenid QBCore/Qbox, license en standalone.
function Bridge.GetIdentifier(src)
    return FW.identifier(tonumber(src))
end

--- Nom du personnage (nom Cfx en standalone).
function Bridge.GetName(src)
    return FW.name(tonumber(src))
end

--- { name, label, grade, gradeLabel, onDuty } ou nil si le joueur n'est pas chargé.
function Bridge.GetJob(src)
    return FW.job(tonumber(src))
end

--- jobs : 'police' | { 'police', 'sheriff' } | { police = 2, sheriff = 0 } (grade minimum).
function Bridge.HasJob(src, jobs)
    local job = Bridge.GetJob(src)
    if not job then return false end
    if type(jobs) == 'string' then return job.name == jobs end
    if type(jobs) ~= 'table' then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' and v == job.name then return true end
        if k == job.name then return job.grade >= (tonumber(v) or 0) end
    end
    return false
end

------------------------------------------------------------------------
-- Argent : account = 'cash' | 'bank' | 'black'
------------------------------------------------------------------------

function Bridge.GetMoney(src, account)
    local ok, n = try(FW.getMoney, tonumber(src), account or 'cash')
    return ok and tonumber(n) or 0
end

function Bridge.AddMoney(src, account, amount, reason)
    amount = validAmount(amount)
    if not amount then return false end
    local ok, res = try(FW.addMoney, tonumber(src), account or 'cash', amount, reason or RES)
    if ok and res then debug('AddMoney %s %s %d', src, account, amount) end
    return ok and res == true
end

--- Retire l'argent seulement si le solde suffit. Renvoie true si retiré.
function Bridge.RemoveMoney(src, account, amount, reason)
    amount = validAmount(amount)
    if not amount then return false end
    account = account or 'cash'
    if Bridge.GetMoney(src, account) < amount then return false end
    local ok, res = try(FW.removeMoney, tonumber(src), account, amount, reason or RES)
    if ok and res then debug('RemoveMoney %s %s %d', src, account, amount) end
    return ok and res == true
end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------

function Bridge.GetItemCount(src, item)
    local ok, n = try(Inv.count, tonumber(src), item)
    return ok and tonumber(n) or 0
end

function Bridge.HasItem(src, item, count)
    count = count == nil and 1 or validAmount(count)
    return count ~= nil and Bridge.GetItemCount(src, item) >= count
end

function Bridge.CanCarry(src, item, count)
    count = count == nil and 1 or validAmount(count)
    if not count then return false end
    local ok, res = try(Inv.canCarry, tonumber(src), item, count)
    return ok and res == true
end

function Bridge.AddItem(src, item, count, metadata)
    count = count == nil and 1 or validAmount(count)
    if not count then return false end
    src = tonumber(src)
    if not Bridge.CanCarry(src, item, count) then return false end
    local ok, res = try(Inv.add, src, item, count, metadata)
    if ok and res then debug('AddItem %s %s x%d', src, item, count) end
    return ok and res == true
end

--- Retire l'item seulement si le joueur en possède assez. Renvoie true si retiré.
function Bridge.RemoveItem(src, item, count, metadata)
    count = count == nil and 1 or validAmount(count)
    if not count then return false end
    src = tonumber(src)
    if Bridge.GetItemCount(src, item) < count then return false end
    local ok, res = try(Inv.remove, src, item, count, metadata)
    if ok and res then debug('RemoveItem %s %s x%d', src, item, count) end
    return ok and res == true
end

--- cb(source, item, metadata) quand un joueur utilise l'item. Renvoie true si enregistré.
function Bridge.RegisterUsableItem(item, cb)
    local register = Inv.usable or FW.usable
    local ok, res = try(register, item, cb)
    if not ok or not res then
        print(('[%s] bridge: cannot register usable item "%s" (%s / %s)'):format(RES, item, Bridge.Framework, Bridge.Inventory))
        return false
    end
    return true
end

------------------------------------------------------------------------
-- Divers
------------------------------------------------------------------------

--- Notification côté joueur (passe par Bridge.Notify du client). type : 'info' | 'success' | 'error' | 'warning'.
function Bridge.Notify(src, msg, notifyType, duration)
    TriggerClientEvent(RES .. ':bridge:notify', src, msg, notifyType, duration)
end

--- ACE 'pop.admin' ou groupe admin du framework.
function Bridge.IsAdmin(src)
    src = tonumber(src)
    if not src then return false end
    if IsPlayerAceAllowed(src, 'pop.admin') then return true end
    local ok, res = try(FW.isAdminGroup, src)
    return ok and res == true
end

--- Liste des sources des joueurs chargés (personnage sélectionné).
function Bridge.GetPlayers()
    local ok, list = try(FW.players)
    return ok and list or {}
end

--- Position serveur du joueur (vector3) ou nil.
function Bridge.GetCoords(src)
    local ped = GetPlayerPed(tonumber(src) or -1)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- Vrai si le joueur est à moins de maxDist mètres de coords (vector3 ou table {x, y, z}).
function Bridge.IsNear(src, coords, maxDist)
    local pos = Bridge.GetCoords(src)
    if not pos or not coords then return false end
    return #(pos - vector3(coords.x, coords.y, coords.z)) <= (tonumber(maxDist) or 0)
end

------------------------------------------------------------------------
-- Évènements unifiés (locaux à la ressource)
--   <ressource>:playerLoaded (src)   <ressource>:playerDropped (src)
------------------------------------------------------------------------

local EV_LOADED = RES .. ':playerLoaded'
local EV_DROPPED = RES .. ':playerDropped'

function Bridge.OnPlayerLoaded(cb) return AddEventHandler(EV_LOADED, cb) end
function Bridge.OnPlayerDropped(cb) return AddEventHandler(EV_DROPPED, cb) end

if Bridge.Framework == 'esx' then
    AddEventHandler('esx:playerLoaded', function(playerId) TriggerEvent(EV_LOADED, tonumber(playerId)) end)
elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
    AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
        TriggerEvent(EV_LOADED, player.PlayerData.source)
    end)
else
    AddEventHandler('playerJoining', function() TriggerEvent(EV_LOADED, source) end)
end

-- NOTE: selon l'ordre des handlers, le framework peut avoir déjà déchargé le joueur ici.
AddEventHandler('playerDropped', function() TriggerEvent(EV_DROPPED, source) end)

-- Au (re)démarrage de la ressource, les joueurs déjà connectés reçoivent playerLoaded.
AddEventHandler('onResourceStart', function(res)
    if res ~= RES then return end
    for _, src in ipairs(Bridge.GetPlayers()) do TriggerEvent(EV_LOADED, src) end
end)
