fx_version 'cerulean'
author 'KL'
game 'gta5'

ui_page 'index.html'

shared_scripts {
    'config.lua'
}

files {
    'index.html',
    'tattoos.json'
}

client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
