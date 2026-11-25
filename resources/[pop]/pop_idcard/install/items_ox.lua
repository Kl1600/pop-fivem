-- ox_inventory : à ajouter dans ox_inventory/data/items.lua
-- (images : copier install/images/*.png dans ox_inventory/web/images/)
-- (copier les entrées ci-dessous / copy the entries below)
return {
    ['idcard'] = {
        label = 'ID card',
        weight = 50,
        stack = false,
        close = true,
        description = 'Identity card',
    },
    ['idcard_mx'] = {
        label = 'Credencial INE',
        weight = 50,
        stack = false,
        close = true,
        description = 'Mexican identity card',
    },
}
