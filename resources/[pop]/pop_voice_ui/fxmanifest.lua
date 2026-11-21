fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_voice_ui'
author 'KL'
version '1.1.0'
description "Barre d'activité vocale (micro) à l'écran"

-- Script d'affichage sans framework : pas de bridge (ni notification, ni argent, ni job).

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua'
}

escrow_ignore {
    'config.lua',
}
