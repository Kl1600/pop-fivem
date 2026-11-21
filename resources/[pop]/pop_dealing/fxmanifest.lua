fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pop_dealing'
author 'KL'
version '1.1.0'
description 'Vente de drogue : clients PNJ, négociation du prix, mode vente au pochon'

dependencies {
    'es_extended',
    'ox_lib',
    'pop_inventory',
    'pop_notify',
    'pop_v3dui',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client.lua',
    'client/common.lua',
    'client/camera.lua',
    'client/offer.lua',
    'client/customers.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/common.lua',
    'server/customers.lua',
    'server/selling.lua',
    'server/deals.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
