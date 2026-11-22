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

-- =====================================================================
--  CHAT STAFF
-- =====================================================================
-- Staff = même règle que le menu admin (pop_admin) : groupes admin, ACE, identifiants listés.
local function isStaff(src)
    if src == 0 then return true end
    if GetResourceState('pop_admin') == 'started' then
        local ok, res = pcall(function() return exports.pop_admin:IsAdmin(src) end)
        if ok then return res == true end
    end
    return Bridge.IsAdmin(src)
end

local function clean(text)
    text = tostring(text or ''):gsub('<', '&lt;'):gsub('>', '&gt;')
    if #text > Config.MaxLength then text = text:sub(1, Config.MaxLength) end
    return text
end

local function sendToStaff(color, author, message)
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if isStaff(id) then
            TriggerClientEvent('chat:addMessage', id, { color = color, multiline = true, args = { author, message } })
        end
    end
    print(('[STAFF] %s %s'):format(author, message))
end

local lastStaff = {}
AddEventHandler('playerDropped', function() lastStaff[source] = nil end)

local function staffCommand(src, args)
    if not isStaff(src) then return end
    local now = GetGameTimer()
    if src ~= 0 and lastStaff[src] and now - lastStaff[src] < 500 then return end
    lastStaff[src] = now
    local message = clean(table.concat(args, ' '))
    if message == '' then return end
    local name = src == 0 and L('staff_console') or GetPlayerName(src)
    sendToStaff(Config.StaffColor, ('%s %s'):format(L('staff_prefix'), name), message)
end

for _, cmd in ipairs(Config.StaffCommands) do
    RegisterCommand(cmd, staffCommand, false)
end

-- Annonce d'une action admin au staff : exports.pop_chat:StaffLog(src, 'a réanimé Dano')
exports('StaffLog', function(src, text)
    src = tonumber(src) or 0
    local name = src == 0 and L('staff_console') or GetPlayerName(src)
    sendToStaff(Config.StaffLogColor, L('staff_prefix'), ('%s %s'):format(name, clean(text)))
end)

-- Suggestion /staff dans le chat, seulement pour le staff
Bridge.OnPlayerLoaded(function(src)
    if not isStaff(src) then return end
    for _, cmd in ipairs(Config.StaffCommands) do
        TriggerClientEvent('chat:addSuggestion', src, '/' .. cmd, L('staff_suggestion'), {
            { name = L('staff_suggestion_arg'), help = L('staff_suggestion_help') },
        })
    end
end)
