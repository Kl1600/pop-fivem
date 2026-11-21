-- pop_management : zones, commandes, panneau patron, formulaire de facture, callbacks NUI.
-- Aucune boucle : les zones sont gérées par le bridge (target ou prompt partagé).

local TARGET_DISTANCE = 2.0
local ZONE_SIZE = vec3(1.2, 1.2, 2.0)
local NEARBY_MAX = 6

local job = nil            -- job en cache (format commun du bridge)
local zones = {}           -- ids des zones créées
local panelOpen = false
local invoiceOpen = false
local requesting = false   -- requête d'ouverture en cours
local currentPoint = nil   -- index du point d'ouverture (nil = commande)

-- Actions autorisées depuis la NUI (table blanche) et champs envoyés au serveur.
local ACTIONS = {
    fire = 'employee', promote = 'employee', demote = 'employee',
    pay = 'pay', deposit = 'amount', withdraw = 'amount', recruit = 'target',
}

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function notifyError(reason, arg)
    if type(reason) ~= 'string' then reason = 'error' end
    if arg ~= nil then
        Bridge.Notify(L(reason, arg), 'error')
    else
        Bridge.Notify(L(reason), 'error')
    end
end

-- Entier strict (les nombres JSON de la NUI peuvent arriver en flottant).
local function toInt(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.tointeger(v)
end

local function offerShown()
    return Offer ~= nil and Offer.IsShown()
end

local function canOpen()
    return not panelOpen and not invoiceOpen and not requesting
        and not Bridge.IsBusy() and not offerShown()
end

--- Joueurs proches : { { id = serverId, dist = 1.4 }, ... } triés par distance.
local function nearby()
    local list = {}
    local me = PlayerId()
    local pos = GetEntityCoords(PlayerPedId())
    local maxDist = Config.InteractDistance
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= me then
            local ped = GetPlayerPed(p)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(pos - GetEntityCoords(ped))
                if d <= maxDist then
                    list[#list + 1] = { id = GetPlayerServerId(p), dist = math.floor(d * 10 + 0.5) / 10 }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    for i = #list, NEARBY_MAX + 1, -1 do list[i] = nil end
    return list
end

------------------------------------------------------------------------
-- Fermeture
------------------------------------------------------------------------

local function closeAll()
    if panelOpen then TriggerServerEvent('pop_management:server:closePanel') end
    SendNUIMessage({ action = 'pop_management:panel', show = false })
    SendNUIMessage({ action = 'pop_management:invoice', show = false })
    if panelOpen or invoiceOpen then SetNuiFocus(false, false) end
    panelOpen, invoiceOpen, currentPoint = false, false, nil
end

Bridge.OnUiClose(closeAll)

------------------------------------------------------------------------
-- Panneau patron
------------------------------------------------------------------------

local function openPanel(point)
    if not canOpen() then return end
    requesting = true
    CreateThread(function()
        local data, reason, arg = Callback.Await('pop_management:getPanel', point)
        requesting = false
        if type(data) ~= 'table' then return notifyError(reason, arg) end
        if panelOpen or invoiceOpen or offerShown() then
            -- Ouverture devenue impossible pendant l'attente : la session serveur est inutile.
            if not panelOpen then TriggerServerEvent('pop_management:server:closePanel') end
            return
        end
        panelOpen, currentPoint = true, point
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'pop_management:panel', show = true, data = data })
    end)
end

-- Recharge les données après une action réussie (à appeler dans un thread).
local function refresh()
    if not panelOpen then return end
    local data, reason, arg = Callback.Await('pop_management:getPanel', currentPoint)
    if not panelOpen then
        if type(data) == 'table' then TriggerServerEvent('pop_management:server:closePanel') end
        return
    end
    if type(data) ~= 'table' then
        closeAll()
        return notifyError(reason, arg)
    end
    SendNUIMessage({ action = 'pop_management:panel', show = true, data = data })
end

------------------------------------------------------------------------
-- Formulaire de facture
------------------------------------------------------------------------

local function openInvoice()
    if not Config.InvoiceCommand or not canOpen() then return end
    local cfg = job and Config.Societies[job.name]
    if not cfg then return notifyError('wrong_job') end
    if cfg.invoiceGrade == false then return notifyError('invoice_disabled') end
    requesting = true
    CreateThread(function()
        local info, reason, arg = Callback.Await('pop_management:canInvoice')
        requesting = false
        if type(info) ~= 'table' then return notifyError(reason, arg) end
        if panelOpen or invoiceOpen or offerShown() then return end
        invoiceOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'pop_management:invoice', show = true,
            society = info.society, max = info.max, players = nearby(),
        })
    end)
