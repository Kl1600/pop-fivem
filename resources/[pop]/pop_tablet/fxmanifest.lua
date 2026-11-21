fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_tablet'
author 'POP'
version '1.0.0'
description 'POP Tab : tablette en objet d inventaire, applis, API pour les autres ressources'

-- Dépendance unique : oxmysql (les données sont stockées). Framework, inventaire et target sont détectés dans bridge/.
dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua',
    'server/apps/*.lua', -- le glob précédent ne descend pas dans les sous-dossiers
}

-- Interface construite (versionnée, jamais construite sur le serveur).
ui_page 'web/dist/index.html'

files {
    'web/dist/**',
}

-- Fichiers laissés lisibles si la ressource est protégée par l'escrow Cfx.
escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
