-- TAB Doorlock | Doorbuilder edition (base: XD_Doorlock by LielXD) --

fx_version 'cerulean'

game 'gta5'

author 'LielXD + Tab'
description 'TAB Doorlock - doorlock + doorbuilder (clé item) pour ESX'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_scripts {
	'@es_extended/imports.lua',
    'config.lua',
    'client/*.lua'
}

server_scripts {
	'@es_extended/imports.lua',
    'config.lua',
    'server/*.lua'
}

dependencies {
	'es_extended'
}
