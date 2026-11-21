-- pop_admin : panneau (ouverture / NUI), touches et events reçus du serveur.
-- Le client n'est qu'une télécommande : chaque action est validée par le serveur.

local VEHICLE_SEARCH = 5.0

local SUBMARINES = { submersible = true, submersible2 = true, kosatka = true, avisa = true }

-- Actions dont le succès ferme le panneau (spectate : seulement avec une cible, noclip : seulement activé).
local CLOSE_ON_SUCCESS = { ['goto'] = true, vehicle_spawn = true }

local isOpen = false
local opening = false
local noclipPending = false

local function started(name)
    return GetResourceState(name) == 'started'
end

local function fail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_admin:close' })
end

-- À appeler dans un thread.
local function openPanel()
    if opening or isOpen then return end
    opening = true
    local data = Callback.Await('pop_admin:open')
    opening = false
    if type(data) ~= 'table' then
        return fail('no_permission')
    end
    data.action = 'pop_admin:open'
    isOpen = true
    SendNUIMessage(data)
    SetNuiFocus(true, true)
end

local function toggle()
    if isOpen then
        closePanel()
    else
        CreateThread(openPanel)
    end
end

RegisterCommand(Config.Command, toggle, false)
RegisterKeyMapping(Config.Command, L('keymap_open'), 'keyboard', Config.OpenKey)

RegisterCommand('popadmin_noclip', function()
    if noclipPending then return end
    noclipPending = true
    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_admin:action', 'noclip')
        noclipPending = false
        if ok ~= true then fail(reason, arg) end
    end)
end, false)
RegisterKeyMapping('popadmin_noclip', L('keymap_noclip'), 'keyboard', Config.NoclipKey)

-- Échap (kit) : le focus est déjà rendu par le bridge.
Bridge.OnUiClose(function()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'pop_admin:close' })
end)

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

RegisterNUICallback('players', function(_, cb)
    local list = Callback.Await('pop_admin:getPlayers')
    cb({ players = type(list) == 'table' and list or {} })
end)

RegisterNUICallback('bans', function(_, cb)
    local list = Callback.Await('pop_admin:getBans')
    cb({ bans = type(list) == 'table' and list or {} })
end)

-- Nombres JSON entiers (12.0) -> entiers Lua (le serveur exige math.type == 'integer').
local function toInt(v)
    if type(v) ~= 'number' then return v end
    return math.tointeger(v) or v
end

local function vehicleType(model, hash)
    if SUBMARINES[model] then return 'submarine' end
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelABoat(hash) or IsThisModelAJetski(hash) then return 'boat' end
    if IsThisModelABike(hash) or IsThisModelABicycle(hash) then return 'bike' end
    return 'automobile'
end

-- Véhicule occupé, sinon le plus proche (scan unique au clic) ; nil si aucun ou non mis en réseau.
local function findVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local pos = GetEntityCoords(ped)
        local best = VEHICLE_SEARCH
        for _, v in ipairs(GetGamePool('CVehicle')) do
            local d = #(pos - GetEntityCoords(v))
            if d <= best then best, veh = d, v end
        end
    end
    if veh == 0 or not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then return nil end
    return veh
end

RegisterNUICallback('action', function(body, cb)
    body = type(body) == 'table' and body or {}
    local action = body.action
    if type(action) ~= 'string' then
        fail('error')
        return cb({ ok = false, reason = 'error' })
    end

    local target = toInt(tonumber(body.target))
    local data = {}
    if type(body.data) == 'table' then
        for k, v in pairs(body.data) do data[k] = toInt(v) end
    end

    -- Enrichissement local (le JS n'envoie pas ces champs).
    if action == 'vehicle_spawn' then
        local model = type(data.model) == 'string' and data.model:lower():match('^%s*(.-)%s*$') or ''
        local hash = joaat(model)
        if model == '' or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            fail('invalid_model')
            return cb({ ok = false, reason = 'invalid_model' })
        end
        data = { model = model, vtype = vehicleType(model, hash) }
    elseif action == 'vehicle_fix' or action == 'vehicle_delete' then
        local veh = findVehicle()
        if not veh then
            fail('vehicle_not_found')
            return cb({ ok = false, reason = 'vehicle_not_found' })
        end
        data = { netId = VehToNet(veh) }
    end

    local ok, reason, arg = Callback.Await('pop_admin:action', action, target, data)
    ok = ok == true

    if not ok then
        fail(reason, arg)
    elseif CLOSE_ON_SUCCESS[action]
        or (action == 'spectate' and target ~= nil)
        or (action == 'noclip' and arg == true) then
        closePanel()
    end

    cb({ ok = ok, reason = reason, arg = arg })
end)

------------------------------------------------------------------------
-- Events serveur -> client
------------------------------------------------------------------------

RegisterNetEvent('pop_admin:client:teleport', function(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ent, x, y, z, false, false, false, false)
    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end
end)

-- Gel : une boucle à 1000 ms seulement tant que le joueur est gelé (nouveau ped après respawn).
local frozen = false
local frozenVeh = 0

local function applyFreeze(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    local veh = state and GetVehiclePedIsIn(ped, false) or 0
    if frozenVeh ~= 0 and frozenVeh ~= veh and DoesEntityExist(frozenVeh) then
        FreezeEntityPosition(frozenVeh, false)
    end
    if veh ~= 0 then FreezeEntityPosition(veh, true) end
    frozenVeh = veh
end

RegisterNetEvent('pop_admin:client:freeze', function(state)
    state = state == true
    if state == frozen then return end
    frozen = state
    applyFreeze(state)
    if not state then return end
    CreateThread(function()
        while frozen do
            Wait(1000)
            if frozen then applyFreeze(true) end
        end
    end)
end)

RegisterNetEvent('pop_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    if started('esx_basicneeds') then TriggerEvent('esx_basicneeds:healPlayer') end
    if started('qb-ambulancejob') then TriggerEvent('hospital:client:adminHeal') end
end)

RegisterNetEvent('pop_admin:client:revive', function()
    if type(Config.ReviveEvent) == 'string' and Config.ReviveEvent ~= '' then
        return TriggerEvent(Config.ReviveEvent)
    end
    if started('esx_ambulancejob') then return TriggerEvent('esx_ambulancejob:revive') end
    if started('qb-ambulancejob') then return TriggerEvent('hospital:client:Revive') end
    -- NOTE: nom d'event à confirmer selon la version de qbx_medical (voir SPEC).
    if started('qbx_medical') then return TriggerEvent('qbx_medical:client:playerRevived') end

    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('pop_admin:client:warn', function(reason)
    reason = tostring(reason or '')
    Bridge.Notify(L('you_warned', reason), 'warning')
    SendNUIMessage({ action = 'pop_admin:warn', reason = reason, duration = 10000 })
end)

RegisterNetEvent('pop_admin:client:announce', function(message)
    SendNUIMessage({
        action = 'pop_admin:announce',
        message = tostring(message or ''),
        duration = (tonumber(Config.AnnounceDuration) or 8) * 1000,
    })
end)

RegisterNetEvent('pop_admin:client:fixVehicle', function(netId)
    netId = tonumber(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    local veh = NetToVeh(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
end)

------------------------------------------------------------------------
-- Exports et nettoyage
------------------------------------------------------------------------

exports('IsOpen', function() return isOpen end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closePanel()
    if frozen then
        frozen = false
        applyFreeze(false)
    end
end)
