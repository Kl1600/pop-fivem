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
        for k,v in pairs(FavoritesEmotes) do 
            if v == emote then 
                EmoteNotify({
                    type = 'ROUGE',
                    content = "Vous avez déjà enregistré cette animation"
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
            content = "L'animation à été~c sauvegardé dans vos favoris"
        })
    else
        EmoteNotify({
            type = 'ROUGE',
            content = "Jouez l'animation pour la mettre en favoris"
        })
    end
end

function GetFavoriteEmotesFromCache()
    local cache = GetResourceKvpString("favoritesemotesVision")
    if cache then 
        FavoritesEmotes = json.decode(cache) or {}
    end
end