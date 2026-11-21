fx_version 'cerulean'
game 'gta5'

exports {
    'CreateCamera',
    'DestroyCamera',
    'FocusOn'
}

description 'POP Character Creator - Premium & Modern'
author 'KL'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/camera.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'skinchanger'
