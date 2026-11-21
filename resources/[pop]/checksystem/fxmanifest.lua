fx_version 'cerulean'

game 'gta5'
lua54 'yes'
name 'Check System'
author 'Tabernac Softwares'

description 'Advanced check system'

version '1.0.0'

dependency 'oxmysql'
dependency 'es_extended'
dependency 'pop_inventory'

ui_page 'html/index.html'

shared_scripts {
  'shared/config.lua'
}

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}

client_scripts {
  '@es_extended/imports.lua',
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}
