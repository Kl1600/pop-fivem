-- QBCore / Qbox (qb-inventory) : à ajouter dans qb-core/shared/items.lua
-- (images : copier install/images/*.png dans qb-inventory/html/images/)
-- (copier les entrées ci-dessous / copy the entries below)
return {
    idcard    = { name = 'idcard',    label = 'ID card',        weight = 50, type = 'item', image = 'idcard.png',    unique = true, useable = true, shouldClose = true, description = 'Identity card' },
    idcard_mx = { name = 'idcard_mx', label = 'Credencial INE', weight = 50, type = 'item', image = 'idcard_mx.png', unique = true, useable = true, shouldClose = true, description = 'Mexican identity card' },
}
