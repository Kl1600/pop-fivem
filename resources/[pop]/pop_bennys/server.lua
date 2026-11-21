-- Paiement des modifications EN ITEMS.
-- Le client n'envoie que les catégories modifiées { wheel = 1, body = 3, ... } :
-- le coût (items et quantités) est recalculé ici à partir de Config.ItemCosts.

local function inv()
    return exports[Config.Inventory]
end

-- Nombre maximum d'éléments par catégorie (pièces de carrosserie, extras)
local MaxPerCategory = { body = 10, extra = 21 }

local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'pop.admin')
end

RegisterNetEvent('pop_bennys:payItems', function(cats)
    local src = source

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - Config.BennysCoords) > 30.0 and not isAdmin(src) then
        TriggerClientEvent('pop_bennys:payResult', src, false)
        return
    end

    if type(cats) ~= 'table' then
        TriggerClientEvent('pop_bennys:payResult', src, false)
        return
    end

    -- Calcul serveur des items requis
    local required, order = {}, {}
    for cat, mult in pairs(cats) do
        local recipe = Config.ItemCosts[cat]
        mult = tonumber(mult)
        if type(recipe) ~= 'table' or not mult or mult < 1 or mult % 1 ~= 0 or mult > (MaxPerCategory[cat] or 1) then
            TriggerClientEvent('pop_bennys:payResult', src, false)
            return
        end
        for _, need in ipairs(recipe) do
            if not required[need.item] then
                required[need.item] = 0
                order[#order + 1] = need.item
            end
            required[need.item] = required[need.item] + (need.qty or 0) * mult
        end
    end

    -- 1) Vérifie que TOUT est disponible avant de retirer quoi que ce soit.
    for _, item in ipairs(order) do
        local qty = required[item]
        if qty > 0 and (inv():getItemCount(src, item) or 0) < qty then
            TriggerClientEvent('pop_bennys:payResult', src, false, item)
            return
        end
    end

    -- 2) Retire la combinaison complète.
    for _, item in ipairs(order) do
        if required[item] > 0 then inv():removeItem(src, item, required[item]) end
    end

    TriggerClientEvent('pop_bennys:payResult', src, true)
end)

-- /bennys : ouverture à distance réservée aux admins (ACE pop.admin)
RegisterCommand(Config.Command, function(src)
    if src == 0 or not isAdmin(src) then return end
    TriggerClientEvent('pop_bennys:adminOpen', src)
end, false)
