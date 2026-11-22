fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_doorlock'
author 'KL'
version '1.1.0'
description 'POP Doorlock - doorlock + doorbuilder (clé item) pour ESX'

dependencies {
    'es_extended'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/doors.lua',
    'client/builder.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/common.lua',
    'server/doors.lua',
    'server/builder.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
