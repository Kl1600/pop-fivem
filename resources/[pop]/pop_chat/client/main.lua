local activeMessages = {}

-- Dessine du texte flottant en 3D dans le monde
local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local dist = #(GetGameplayCamCoords() - vector3(x, y, z))
    local scale = (1 / dist) * 2.0
    local fov   = (1 / GetGameplayCamFov()) * 100.0
    scale = scale * fov

    SetTextScale(0.0, scale * 0.6)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow()
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

-- Reçoit les /me des autres joueurs (et du soi-même)
RegisterNetEvent('pop_chat:showMe', function(netId, playerName, message)
    local expireAt = GetGameTimer() + Config.DisplayTime
    -- Remplace si le joueur a déjà un message actif
    for i, entry in ipairs(activeMessages) do
        if entry.netId == netId then
            table.remove(activeMessages, i)
            break
        end
    end
    table.insert(activeMessages, { netId = netId, name = playerName, text = message, expireAt = expireAt })
end)

-- Boucle d'affichage
CreateThread(function()
    while true do
        -- Attente adaptative : on ne dessine à chaque frame que s'il y a un /me actif.
        Wait(#activeMessages > 0 and 0 or 500)
        local now = GetGameTimer()
        local i = 1
        while i <= #activeMessages do
            local entry = activeMessages[i]
            if now >= entry.expireAt then
                table.remove(activeMessages, i)
            else
                local ped = GetPlayerPed(GetPlayerFromServerId(entry.netId))
                if DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    DrawText3D(coords.x, coords.y, coords.z + 1.15, entry.text)
                end
                i = i + 1
            end
        end
    end
end)

-- Enregistrement de la commande
RegisterCommand('me', function(_, args)
    if #args == 0 then return end
    local message = table.concat(args, ' ')
    TriggerServerEvent('pop_chat:me', message)
end, false)

TriggerEvent('chat:addSuggestion', '/me', L('me_suggestion'), {
    { name = L('me_suggestion_arg'), help = L('me_suggestion_help') }
})

-- =====================================================================
--  Le chat se cache quand un menu s'ouvre devant lui
-- =====================================================================
-- Menu = une interface qui prend la souris (sauf la saisie du chat elle-même),
-- le menu admin, ou tout script qui met LocalPlayer.state.popMenuOpen à true.
CreateThread(function()
    local hidden, typing, typingFocused, typingSince = false, false, false, 0

    while true do
        Wait(100)
        local focused = IsNuiFocused()

        -- Touche T : c'est la saisie du chat qui va prendre la souris, pas un menu.
        if not typing and not focused and IsControlPressed(0, 245) then
            typing, typingFocused, typingSince = true, false, GetGameTimer()
        end
        if typing then
            if focused then
                typingFocused = true
            elseif typingFocused or GetGameTimer() - typingSince > 2000 then
                typing = false
            end
        end

        local adminOpen = false
        if GetResourceState('pop_admin') == 'started' then
            local ok, open = pcall(function() return exports.pop_admin:IsMenuOpen() end)
            adminOpen = ok and open == true
        end

        local menuOpen = (focused and not typing) or adminOpen or LocalPlayer.state.popMenuOpen == true
        if menuOpen ~= hidden then
            hidden = menuOpen
            ExecuteCommand(menuOpen and 'toggleChat hidden' or 'toggleChat whenactive')
        end
    end
end)
