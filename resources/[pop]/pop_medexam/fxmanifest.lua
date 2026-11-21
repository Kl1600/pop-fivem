fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description 'POP Medical Examination - examen des blessures par zone du corps'
version '1.0.0'

dependencies {
  'es_extended',
  'ox_target'
}

shared_scripts {
  '@es_extended/imports.lua',
  'config.lua',
}

client_scripts {
  'client.lua',
}

server_scripts {
  'server.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/styles.css',
  'html/script.js',
}
