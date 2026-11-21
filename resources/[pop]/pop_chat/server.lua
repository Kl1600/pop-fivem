local DISTANCE = 20.0

RegisterNetEvent('pop_chat:me', function(message)
    local src = source

    if type(message) ~= 'string' or message == '' then return end
    message = message:gsub('<', '&lt;'):gsub('>', '&gt;')
    if #message > 200 then message = message:sub(1, 200) end

    local playerName   = GetPlayerName(src)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))

    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local otherPed = GetPlayerPed(id)
        if otherPed ~= 0 and #(playerCoords - GetEntityCoords(otherPed)) <= DISTANCE then
            -- Affiche au-dessus de la tête
            TriggerClientEvent('pop_chat:showMe', id, src, playerName, message)
            -- Affiche aussi dans le chat local
            TriggerClientEvent('chat:addMessage', id, {
                color     = { 255, 255, 255 },
                multiline = true,
                args      = { '', message }
            })
        end
    end
end)
