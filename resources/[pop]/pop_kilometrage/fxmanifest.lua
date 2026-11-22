fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_kilometrage'
author 'KL'
version '1.1.0'
description 'Suivi et sauvegarde du kilometrage des vehicules'

dependencies {
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
