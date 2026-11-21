fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_notify'
author 'KL'
version '1.1.0'
description 'Notifications POP (export ShowNotify) et checklist de mission'

-- Script d'affichage sans framework : pas de bridge (c'est lui que le bridge des autres scripts appelle).

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

client_scripts {
    'client.lua',
}

exports {
    'ShowNotify',
}
