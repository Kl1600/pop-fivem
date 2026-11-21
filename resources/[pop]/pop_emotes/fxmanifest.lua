fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Discreet Animation Menu with full RPEmotes assets'
version '1.1.0'
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

shared_scripts {
    'shared/emotes.lua',
    'shared/emotes_custom.lua'
}

client_scripts {
    'client/core/utils.lua',
    'client/core/favorites.lua',
    'client/core/events.lua',
    'client/core/crouch.lua',
    'client/main.lua',
    'client/radio_anim.lua'
}

server_scripts {
    'server/main.lua'
}

exports {
    'GetCurrentEmoteName',
    'CopyEmoteFromPlayer',
}

-- Original Prop assets
data_file 'DLC_ITYP_REQUEST' 'stream/taymckenzienz_rpemotes.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pata_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ems_props.ytyp'
