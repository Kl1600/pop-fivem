local isMenuOpen = false
local inputFocused = false

function SetNuiState(state)
    isMenuOpen = state
    if not state then
        inputFocused = false
    end
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(state) -- Allows moving while NUI is focused
    SendNUIMessage({
        type = "toggle",
        display = state
    })

    if state then
        -- Affiche le perso solide à l'écran pendant que le menu est ouvert
        CreateThread(StartPedPreview)
    else
        StopPedPreview()
        -- Disable ESC for a few frames to prevent pause menu from popping up
        CreateThread(function()
            local ticks = 15
            while ticks > 0 do
                Wait(0)
                ticks = ticks - 1
                DisableControlAction(0, 200, true)
                DisableControlAction(0, 199, true)
                DisableControlAction(0, 322, true)
            end
        end)
    end
end

RegisterNUICallback("close", function(_, cb)
    SetNuiState(false)
    if cb then cb("ok") end
end)

RegisterNUICallback("inputFocus", function(data, cb)
    inputFocused = data.focus == true
    SetNuiFocusKeepInput(not inputFocused)
    cb("ok")
end)

-- Sending animations data to UI
RegisterNUICallback("getAnimations", function(data, cb)
    local response = {
        emotes = {},
        dances = {},
        props = {},
        walks = {},
        expressions = {},
        shared = {}
    }

    if _G.EmotesList then
        -- Map of RPEmotes categories to our UI categories
        local mapping = {
            ["Dances"] = "dances",
            ["PropEmotes"] = "props",
            ["Walks"] = "walks",
            ["Expressions"] = "expressions",
            ["Shared"] = "shared"
        }

        for categoryName, categoryTable in pairs(EmotesList) do
            local key = mapping[categoryName] or "emotes"
            local count = 0
            if type(categoryTable) == "table" then
                for emoteName, emoteData in pairs(categoryTable) do
                    count = count + 1
                    local label
                    -- Standard RPEmotes format: [1]=dict, [2]=anim, [3]=label
                    -- Walks/Expressions format: [1]=dict/style, [2]=label
                    if key == "walks" or key == "expressions" then
                        label = emoteData[2] or emoteName
                    else
                        label = emoteData[3] or emoteName
                    end
                    response[key][emoteName] = label
                end
            end
        end
    end

    cb(response)
end)

RegisterNUICallback("previewEmote", function(data, cb)
    local emote = data.emote
    local category = data.category

    if not previewActive or emotePed == nil or not DoesEntityExist(emotePed) then
        cb('ok')
        return
    end

    if emote == "c" then
        ClearPedTasksImmediately(emotePed)
        DestroyCloneAttachedProps()
        cb('ok')
        return
    end

    -- Pas d'anim jouable pour les démarches / humeurs : on ne prévisualise pas
    if category == "walks" or category == "expressions" then
        cb('ok')
        return
    end

    local emoteData = nil

    if category == "shared" then
        emoteData = EmotesList.Shared[emote]
    else
        for _, catTable in pairs(EmotesList) do
            if catTable[emote] then
                emoteData = catTable[emote]
                break
            end
        end
    end

    if emoteData then
        PreviewEmote(emoteData)
    end
    cb('ok')
end)

RegisterNUICallback("playEmote", function(data, cb)
    local emote = data.emote
    local category = data.category

    if emote == "c" then
        ExecuteCommand("e c")
        cb('ok')
        return
    end

    if category == "expressions" then
        if EmotesList.Expressions and EmotesList.Expressions[emote] then
            SetFacialIdleAnimOverride(PlayerPedId(), EmotesList.Expressions[emote][1])
        end
    elseif category == "walks" then
        ExecuteCommand("walk " .. emote)
    elseif category == "shared" then
        ExecuteCommand("nearby " .. emote)
    else
        ExecuteCommand("e " .. emote)
    end
    cb('ok')
end)

RegisterCommand('animenu', function()
    SetNuiState(not isMenuOpen)
end)

-- Touche d'ouverture (Config.MenuKey, F5 par défaut) via key mapping : plus de boucle par frame au repos.
RegisterKeyMapping('animenu', L('keymap_menu'), 'keyboard', Config.MenuKey)

-- Boucle de contrôles : par frame uniquement quand le menu est ouvert.
CreateThread(function()
    while true do
        if not isMenuOpen then
            Wait(250)
        else
            Wait(0)
        end
        if isMenuOpen then
            if inputFocused then
                DisableAllControlActions(0)
            else
                -- Disable camera look to allow mouse interaction without turning
                DisableControlAction(0, 1, true) -- LookLeftRight
                DisableControlAction(0, 2, true) -- LookUpDown
                DisableControlAction(0, 106, true) -- VehicleMouseControlOverride

                -- Disable actions that might interfere or cause bugs
                DisableControlAction(0, 200, true) -- pause menu
                DisableControlAction(0, 199, true) -- pause menu
                DisableControlAction(0, 322, true) -- pause menu
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 257, true) -- Attack 2
                DisableControlAction(0, 25, true) -- Aim
                DisableControlAction(0, 263, true) -- Melee Attack 1
                DisableControlAction(0, 140, true) -- Melee Attack Light
                DisableControlAction(0, 141, true) -- Melee Attack Heavy
                DisableControlAction(0, 142, true) -- Melee Attack Alternate
                DisableControlAction(0, 81, true) -- Radio Next
                DisableControlAction(0, 82, true) -- Radio Previous
            end

            -- Allow characters movement (WASD/Joystick)
            -- These are NOT disabled by default, so character will move

            if IsControlJustPressed(0, 202) then -- ESC
                SetNuiState(false)
            end
        end
    end
end)
