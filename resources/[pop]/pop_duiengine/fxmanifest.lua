fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'KL'
description 'tabernac DUI engine'
version '2.6'

client_scripts {
  'client/config.lua',
  'client/state.lua',

  'client/util/vec.lua',
  'client/util/time.lua',

  'client/render/basis.lua',
  'client/render/draw.lua',

  'client/input/raycast_uv.lua',
  'client/focus/focus.lua',

  'client/replace/replace_texture.lua',

  'client/main.lua',
}

files {
  'assets/cursor.png'
}

shared_scripts {
}
