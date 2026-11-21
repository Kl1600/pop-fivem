-- pop_enterprisegarage — client : menu, sortie et rangement des véhicules

-- ESX direct : spawn / propriétés / suppression de véhicule (non couverts par le bridge).
local ESX = exports['es_extended']:getSharedObject()

Garage = {
    nuiOpen = false,
    current = nil, -- label du garage ouvert
}

local function normalPlate(plate)
    return string.upper(string.gsub(plate or '', '%s+', ''))
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
function Garage.OpenMenu(garageLabel)
    Garage.current = garageLabel
    TriggerServerEvent('pop_enterprisegarage:requestList', garageLabel)
end

function Garage.CloseMenu()
    Garage.nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('pop_enterprisegarage:openMenu', function(data)
    Garage.nuiOpen = true
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
        Bridge.Notify(L('vehicle_out', data.plate))
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
    Bridge.Notify(L('vehicle_stored'))
    if Garage.current then TriggerServerEvent('pop_enterprisegarage:requestList', Garage.current) end
end)

-- ── Callbacks NUI ────────────────────────────────────────────────────────────
-- 'close' (Échap / bouton) : callback NUI du bridge, qui rend déjà le focus.
Bridge.OnUiClose(function() Garage.CloseMenu() end)

RegisterNUICallback('takeOut', function(data, cb)
    if Garage.current then
        TriggerServerEvent('pop_enterprisegarage:takeOut', Garage.current, data.plate)
    end
    Garage.CloseMenu()
    cb('ok')
end)

RegisterNUICallback('store', function(_, cb)
    local veh = getCurrentVehicle()
    if veh == 0 then
        Bridge.Notify(L('no_vehicle_near'))
        cb('ok'); return
    end
    local plate = normalPlate(GetVehicleNumberPlateText(veh))
    local props = ESX.Game.GetVehicleProperties(veh)
    local netId = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) or nil
    if Garage.current then
        TriggerServerEvent('pop_enterprisegarage:store', Garage.current, plate, props, netId)
    end
    Garage.CloseMenu()
    cb('ok')
end)

exports('open', Garage.OpenMenu)
