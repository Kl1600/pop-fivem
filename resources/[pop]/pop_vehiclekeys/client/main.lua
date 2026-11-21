-- pop_vehiclekeys : client
-- Télécommande (bip + feux), moteur bloqué sans clé, serrurier.
-- Le client ne décide de rien : clé, distance, argent et plaque sont vérifiés par le serveur.

local blips = {}
local zones = {}
local setupDone = false
local lockPending = false

-- Classes exemptées, en ensemble pour un test direct.
local exemptClasses = {}
for _, class in ipairs(Config.NoKeyClasses or {}) do exemptClasses[class] = true end

local function notifyFail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

------------------------------------------------------------------------
-- Télécommande
------------------------------------------------------------------------

-- Véhicule actuel, sinon le plus proche à portée (calcul ponctuel, pas de boucle).
local function findTargetVehicle(ped)
    local current = GetVehiclePedIsIn(ped, false)
    if current ~= 0 then return current end

    local pos = GetEntityCoords(ped)
    local best, bestDist = nil, Config.LockDistance
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(pos - GetEntityCoords(veh))
        if d <= bestDist then best, bestDist = veh, d end
    end
    return best
end

local function toggleLock()
    if lockPending or Bridge.IsBusy() then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then return end

    local veh = findTargetVehicle(ped)
    if not veh then return notifyFail('no_vehicle') end
    if not NetworkGetEntityIsNetworked(veh) then return notifyFail('no_key') end

    lockPending = true
    local ok, reason, arg = Callback.Await('pop_vehiclekeys:toggleLock', VehToNet(veh))
    lockPending = false
    if not ok then notifyFail(reason, arg) end
end

RegisterCommand('pop_vehiclekeys_lock', function()
    CreateThread(toggleLock)
end, false)

RegisterKeyMapping('pop_vehiclekeys_lock', L('keymap_lock'), 'keyboard', Config.LockKey)

------------------------------------------------------------------------
-- Effets de verrouillage (bip, feux, animation)
------------------------------------------------------------------------

local FOB_DICT, FOB_CLIP = 'anim@mp_player_intmenu@key_fob@', 'fob_click'

local function playFobAnim(ped)
    RequestAnimDict(FOB_DICT)
    local timeout = GetGameTimer() + 1000
    while not HasAnimDictLoaded(FOB_DICT) and GetGameTimer() < timeout do Wait(10) end
    if not HasAnimDictLoaded(FOB_DICT) then return end
    TaskPlayAnim(ped, FOB_DICT, FOB_CLIP, 8.0, 8.0, 1000, 48, 0.0, false, false, false)
    RemoveAnimDict(FOB_DICT)
end

