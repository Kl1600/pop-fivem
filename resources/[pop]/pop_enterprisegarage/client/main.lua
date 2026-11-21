-- pop_enterprisegarage : client (blips, comptoirs, zone de rangement, NUI).
-- Le client ne décide de rien : il demande au serveur.

local ACTION_DISTANCE = 3.0
local STORE_RADIUS    = 5.0

local blips = {}
local myJob = nil
local myDuty = false
local uiOpen = false
local garageId = nil -- mémorisé à l'ouverture, jamais envoyé par la NUI
local promptShown = false
local ready = false

local function notifyFail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

------------------------------------------------------------------------
-- NUI
------------------------------------------------------------------------

local function closeUi()
    if uiOpen then SetNuiFocus(false, false) end
    uiOpen = false
    garageId = nil
    SendNUIMessage({ action = 'pop_enterprisegarage:close' })
end

local function vehicleName(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(joaat(model)))
    if not label or label == 'NULL' or label == '' then return model end
    return label
end

local function open(id)
    if uiOpen or Bridge.IsBusy() then return end
    local ok, reason, data = Callback.Await('pop_enterprisegarage:list', id)
    if not ok then return notifyFail(reason, data) end
    if uiOpen or type(data) ~= 'table' then return end

    local vehicles = {}
    for _, v in ipairs(data.vehicles or {}) do
        vehicles[#vehicles + 1] = { index = v.index, name = vehicleName(v.model) }
    end

    garageId = id
    uiOpen = true
    SendNUIMessage({ action = 'pop_enterprisegarage:open', vehicles = vehicles, out = data.out or 0, max = data.max or 0 })
    SetNuiFocus(true, true)
end

RegisterNUICallback('pop_enterprisegarage:takeOut', function(data, cb)
    local id = garageId
    local index = type(data) == 'table' and math.tointeger(tonumber(data.index)) or nil
    closeUi()
    if not id or not index then
        notifyFail('error')
        return cb({ ok = false, error = 'error' })
    end
    local ok, reason, arg = Callback.Await('pop_enterprisegarage:takeOut', id, index)
    if not ok then
        notifyFail(reason, arg)
        return cb({ ok = false, error = reason or 'error' })
    end
    cb({ ok = true })
end)

Bridge.OnUiClose(function()
    uiOpen = false
    garageId = nil
end)

------------------------------------------------------------------------
-- Blips et comptoirs
------------------------------------------------------------------------

local function setup()
    if ready then return end
    ready = true

    for _, g in ipairs(Config.Garages or {}) do
        if g.blip then
            local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
            SetBlipSprite(blip, g.blip.sprite or 357)
            SetBlipColour(blip, g.blip.color or 0)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        local id = g.id
        Bridge.Target.AddBoxZone('pop_enterprisegarage_' .. id, g.coords, vec3(1.5, 1.5, 2.0), 0.0, {
            {
                label = L('open_target'),
                icon = 'fa-solid fa-warehouse',
                distance = ACTION_DISTANCE,
                canInteract = function() return myJob == g.job and myDuty end,
                onSelect = function() open(id) end,
            },
        })
    end
end

Bridge.OnPlayerLoaded(function()
    local job = Bridge.GetJob()
    myJob = job and job.name or nil
    myDuty = job and job.onDuty == true or false
    setup()
end)

Bridge.OnJobUpdate(function(job)
    myJob = job and job.name or nil
    myDuty = job and job.onDuty == true or false
end)

------------------------------------------------------------------------
-- Zone de rangement (boucle adaptative)
------------------------------------------------------------------------

local function setPrompt(show)
    if promptShown == show then return end
    promptShown = show
    SendNUIMessage({ action = 'pop:prompt', show = show, key = Config.Keys.Interact.label, label = show and L('store_hint') or nil })
end

CreateThread(function()
    while true do
        local sleep = 2000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local best

        for _, g in ipairs(Config.Garages or {}) do
            if g.store and g.job == myJob and myDuty then
                local d = #(pos - g.store)
                if not best or d < best then best = d end
            end
        end

        local inZone = false
        if best then
            sleep = best > 30.0 and 1500 or 500
            if best <= STORE_RADIUS then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Entity(veh).state.pop_enterprisegarage then
                    inZone = true
                    sleep = 0
                    setPrompt(true)
                    DisableControlAction(0, 86, true)
                    if not uiOpen and (IsDisabledControlJustReleased(0, 86) or IsControlJustReleased(0, Config.Keys.Interact.control)) then
                        setPrompt(false)
                        local ok, reason = Callback.Await('pop_enterprisegarage:store', VehToNet(veh))
                        if not ok then notifyFail(reason) end
                        sleep = 1000
                    end
                end
            end
        end
        if not inZone then setPrompt(false) end

        Wait(sleep)
    end
end)

------------------------------------------------------------------------
-- Arrêt
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    SendNUIMessage({ action = 'pop_enterprisegarage:close' })
    SendNUIMessage({ action = 'pop:prompt', show = false })
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    -- Targets et prompt partagé : nettoyés par le bridge.
end)
