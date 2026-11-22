fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_medexam'
author 'KL'
version '1.1.0'
description 'POP Medical Examination - examen des blessures par zone du corps'

dependencies {
  'es_extended',
  'ox_target'
}

shared_scripts {
  'config.lua',
  'shared/*.lua',
  'locales/*.lua',
}

client_scripts {
  'bridge/client.lua',
  'client/injuries.lua',
  'client/exam.lua',
}

server_scripts {
  'bridge/server.lua',
  'server/main.lua',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/styles.css',
  'html/script.js',
}

escrow_ignore {
  'config.lua',
  'locales/*.lua',
  'bridge/*.lua',
}
