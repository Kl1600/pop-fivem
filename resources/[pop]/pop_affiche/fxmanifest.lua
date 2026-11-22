fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_affiche'
author 'KL'
version '1.1.0'
description 'POP Affiche - Posez des affiches avec un lien Discord'

ui_page 'html/nui.html'

files {
    'html/nui.html',
    'html/affiche.html',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client.lua',
    'client/panels.lua',
    'client/editor.lua',
    'client/placement.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/database.lua',
    'server/affiches.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
