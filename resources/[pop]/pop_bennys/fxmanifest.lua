fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bennys'
author 'KL'
version '1.1.0'
description "Custom Benny's Motor Works UI"

dependencies {
    'pop_v3dui',
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
    'client/vehicle.lua',
    'client/camera.lua',
    'client/menu.lua',
    'client/preview.lua',
    'client/zone.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/payment.lua',
    'server/admin.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