end

------------------------------------------------------------------------
-- Zones
------------------------------------------------------------------------

local function removeZones()
    for _, id in ipairs(zones) do Bridge.Target.Remove(id) end
    zones = {}
end

local function buildZones()
    removeZones()
    local name = job and job.name
    local cfg = name and Config.Societies[name]
    if not cfg or type(cfg.points) ~= 'table' then return end
    for i, point in ipairs(cfg.points) do
        local index = i
        zones[#zones + 1] = Bridge.Target.AddBoxZone('pop_management_' .. index, point, ZONE_SIZE, 0.0, {
            {
                label = L('open_panel'),
                icon = 'fa-solid fa-briefcase',
                distance = TARGET_DISTANCE,
                canInteract = function()
                    return job ~= nil and job.name == name and (tonumber(job.grade) or 0) >= cfg.bossGrade
                end,
                onSelect = function() openPanel(index) end,
            },
        })
    end
end

local function setJob(newJob)
    if type(newJob) ~= 'table' then return end
    local old = job
    job = newJob
    if (panelOpen or invoiceOpen) and (not old or old.name ~= newJob.name or old.grade ~= newJob.grade) then
        closeAll()
    end
    buildZones()
end

Bridge.OnPlayerLoaded(function() setJob(Bridge.GetJob()) end)
Bridge.OnJobUpdate(setJob)

------------------------------------------------------------------------
-- Commandes
------------------------------------------------------------------------

if type(Config.Command) == 'string' and Config.Command ~= '' then
    RegisterCommand(Config.Command, function() openPanel(nil) end, false)
end

if type(Config.InvoiceCommand) == 'string' and Config.InvoiceCommand ~= '' then
    RegisterCommand(Config.InvoiceCommand, openInvoice, false)
end

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

RegisterNUICallback('pop_management:action', function(data, cb)
    local action = type(data) == 'table' and data.action or nil
    local kind = type(action) == 'string' and ACTIONS[action] or nil
    if not kind or not panelOpen then return cb({ ok = false, reason = 'error' }) end

    local args
    if kind == 'employee' or kind == 'pay' then
        local employeeId = toInt(data.employeeId)
        if not employeeId then return cb({ ok = false, reason = 'error' }) end
        args = { employeeId }
    elseif kind == 'target' then
        local targetId = toInt(data.targetId)
        if not targetId then return cb({ ok = false, reason = 'error' }) end
        args = { targetId }
    else
        args = {}
    end
    if kind == 'pay' or kind == 'amount' then
        local amount = toInt(data.amount)
        if not amount or amount < 1 then
            notifyError('invalid_amount')
            return cb({ ok = false, reason = 'invalid_amount' })
        end
        args[#args + 1] = amount
    end

    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_management:' .. action, table.unpack(args))
        if ok == true then
            refresh()
            return cb({ ok = true })
        end
        if type(reason) ~= 'string' then reason = 'error' end
        notifyError(reason, arg)
        cb({ ok = false, reason = reason })
    end)
end)

RegisterNUICallback('pop_management:nearby', function(_, cb)
    cb({ players = nearby() })
end)

RegisterNUICallback('pop_management:sendInvoice', function(data, cb)
    if not invoiceOpen or type(data) ~= 'table' then return cb({ ok = false, reason = 'error' }) end
    local targetId = toInt(data.targetId)
    if not targetId then return cb({ ok = false, reason = 'error' }) end
    local amount = toInt(data.amount)
    if not amount or amount < 1 then
        notifyError('invalid_amount')
        return cb({ ok = false, reason = 'invalid_amount' })
    end
    local note = type(data.note) == 'string' and data.note ~= '' and data.note or nil

    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_management:sendInvoice', targetId, amount, note)
        if ok == true then
            closeAll()
            return cb({ ok = true })
        end
        if type(reason) ~= 'string' then reason = 'error' end
        notifyError(reason, arg)
        cb({ ok = false, reason = reason })
    end)
end)

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------

exports('OpenPanel', function()
    if type(Config.Command) ~= 'string' then return end
    openPanel(nil)
end)

exports('OpenInvoice', openInvoice)

exports('IsOpen', function()
    return panelOpen or invoiceOpen
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeAll()
    removeZones()
end)
