-- pop_ems : objets pour QBCore.
-- Copiez les lignes ci-dessous (sans le `return {` ni la dernière accolade) dans qb-core/shared/items.lua (QBShared.Items).
-- NOTE: qb-core fournit déjà 'bandage' par défaut : ne gardez que les objets absents.
-- Images : copier install/images/*.webp dans qb-inventory/html/images/.

return {
    bandage  = { name = 'bandage',  label = 'Bandage',        weight = 100,  type = 'item', image = 'bandage.webp',  unique = false, useable = false, shouldClose = true, description = 'EMS' },
    kitsoins = { name = 'kitsoins', label = 'Kit de soins',   weight = 1000, type = 'item', image = 'kitsoins.webp', unique = false, useable = false, shouldClose = true, description = 'EMS' },
    defib    = { name = 'defib',    label = 'Défibrillateur', weight = 2500, type = 'item', image = 'defib.webp',    unique = true,  useable = false, shouldClose = true, description = 'EMS' },
}
