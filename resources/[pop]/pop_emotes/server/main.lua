-- Les événements relaient une action d'un joueur vers un autre : on vérifie que la
-- cible existe et qu'elle est proche de la source (anti-abus à distance).
local MAX_DIST = 10.0

local function isNear(src, target)
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= MAX_DIST
end

RegisterNetEvent("emotes:AskForSharedEmote")
AddEventHandler("emotes:AskForSharedEmote", function(player, emote)
    local src = source
    if not isNear(src, player) or type(emote) ~= "table" then return end
    TriggerClientEvent("emotes:AskForSharedEmote", player, emote, src)
end)

RegisterNetEvent("emotes:AcceptSharedEmote")
AddEventHandler("emotes:AcceptSharedEmote", function(emote, player)
    local src = source
    if not isNear(src, player) or type(emote) ~= "table" then return end
    TriggerClientEvent("emotes:PlaySharedEmote", player, emote, 1, src)
    TriggerClientEvent("emotes:PlaySharedEmote", src, emote, 2, player)
end)

RegisterNetEvent("emotes:StopEmote")
AddEventHandler("emotes:StopEmote", function(player)
    if not isNear(source, player) then return end
    TriggerClientEvent("emotes:StopEmote", player)
end)

RegisterNetEvent("emotes:CloneEmote")
AddEventHandler("emotes:CloneEmote", function(player)
    local src = source
    if not isNear(src, player) then return end
    TriggerClientEvent("emotes:RequestCloneEmote", player, src)
end)

RegisterNetEvent("emotes:GiveEmoteCloned")
AddEventHandler("emotes:GiveEmoteCloned", function(player, emote)
    if not isNear(source, player) or type(emote) ~= "table" then return end
    TriggerClientEvent("emotes:PlayEmote", player, emote)
end)

RegisterNetEvent("emotes:CopyEmoteFromPlayer")
AddEventHandler("emotes:CopyEmoteFromPlayer", function(targetPlayer)
    local requester = source
    if not isNear(requester, targetPlayer) then return end
    TriggerClientEvent("emotes:RequestCopyEmote", targetPlayer, requester)
end)

RegisterNetEvent("emotes:GiveCopiedEmote")
AddEventHandler("emotes:GiveCopiedEmote", function(requester, emote, emoteName)
    if not isNear(source, requester) then return end
    TriggerClientEvent("emotes:ReceiveCopiedEmote", requester, emote, emoteName)
end)
