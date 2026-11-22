fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_charcreator'
author 'KL'
version '1.1.0'
description 'POP Character Creator - Premium & Modern'

dependency 'skinchanger'

exports {
    'CreateCamera',
    'DestroyCamera',
    'FocusOn'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    '@es_extended/imports.lua', -- ESX direct : globale ESX utilisée côté serveur (xPlayer, commande admin)
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/camera.lua',
    'client/creator.lua',
    'client/appearance.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/save.lua',
    'server/instance.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
