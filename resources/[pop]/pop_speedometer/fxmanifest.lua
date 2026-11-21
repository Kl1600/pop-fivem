fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_speedometer'
author 'KL'
version '1.1.0'
description 'Compteur de vitesse, carburant et kilométrage'

-- Script d'affichage sans framework : pas de bridge.

dependencies {
    'pop_kilometrage',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/fuel.svg',
    'ui/script.js',
    'ui/style.css',
}

client_scripts {
    'config.lua',
    'client/main.lua',
}

escrow_ignore {
    'config.lua',
}
