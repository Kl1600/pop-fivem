fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_v3dui'
author 'KL'
version '2.1.0'
description 'Interface 3D (prompts, textes, icônes) affichée dans le monde, en HTML/CSS'

-- Script d'affichage sans framework : pas de bridge (c'est une brique utilisée par les autres scripts).

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/icons/garage.svg',
}

client_scripts {
    'config.lua',
    'client/main.lua',
}

-- Exports déclarés dans client/main.lua : Create, Remove, Update, UpdateCoords, ClearAll.

escrow_ignore {
    'config.lua',
}
