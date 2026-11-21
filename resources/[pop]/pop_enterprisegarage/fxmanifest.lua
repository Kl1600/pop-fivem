fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description 'Garage entreprise (flotte persistante, collabore avec pop_vehiclepersistence)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'

client_scripts {
    '@es_extended/imports.lua',
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'es_extended',
    'oxmysql',
    'pop_vehiclepersistence',
}
