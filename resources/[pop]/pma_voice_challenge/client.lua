local uiVisible = false

function SetUIVisible(visible)
    uiVisible = visible
    SendNUIMessage({
        action = visible and 'show' or 'hide'
    })
    SetNuiFocus(visible, visible)
end

RegisterCommand('voice-ui', function()
    SetUIVisible(not uiVisible)
end)

local thorntonPed = nil
RegisterCommand('spawn-thornton', function()
    local model = GetHashKey('ig_thornton')
    local spawnPos = vector4(-72.6626, 84.9975, 71.4851, 57.4806)
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    if DoesEntityExist(thorntonPed) then DeleteEntity(thorntonPed) end
    
    thorntonPed = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, spawnPos.w, true, true)
    
    -- Matching components from grandtheftauto script
    SetPedPropIndex(thorntonPed, 0, 0, 0, true)
    
    -- Basic NPC settings
    SetEntityInvincible(thorntonPed, true)
    SetBlockingOfNonTemporaryEvents(thorntonPed, true)
    SetEntityAsMissionEntity(thorntonPed, true, true)
    
    -- Optional: move clipset if you want him to have the same "depressed" walk
    local moveClipset = "move_f@depressed@a"
    RequestAnimSet(moveClipset)
    while not HasAnimSetLoaded(moveClipset) do Wait(1) end
    SetPedMovementClipset(thorntonPed, moveClipset, 1.0)
    
    print("Thornton Duggan spawned at original location.")

    -- Make him talk for 10 seconds
    Citizen.CreateThread(function()
        local duration = 10000
        local startTime = GetGameTimer()
        
        -- Override facial animation to 'talking'
        SetFacialIdleAnimOverride(thorntonPed, "mood_talking_1", 0)
        
        -- Display subtitle (using GTA native style)

        while GetGameTimer() - startTime < duration do
            if not DoesEntityExist(thorntonPed) then break end
            Wait(100)
        end
        
        if DoesEntityExist(thorntonPed) then
            ClearFacialIdleAnimOverride(thorntonPed)
        end
    end)
end)

-- Listen for Escape or NUI close events if needed
RegisterNUICallback('close', function(data, cb)
    SetUIVisible(false)
    cb('ok')
end)

RegisterNUICallback('finish', function(data, cb)
    SetUIVisible(false)
    TriggerEvent('pma_voice_challenge:finished', data.success)
    cb('ok')
end)

exports('StartChallenge', function()
    SetUIVisible(true)
end)

-- Voice Detection Loop
Citizen.CreateThread(function()
    local lastTalking = false
    while true do
        if uiVisible then
            local isTalking = MumbleIsPlayerTalking(PlayerId()) == 1
            
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
