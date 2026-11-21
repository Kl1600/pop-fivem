fx_version 'cerulean'
author 'KL'
game 'gta5'

name        'pop_bennys'
description "Custom Benny's Motor Works UI"

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'pop_v3dui',
}

client_script 'client.lua'
server_script 'server.lua'
shared_script 'config.lua'
