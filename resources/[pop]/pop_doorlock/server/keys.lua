-- pop_doorlock : clés de porte (item Config.KeyItem avec la metadata pop_door = clé du groupe).
-- Le test dépend de l'inventaire : seuls ceux qui gèrent la metadata des items sont pris en charge.

local Doorlock = Doorlock

local KEY_CHARS  = 'abcdefghijklmnopqrstuvwxyz0123456789'
local KEY_LENGTH = 8  -- longueur de key_id
local KEY_TRIES  = 20 -- tentatives en cas de collision

local isQb = Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox'

-- Cherche une clé du groupe dans une liste d'items (format QBCore / qs-inventory : info ou metadata).
local function findKey(items, keyId)
    if type(items) ~= 'table' then return false end
    for _, it in pairs(items) do
        if type(it) == 'table' and it.name == Config.KeyItem then
            local info = it.info or it.metadata
            if type(info) == 'table' and info.pop_door == keyId then return true end
        end
    end
    return false
end

local function qbItems(src, keyId)
    local p = Bridge.GetPlayer(src)
    return type(p) == 'table' and type(p.PlayerData) == 'table' and findKey(p.PlayerData.items, keyId)
end

-- Test de possession par inventaire. Absent = clés non gérées.
local CHECKS = {
    ox_inventory = function(src, keyId)
        return (exports.ox_inventory:Search(src, 'count', Config.KeyItem, { pop_door = keyId }) or 0) > 0
    end,
    ['qs-inventory'] = function(src, keyId)
        return findKey(exports['qs-inventory']:GetInventory(src), keyId)
    end,
    -- NOTE: même signature qu'ox_inventory (GetItemCount avec filtre de metadata), à confirmer quand pop_inventory sera écrit.
    pop_inventory = function(src, keyId)
        return (exports.pop_inventory:GetItemCount(src, Config.KeyItem, { pop_door = keyId }) or 0) > 0
    end,
    ['qb-inventory'] = isQb and qbItems or nil,
    ['ps-inventory'] = isQb and qbItems or nil,
    framework = isQb and qbItems or nil, -- inventaire ESX de base et standalone : pas de metadata fiable
}

local check = CHECKS[Bridge.Inventory]

--- Vrai si l'inventaire détecté permet de distinguer les clés par metadata.
function Doorlock.KeysSupported()
    return check ~= nil
end

--- Vrai si le joueur possède une clé valide (keyId courant) pour ce groupe.
function Doorlock.HasDoorKey(src, keyId)
    if not check or type(keyId) ~= 'string' then return false end
    local ok, res = pcall(check, tonumber(src), keyId)
    if not ok then
        Doorlock.Debug('key check failed (%s): %s', Bridge.Inventory, tostring(res))
        return false
    end
    return res == true
end

--- Donne une clé du groupe. Renvoie true, ou false + clé de locale.
function Doorlock.GiveKey(src, group)
    if not group or not group.keyId then return false, 'editor_no_key' end
    if not check then return false, 'editor_key_unsupported' end
    -- NOTE: la description est écrite dans la langue du serveur (Config.Locale), elle reste dans la metadata.
    local metadata = { pop_door = group.keyId, description = L('key_description', group.label) }
    local ok, res = pcall(Bridge.AddItem, src, Config.KeyItem, 1, metadata)
    if not ok or res ~= true then return false, 'inventory_full' end
    return true
end

--- Nouvelle clé de groupe : 8 caractères [a-z0-9], unique dans le cache (qui reflète la base). nil si échec.
function Doorlock.NewKeyId()
    for _ = 1, KEY_TRIES do
        local chars = {}
        for i = 1, KEY_LENGTH do
            local n = math.random(1, #KEY_CHARS)
            chars[i] = KEY_CHARS:sub(n, n)
        end
        local key = table.concat(chars)
        local used = false
        for _, g in pairs(Doorlock.groups) do
            if g.keyId == key then used = true break end
        end
        if not used then return key end
    end
    return nil
end

--- Appelé par main.lua après le chargement : avertit si des groupes ont une clé inutilisable.
function Doorlock.CheckKeySupport()
    if check then return end
    for _, g in pairs(Doorlock.groups) do
        if g.keyId then
            Doorlock.Log('warning: inventory "%s" (%s) does not support item metadata, door keys will not work',
                Bridge.Inventory, Bridge.Framework)
            return
        end
    end
end
