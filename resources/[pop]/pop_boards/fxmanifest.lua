fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_boards'
author 'KL'
version '1.1.0'
description 'POP Boards'

ui_page 'html/nui.html'

files {
    'html/index.html',
    'html/nui.html',
    'html/toile.png',
    'html/editor_bg.png'
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/panels.lua',
    'client/editor.lua',
    'client/placement.lua',
    'client/sync.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/database.lua',
    'server/boards.lua',
    'server/sync.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
