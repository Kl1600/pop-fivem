
------
-- Interaction Sounds by Scott
-- Version: v0.0.1
-- Path: server/main.lua
--
-- Allows sounds to be played on single clients, all clients, or all clients within
-- a specific range from the entity to which the sound has been created. Triggers
-- client events only. Used to trigger sounds on other clients from the client or
-- server without having to pass directly to another client.
------

------
-- POP : garde-fous anti-abus (un client ne peut plus jouer un son chez tout le monde,
-- ni à n'importe quelle distance / volume, ni en boucle)
------
local MAX_DISTANCE = 50.0   -- portée max d'un son relayé (m)
local MAX_VOLUME   = 1.0
local COOLDOWN_MS  = 250    -- délai mini entre deux sons d'un même joueur
local lastSound    = {}

local function isPlayer(src)
    src = tonumber(src)
    return src ~= nil and src > 0
end

-- Nom de fichier simple (lettres, chiffres, _ - /) : pas de chemin bizarre
local function cleanSound(soundFile)
    if type(soundFile) ~= 'string' or #soundFile > 64 then return nil end
    if not soundFile:match('^[%w_%-/]+$') then return nil end
    return soundFile
end

local function cleanVolume(v)
    v = tonumber(v)
    if not v then return nil end
    return math.max(0.0, math.min(MAX_VOLUME, v))
end

local function allowed(src)
    if not isPlayer(src) then return true end -- appel serveur (TriggerEvent)
    local now = GetGameTimer()
    if lastSound[src] and now - lastSound[src] < COOLDOWN_MS then return false end
    lastSound[src] = now
    return true
end

AddEventHandler('playerDropped', function()
    lastSound[source] = nil
end)

------
-- RegisterServerEvent InteractSound_SV:PlayOnOne
-- Triggers -> ClientEvent InteractSound_CL:PlayOnOne
--
-- @param clientNetId  - The network id of the client that the sound should be played on.
-- @param soundFile    - The name of the soundfile within the client/html/sounds/ folder.
--                     - Can also specify a folder/sound file.
-- @param soundVolume  - The volume at which the soundFile should be played. Nil or don't
--                     - provide it for the default of standardVolumeOutput. Should be between
--                     - 0.1 to 1.0.
--                     - Can also specify a folder/sound file.
--
-- Starts playing a sound locally on a single client.
------
RegisterNetEvent('InteractSound_SV:PlayOnOne')
AddEventHandler('InteractSound_SV:PlayOnOne', function(clientNetId, soundFile, soundVolume)
    local src = source
    soundFile, soundVolume = cleanSound(soundFile), cleanVolume(soundVolume)
    clientNetId = tonumber(clientNetId)
    if not soundFile or not clientNetId or not allowed(src) then return end
    -- Depuis un client : seulement vers un joueur proche
    if isPlayer(src) and clientNetId ~= tonumber(src) then
        local a, b = GetPlayerPed(src), GetPlayerPed(clientNetId)
        if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > MAX_DISTANCE then return end
    end
    TriggerClientEvent('InteractSound_CL:PlayOnOne', clientNetId, soundFile, soundVolume)
end)

------
-- RegisterServerEvent InteractSound_SV:PlayOnSource
-- Triggers -> ClientEvent InteractSound_CL:PlayOnSource
--
-- Starts playing a sound locally on a single client, which is the source of the event.
------
RegisterNetEvent('InteractSound_SV:PlayOnSource')
AddEventHandler('InteractSound_SV:PlayOnSource', function(soundFile, soundVolume)
    local src = source
    soundFile, soundVolume = cleanSound(soundFile), cleanVolume(soundVolume)
    if not soundFile or not isPlayer(src) or not allowed(src) then return end
    TriggerClientEvent('InteractSound_CL:PlayOnOne', src, soundFile, soundVolume)
end)

------
-- RegisterServerEvent InteractSound_SV:PlayOnAll
-- Starts playing a sound on all clients who are online in the server.
-- POP : réservé au serveur (TriggerEvent) ; refusé quand il vient d'un client.
------
RegisterNetEvent('InteractSound_SV:PlayOnAll')
AddEventHandler('InteractSound_SV:PlayOnAll', function(soundFile, soundVolume)
    local src = source
    if isPlayer(src) then
        print(('[interact-sound] [^3WARNING^7] %s (%s) a tenté PlayOnAll depuis le client : refusé'):format(GetPlayerName(src) or '?', src))
        return
    end
    soundFile, soundVolume = cleanSound(soundFile), cleanVolume(soundVolume)
    if not soundFile then return end
    TriggerClientEvent('InteractSound_CL:PlayOnAll', -1, soundFile, soundVolume)
end)

------
-- RegisterServerEvent InteractSound_SV:PlayWithinDistance
-- Starts playing a sound on clients within maxDistance of the source player.
-- POP : un seul handler (l'ancien doublon envoyait le son deux fois, dont une fois avec
-- un numéro de joueur à la place des coordonnées) ; distance et volume plafonnés.
------
RegisterNetEvent('InteractSound_SV:PlayWithinDistance')
AddEventHandler('InteractSound_SV:PlayWithinDistance', function(maxDistance, soundFile, soundVolume)
    local src = source
    maxDistance = tonumber(maxDistance)
    soundFile, soundVolume = cleanSound(soundFile), cleanVolume(soundVolume)
    if not isPlayer(src) or not maxDistance or not soundFile then return end
    if maxDistance > MAX_DISTANCE then
        print(('[interact-sound] [^3WARNING^7] %s attempted to trigger InteractSound_SV:PlayWithinDistance over the distance limit %d'):format(GetPlayerName(src) or '?', MAX_DISTANCE))
        return
    end
    if not allowed(src) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    TriggerClientEvent('InteractSound_CL:PlayWithinDistance', -1, GetEntityCoords(ped), maxDistance, soundFile, soundVolume)
end)
