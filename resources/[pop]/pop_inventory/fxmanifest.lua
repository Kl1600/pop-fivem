fx_version 'cerulean'

game 'gta5'
lua54 'yes'
name 'POP Inventory'
author 'KL'

description 'Advanced POP Inventory NUI resource'

version '0.2.0'

dependency 'oxmysql'
dependency 'es_extended'
dependency 'ox_target'
dependency 'utility_lib'

ui_page 'html/index.html'

shared_scripts {
  'config.lua',
  'paint_config.lua', -- Pistolet a peinture : couleurs GTA + config (global PaintGun)
  'chargeurs_config.lua', -- Module chargeurs (ex tab_chargeurs) : ChargeursConfig
  'vehiclekeys_config.lua', -- Module clés véhicule (ex vehicle_keys) : VehicleKeysConfig
  'douilles_config.lua', -- Module douilles (ex tab_douilles) : DouillesConfig
  'sabot_config.lua' -- Module sabot de roue (ex tab_sabot) : SabotConfig
}

files {
  'html/index.html',
  'html/*.css',
  'html/*.js',
  'html/img/*.png',
  'html/torso/*.png',
  'html/svg/*',
  -- Module coffre (ex standby_ui) : l'iframe partage les assets du parent (html/svg, html/*.css)
  -- -> plus de doublons svg/css. (Fusion complete sans iframe prevue ensuite.)
  'html/standby/index.html',
  -- Radio (ex resource [interact]/radio) importée : NUI inline dans index.html
  'html/radio/script.js',
  'html/radio/style.css',
  'html/radio/img/*.png', -- inclut radio_80s.png (skin SECURECOM)
  -- Pistolet a peinture : metas de l'arme WEAPON_PRESSURE1
  'weaponarchetypes.meta',
  'weaponanimations.meta',
  'weaponpressurewand.meta',
  -- Lampe UV de poche : metas de l'arme WEAPON_POCKETLIGHT
  'weaponpocketlight_archetypes.meta',
  'weaponpocketlight.meta',
  -- Sabot de roue : type definition pour le prop clamp
  'stream/clamp.ytyp'
}

-- Pistolet a peinture : declaration de l'arme (modele streame depuis stream/)
data_file 'WEAPON_METADATA_FILE'   'weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'weaponanimations.meta'
data_file 'WEAPONINFO_FILE'        'weaponpressurewand.meta'

-- Lampe UV de poche : declaration de l'arme WEAPON_POCKETLIGHT
data_file 'WEAPON_METADATA_FILE' 'weaponpocketlight_archetypes.meta'
data_file 'WEAPONINFO_FILE'      'weaponpocketlight.meta'

-- Sabot de roue : type definition du prop clamp
data_file 'DLC_ITYP_REQUEST' 'stream/clamp.ytyp'

-- stream/ : assets streamés (auto-détecté par FiveM)
-- stream/p_cs_cuffs_02_s.ydr  -> British Speedcuffs model
-- stream/w_ar_pressure1*      -> modele du pistolet a peinture
-- stream/w_me_pocketlight*    -> modele de la lampe UV de poche

client_scripts {
  -- config.lua déjà chargé via shared_scripts (évite un double chargement)
  'lib_shim.lua', -- Shim lib.* (pas d'ox_lib dans pop_inventory) : DOIT être avant les modules
  'client.lua',
  'malette_weapon.lua',
  'remote_container.lua',
  'items_client.lua',
  'standby_client.lua',
  'radio_client.lua', -- Radio (ex [interact]/radio) importée
  'interactions_client.lua', -- Interactions (ex tab_interactions) importées
  'chargeurs_client.lua', -- Module chargeurs (ex tab_chargeurs)
  'vehiclekeys_client.lua', -- Module clés véhicule (ex vehicle_keys)
  'douilles_client.lua', -- Module douilles (ex tab_douilles)
  'paint_client.lua', -- Pistolet a peinture (logique client + spray)
  'weapon_preview.lua', -- Prévisualisation 3D d'arme (section accessoires)
  'sabot_client.lua', -- Module sabot de roue (ex tab_sabot)
  'uvpocketlight_client.lua' -- Lampe UV de poche : composant UV force sur WEAPON_POCKETLIGHT
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua',
  'items_server.lua',
  'interactions_server.lua', -- Interactions (ex tab_interactions) importées
  'chargeurs_server.lua', -- Module chargeurs (ex tab_chargeurs)
  'vehiclekeys_server.lua', -- Module clés véhicule (ex vehicle_keys)
  'douilles_server.lua', -- Module douilles (ex tab_douilles)
  'paint_server.lua', -- Pistolet a peinture (pots / reservoir)
  'engine_server.lua', -- Capot / moteur : conteneur distant du capot (moteur 3x3 + batterie)
  'sabot_server.lua' -- Module sabot de roue (ex tab_sabot)
}
