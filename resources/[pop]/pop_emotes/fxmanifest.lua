fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_emotes'
author 'POP'
version '1.0.0'
description 'Animation menu and shared emotes'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/main.lua' }
server_scripts { 'bridge/server.lua', 'server/main.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/script.js', 'web/style.css', 'web/kit/*' }
escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
