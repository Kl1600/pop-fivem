fx_version 'cerulean'
game 'gta5'

description 'POP Passport (US / MX)'
author 'KL'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/usapassport.png',
    'html/mexicopassport.png'
}

shared_scripts {
    '@es_extended/imports.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
