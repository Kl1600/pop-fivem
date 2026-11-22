local GM = { State = { CinemaMode = 0 } }
local useMetric = Config.UseMetric
local speedFactor = useMetric and 3.6 or 2.236936
local speedUnit = useMetric and "km/h" or "mph"

-- Masquage forcé (ex: menu Benny's) via l'event partagé 'hud:toggleui'.
local hudHidden = false
AddEventHandler('hud:toggleui', function(show)
	hudHidden = (show == false)
	if hudHidden then SendNUIMessage({ showhud = false }) end
end)

local function getMileage()
	if GetResourceState('pop_kilometrage') ~= 'started' then return 0 end
	local ok, mileage = pcall(function() return exports['pop_kilometrage']:GetMileage() end)
	if not ok or not mileage then return 0 end
	return mileage
end

Citizen.CreateThread(function()
	local hudEnabled = false
	local lastSpeed, lastFuel, lastMileage
	local mileage, mileageTick = 0, 0
	local PlayerPedId, GetVehiclePedIsIn, GetIsVehicleEngineRunning, SendNUIMessage, GetEntitySpeed, GetVehicleFuelLevel = PlayerPedId, GetVehiclePedIsIn, GetIsVehicleEngineRunning, SendNUIMessage, GetEntitySpeed, GetVehicleFuelLevel

	while true do
		local waitTime = Config.RefreshIdle
		local veh = GetVehiclePedIsIn(PlayerPedId(), false)

		if not hudHidden and veh ~= 0 and GetIsVehicleEngineRunning(veh) and GM.State.CinemaMode == 0 then
			waitTime = Config.RefreshDriving
			-- kilométrage : export appelé ~1x/s seulement
			mileageTick = mileageTick - 1
			if mileageTick <= 0 then
				mileage = getMileage()
				mileageTick = Config.MileageTicks
			end

			local speed = math.ceil(GetEntitySpeed(veh) * speedFactor)
			local fuel = math.floor(GetVehicleFuelLevel(veh) + 0.5)
			if not hudEnabled or speed ~= lastSpeed or fuel ~= lastFuel or mileage ~= lastMileage then
				hudEnabled = true
				lastSpeed, lastFuel, lastMileage = speed, fuel, mileage
				SendNUIMessage({
					showhud = true,
					speed = speed,
					speedUnit = speedUnit,
					fuel = fuel,
					mileage = mileage
				})
			end
		elseif hudEnabled then
			hudEnabled = false
			mileageTick = 0
			SendNUIMessage({ showhud = false })
		end

		Citizen.Wait(waitTime)
	end
end)
