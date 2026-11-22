-- Vie, faim, soif, heure et voix envoyées à l'interface (seulement quand une valeur change).

-- État partagé entre les fichiers client du HUD
Hud = {
    show  = true,   -- hud:toggleui
    ready = false,  -- personnage chargé (pas d'affichage sous l'écran de connexion)
    food  = 100,
    water = 100,
}

local function clamp(value)
    return math.max(0, math.min(100, value))
end

-- Désactive l'interface par défaut de pma-voice
local function hidePmaVoiceUi()
    if GetResourceState('pma-voice') ~= 'started' then return end
    exports['pma-voice']:setVoiceProperty('displayUi', false)
    exports['pma-voice']:setVoiceProperty('uiEnabled', false)
end

-- Une fois au démarrage, puis à chaque (re)démarrage de pma-voice
CreateThread(function()
    Wait(2000)
    hidePmaVoiceUi()
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == 'pma-voice' then
        SetTimeout(1000, hidePmaVoiceUi)
    end
end)

-- Les autres ressources mettent à jour faim / soif par évènement ou export
RegisterNetEvent('hud:setFood')
AddEventHandler('hud:setFood', function(value)
    Hud.food = clamp(value)
end)

RegisterNetEvent('hud:setWater')
AddEventHandler('hud:setWater', function(value)
    Hud.water = clamp(value)
end)

exports('setFood',  function(value) Hud.food  = clamp(value) end)
exports('setWater', function(value) Hud.water = clamp(value) end)

-- Passerelle esx_status
AddEventHandler('esx_status:onTick', function(status)
    for i = 1, #status do
        if status[i].name == 'hunger' then
            Hud.food = status[i].percent
        elseif status[i].name == 'thirst' then
            Hud.water = status[i].percent
        end
    end
end)

RegisterNetEvent('hud:toggleui')
AddEventHandler('hud:toggleui', function(show)
    Hud.show = show == true
end)

local voiceModes = { Whisper = 1, Normal = 2, Shouting = 3 }
local last = {}

CreateThread(function()
    local playerId = PlayerId()
    while true do
        -- Vie en % (le max diffère entre ped homme 200 et femme 175)
        local ped = PlayerPedId()
        local maxHealth = GetEntityMaxHealth(ped) - 100
        local health = maxHealth > 0 and math.floor((GetEntityHealth(ped) - 100) / maxHealth * 100 + 0.5) or 0
        local showHud = Hud.show and Hud.ready and not LocalPlayer.state.charcreatorOpen
        local _, _, _, hours, minutes = GetLocalTime()

        -- Mode de voix (pma-voice)
        local voiceMode = 2 -- Normal par défaut
        local proximity = LocalPlayer.state.proximity
        if proximity then
            voiceMode = voiceModes[proximity.mode] or voiceMode
        end

        local isTalking = NetworkIsPlayerTalking(playerId)
        local hasRadio  = LocalPlayer.state.hasRadio == true
        local food, water = Hud.food, Hud.water

        if last.show ~= showHud or last.health ~= health or last.food ~= food or last.water ~= water
            or last.hours ~= hours or last.minutes ~= minutes or last.voiceMode ~= voiceMode
            or last.isTalking ~= isTalking or last.hasRadio ~= hasRadio then
            last.show, last.health, last.food, last.water = showHud, health, food, water
            last.hours, last.minutes, last.voiceMode = hours, minutes, voiceMode
            last.isTalking, last.hasRadio = isTalking, hasRadio
            SendNUIMessage({
                action    = 'updateStatusHud',
                show      = showHud,
                health    = health,
                food      = food,
                water     = water,
                hours     = hours,
                minutes   = minutes,
                voiceMode = voiceMode,
                isTalking = isTalking,
                hasRadio  = hasRadio,
            })
        end
        Wait(Config.StatusRefresh)
    end
end)

local function updateAdminOverlay(show, activeReports)
    SendNUIMessage({
        action        = 'updateAdminOverlay',
        show          = show,
        activeReports = activeReports,
    })
end

exports('updateAdminOverlay', updateAdminOverlay)

-- Fermeture de la checklist mécanique depuis la NUI
RegisterNUICallback('closeChecklist', function(_, cb)
    cb('ok')
end)
