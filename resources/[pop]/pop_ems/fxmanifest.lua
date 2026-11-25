fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'pop_ems'
author 'KL'
description 'POP EMS - ambulance job: duty, calls, care, transport'
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/script.js', 'web/kit/*.css', 'web/kit/*.js' }
shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/main.lua', 'client/injuries.lua', 'client/calls.lua', 'client/care.lua', 'client/transport.lua' }
server_scripts { 'bridge/server.lua', 'server/common.lua', 'server/duty.lua', 'server/calls.lua', 'server/care.lua', 'server/transport.lua' }
escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
version '1.0.0'
