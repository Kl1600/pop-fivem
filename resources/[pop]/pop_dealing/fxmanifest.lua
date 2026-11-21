fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'KL'
description 'Drug dealing system (Schedule 1 inspired)'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_lib',
    'pop_inventory',
    'pop_notify',
    'pop_v3dui',
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'
server_script 'server.lua'
client_script 'client.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
