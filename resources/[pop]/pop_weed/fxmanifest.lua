fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'Vanguard'
description 'Weed growing system'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
    'object_gizmo',
}

shared_script '@ox_lib/init.lua'
shared_script 'config.lua'
server_script 'server.lua'
client_script 'client.lua'

