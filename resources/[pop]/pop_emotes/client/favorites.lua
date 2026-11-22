-- luacheck: ignore 131
FavoritesEmotes = {}

function RegisterFavoriteEmote()
    if current_emote ~= nil then
        local emote = ""
        for k,v in pairs(AllEmotes) do
            if v[3] == current_emote[3] then
                emote = k
            end
        end
        local goodgo = true
        for _,v in pairs(FavoritesEmotes) do
            if v == emote then
                EmoteNotify({
                    type = 'ROUGE',
                    content = L('fav_already')
                })
                goodgo = false
                break
            end
        end
        if not goodgo then return end
        table.insert(FavoritesEmotes, emote)
        SetResourceKvp("favoritesemotesVision",json.encode(FavoritesEmotes))
        EmoteNotify({
            type = 'VERT',
            content = L('fav_saved')
        })
    else
        EmoteNotify({
            type = 'ROUGE',
            content = L('fav_need_emote')
        })
    end
end

function GetFavoriteEmotesFromCache()
    local cache = GetResourceKvpString("favoritesemotesVision")
    if cache then
        FavoritesEmotes = json.decode(cache) or {}
    end
end