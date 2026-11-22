fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_crew'
author 'KL'
version '1.1.0'
description 'Système de crew minimal (base pour la guerre de territoires)'

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
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/database.lua',
    'server/exports.lua',
    'server/actions.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
