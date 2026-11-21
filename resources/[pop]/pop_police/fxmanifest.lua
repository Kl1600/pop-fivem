fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Tabernac'
description 'Tabernac Police Dispatch'
version '1.0.0'

dependencies {
  'es_extended',
  'oxmysql'
}

shared_scripts {
  'config.lua',
}

client_scripts {
  '@es_extended/imports.lua',
  'client.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/styles.css',
  'html/script.js',
}

-- Exports pour les autres scripts
export 'createCall'
server_export 'createCall'