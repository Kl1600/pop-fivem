-- Luacheck pour les scripts POP (FiveM, Lua 5.4).
-- Lancer : luacheck templates resources
std = 'lua54'
codes = true
max_line_length = false

-- Les globales POP (Config, Locales, L, Bridge, Callback, GetLocaleTable) sont définies dans les fichiers partagés.
allow_defined_top = true

globals = {
    'Config', 'Locales', 'L', 'GetLocaleTable', 'Bridge', 'Callback', 'GlobalState',
}

read_globals = {
    -- Runtime CitizenFX
    'Citizen', 'CreateThread', 'Wait', 'SetTimeout', 'exports', 'source', 'promise', 'json',
    'vector2', 'vector3', 'vector4', 'vec2', 'vec3', 'vec4', 'quat', 'joaat', 'GetHashKey',
    'RegisterNetEvent', 'RegisterServerEvent', 'AddEventHandler', 'RemoveEventHandler',
    'TriggerEvent', 'TriggerServerEvent', 'TriggerClientEvent', 'TriggerLatentClientEvent',
    'RegisterCommand', 'RegisterKeyMapping', 'RegisterNUICallback', 'SendNUIMessage', 'SetNuiFocus',
    'GetCurrentResourceName', 'GetResourceState', 'GetResourceMetadata', 'IsDuplicityVersion',
    'LocalPlayer', 'Player', 'Entity',
    -- Bibliothèques optionnelles
    'lib', 'MySQL', 'cache',
    -- Ajouts de manifest
    'fx_version', 'game', 'games', 'lua54', 'name', 'author', 'version', 'description',
    'shared_script', 'shared_scripts', 'client_script', 'client_scripts', 'server_script', 'server_scripts',
    'ui_page', 'files', 'file', 'dependency', 'dependencies', 'escrow_ignore', 'provide',
}

-- Natives GTA / FiveM : trop nombreuses pour être listées. On ignore les accès à des
-- globales non définies (113) ; les fautes de frappe restent visibles en jeu et à l'audit.
ignore = {
    '113', -- accès à une globale non définie (natives)
    '212', -- argument inutilisé (signatures imposées par les frameworks)
}
