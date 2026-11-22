local lastMe = {}

-- Nom RP (prénom nom du personnage), sinon nom du compte
local function GetRpName(src)
    local name = Bridge.GetName(src)
    if name and name ~= '' then return name end
    return GetPlayerName(src)
end

AddEventHandler('playerDropped', function()
    lastMe[source] = nil
end)

RegisterNetEvent('pop_chat:me', function(message)
    local src = source

    -- Une action /me toutes les Config.Cooldown ms maximum
    local now = GetGameTimer()
    if lastMe[src] and now - lastMe[src] < Config.Cooldown then return end
    lastMe[src] = now

    if type(message) ~= 'string' or message == '' then return end
    message = message:gsub('<', '&lt;'):gsub('>', '&gt;')
    if #message > Config.MaxLength then message = message:sub(1, Config.MaxLength) end

    local playerName   = GetRpName(src)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))

    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local otherPed = GetPlayerPed(id)
        if otherPed ~= 0 and #(playerCoords - GetEntityCoords(otherPed)) <= Config.Distance then
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
