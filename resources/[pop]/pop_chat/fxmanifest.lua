fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_chat'
author 'KL'
version '1.1.0'
description 'Chat roleplay (/me) et chat staff (/staff)'

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
    'bridge/server.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
