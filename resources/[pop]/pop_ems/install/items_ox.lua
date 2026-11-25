-- pop_ems : objets pour ox_inventory.
-- Copiez les entrées ci-dessous (sans le `return {` ni la dernière accolade) dans ox_inventory/data/items.lua.
-- NOTE: ox_inventory fournit déjà 'bandage' par défaut : ne gardez que les objets absents.
-- Aucun n'est utilisable seul : ils servent via le menu de soins EMS.
-- Images : copier install/images/*.webp dans ox_inventory/web/images/.

return {
    ['bandage'] = {
        label = 'Bandage',
        weight = 100,
        stack = true,
        close = true,
        description = 'EMS',
    },

    ['kitsoins'] = {
        label = 'Kit de soins',
        weight = 1000,
        stack = true,
        close = true,
        description = 'EMS',
    },

    ['defib'] = {
        label = 'Défibrillateur',
        weight = 2500,
        stack = false,
        close = true,
        description = 'EMS',
    },
}
