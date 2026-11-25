fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_idcard'
author 'KL'
description 'ID card (US / Mexico) with holder photo - ESX, QBCore, Qbox, standalone'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/i18n.js',
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
    'bridge/server.lua',
    'server/common.lua',
    'server/main.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}

version '1.0.0'
