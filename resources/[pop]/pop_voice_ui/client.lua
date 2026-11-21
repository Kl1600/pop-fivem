local uiVisible = false

local function SetUIVisible(visible)
    uiVisible = visible
    SendNUIMessage({
        action = visible and 'show' or 'hide'
    })
end

RegisterCommand('voice-ui', function()
    SetUIVisible(not uiVisible)
end)

CreateThread(function()
    local playerId = PlayerId()
    local wasTalking = false
    while true do
        if uiVisible then
            local isTalking = MumbleIsPlayerTalking(playerId) == 1

            if isTalking then
                -- Simulate volume for the "débit vocal" look
                -- Native volume detection in FiveM is complex without submix monitoring,
                -- so we simulate a flow between 60% and 100% when talking is detected.
                SendNUIMessage({
                    action = 'voiceLevel',
                    volume = 0.6 + (math.random() * 0.4)
                })
            elseif wasTalking then
                -- Silence : un seul message suffit
                SendNUIMessage({
                    action = 'voiceLevel',
                    volume = 0.0
                })
            end
            wasTalking = isTalking

            Wait(50) -- 20 FPS UI update for smooth bar
        else
            wasTalking = false
            Wait(500)
        end
    end
end)
