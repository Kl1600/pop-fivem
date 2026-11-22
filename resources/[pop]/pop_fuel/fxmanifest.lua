fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_fuel'
author 'KL'
version '1.0.0'
description 'Essence : consommation et stations-service (espèces ou carte)'

dependencies {
    'ox_lib',
    'pop_inventory', -- le bridge doit le détecter pour payer avec l'objet cash
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client.lua',
    'client/consumption.lua',
    'client/stations.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
