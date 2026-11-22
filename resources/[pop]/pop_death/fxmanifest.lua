fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_death'
author 'KL'
version '1.0.0'
description 'Mort : écran inconscient, appel des secours, réapparition à l\'hôpital'

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

ui_page 'html/index.html'

files {
    'html/index.html',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
