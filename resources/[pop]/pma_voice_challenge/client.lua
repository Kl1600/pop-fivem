local uiVisible = false

function SetUIVisible(visible)
    uiVisible = visible
    SendNUIMessage({
        action = visible and 'show' or 'hide'
    })
    -- Pas de focus NUI : il bloquerait la touche push-to-talk dont le joueur a besoin ici.
end

-- (Commandes de test /voice-ui et /spawn-thornton retirées : /voice-ui est fourni par pop_voice_ui.)

-- Listen for Escape or NUI close events if needed
RegisterNUICallback('close', function(data, cb)
    SetUIVisible(false)
    cb('ok')
end)

RegisterNUICallback('finish', function(data, cb)
    if not uiVisible then cb('ok') return end
    SetUIVisible(false)
    TriggerEvent('pma_voice_challenge:finished', data.success == true)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiVisible then SetUIVisible(false) end
end)

exports('StartChallenge', function()
    SetUIVisible(true)
end)

-- Voice Detection Loop
Citizen.CreateThread(function()
    local lastTalking = false
    while true do
        if uiVisible then
            -- MumbleIsPlayerTalking renvoie un booléen (le test '== 1' était toujours faux)
            local isTalking = MumbleIsPlayerTalking(PlayerId()) == true
            
            if isTalking ~= lastTalking then
                lastTalking = isTalking
                SendNUIMessage({
                    action = 'voiceStatus',
                    talking = isTalking
                })
            end
            
            -- Optional: if we want to simulate volume changes more frequently when talking
            if isTalking then
                SendNUIMessage({
                    action = 'voiceStatus',
                    talking = true,
                    volume = 0.6 + (math.random() * 0.4) 
                })
            end
            
            Wait(50) 
        else
            Wait(500) 
        end
    end
end)
