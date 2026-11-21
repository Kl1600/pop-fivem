fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

author 'Tabernac'
name 'pop_admin'
description 'Menu admin liste façon GTA (haut à droite, clavier) : joueurs, items, jobs, véhicules, temps & météo, mode spec.'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
    'client/timeweather.lua',
    'client/players.lua',
    'client/characters.lua',
    'client/bridge.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
