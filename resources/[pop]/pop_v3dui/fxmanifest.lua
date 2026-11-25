fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_v3dui'
author 'KL'
description '3D world UI (prompts, texts, icons) rendered in HTML/CSS'

-- Display-only resource, no framework: no bridge (it is a building block used by other scripts).

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/icons/garage.svg',
}

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',
}

-- Exports declared in client/main.lua: Create, Remove, Update, UpdateCoords, ClearAll.

escrow_ignore {
    'config.lua',
    'locales/*.lua',
}

version '1.0.0'
