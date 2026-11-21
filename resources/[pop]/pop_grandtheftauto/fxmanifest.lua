fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

dependencies {
    'pma_voice_challenge',
    'clm_ProgressBar',
    'chHyperSound',
    'ultra-voltlab',
    'interact-sound',
    'pop_inventory',
    'pop_notify',
    'pop_v3dui',
}
-- kq_lasers : facultatif (lasers de sécurité), la mission marche sans.

name 'Grand Vol de Voitures'
author 'KL'
description 'Casse de la concession Benefactor, west Vinewood'
version 'beta'

client_scripts {
    'shared/config.lua',

    -- utilitaires globaux d'abord
    'client/utils.lua',

    -- couche synchro coop
    'client/client.lua',

    -- scénario/PNJ (définit ShowSubtitle + npcHandle)
    'client/scenario.lua',

    -- portes / veh démo / commandes
    'client/doors.lua',

    -- voitures showroom (Cars)
    'client/spawn.lua',

    -- blips (removeblip1 etc.)
    'client/blips.lua',

    -- terminal hack / clés / porte / véhicule Thornton
    'client/interact.lua',

    -- hack véhicules (s'appuie sur Cars/_G.Cars)
    'client/crack.lua',

    -- livraison
    'client/delivery.lua',
}

server_scripts {
    'shared/config.lua',
    'server/alert.lua',
    'server/items.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html'
}

exports {
    'startCircuit'
}
