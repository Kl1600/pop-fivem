fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description 'Guerre de territoires : parts de zone par crew + multiplicateurs sur la vente de drogue'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client.lua',
    'checklist.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/checklist.html'

files {
    'html/checklist.html',
}
