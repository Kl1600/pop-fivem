RegisterNetEvent("pop_emotes:AskForSharedEmote")
AddEventHandler("pop_emotes:AskForSharedEmote", function(emoteName, player)
    local emote = EmotesList.Shared[emoteName]
    if not emote then return end
    EmoteNotify({
        type = 'VERT',
        duration = 5,
        content = L('share_accept', tostring(emote[3] or emoteName))
    })
    CreateThread(function()
        local timeout = GetGameTimer() + Config.ShareAcceptTime
        while GetGameTimer() < timeout do
            if IsControlJustPressed(0, 246) then
                TriggerServerEvent("pop_emotes:AcceptSharedEmote", emoteName, player)
                return
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent("pop_emotes:PlaySharedEmote")
AddEventHandler("pop_emotes:PlaySharedEmote", function(emoteName, role, player)
    local emote = EmotesList.Shared[emoteName]
    if not emote then return end
    if role == 2 then
        emote = EmotesList.Shared[emote[4]]
        if not emote then return end
    end
    PlaySharedEmote(emote, player)
end)

RegisterNetEvent("pop_emotes:StopEmote")
AddEventHandler("pop_emotes:StopEmote", function()
    StopEmote()
end)

RegisterCommand("e", function(source, args)
    local emoteKey = args[1]
    local emote = args[1]
    if emote == nil then
        return
    end
    if emote == "c" then
        StopEmote()
        return
    end
    -- find the emote in all emotes
    -- Recherche directe par clé (au lieu de parcourir toutes les listes)
    local found = nil
    for _, emoteList in pairs(EmotesList) do
        if type(emoteList) == 'table' and emoteList[emoteKey] then
            found = emoteList[emoteKey]
            break
        end
    end

    if found == nil then
        return
    end
    emote = found

    PlayEmote(emote, emoteKey)
end)

local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

RegisterCommand("walk", function(source, args)
    if not args[1] then return end
    local arg = firstToUpper(args[1])
    if EmotesList.Walks[arg] then
        RequestWalking(EmotesList.Walks[arg][1])
        SetPedMovementClipset(PlayerPedId(), EmotesList.Walks[arg][1], 0.2)
        SetResourceKvp('demarcheVision',tostring(EmotesList.Walks[arg][1]))
    end
end)

RegisterCommand("nearby", function(source, args)
    if not args[1] then return end
    local arg = args[1]
    if not EmotesList.Shared[arg] then return end
    local player = GetClosestPlayer(Config.NearbyRadius)
    if player ~= nil then
        TriggerServerEvent("pop_emotes:AskForSharedEmote", GetPlayerServerId(player), arg)
    else
        EmoteNotify({
            type = 'ROUGE',
            content = L('no_player_nearby')
        })
    end
end)

RegisterNetEvent("pop_emotes:RequestCloneEmote")
AddEventHandler("pop_emotes:RequestCloneEmote", function(player)
    local name = GetCurrentEmoteName()
    if not name or name == '' then
        return
    end
    TriggerServerEvent("pop_emotes:GiveEmoteCloned", player, name)
end )

RegisterNetEvent("pop_emotes:PlayEmote")
AddEventHandler("pop_emotes:PlayEmote", function(emoteName)
    local emote = type(emoteName) == 'string' and AllEmotes[emoteName] or nil
    if not emote then return end
    PlayEmote(emote, emoteName)
end)

CreateThread(function()
    while not HasModelLoaded(GetEntityModel(PlayerPedId())) do Wait(500) end
    Wait(250)
    local demarche = GetResourceKvpString('demarcheVision')
    GetFavoriteEmotesFromCache()
    if demarche then
        RequestWalking(demarche)
        SetPedMovementClipset(PlayerPedId(), demarche, 0.2)
    end
end)

RegisterNetEvent("pop_emotes:RequestCopyEmote")
AddEventHandler("pop_emotes:RequestCopyEmote", function(requester)
    TriggerServerEvent("pop_emotes:GiveCopiedEmote", requester, current_emote_name or '')
end)

RegisterNetEvent("pop_emotes:ReceiveCopiedEmote")
AddEventHandler("pop_emotes:ReceiveCopiedEmote", function(emoteName)
    local emote = type(emoteName) == 'string' and AllEmotes[emoteName] or nil
    if not emote then return end
    PlayEmote(emote, emoteName)
    local label = (emoteName and emoteName ~= '') and emoteName or L('unknown_emote')
    EmoteNotify({
        type = 'VERT',
        duration = 4,
        content = L('copied_emote', label)
    })
end)