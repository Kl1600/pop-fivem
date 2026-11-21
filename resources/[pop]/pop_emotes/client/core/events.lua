RegisterNetEvent("emotes:AskForSharedEmote")
AddEventHandler("emotes:AskForSharedEmote", function(emoteName, player)
    local emote = EmotesList.Shared[emoteName]
    if not emote then return end
    EmoteNotify({
        type = 'VERT',
        duration = 5,
        content = "Appuyer sur ~K Y pour accepter l'animation ~s".. tostring(emote[3] or emoteName)
    })
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        while GetGameTimer() < timeout do
            if IsControlJustPressed(0, 246) then
                TriggerServerEvent("emotes:AcceptSharedEmote", emoteName, player)
                return
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent("emotes:PlaySharedEmote")
AddEventHandler("emotes:PlaySharedEmote", function(emoteName, role, player)
    local emote = EmotesList.Shared[emoteName]
    if not emote then return end
    if role == 2 then
        emote = EmotesList.Shared[emote[4]]
        if not emote then return end
    end
    PlaySharedEmote(emote, player)
end)

RegisterNetEvent("emotes:StopEmote")
AddEventHandler("emotes:StopEmote", function()
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
    local player = GetClosestPlayer(3.0)
    if player ~= nil then
        TriggerServerEvent("emotes:AskForSharedEmote", GetPlayerServerId(player), arg)
    else
        EmoteNotify({
            type = 'ROUGE',
            content = "~s Aucun joueur à proximité !"
        })
    end
end)

RegisterNetEvent("emotes:RequestCloneEmote")
AddEventHandler("emotes:RequestCloneEmote", function(player)
    local name = GetCurrentEmoteName()
    if not name or name == '' then
        return
    end
    TriggerServerEvent("emotes:GiveEmoteCloned", player, name)
end )

RegisterNetEvent("emotes:PlayEmote")
AddEventHandler("emotes:PlayEmote", function(emoteName)
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

RegisterNetEvent("emotes:RequestCopyEmote")
AddEventHandler("emotes:RequestCopyEmote", function(requester)
    TriggerServerEvent("emotes:GiveCopiedEmote", requester, current_emote_name or '')
end)

RegisterNetEvent("emotes:ReceiveCopiedEmote")
AddEventHandler("emotes:ReceiveCopiedEmote", function(emoteName)
    local emote = type(emoteName) == 'string' and AllEmotes[emoteName] or nil
    if not emote then return end
    PlayEmote(emote, emoteName)
    local label = (emoteName and emoteName ~= '') and emoteName or 'inconnue'
    EmoteNotify({
        type = 'VERT',
        duration = 4,
        content = 'Vous avez copié et lancé l\'animation ' .. label .. '.'
    })
end)