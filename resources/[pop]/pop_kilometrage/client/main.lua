-- pop_kilometrage — client
-- Calcule la distance parcourue par le vehicule conduit et la sauvegarde par plaque.

local function normalPlate(plate)
    return string.upper(string.gsub(plate or '', '%s+', ''))
end

local trackedVehicle    = nil
local lastCoords        = nil
local currentMileage    = 0
local lastSavedMileage  = nil
local mileageFetched    = false

local function getMileageFromState(vehicle)
    local state = Entity(vehicle).state
    return state and state.vehicleMileage
end

local function startTracking(vehicle, plate)
    trackedVehicle   = vehicle
    lastCoords       = GetEntityCoords(vehicle)
    lastSavedMileage = nil
    mileageFetched   = false

    local cached = getMileageFromState(vehicle)
    if cached then
        currentMileage = cached
        mileageFetched = true
    else
        TriggerServerEvent('pop_kilometrage:server:requestMileage', plate)
    end
end

local lastAskTime = nil

RegisterNetEvent('pop_kilometrage:client:receiveMileage', function(plate, mileage)
    if not trackedVehicle or normalPlate(GetVehicleNumberPlateText(trackedVehicle)) ~= plate then return end
    currentMileage = mileage
    mileageFetched = true
end)

CreateThread(function()
    while true do
        Wait(Config.CheckInterval)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            trackedVehicle = nil
        else
            local plate = normalPlate(GetVehicleNumberPlateText(vehicle))

            if trackedVehicle ~= vehicle then
                startTracking(vehicle, plate)
            elseif not mileageFetched then
                -- Réponse perdue (limite serveur d'une demande/s) : on redemande toutes les 3 s
                if not lastAskTime or GetGameTimer() - lastAskTime > 3000 then
                    lastAskTime = GetGameTimer()
                    TriggerServerEvent('pop_kilometrage:server:requestMileage', plate)
                end
            elseif mileageFetched then
                local coords = GetEntityCoords(vehicle)

                if IsVehicleOnAllWheels(vehicle) and not IsEntityInWater(vehicle) then
                    local distKm = #(lastCoords - coords) / 1000
                    currentMileage = currentMileage + distKm
                end
                lastCoords = coords

                local rounded = math.floor(currentMileage * 100 + 0.5) / 100
                -- Réplication du statebag uniquement si la valeur a changé.
                local state = Entity(vehicle).state
                if state.vehicleMileage ~= rounded then
                    state:set('vehicleMileage', rounded, true)
                end

                if not lastSavedMileage or math.abs(rounded - lastSavedMileage) >= Config.ServerUpdateThreshold then
                    TriggerServerEvent('pop_kilometrage:server:updateMileage', plate, rounded)
                    lastSavedMileage = rounded
                end
            end
        end
    end
end)

--------------------
-- EXPORT CLIENT --
--------------------

---@return number|false kilometrage en km du vehicule courant
exports('GetMileage', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    return getMileageFromState(vehicle) or 0
end)
