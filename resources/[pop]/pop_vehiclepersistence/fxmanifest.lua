fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_vehiclepersistence'
author 'POP'
version '1.0.0'
description 'POP Vehicle Persistence - parked vehicles stay where they were left'

-- OneSync obligatoire (véhicules créés côté serveur : CreateVehicleServerSetter).
dependencies { 'oxmysql' }

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua', 'common/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/*.lua' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
