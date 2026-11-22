-- Barre d'activité vocale : /voice-ui affiche ou cache la barre, qui suit le micro (MumbleIsPlayerTalking).

local uiVisible = false

local function SetUIVisible(visible)
    uiVisible = visible
    SendNUIMessage({
        action = visible and 'show' or 'hide'
    })
    if Config.Debug then print(('[pop_voice_ui] barre %s'):format(visible and 'affichée' or 'cachée')) end
end

RegisterCommand(Config.Command, function()
    SetUIVisible(not uiVisible)
end)

CreateThread(function()
    local playerId = PlayerId()
    local wasTalking = false
    while true do
        if uiVisible then
            local isTalking = MumbleIsPlayerTalking(playerId) == true -- booléen, pas 1

            if isTalking then
                -- Simulate volume for the "débit vocal" look
                -- Native volume detection in FiveM is complex without submix monitoring,
                -- so we simulate a flow between 60% and 100% when talking is detected.
                SendNUIMessage({
                    action = 'voiceLevel',
                    volume = Config.VolumeMin + (math.random() * Config.VolumeRange)
                })
            elseif wasTalking then
                -- Silence : un seul message suffit
                SendNUIMessage({
                    action = 'voiceLevel',
                    volume = 0.0
                })
            end
            wasTalking = isTalking

            Wait(Config.ActiveInterval) -- 20 FPS UI update for smooth bar
        else
            wasTalking = false
            Wait(Config.IdleInterval)
        end
    end
end)
