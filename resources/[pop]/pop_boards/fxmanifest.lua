fx_version 'cerulean'
game 'gta5'

description 'POP Boards'
author 'KL'
ui_page 'html/nui.html'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/main.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/nui.html',
    'html/toile.png',
    'html/editor_bg.png'
}
