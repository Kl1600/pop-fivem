fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_clothes'
author 'KL'
version '1.1.0'
description 'Magasins de vêtements, barbiers et tatoueurs (vêtements en objets pop_inventory)'

-- pop_inventory démarré avant : le bridge doit le détecter pour payer avec l'objet cash
dependencies {
    'pop_inventory',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'tattoos.json',
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/common.lua',
    'client/tattoos.lua',
    'client/camera.lua',
    'client/barber.lua',
    'client/shop.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/common.lua',
    'server/tattoos.lua',
    'server/shop.lua',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
