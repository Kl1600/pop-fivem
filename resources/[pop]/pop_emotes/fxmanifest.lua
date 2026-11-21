fx_version 'cerulean'
game 'gta5'

author 'KL'
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

-- Props : .ytyp de stream/[Props]/ (référencés par leur nom de fichier, comme RPEmotes)
data_file 'DLC_ITYP_REQUEST' 'brum_heart.ytyp'
data_file 'DLC_ITYP_REQUEST' 'brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_food_dessert_a.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_food_icecream_pack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_food_xmas22.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_foodpack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_cake_baby_001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_cake_birthday_001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_cake_casino001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_cake_love_001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_give_gift.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_prop_torch_fire001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'ems_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'pata_christmasfood.ytyp'
data_file 'DLC_ITYP_REQUEST' 'pata_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'taymckenzienz_rpemotes.ytyp'
data_file 'DLC_ITYP_REQUEST' 'ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'badge1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'copbadge.ytyp'
