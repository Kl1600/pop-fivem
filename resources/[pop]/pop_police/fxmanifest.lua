fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_police'
author 'POP'
version '1.0.0'
description 'POP Police - police job tools'

dependencies { 'oxmysql' }

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
    'common/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/actions.lua',
    'client/effects.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/main.lua',
    'server/actions.lua',
    'server/fines.lua',
    'server/mdt.lua',
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
}
