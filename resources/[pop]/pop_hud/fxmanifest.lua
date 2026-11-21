fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_hud'
author 'POP'
version '1.0.0'
description 'Contextual player and vehicle HUD'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/main.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/script.js', 'web/style.css', 'web/kit/*' }
escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
