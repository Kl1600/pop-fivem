fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_territories'
author 'KL'
version '1.1.0'
description 'Guerre de territoires : parts de zone par crew + multiplicateurs sur la vente de drogue'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/checklist.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/war.lua',
    'server/sales.lua',
    'server/main.lua',
}

ui_page 'html/checklist.html'

files {
    'html/checklist.html',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
