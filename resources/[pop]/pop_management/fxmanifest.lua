fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Tabernac'
description 'Tabernac Gestion'
version '1.0.0'

-- Refresh cache

dependencies {
  'es_extended',
  'oxmysql',
  'ox_lib',
}

client_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua',
    'client.lua'
}

server_scripts {
  'config.lua',
  'server.lua'
}

-- Keep the UI page as the invisible input bridge (it does not need to be visible).
ui_page 'html/input.html'

-- IMPORTANT: DUI pages MUST be listed here or FiveM will 404 them (black texture).
files {
  'html/*.html',
  'html/*.js',
  'html/*.png',
  'html/*.webp',
  'html/*.svg',
  'html/themes/*.css',
  'html/adder.jpg',
  'html/baller.jpg',
  'html/comet2.jpg',
  'html/elegy.jpg',
  'html/sentinel_gts.jpg',
  'html/t20.jpg',
  'html/zentorno.jpg',
  'html/pdm.png',
  'html/ambulance.jpg',
  'html/poldorado.jpg',
  'html/polbuffalostx.jpg',
  'html/polgauntlet.jpg',
  'html/entrepot.png',
  'html/b8f1f98587_sparrow.jpg',

}
