fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_inventory'
author 'KL'
version '0.3.0'
description 'Inventaire POP : conteneurs, équipement, armes, coffres, boutiques, craft et objets RP'

dependencies {
  'oxmysql',
  'es_extended',
  'ox_target',
  'utility_lib',
}

ui_page 'html/index.html'

shared_scripts {
  'config.lua',
  -- Suite de la configuration, dans cet ordre (mêmes tables Config.*)
  'config/props.lua',
  'config/items_1.lua',
  'config/items_2.lua',
  'config/items_3.lua',
  'config/items_4.lua',
  'config/items_5.lua',
  'config/attachments.lua', -- après les objets : complète Config.Items
  'config/clothing.lua',
  'config/shops.lua',
  'config/chests.lua',
  'config/recipes.lua',
  'config/paint.lua',       -- PaintGun
  'config/chargeurs.lua',   -- ChargeursConfig
  'config/vehiclekeys.lua', -- VehicleKeysConfig
  'config/douilles.lua',    -- DouillesConfig
  'config/sabot.lua',       -- SabotConfig
  'shared/*.lua',
  'locales/*.lua',
}

client_scripts {
  'bridge/client.lua',
  'client/common.lua',   -- table Inv, ESX direct, notifications
  'client/lib_shim.lua', -- lib.* minimal (pas d'ox_lib) : avant les modules
  'client/main.lua',
  'client/wheel.lua',
  'client/admin.lua',
  'client/drag.lua',
  'client/state.lua',
  'client/equipment.lua',
  'client/zones.lua',
  'client/malette_weapon.lua',
  'client/containers/carry.lua',
  'client/containers/targets.lua',
  'client/items/usables.lua',
  'client/items/handcuffs.lua',
  'client/items/tyres.lua',
  'client/items/stretcher.lua',
  'client/standby.lua',
  'client/radio.lua',
  'client/interactions.lua',
  'client/chargeurs.lua',
  'client/vehiclekeys.lua',
  'client/douilles.lua',
  'client/paint.lua',
  'client/weapon_preview.lua',
  'client/sabot.lua',
  'client/uvpocketlight.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'bridge/server.lua',
  'server/common.lua',
  -- Cœur de l'inventaire : même ordre que l'ancien chargement par server.lua
  -- (les fichiers partagent leurs fonctions en globales).
  'server/sv_database.lua',
  'server/sv_ground.lua',
  'server/sv_utils.lua',
  'server/sv_stores.lua',
  'server/sv_stores_insert.lua',
  'server/sv_inventory_state.lua',
  'server/sv_state_build.lua',
  'server/sv_ground_drop.lua',
  'server/sv_sync.lua',
  'server/sv_actions.lua',
  'server/sv_exports.lua',
  'server/sv_remote_containers.lua',
  'server/sv_standby.lua',
  'server/sv_static_chests.lua',
  'server/sv_lockers.lua',
  'server/sv_player_items.lua',
  'server/sv_craft_exports.lua',
  'server/sv_bank_vaults.lua',
  'server/sv_admin.lua',
  -- Modules
  'server/items/usables.lua',
  'server/items/stretcher.lua',
  'server/interactions.lua',
  'server/chargeurs.lua',
  'server/vehiclekeys.lua',
  'server/douilles.lua',
  'server/paint.lua',
  'server/engine.lua',  -- capot / moteur : conteneur distant (moteur 3x3 + batterie)
  'server/sabot.lua',
}

files {
  'html/index.html',
  'html/*.css',
  'html/*.js',
  'html/img/*.webp',
  -- PNG gardés pour pop_bennys et pop_management, qui pointent encore vers
  -- nui://pop_inventory/html/img/<nom>.png (voir README).
  'html/img/*.png',
  'html/torso/*.webp',
  'html/svg/*',
  -- Coffre : l'iframe partage les assets du parent (html/svg, html/*.css)
  'html/standby/index.html',
  -- Radio : NUI inline dans index.html
  'html/radio/script.js',
  'html/radio/style.css',
  'html/radio/img/*.webp', -- inclut radio_80s (skin SECURECOM)
  -- Pistolet à peinture : metas de l'arme WEAPON_PRESSURE1
  'weaponarchetypes.meta',
  'weaponanimations.meta',
  'weaponpressurewand.meta',
  -- Lampe UV de poche : metas de l'arme WEAPON_POCKETLIGHT
  'weaponpocketlight_archetypes.meta',
  'weaponpocketlight.meta',
  -- Sabot de roue : type definition pour le prop clamp
  'stream/clamp.ytyp',
}

-- Pistolet à peinture : déclaration de l'arme (modèle streamé depuis stream/)
data_file 'WEAPON_METADATA_FILE'   'weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'weaponanimations.meta'
data_file 'WEAPONINFO_FILE'        'weaponpressurewand.meta'

-- Lampe UV de poche : déclaration de l'arme WEAPON_POCKETLIGHT
data_file 'WEAPON_METADATA_FILE' 'weaponpocketlight_archetypes.meta'
data_file 'WEAPONINFO_FILE'      'weaponpocketlight.meta'

-- Sabot de roue : type definition du prop clamp
data_file 'DLC_ITYP_REQUEST' 'stream/clamp.ytyp'

-- stream/ : assets streamés (détectés par FiveM)
-- stream/p_cs_cuffs_02_s.ydr  -> menottes (British Speedcuffs)
-- stream/w_ar_pressure1*      -> pistolet à peinture
-- stream/w_me_pocketlight*    -> lampe UV de poche

escrow_ignore {
  'config.lua',
  'config/*.lua',
  'locales/*.lua',
  'bridge/*.lua',
}
