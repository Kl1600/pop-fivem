fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_inventory'
author 'POP'
version '1.0.0'
description 'POP Inventory - slots, weight, metadata, vehicles, stashes, shops'

dependencies { 'oxmysql' }

-- Qbox uniquement (voir README) : décommenter pour remplacer ox_inventory, que qbx_core exige.
-- provide 'ox_inventory'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/weapons.lua',
    'client/world.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'data/items.lua',
    'server/items.lua',
    'server/inventory.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/players.lua',
    'server/containers.lua',
    'server/drops.lua',
    'server/vehicles.lua',
    'server/stashes.lua',
    'server/shops.lua',
    'server/search.lua',
    'server/exports.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
    'data/*.lua',
}
