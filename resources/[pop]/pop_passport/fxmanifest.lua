fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_passport'
author 'POP'
version '1.0.0'
description 'POP Passport'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

dependencies { 'oxmysql' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

-- Fichiers laissés lisibles si la ressource est protégée par l'escrow Cfx.
escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
