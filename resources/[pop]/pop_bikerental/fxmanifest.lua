fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bikerental'
author 'KL'
version '1.1.0'
description 'Location de vélos et de Ventoso payée en espèces'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/common.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
