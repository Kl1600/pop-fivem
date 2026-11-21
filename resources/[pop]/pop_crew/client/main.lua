-- pop_crew : état local du crew, commande / touche, panneau NUI, export GetMyCrew.
-- Le client ne décide de rien : chaque action est un callback serveur (SPEC §4).

local RES = GetCurrentResourceName()
-- Commande vide ou invalide : repli sur 'crew' (comme le serveur), sinon le panneau serait inaccessible.
local COMMAND = (type(Config.Command) == 'string' and Config.Command ~= '') and Config.Command or 'crew'
local REFRESH_DELAY = 500 -- ms entre deux rafraîchissements du panneau (regroupe les rafales)

-- État partagé avec client/tags.lua (chargé après ce fichier).
PopCrew = {
    crew = nil,     -- CrewSummary | nil
    listeners = {}, -- fn(crew) appelées à chaque changement du cache
}

local isOpen, opening = false, false
local refreshQueued, lastRefresh = false, 0
local pushCount = 0 -- nombre de pushs serveur reçus (évite qu'un getMine lent écrase un push récent)

local function debug(msg, ...)
    if Config.Debug then print(('[%s] client: ' .. msg):format(RES, ...)) end
end

------------------------------------------------------------------------
-- Cache local
------------------------------------------------------------------------

local function setCrew(crew)
    if type(crew) ~= 'table' then crew = nil end
    PopCrew.crew = crew
    for _, fn in ipairs(PopCrew.listeners) do
        local ok, err = pcall(fn, crew)
        if not ok then debug('listener error: %s', tostring(err)) end
    end
end

exports('GetMyCrew', function()
    local c = PopCrew.crew
    if not c then return nil end
    return { id = c.id, name = c.name, color = c.color, rank = c.rank, rankLabel = c.rankLabel }
end)

------------------------------------------------------------------------
-- Convention des actions : ok, key, ...args (SPEC §4)
------------------------------------------------------------------------

local function notifyResult(ok, key, ...)
    if type(ok) ~= 'boolean' or type(key) ~= 'string' then
        Bridge.Notify(L('error'), 'error')
        return false
    end
    Bridge.Notify(L(key, ...), ok and 'success' or 'error')
    return ok
end

local function toInt(v)
    local n = tonumber(v)
    return n and math.tointeger(n) or nil
end

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function fetchPanel()
    local data = Callback.Await('pop_crew:getPanel')
    return type(data) == 'table' and data or nil
end

-- Redemande le panneau (au plus une requête toutes les REFRESH_DELAY ms), seulement s'il est ouvert.
local function requestRefresh()
    if not isOpen or refreshQueued then return end
    refreshQueued = true
    local delay = math.max(0, REFRESH_DELAY - (GetGameTimer() - lastRefresh))
    SetTimeout(delay, function()
        CreateThread(function()
            lastRefresh = GetGameTimer()
            local data = isOpen and fetchPanel() or nil
            refreshQueued = false
            if data and isOpen then
                SendNUIMessage({ action = 'crew:update', data = data })
            end
        end)
    end)
end

local function canOpen()
    return not IsPauseMenuActive() and not Bridge.IsBusy()
end

local function openPanel()
    if isOpen or opening or not canOpen() then return end
    opening = true
    local data = fetchPanel()
    opening = false
    if not data then
        Bridge.Notify(L('error'), 'error')
        return
    end
    if isOpen or not canOpen() then return end
    isOpen = true
    lastRefresh = GetGameTimer()
    SendNUIMessage({ action = 'crew:open', data = data })
    SetNuiFocus(true, true)
end

-- Fermeture forcée (commande / touche pendant l'ouverture, arrêt de la ressource).
local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'crew:close' })
end

local function togglePanel()
    if isOpen then closePanel() else openPanel() end
end

-- Échap ou bouton Fermer : le bridge a déjà rendu le focus.
Bridge.OnUiClose(function()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'crew:close' })
end)

RegisterCommand(COMMAND, function()
    CreateThread(togglePanel)
end, false)
if type(Config.Key) == 'string' and Config.Key ~= '' then
    RegisterKeyMapping(COMMAND, L('keymap_open'), 'keyboard', Config.Key)
end

------------------------------------------------------------------------
-- Synchronisation avec le serveur
------------------------------------------------------------------------

Bridge.OnPlayerLoaded(function()
    local before = pushCount
    local crew = Callback.Await('pop_crew:getMine')
    if pushCount == before then setCrew(crew) end
end)

RegisterNetEvent('pop_crew:client:update', function(crew)
    pushCount = pushCount + 1
    setCrew(crew)
    requestRefresh()
end)

------------------------------------------------------------------------
-- Callbacks NUI (SPEC §5.2) : conversion des types, appel serveur, notification, rafraîchissement
------------------------------------------------------------------------

local function registerAction(name, serverName, readArgs)
    RegisterNUICallback(name, function(body, cb)
        if type(body) ~= 'table' then body = {} end
        local args = readArgs and table.pack(readArgs(body)) or { n = 0 }
        CreateThread(function()
            local ok = notifyResult(Callback.Await(serverName, table.unpack(args, 1, args.n)))
            if ok then requestRefresh() end
            cb({ ok = ok })
        end)
    end)
end

registerAction('create', 'pop_crew:create', function(b)
    return tostring(b.name or ''), tostring(b.color or '')
end)
registerAction('invite', 'pop_crew:invite', function(b) return toInt(b.id) end)
registerAction('respond', 'pop_crew:respond', function(b) return b.accept == true end)
registerAction('leave', 'pop_crew:leave')
registerAction('kick', 'pop_crew:kick', function(b) return toInt(b.memberId) end)
registerAction('setRank', 'pop_crew:setRank', function(b) return toInt(b.memberId), toInt(b.rank) end)
registerAction('disband', 'pop_crew:disband')

RegisterNUICallback('nearby', function(_, cb)
    CreateThread(function()
        local list = Callback.Await('pop_crew:getNearby')
        local players = {}
        if type(list) == 'table' then
            for _, p in ipairs(list) do
                if type(p) == 'table' and tonumber(p.id) then
                    players[#players + 1] = { id = tonumber(p.id), dist = tonumber(p.dist) or 0 }
                end
            end
        else
            Bridge.Notify(L('error'), 'error')
        end
        -- NOTE: liste vide éventuellement encodée en objet JSON : la NUI retombe sur [] (Array.isArray).
        cb({ players = players })
    end)
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    isOpen = false
    SetNuiFocus(false, false)
end)
