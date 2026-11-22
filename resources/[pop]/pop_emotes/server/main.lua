-- Les événements relaient une action d'un joueur vers un autre : on vérifie que la
-- cible existe et qu'elle est proche de la source (anti-abus à distance).
-- Seul le NOM de l'emote circule : chaque client la retrouve dans sa propre liste.
local MAX_DIST = Config.ShareMaxDistance
local REQUEST_TTL = Config.ShareRequestTTL -- secondes de validité d'une demande

local pendingShare = {}  -- [cible] = { from = src, name = nom, t = os.time() }
local pendingClone = {}  -- [cible] = { [demandeur] = os.time() }
local partners = {}      -- [joueur] = partenaire de l'emote partagée en cours

local function isNear(src, target)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= MAX_DIST
end

local function validName(name)
    return type(name) == 'string' and #name > 0 and #name <= 64 and name:match('^[%w_%-]+$') ~= nil
end

local function isSharedEmote(name)
    return validName(name) and EmotesList and EmotesList.Shared and EmotesList.Shared[name] ~= nil
end

local function isKnownEmote(name)
    return validName(name) and AllEmotes and AllEmotes[name] ~= nil
end

local function addPendingClone(target, requester)
    pendingClone[target] = pendingClone[target] or {}
    pendingClone[target][requester] = os.time()
end

local function takePendingClone(target, requester)
    local list = pendingClone[target]
    local t = list and list[requester]
    if list then list[requester] = nil end
    return t ~= nil and (os.time() - t) <= REQUEST_TTL
end

-- Emote partagée : demande
RegisterNetEvent("pop_emotes:AskForSharedEmote")
AddEventHandler("pop_emotes:AskForSharedEmote", function(player, emoteName)
    local src = source
    player = tonumber(player)
    if not isNear(src, player) or not isSharedEmote(emoteName) then return end
    pendingShare[player] = { from = src, name = emoteName, t = os.time() }
    TriggerClientEvent("pop_emotes:AskForSharedEmote", player, emoteName, src)
end)

-- Emote partagée : acceptation (seulement si une demande existe)
RegisterNetEvent("pop_emotes:AcceptSharedEmote")
AddEventHandler("pop_emotes:AcceptSharedEmote", function(emoteName, player)
    local src = source
    player = tonumber(player)
    local req = pendingShare[src]
    if not req or req.from ~= player or req.name ~= emoteName or (os.time() - req.t) > REQUEST_TTL then return end
    pendingShare[src] = nil
    if not isNear(src, player) then return end
    partners[src], partners[player] = player, src
    TriggerClientEvent("pop_emotes:PlaySharedEmote", player, emoteName, 1, src)
    TriggerClientEvent("pop_emotes:PlaySharedEmote", src, emoteName, 2, player)
end)

-- Arrêt : seul le partenaire de l'emote partagée peut arrêter l'autre joueur
RegisterNetEvent("pop_emotes:StopEmote")
AddEventHandler("pop_emotes:StopEmote", function(player)
    local src = source
    player = tonumber(player)
    if not player or partners[src] ~= player then return end
    partners[src] = nil
    if partners[player] == src then partners[player] = nil end
    TriggerClientEvent("pop_emotes:StopEmote", player)
end)

-- Cloner l'emote d'un joueur proche
RegisterNetEvent("pop_emotes:CloneEmote")
AddEventHandler("pop_emotes:CloneEmote", function(player)
    local src = source
    player = tonumber(player)
    if not isNear(src, player) then return end
    addPendingClone(player, src)
    TriggerClientEvent("pop_emotes:RequestCloneEmote", player, src)
end)

RegisterNetEvent("pop_emotes:GiveEmoteCloned")
AddEventHandler("pop_emotes:GiveEmoteCloned", function(player, emoteName)
    local src = source
    player = tonumber(player)
    if not takePendingClone(src, player) or not isNear(src, player) or not isKnownEmote(emoteName) then return end
    TriggerClientEvent("pop_emotes:PlayEmote", player, emoteName)
end)

-- Copier l'emote d'un joueur (export CopyEmoteFromPlayer)
RegisterNetEvent("pop_emotes:CopyEmoteFromPlayer")
AddEventHandler("pop_emotes:CopyEmoteFromPlayer", function(targetPlayer)
    local requester = source
    targetPlayer = tonumber(targetPlayer)
    if not isNear(requester, targetPlayer) then return end
    addPendingClone(targetPlayer, requester)
    TriggerClientEvent("pop_emotes:RequestCopyEmote", targetPlayer, requester)
end)

RegisterNetEvent("pop_emotes:GiveCopiedEmote")
AddEventHandler("pop_emotes:GiveCopiedEmote", function(requester, emoteName)
    local src = source
    requester = tonumber(requester)
    if not takePendingClone(src, requester) or not isNear(src, requester) then return end
    if not isKnownEmote(emoteName) then emoteName = nil end
    TriggerClientEvent("pop_emotes:ReceiveCopiedEmote", requester, emoteName)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingShare[src] = nil
    pendingClone[src] = nil
    local p = partners[src]
    if p and partners[p] == src then partners[p] = nil end
    partners[src] = nil
end)
