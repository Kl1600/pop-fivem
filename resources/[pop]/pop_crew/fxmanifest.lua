fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_crew'
author 'POP'
version '1.0.0'
description 'POP Crew : player-made crews'

dependency 'oxmysql'

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
    'locales/*.lua',
    'bridge/*.lua',
    'sql/*.sql',
}
