fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_vehiclepersistence'
author 'KL'
version '1.1.0'
description 'Sauvegarde et réapparition des véhicules autour des joueurs'

dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/notify.lua',
    'client/props.lua',
    'client/main.lua',
    'client/debug_hud.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/keys.lua',
    'server/storage.lua',
    'server/spatial.lua',
    'server/events.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
