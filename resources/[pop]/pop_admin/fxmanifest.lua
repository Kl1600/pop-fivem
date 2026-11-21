fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_admin'
author 'POP'
version '1.0.0'
description 'POP Admin - simple and secure admin panel'

dependencies { 'oxmysql' }

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config_server.lua',
    'bridge/server.lua',
    'server/*.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

escrow_ignore {
    'config.lua',
    'config_server.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
