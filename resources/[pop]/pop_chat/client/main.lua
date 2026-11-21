local activeMessages = {}
local DISPLAY_TIME = 6000 -- ms d'affichage au-dessus de la tête

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
    local expireAt = GetGameTimer() + DISPLAY_TIME
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
RegisterCommand('me', function(source, args)
    if #args == 0 then return end
    local message = table.concat(args, ' ')
    TriggerServerEvent('pop_chat:me', message)
end, false)

TriggerEvent('chat:addSuggestion', '/me', 'Affiche une action roleplay au-dessus de votre tête', {
    { name = 'action', help = 'Ex: sort son téléphone' }
})
