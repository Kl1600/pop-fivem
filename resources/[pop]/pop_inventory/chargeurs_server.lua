-- =====================================================
--  Module CHARGEURS (ex tab_chargeurs) — SERVER (autoritaire sur les balles)
--  lib.callback remplacé par ESX.RegisterServerCallback. Export onUseAmmo réémis
--  sur pop_inventory (les items munitions_* pointent sur 'pop_inventory:onUseAmmo').
-- =====================================================
local ESX = exports['es_extended']:getSharedObject()

local WeaponByHash  = {}
local WeaponByDefId = {}
local MagItemByCat  = {}
local AmmoBoxCat    = {}

CreateThread(function()
    for defId, w in pairs(ChargeursConfig.Weapons or {}) do
        local data = {
            defId = defId, weaponHash = w.weaponHash, hash = GetHashKey(w.weaponHash),
            category = w.category, magItem = w.magItem, capacity = w.capacity,
        }
        WeaponByHash[data.hash] = data
        WeaponByDefId[defId] = data
        MagItemByCat[w.category] = { magItem = w.magItem, capacity = w.capacity }
    end
    for boxDef, cat in pairs(ChargeursConfig.AmmoBoxes or {}) do
        AmmoBoxCat[boxDef] = cat
    end
end)

local NOTIF_ICONS = {
    success = 'fas fa-circle-check',
    error   = 'fas fa-triangle-exclamation',
    info    = 'fas fa-bullseye',
}

local function notify(target, message, ntype)
    TriggerClientEvent('notification:client:ShowNotify', target, {
        title = 'Armement',
        message = message,
        icon = NOTIF_ICONS[ntype or 'info'] or NOTIF_ICONS.info,
        duration = 5000,
    })
end

local function magLabelFor(category, rounds, capacity)
    local catLabel = ChargeursConfig.CategoryLabels[category] or category
    local suffix = (rounds <= 0) and ' (vide)' or ''
    return ('Chargeur %s %d/%d%s'):format(catLabel, rounds, capacity, suffix)
end

local function findMagazineForHash(src, hash)
    local wdata = WeaponByHash[hash]
    if not wdata then return nil, nil, nil, false end

    local store = exports.pop_inventory:getStore(src)
    if not store or not store.equipment then return nil, nil, wdata, false end

    for _, itemId in pairs(store.equipment) do
        local item = store.items and store.items[itemId]
        if item and item.defId == wdata.defId then
            if not item.containerId then
                return nil, nil, wdata, false
            end
            local cont = store.containers and store.containers[item.containerId]
            if cont and cont.items then
                for _, magId in pairs(cont.items) do
                    local mag = store.items[magId]
                    if mag and mag.defId == wdata.magItem then
                        return magId, mag, wdata, true
                    end
                end
            end
            return nil, nil, wdata, true
        end
    end
    return nil, nil, wdata, false
end

local function getRounds(src, magId, mag, wdata)
    local cap = wdata.capacity
    local rounds = mag.meta and mag.meta.rounds
    if rounds == nil then
        rounds = cap
        local meta = mag.meta or {}
        meta.rounds = rounds
        meta.capacity = cap
        meta.customLabel = magLabelFor(wdata.category, rounds, cap)
        exports.pop_inventory:UpdateItemMetadata(src, magId, meta)
    end
    return rounds
end

ESX.RegisterServerCallback('tab_chargeurs:getRounds', function(src, cb, hash)
    hash = tonumber(hash)
    if not hash then return cb(-1) end
    local magId, mag, wdata, hasContainer = findMagazineForHash(src, hash)
    if not hasContainer then return cb(-1) end
    if not magId or not mag then return cb(0) end
    cb(getRounds(src, magId, mag, wdata))
end)

RegisterNetEvent('tab_chargeurs:server:consumed', function(hash, count)
    local src = source
    hash = tonumber(hash)
    count = tonumber(count)
    if not hash or not count or count <= 0 then return end
    count = math.min(count, ChargeursConfig.MaxConsumePerTick)

    local magId, mag, wdata = findMagazineForHash(src, hash)
    if not magId or not mag or not wdata then return end

    local cap = wdata.capacity
    local rounds = (mag.meta and mag.meta.rounds) or cap
    rounds = math.max(0, rounds - count)

    local meta = mag.meta or {}
    meta.rounds = rounds
    meta.capacity = cap
    meta.customLabel = magLabelFor(wdata.category, rounds, cap)
    exports.pop_inventory:UpdateItemMetadata(src, magId, meta)
end)

-- Boîte de munitions (recharge un chargeur). Appelé via le champ `export` de l'item
-- ('pop_inventory:onUseAmmo'). Retourne false : on gère nous-mêmes la consommation.
exports('onUseAmmo', function(_, src, item, def)
    local boxDef = item and item.defId
    local cat = AmmoBoxCat[boxDef]
    if not cat then return false end

    local catInfo = MagItemByCat[cat]
    if not catInfo then return false end
    local magItem, capacity = catInfo.magItem, catInfo.capacity

    local store = exports.pop_inventory:getStore(src)
    if not store or not store.items then return false end

    local bestId, bestMag, bestRounds
    for id, it in pairs(store.items) do
        if it.defId == magItem and not it._isTemporary then
            local r = (it.meta and it.meta.rounds) or capacity
            if r < capacity and (bestRounds == nil or r < bestRounds) then
                bestId, bestMag, bestRounds = id, it, r
            end
        end
    end

    if not bestId then
        notify(src, ('Aucun chargeur %s a recharger.'):format(ChargeursConfig.CategoryLabels[cat] or cat), 'error')
        return false
    end

    -- On consomme la boîte AVANT de remplir le chargeur (pas de recharge gratuite si le retrait échoue)
    if not exports.pop_inventory:removeItem(src, boxDef, 1) then return false end

    local meta = bestMag.meta or {}
    meta.rounds = capacity
    meta.capacity = capacity
    meta.customLabel = magLabelFor(cat, capacity, capacity)
    exports.pop_inventory:UpdateItemMetadata(src, bestId, meta)
    notify(src, ('Chargeur %s recharge (%d balles).'):format(ChargeursConfig.CategoryLabels[cat] or cat, capacity), 'success')
    return false
end)
