fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_computer'
author 'POP'
version '1.0.0'
description 'POP Computer - configurable workstations'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/main.lua' }
server_scripts { 'bridge/server.lua', 'server/main.lua' }

ui_page 'web/index.html'
files { 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
