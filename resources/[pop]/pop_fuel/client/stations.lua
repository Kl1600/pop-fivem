-- pop_fuel : stations. Pompe (ox_target) → véhicule à côté, moteur coupé → choix espèces / carte
-- → remplissage (annulable, rien n'est payé avant la fin) → le serveur encaisse et valide le plein.

local busy = false
local pending = nil -- véhicule en attente du choix de paiement

local function notify(message, icon)
    Bridge.Notify({ title = L('title'), message = message, icon = icon or 'fas fa-gas-pump', duration = 5000 })
end

local function closestVehicle(coords)
    local best, bestDist = 0, Config.MaxVehicleDistance
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(vehicle) - coords)
        if d < bestDist then best, bestDist = vehicle, d end
    end
    return best
end

local function refuel(vehicle, method)
    if busy then return end
    busy = true
    local liters = math.floor(100.0 - Fuel.Get(vehicle))
    local duration = math.max(3000, math.min(15000, liters * Config.RefuelMsPerLiter))
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 800)
    Wait(800)

    local done = Bridge.Progress(L('refueling'), duration, {
        anim = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flag = 49 },
    })
    if not done then busy = false return end

    -- Le serveur relit le niveau partagé : on le publie juste avant.
    Fuel.Set(vehicle, Fuel.Get(vehicle))
    Callback.Trigger('pop_fuel:pay', function(ok, filled, price, reason)
        busy = false
        if ok then
            Fuel.Set(vehicle, 100.0)
            notify(L('refuel_done', filled, price), 'fas fa-circle-check')
        else
            notify(L(reason or 'refuel_failed'), 'fas fa-triangle-exclamation')
        end
    end, NetworkGetNetworkIdFromEntity(vehicle), method)
end

local function openPump(pump)
    if busy then return end
    local vehicle = closestVehicle(GetEntityCoords(pump))
    if vehicle == 0 then return notify(L('no_vehicle')) end
    if Fuel.IsElectric(vehicle) then return notify(L('electric')) end
    if GetIsVehicleEngineRunning(vehicle) then return notify(L('engine_on')) end

    local liters = math.floor(100.0 - Fuel.Get(vehicle))
    if liters < 1 then return notify(L('already_full')) end
    local price = math.ceil(liters * Config.PricePerLiter)

    pending = vehicle
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open', liters = liters, price = price,
        texts = { title = L('title'), total = L('total'), cash = L('pay_cash'), card = L('pay_card'), close = L('close') },
    })
end

RegisterNUICallback('pay', function(data, cb)
    SetNuiFocus(false, false)
    local vehicle = pending
    pending = nil
    if vehicle and DoesEntityExist(vehicle) and (data.method == 'cash' or data.method == 'bank') then
        CreateThread(function() refuel(vehicle, data.method) end)
    end
    cb('ok')
end)

-- Échap : le bridge enlève le focus (callback NUI 'close'), on oublie le véhicule.
Bridge.OnUiClose(function() pending = nil end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and pending then SetNuiFocus(false, false) end
end)

CreateThread(function()
    Bridge.Target.AddModel(Config.PumpModels, {
        { label = L('target_refuel'), icon = 'fas fa-gas-pump', distance = 2.0, onSelect = openPump },
    })

    if Config.ShowBlips then
        for _, coords in ipairs(Config.Stations) do
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip_name'))
            EndTextCommandSetBlipName(blip)
        end
    end
end)
