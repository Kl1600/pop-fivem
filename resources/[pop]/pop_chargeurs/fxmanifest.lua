fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_chargeurs'
author 'POP'
version '1.0.0'
description 'POP Chargeurs - magazine items to reload weapons'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/weapons.lua', 'server/main.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
