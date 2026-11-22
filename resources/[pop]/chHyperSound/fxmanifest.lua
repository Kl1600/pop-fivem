fx_version 'cerulean'
games      { 'gta5' }
lua54      'yes'

author      'CharlesHacks#9999'
description '3D positional audio library for FiveM.'
version     '0.0.1'

--
-- Server
--

server_scripts {
    'config.lua',

    'server/server.lua',
}

--
-- Client
--

client_scripts {
    'config.lua',

    'client/client.lua',
}

--
-- NUI
--

ui_page 'nui/nui.html'

files {
    'nui/nui.html',
    'nui/app.js',

    'nui/lib/*.js',

    'sounds/*.ogg',
    'sounds/1t.ogg',
    'sounds/2t.ogg',
    'sounds/3t.ogg',
    'sounds/4t.ogg',
    'sounds/5t.ogg',
    'sounds/andaleloud.ogg',
    'sounds/intrusion.ogg',
    'sounds/demo.ogg',
    'sounds/letsgoloud.ogg',
    'sounds/p1.ogg',
    'sounds/shutdown.ogg',
    'sounds/svetlana_line1.ogg',
    'sounds/svetlana_line2.ogg',
    'sounds/svetlana_line3.ogg',
    'sounds/unlock.ogg',
    'sounds/wegottamovequick.ogg',
    'sounds/vamosloud.ogg',
    -- fire.ogg est dans sounds/ (couvert par sounds/*.ogg)
}
