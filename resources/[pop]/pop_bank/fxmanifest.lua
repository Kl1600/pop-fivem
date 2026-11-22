fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bank'
author 'KL'
version '1.1.0'
description 'Agences bancaires : consultation de compte et dépôt de chèques'

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'pop_inventory',
    'checksystem',
}

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
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/accounts.lua',
    'server/cheques.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
