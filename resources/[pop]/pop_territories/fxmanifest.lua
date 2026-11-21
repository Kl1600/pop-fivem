fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_territories'
author 'POP'
version '1.0.0'
description 'POP Territories : crew turf wars'

dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',      -- callback.lua, locale.lua, zones.lua
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua',      -- commands.lua, crew.lua, main.lua (les fonctions sont appelées à l'exécution, pas au chargement)
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
    'sql/*.sql',
}
