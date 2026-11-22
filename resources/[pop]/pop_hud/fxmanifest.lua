fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_hud'
author 'KL'
version '1.1.0'
description 'HUD : mini-carte ronde, vie, faim, soif, voix, heure'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/status.lua',
    'client/minimap.lua',
}

ui_page 'html/index.html'

files {
    'html/script.js',
    'html/styles.css',
    'html/index.html',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
