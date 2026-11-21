-- pop_bikerental : client. Blips, comptoirs (target / prompt) et minuteur discret.
-- Le client ne décide de rien : il envoie l'index du point et du véhicule au serveur.

local ACTION_DISTANCE = 2.0
local WARN_BEFORE     = 120

local rental = nil       -- { netId, expiresAt }
local timerVisible = false
local pending = false
local blips = {}
local zonesReady = false

local function setTimer(show, seconds)
    timerVisible = show
    SendNUIMessage({ action = 'pop_bikerental:timer', show = show, seconds = seconds })
end

-- Montant de la config ramené à un entier >= 0 (même règle que le serveur).
local function amount(n)
    n = tonumber(n) or 0
    if n ~= n or n < 0 then return 0 end
    return math.floor(n)
end

local function vehicleLabel(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(joaat(model)))
    if not label or label == 'NULL' then return model end
    return label
end

-- Minuteur : une seule boucle, seulement pendant une location.
local function startTimer()
    local current = rental
    CreateThread(function()
        while rental and rental == current do
            local remaining = math.max(0, math.floor((current.expiresAt - GetGameTimer()) / 1000 + 0.5))
            local veh = NetToVeh(current.netId)
            local inside = veh ~= 0 and GetVehiclePedIsIn(PlayerPedId(), false) == veh
            local visible = inside or remaining <= WARN_BEFORE
            if visible ~= timerVisible then
                if visible then setTimer(true, remaining) else setTimer(false) end
            end
            Wait(1000)
        end
    end)
end

local function request(name, ...)
    if pending then return end
    pending = true
    local ok, reason, netId, seconds = Callback.Await(name, ...)
    pending = false
    if not ok then
        Bridge.Notify(L(reason or 'error'), 'error')
        return
    end
    return true, netId, seconds
end

local function setupZones()
    if zonesReady then return end
    zonesReady = true

    for i, loc in ipairs(Config.Locations) do
        local options = {}
        for j, v in ipairs(Config.Vehicles) do
            options[#options + 1] = {
                label = L('rent_target', vehicleLabel(v.model), amount(v.price) + amount(Config.Deposit)),
                icon = 'fa-solid fa-bicycle',
                distance = ACTION_DISTANCE,
                canInteract = function() return rental == nil end,
                onSelect = function()
                    local ok, netId, seconds = request('pop_bikerental:rent', i, j)
                    if ok and netId and seconds then
                        rental = { netId = netId, expiresAt = GetGameTimer() + seconds * 1000 }
                        timerVisible = false
                        startTimer()
                    end
                end,
            }
        end
        options[#options + 1] = {
            label = L('return_target'),
            icon = 'fa-solid fa-rotate-left',
            distance = ACTION_DISTANCE,
            -- Toujours visible : l'état local peut être perdu (reconnexion, redémarrage) ; le serveur tranche.
            canInteract = function() return true end,
            onSelect = function()
                request('pop_bikerental:giveBack', i)
            end,
        }
        Bridge.Target.AddBoxZone('pop_bikerental_' .. i, loc.coords, vec3(1.5, 1.5, 2.0), 0.0, options)
    end
end

CreateThread(function()
    for _, loc in ipairs(Config.Locations) do
        if loc.blip then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, 226)
            SetBlipColour(blip, 0)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)

Bridge.OnPlayerLoaded(setupZones)

-- Location terminée (rendue, expirée, perdue).
RegisterNetEvent('pop_bikerental:client:ended', function()
    rental = nil
    setTimer(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    rental = nil
    SendNUIMessage({ action = 'pop_bikerental:timer', show = false })
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end)
