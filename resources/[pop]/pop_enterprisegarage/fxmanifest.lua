fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_enterprisegarage'
author 'POP'
version '1.0.0'
description 'POP Enterprise Garage - job service vehicles'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