RegisterNetEvent('pop_vehiclekeys:client:lockFx', function(netId, locked, actor)
    if type(netId) ~= 'number' or not NetworkDoesNetIdExist(netId) then return end
    local veh = NetToVeh(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    locked = locked == true

    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', veh, 'PI_Menu_Sounds', true, 0)

    if actor == GetPlayerServerId(PlayerId()) then
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then CreateThread(function() playFobAnim(ped) end) end
    end

    CreateThread(function()
        for _ = 1, locked and 2 or 1 do
            if not DoesEntityExist(veh) then return end
            SetVehicleLights(veh, 2)
            Wait(150)
            if not DoesEntityExist(veh) then return end
            SetVehicleLights(veh, 0)
            Wait(150)
        end
        if DoesEntityExist(veh) then SetVehicleLights(veh, 0) end
    end)
end)

------------------------------------------------------------------------
-- Moteur bloqué sans clé
------------------------------------------------------------------------

-- Le serveur publie GlobalState.pop_vehiclekeys_supported. On l'attend quelques secondes au démarrage ;
-- false = inventaire sans métadonnées : aucune clé possible, la boucle moteur n'est pas lancée.
local function engineLockSupported()
    local timeout = GetGameTimer() + 10000
    while GlobalState.pop_vehiclekeys_supported == nil and GetGameTimer() < timeout do Wait(500) end
    return GlobalState.pop_vehiclekeys_supported ~= false
end

if Config.RequireKeyForEngine then
    CreateThread(function()
        if not engineLockSupported() then return end

        -- hasKey : true / false, ou nil tant que la réponse du serveur est inconnue.
        local lastVeh, hasKey, lastCheck, notified = 0, nil, 0, false

        local function askServer(veh)
            local res = Callback.Await('pop_vehiclekeys:hasKey', VehToNet(veh))
            -- nil : le serveur ne voit pas encore le joueur dans ce véhicule (ou timeout) :
            -- on garde l'état actuel et on redemandera, sans couper le moteur ni notifier.
            if res == nil then return end
            lastCheck = GetGameTimer()
            local had = hasKey
            hasKey = res == true
            -- Clé (re)trouvée : on rend le démarrage automatique au moteur (sans changer son état).
            if hasKey and had ~= true and DoesEntityExist(veh) then
                SetVehicleEngineOn(veh, GetIsVehicleEngineRunning(veh), true, false)
            end
        end

        while true do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
                lastVeh, hasKey, notified = 0, nil, false
                Wait(1000)
            elseif exemptClasses[GetVehicleClass(veh)] or not NetworkGetEntityIsNetworked(veh) then
                lastVeh, hasKey, notified = 0, nil, false
                Wait(1000)
            else
                local elapsed = GetGameTimer() - lastCheck
                if veh ~= lastVeh then
                    lastVeh, hasKey, notified = veh, nil, false
                    askServer(veh)
                elseif hasKey == nil
                    or (hasKey == false and elapsed > Keys.ENGINE_RECHECK)
                    or (hasKey == true and elapsed > Keys.ENGINE_RECHECK_OWNED) then
                    askServer(veh)
                end

                if hasKey == nil then
                    Wait(Keys.ENGINE_RETRY)
                elseif hasKey then
                    Wait(1000)
                else
                    -- Toujours au volant de ce véhicule après la réponse du serveur ?
                    if GetVehiclePedIsIn(PlayerPedId(), false) == veh then
                        SetVehicleEngineOn(veh, false, true, true)
                        if not notified then
                            notified = true
                            Bridge.Notify(L('no_key_engine'), 'error')
                        end
                    end
                    Wait(500)
                end
            end
        end
    end)
end

------------------------------------------------------------------------
-- Serrurier
------------------------------------------------------------------------

local function setupLocksmith()
    if setupDone then return end
    setupDone = true

    local cfg = Config.Locksmith
    if type(cfg) ~= 'table' or type(cfg.locations) ~= 'table' then return end

    for i, coords in ipairs(cfg.locations) do
        if cfg.blip then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 134)
            SetBlipColour(blip, 0)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('locksmith_blip'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        zones[#zones + 1] = Bridge.Target.AddBoxZone('pop_vehiclekeys_locksmith_' .. i, coords, vec3(2.0, 2.0, 2.0), 0.0, {
            {
                label = L('locksmith_target'),
                icon = 'fa-solid fa-key',
                distance = 2.0,
                onSelect = function()
                    Bridge.Notify(L('locksmith_hint'), 'info')
                end,
            },
        })
    end
end

Bridge.OnPlayerLoaded(setupLocksmith)

-- Le serveur a validé la position (serrurier) : barre de progression, puis demande du double.
RegisterNetEvent('pop_vehiclekeys:client:startDuplicate', function(plate, price)
    if Bridge.IsBusy() or type(plate) ~= 'string' then return end
    CreateThread(function()
        local done = Bridge.Progress(L('duplicating', tonumber(price) or 0), Config.Locksmith.duration, {
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        })
        if not done then return end
        local ok, reason, arg = Callback.Await('pop_vehiclekeys:duplicate', plate)
        if not ok then notifyFail(reason, arg) end
    end)
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    for _, id in ipairs(zones) do pcall(Bridge.Target.Remove, id) end
    blips, zones = {}, {}
    StopAnimTask(PlayerPedId(), FOB_DICT, FOB_CLIP, 1.0)
end)
