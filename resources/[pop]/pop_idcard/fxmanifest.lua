fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_idcard'
author 'KL'
version '1.1.0'
description "Carte d'identité (US / Mexique) avec photo du titulaire"

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/bg.webp',
    'html/bg_mx.webp',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/photo.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
