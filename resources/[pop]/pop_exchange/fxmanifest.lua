fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Bureau de change - Echange Dollars/Pesos via PNJ et UI'
version '1.0.0'
lua54 'yes'

dependencies {
    'es_extended',
    'pop_v3dui',
    'pop_inventory'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
