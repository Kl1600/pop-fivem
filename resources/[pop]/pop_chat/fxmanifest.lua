fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_chat'
author 'KL'
version '1.1.0'
description 'Chat roleplay (/me) et chat staff (/staff)'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua',
}

-- Thème du chat FiveM (ressource « chat ») au style du serveur : cartes en verre, police TT Firs Neue.
file 'html/chat_theme.css'

chat_theme 'pop' {
    styleSheet = 'html/chat_theme.css',
    msgTemplates = {
        default = '<b>{0}</b><span>{1}</span>',
    },
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
