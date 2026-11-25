-- pop_inventory : déjà présents dans pop_inventory/config/items_1.lua.
-- Sur un autre serveur avec pop_inventory, ajouter dans Config.Items :
-- (copier les entrées ci-dessous / copy the entries below)
return {
    idcard = {
        label    = 'Carte d\'identité',
        weight   = 0.05,
        maxStack = 1,
        icon     = 'img/idcard.webp',
        tags     = { 'misc', 'identity' },
        usable   = true,
        onUse    = function(source, itemData)
            TriggerClientEvent('pop_idcard:display', source, itemData)
            return false -- garde la carte
        end,
    },
    idcard_mx = {
        label    = 'Credencial INE',
        weight   = 0.05,
        maxStack = 1,
        icon     = 'img/idcard.webp',
        tags     = { 'misc', 'identity' },
        usable   = true,
        onUse    = function(source, itemData)
            TriggerClientEvent('pop_idcard:display', source, itemData)
            return false
        end,
    },
}
