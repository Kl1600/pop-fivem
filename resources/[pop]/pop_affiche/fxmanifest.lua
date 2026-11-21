fx_version 'cerulean'
game 'gta5'

description 'POP Affiche - Posez des affiches avec un lien Discord'
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
    'html/nui.html',
    'html/affiche.html',
}
