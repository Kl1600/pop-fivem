-- FXVersion Version
fx_version 'adamant'
games {"rdr3","gta5"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

-- Client Scripts
client_script 'client/main.lua'

-- Server Scripts
server_script 'server/main.lua'

-- NUI Default Page
ui_page "client/html/index.html"

-- Files needed for NUI
-- DON'T FORGET TO ADD THE SOUND FILES TO THIS!
files {
    'client/html/index.html',
    -- Begin Sound Files Here...
    -- client/html/sounds/ ... .ogg
    'client/html/sounds/demo.ogg',
    'client/html/sounds/intrusion.ogg',
    'client/html/sounds/p1.ogg',
    'client/html/sounds/shutdown.ogg',
    'client/html/sounds/unlock.ogg',
    'client/html/sounds/svetlana_line1.ogg',
    'client/html/sounds/svetlana_line2.ogg',
    'client/html/sounds/svetlana_line3.ogg',
    'client/html/sounds/svetlana_line4.ogg',
    'client/html/sounds/svetlana_line5.ogg'

}



shared_scripts {
}
