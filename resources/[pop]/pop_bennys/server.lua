-- Paiement des modifications EN ITEMS (plus en argent).
-- Le NUI envoie la liste agrégée des items requis : { { item = 'wheel', qty = 4 }, ... }
-- On vérifie que le joueur possède tout, puis on retire.

local function inv()
    return exports[Config.Inventory]
end

-- Liste blanche des items payables (issue du config, jamais du client).
local allowedItems = {}
for _, recipe in pairs(Config.ItemCosts) do
    for _, need in ipairs(recipe) do allowedItems[need.item] = true end
end

RegisterNetEvent('pop_bennys:payItems', function(items)
    local src = source

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - Config.BennysCoords) > 30.0 then
        TriggerClientEvent('pop_bennys:payResult', src, false)
        return
    end

    if type(items) ~= 'table' or #items == 0 then
        TriggerClientEvent('pop_bennys:payResult', src, true)
        return
    end

    -- Validation : items connus, quantités entières strictement positives.
    for _, need in ipairs(items) do
        local qty = type(need) == 'table' and tonumber(need.qty)
        if not qty or qty < 1 or qty > 1000 or qty % 1 ~= 0 or not allowedItems[need.item] then
            TriggerClientEvent('pop_bennys:payResult', src, false)
            return
        end
        need.qty = qty
    end

    -- 1) Vérifie que TOUT est disponible avant de retirer quoi que ce soit.
    for _, need in ipairs(items) do
        local have = inv():getItemCount(src, need.item) or 0
        if have < need.qty then
            TriggerClientEvent('pop_bennys:payResult', src, false, need.item)
            return
        end
    end

    -- 2) Retire la combinaison complète.
    for _, need in ipairs(items) do
        inv():removeItem(src, need.item, need.qty)
    end

    TriggerClientEvent('pop_bennys:payResult', src, true)
end)
