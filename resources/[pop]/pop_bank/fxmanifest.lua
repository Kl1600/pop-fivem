fx_version 'cerulean'

game 'gta5'
lua54 'yes'
name 'Tab Bank'
author 'Tabernac Softwares'
description 'Agences bancaires : consultation de compte et dépôt de chèques'
version '1.0.0'

dependencies {
  'es_extended',
  'oxmysql',
  'ox_lib',
  'ox_target',
  'pop_inventory',
  'checksystem',
}

shared_scripts {
  'config.lua'
}

client_scripts {
  '@ox_lib/init.lua',
  '@es_extended/imports.lua',
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}
