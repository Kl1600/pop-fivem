fx_version 'cerulean'
game 'gta5'

author 'KL'
description 'Vehicle Saving and Respawning Script'
version '1.0.0'
lua54 'yes'

dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'bridge.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}