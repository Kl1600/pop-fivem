fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description 'Suivi et sauvegarde du kilometrage des vehicules'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'oxmysql',
}
