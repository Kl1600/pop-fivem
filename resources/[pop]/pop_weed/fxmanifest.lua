fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pop_weed'
author 'KL'
version '1.1.0'
description 'Culture de cannabis : plantation, arrosage, croissance et récolte'

dependencies {
    'ox_lib',
    'ox_target',
    'object_gizmo',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client.lua',
    'client/plants.lua',
    'client/placement.lua',
    'client/hud.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/common.lua',
    'server/main.lua',
    'server/actions.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
