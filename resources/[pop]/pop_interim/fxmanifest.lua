fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description "Agence d'intérim — menu NUI (style pop_emotes) au blip Intérim"
version '1.0.0'

dependencies {
    'es_extended',
}

ui_page 'html/index.html'

shared_script 'config.lua'

client_scripts {
    '@es_extended/imports.lua',
    'client.lua',
}

server_scripts {
    '@es_extended/imports.lua',
    'server.lua',
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}
