fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_grandtheftauto'
author 'KL'
version '1.1.0'
description 'Casse de la concession Benefactor (Vinewood ouest) : vol de sportives en équipe'

dependencies {
    'clm_ProgressBar',
    'chHyperSound',
    'interact-sound',
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
    'bridge/client.lua',
    'client/utils.lua',     -- outils communs (synchro coop, chargements, invites, minuteur)
    'client/guide.lua',     -- guidage : checklist, itinéraire GPS, notifications d'étape
    'client/sync.lua',      -- synchro coop, police (GPS), fin de mission
    'client/lasers.lua',
    'client/scenario.lua',  -- Thornton (ShowSubtitle, npcHandle)
    'client/doors.lua',     -- portes, voiture de démo, GPS livraison
    'client/spawn.lua',     -- voitures du showroom (Cars)
    'client/blips.lua',
    'client/interact.lua',  -- Svetlana, panneau, clés, porte
    'client/hack.lua',      -- piratage des voitures
    'client/pcb.lua',       -- module pirate : commande, inventaire, livraison coop
    'client/delivery.lua',  -- camions de livraison
}

server_scripts {
    'bridge/server.lua',
    'server/common.lua',
    'server/mission.lua',
    'server/police.lua',
    'server/hack.lua',
    'server/delivery.lua',
    'server/items.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/kit/pop.css',
    'html/kit/pop.js',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
