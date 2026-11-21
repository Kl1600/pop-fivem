fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_doorlock'
author 'POP'
version '1.0.0'
description 'Door lock system with in-game editor'

-- Framework, inventaire et target sont détectés dans bridge/. Seul oxmysql est requis (stockage des portes).
dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

-- Ordre explicite : les fichiers d'un même côté partagent la table Doorlock définie dans main.lua.
client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/lockpick.lua',
    'client/editor.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/main.lua',
    'server/keys.lua',
    'server/lockpick.lua',
    'server/editor.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

-- Fichiers laissés lisibles si la ressource est protégée par l'escrow Cfx.
escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
