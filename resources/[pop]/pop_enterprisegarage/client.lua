-- pop_enterprisegarage — client

local nuiOpen      = false
local currentGarage = nil   -- label du garage ouvert

local function normalPlate(plate)
    return string.upper(string.gsub(plate or '', '%s+', ''))
end

local function notify(msg)
    if exports.pop_vehiclepersistence and GetResourceState('pop_vehiclepersistence') == 'started' then
        local ok = pcall(function() exports.pop_vehiclepersistence:Notify(msg, 'inform') end)
        if ok then return end
    end
    ESX.ShowNotification(msg)
end

-- ── Trouve le véhicule (dans lequel on est, sinon le plus proche < 5m) ────────
local function getCurrentVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    local pos = GetEntityCoords(ped)
    local handle, found = FindFirstVehicle()
    local closest, bestDist = 0, 5.0
    local success
    repeat
        if DoesEntityExist(found) then
            local d = #(pos - GetEntityCoords(found))
            if d < bestDist then bestDist = d; closest = found end
        end
        success, found = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
    return closest
end

-- ── Ouverture du menu ────────────────────────────────────────────────────────
local function openMenu(garageLabel)
    currentGarage = garageLabel
    TriggerServerEvent('pop_enterprisegarage:requestList', garageLabel)
end

local function closeMenu()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('pop_enterprisegarage:openMenu', function(data)
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'open',
        garage   = data.garage,
        vehicles = data.vehicles,
    })
end)

-- ── Spawn d'un véhicule sorti ────────────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:spawn', function(data)
    local s = data.spawn
    ESX.Game.SpawnVehicle(data.model, vector3(s.x, s.y, s.z), s.w, function(vehicle)
        if not DoesEntityExist(vehicle) then return end
        SetVehicleNumberPlateText(vehicle, data.plate)
        if data.props then
            ESX.Game.SetVehicleProperties(vehicle, data.props)
            SetVehicleNumberPlateText(vehicle, data.plate)
        end
        SetVehicleEngineOn(vehicle, true, true, false)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        TriggerServerEvent('pop_enterprisegarage:giveKeys', data.plate)
        notify(('Véhicule sorti — plaque : %s'):format(data.plate))
    end)
end)

-- ── Confirmation de rangement -> suppression du véhicule ─────────────────────
RegisterNetEvent('pop_enterprisegarage:confirmStore', function(plate)
    plate = normalPlate(plate)
    local veh = getCurrentVehicle()
    if veh ~= 0 and normalPlate(GetVehicleNumberPlateText(veh)) == plate then
        if GetVehiclePedIsIn(PlayerPedId(), false) == veh then
            TaskLeaveVehicle(PlayerPedId(), veh, 0)
            Wait(300)
        end
        ESX.Game.DeleteVehicle(veh)
    end
    notify('Véhicule rangé au garage.')
    if currentGarage then TriggerServerEvent('pop_enterprisegarage:requestList', currentGarage) end
end)

-- ── Callbacks NUI ────────────────────────────────────────────────────────────
RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('takeOut', function(data, cb)
    if currentGarage then
        TriggerServerEvent('pop_enterprisegarage:takeOut', currentGarage, data.plate)
    end
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('store', function(_, cb)
    local veh = getCurrentVehicle()
    if veh == 0 then
        notify('Aucun véhicule à proximité.')
        cb('ok'); return
    end
    local plate = normalPlate(GetVehicleNumberPlateText(veh))
    local props = ESX.Game.GetVehicleProperties(veh)
    if currentGarage then
        TriggerServerEvent('pop_enterprisegarage:store', currentGarage, plate, props)
    end
    closeMenu()
    cb('ok')
end)

-- ── Commande debug : ouvre le garage le plus proche autorisé ─────────────────
RegisterCommand(Config.Command, function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, g in ipairs(Config.Garages) do
        local d = #(pos - g.coords)
        if not bestDist or d < bestDist then best = g; bestDist = d end
    end
    if best then openMenu(best.label) end
end, false)

exports('open', openMenu)

-- ── Blips ────────────────────────────────────────────────────────────────────
CreateThread(function()
    for _, g in ipairs(Config.Garages) do
        if g.blip then
            local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
            SetBlipSprite(blip, g.blip.sprite or 357)
            SetBlipColour(blip, g.blip.color or 38)
            SetBlipScale(blip, g.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(g.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ── Zone d'interaction (marker + touche) ─────────────────────────────────────
local function jobAllowed(garage)
    return ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name == garage.job
end

CreateThread(function()
    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())
        for _, g in ipairs(Config.Garages) do
            local d = #(pos - g.coords)
            if d < Config.DrawDistance then
                sleep = 0
                DrawMarker(36, g.coords.x, g.coords.y, g.coords.z + 0.4, 0,0,0, 0,0,0,
                    0.6,0.6,0.6, Config.MarkerColor[1], Config.MarkerColor[2], Config.MarkerColor[3], 180,
                    false, false, 2, true, nil, nil, false)
                if d < 2.0 and jobAllowed(g) then
                    if not nuiOpen then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('Appuie sur ~INPUT_PICKUP~ pour ouvrir le ~p~garage entreprise')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                    end
                    if IsControlJustPressed(0, Config.OpenKey) and not nuiOpen then
                        openMenu(g.label)
                    end
                end
            end
        end
        if nuiOpen and IsControlJustPressed(0, 200) then closeMenu() end
        Wait(sleep)
    end
end)
