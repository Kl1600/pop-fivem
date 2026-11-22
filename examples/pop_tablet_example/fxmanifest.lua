fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_tablet_example'
description 'Exemple minimal d appli tierce pour pop_tablet (RegisterApp, Notify, OpenApp, AppEvent). Hors resources/[pop] : non deploye.'
version '1.0.0'

dependency 'pop_tablet'

server_scripts {
    'server.lua',
}

-- La page de l'appli doit etre declaree ici pour que nui://pop_tablet_example/... fonctionne.
files {
    'web/index.html',
}
