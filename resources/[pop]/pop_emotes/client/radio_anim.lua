local isTransmitting = false

RegisterNetEvent('pma-voice:radioActive')
AddEventHandler('pma-voice:radioActive', function(radioActive)
    isTransmitting = radioActive
    if radioActive then
        -- Play "radio2" emote when transmitting on radio
        if EmotesList and EmotesList.PropEmotes and EmotesList.PropEmotes["radio2"] then
            local ped = PlayerPedId()
            -- Only play if the player is on foot and not dead/cuffed
            if not IsPedInVehicle(ped, GetVehiclePedIsIn(ped, false), false) and not IsPlayerDead(PlayerId()) then
                PlayEmote(EmotesList.PropEmotes["radio2"])
            end
        end
    else
        -- Stop the animation when stopping transmission
        if EmotesList and EmotesList.PropEmotes and EmotesList.PropEmotes["radio2"] then
            if current_emote == EmotesList.PropEmotes["radio2"] then
                StopEmote()
            end
        end
    end
end)
