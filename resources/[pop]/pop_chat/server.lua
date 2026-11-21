local DISTANCE = 20.0
local COOLDOWN_MS = 2000
local lastMe = {}

local ESX = nil
if GetResourceState('es_extended') ~= 'missing' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok then ESX = obj end
end

-- Nom RP (prénom nom ESX), sinon nom du compte
local function GetRpName(src)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getName then
            local name = xPlayer.getName()
            if name and name ~= '' then return name end
        end
    end
    return GetPlayerName(src)
end

AddEventHandler('playerDropped', function()
    lastMe[source] = nil
end)

RegisterNetEvent('pop_chat:me', function(message)
    local src = source

    -- Une action /me toutes les 2 s maximum
    local now = GetGameTimer()
    if lastMe[src] and now - lastMe[src] < COOLDOWN_MS then return end
    lastMe[src] = now

    if type(message) ~= 'string' or message == '' then return end
    message = message:gsub('<', '&lt;'):gsub('>', '&gt;')
    if #message > 200 then message = message:sub(1, 200) end

    local playerName   = GetRpName(src)
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
