fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_loading'
author 'KL'
version '1.1.0'
description 'Écran de chargement et écran « Accéder au plateau de jeu »'

-- Écran de chargement : le framework n'est pas encore chargé quand il s'affiche.
-- Le bridge est chargé pour suivre le gabarit POP, mais le script ne l'utilise pas.

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
}

files {
    'html/index.html',
    'html/img/*',
    'html/music.mp3',
}

loadscreen 'html/index.html'
ui_page 'html/index.html?nuipage=true'
loadscreen_cursor 'yes'
loadscreen_manual_shutdown 'yes'

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
