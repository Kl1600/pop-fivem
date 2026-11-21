local toghud = true
local minimapScaleform = RequestScaleformMovie("minimap")
local hudFood   = 100
local hudWater  = 100

-- Disable pma-voice default UI
local function hidePmaVoiceUi()
    if GetResourceState('pma-voice') ~= 'started' then return end
    exports['pma-voice']:setVoiceProperty('displayUi', false)
    exports['pma-voice']:setVoiceProperty('uiEnabled', false)
end

CreateThread(function()
    while true do
        hidePmaVoiceUi()
        Wait(5000)
    end
end)

-- Other resources update food/water via events or exports
RegisterNetEvent('hud:setFood')
AddEventHandler('hud:setFood', function(value)
    hudFood = math.max(0, math.min(100, value))
end)

RegisterNetEvent('hud:setWater')
AddEventHandler('hud:setWater', function(value)
    hudWater = math.max(0, math.min(100, value))
end)

exports('setFood',  function(value) hudFood  = math.max(0, math.min(100, value)) end)
exports('setWater', function(value) hudWater = math.max(0, math.min(100, value)) end)

-- Bridge for esx_status
AddEventHandler('esx_status:onTick', function(status)
    for i=1, #status do
        if status[i].name == 'hunger' then
            hudFood = status[i].percent
        elseif status[i].name == 'thirst' then
            hudWater = status[i].percent
        end
    end
end)


RegisterNetEvent('hud:toggleui')
AddEventHandler('hud:toggleui', function(show)
    toghud = show == true
end)

-- Update health / food / water / clock : envoi NUI uniquement si une valeur change
local voiceModes = { Whisper = 1, Normal = 2, Shouting = 3 }
local last = {}

CreateThread(function()
    local playerId = PlayerId()
    while true do
        local health = GetEntityHealth(PlayerPedId()) - 100
        local _, _, _, hours, minutes = GetLocalTime()

        -- Voice Mode (pma-voice)
        local voiceMode = 2 -- Default to Normal
        local proximity = LocalPlayer.state.proximity
        if proximity then
            voiceMode = voiceModes[proximity.mode] or voiceMode
        end

        local isTalking = NetworkIsPlayerTalking(playerId)
        local hasRadio  = LocalPlayer.state.hasRadio == true

        if last.show ~= toghud or last.health ~= health or last.food ~= hudFood or last.water ~= hudWater
            or last.hours ~= hours or last.minutes ~= minutes or last.voiceMode ~= voiceMode
            or last.isTalking ~= isTalking or last.hasRadio ~= hasRadio then
            last.show, last.health, last.food, last.water = toghud, health, hudFood, hudWater
            last.hours, last.minutes, last.voiceMode = hours, minutes, voiceMode
            last.isTalking, last.hasRadio = isTalking, hasRadio
            SendNUIMessage({
                action    = 'updateStatusHud',
                show      = toghud,
                health    = health,
                food      = hudFood,
                water     = hudWater,
                hours     = hours,
                minutes   = minutes,
                voiceMode = voiceMode,
                isTalking = isTalking,
                hasRadio  = hasRadio,
            })
        end
        Wait(200)
    end
end)

local function InitMinimap()
    RequestStreamedTextureDict("circlemap", false)
    while not HasStreamedTextureDictLoaded("circlemap") do
        Wait(100)
    end
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
    SetMinimapClipType(1)
    
    -- Correctly position the map tiles behind the mask
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, 0.002, 0.150, 0.18888)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.021, 0.032, 0.1112, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.0005, 0.008, 0.199999, 0.272)
    
    -- Correct refresh logic (Toggle true then false)
    DisplayRadar(true)
    SetRadarBigmapEnabled(true, false)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
end

-- Restore minimap mask/background but keep it sharp (no blur)
local uiHidden = false
CreateThread(function()
    InitMinimap()

    while true do
        -- Ces réglages radar sont des propriétés persistantes : les réappliquer
        -- ~5x/s suffit (au lieu de chaque frame) → gros gain resmon sans changement visuel.
        Wait(200)
        -- Force radar visibility (hide when pause menu is active, HUD toggle is
        -- disabled, ou pendant le créateur de personnage -> évite le clignotement)
        local pauseActive = IsPauseMenuActive()
        if pauseActive or not toghud or LocalPlayer.state.charcreatorOpen then
            DisplayRadar(false)
        else
            DisplayRadar(true)
        end
        -- Lock zoom to prevent tiles from disappearing at low speed/on foot
        SetRadarZoom(1100)

        if not HasStreamedTextureDictLoaded("circlemap") then
            RequestStreamedTextureDict("circlemap", false)
            AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
        end

        BeginScaleformMovieMethod(minimapScaleform, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()

        -- Hide HUD when big map or radar is active
        if IsBigmapActive() or IsRadarHidden() or pauseActive then
            if not uiHidden then
                SendNUIMessage({ action = "hideUI" })
                uiHidden = true
            end
        elseif uiHidden then
            SendNUIMessage({ action = "displayUI" })
            uiHidden = false
        end
    end
end)

-- Re-initialize on player loaded or spawned to prevent default rect map overrides
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    CreateThread(function()
        Wait(2000) -- Wait for spawn sequences to settle
        InitMinimap()
    end)
end)

RegisterNetEvent('playerSpawned')
AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(2000) -- Wait for spawn sequences to settle
        InitMinimap()
    end)
end)

local function updateAdminOverlay(show, activeReports)
    SendNUIMessage({
        action        = 'updateAdminOverlay',
        show          = show,
        activeReports = activeReports,
    })
end

exports('updateAdminOverlay', updateAdminOverlay)
