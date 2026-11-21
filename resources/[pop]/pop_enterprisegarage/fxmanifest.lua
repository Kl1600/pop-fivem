fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_enterprisegarage'
author 'KL'
version '1.1.0'
description 'Garage entreprise (flotte persistante, collabore avec pop_vehiclepersistence)'

dependencies {
    'es_extended',
    'oxmysql',
    'pop_vehiclepersistence',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/fleet.lua',
    'server/garage.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
