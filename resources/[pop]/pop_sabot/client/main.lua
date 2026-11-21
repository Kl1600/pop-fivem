-- pop_sabot : client. Suivi des véhicules sabotés (statebag), prop local, interactions.
-- Le client ne décide de rien : pose, retrait et découpe sont validés par le serveur.

local ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 }

local clamped = {}    -- [veh] = { prop = handle|nil, target = id|nil, warned = bool }
local blips = {}      -- [blip] = true (alertes police)
local isJob = false   -- job autorisé et en service
local acting = false  -- action en cours (callback + barre)
local loopRunning = false

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function notifyFail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

local function inJobs(name)
    if not name then return false end
    for k, v in pairs(Config.Jobs or {}) do
        if v == name or k == name then return true end
    end
    return false
end

local function updateJob(job)
    isJob = type(job) == 'table' and job.onDuty == true and inJobs(job.name) or false
end

local function isOwner(veh)
    return NetworkGetEntityOwner(veh) == PlayerId()
end

-- Position de la roue qui porte le sabot (os Config.Prop.bone), sinon le centre du véhicule.
local function wheelCoords(veh)
    local bone = Config.Prop and Config.Prop.bone and GetEntityBoneIndexByName(veh, Config.Prop.bone) or -1
    if bone ~= -1 then return GetWorldPositionOfEntityBone(veh, bone) end
    return GetEntityCoords(veh)
end

local function nearWheel(veh)
    return DoesEntityExist(veh)
        and #(GetEntityCoords(PlayerPedId()) - wheelCoords(veh)) <= Clamp.TARGET_DISTANCE
end

-- Contrôles avant la barre : renvoie la raison d'échec ou nil.
local function checkAction(veh)
    if acting or Bridge.IsBusy() then return 'busy' end
    if not DoesEntityExist(veh) then return 'no_vehicle' end
    if not nearWheel(veh) then return 'too_far' end
    if not IsVehicleSeatFree(veh, -1) then return 'vehicle_occupied' end
    return nil
end

-- Gel + conduite bloquée : seulement par le propriétaire réseau (le serveur ne fait que le demander).
local function immobilize(veh)
    if isOwner(veh) then
        FreezeEntityPosition(veh, true)
        SetVehicleUndriveable(veh, true)
    end
end

------------------------------------------------------------------------
-- Nettoyage d'un véhicule
------------------------------------------------------------------------

local function removeVisuals(data)
    if data.target then
        Bridge.Target.Remove(data.target)
        data.target = nil
    end
    if data.prop then
        if DoesEntityExist(data.prop) then
            DetachEntity(data.prop, false, false)
            DeleteEntity(data.prop)
        end
        data.prop = nil
    end
end

local function clear(veh)
    local data = clamped[veh]
    if not data then return end
    removeVisuals(data)
    if DoesEntityExist(veh) and isOwner(veh) then
        FreezeEntityPosition(veh, false)
        SetVehicleUndriveable(veh, false)
    end
    clamped[veh] = nil
end

------------------------------------------------------------------------
-- Actions (retrait, découpe, pose)
------------------------------------------------------------------------

local function doRemove(veh)
    local fail = checkAction(veh)
    if fail then return notifyFail(fail) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    acting = true
    if Bridge.Progress(L('removing'), Config.Durations.remove, { anim = ANIM }) then
        local ok, reason, arg = Callback.Await('pop_sabot:remove', netId)
        if not ok then notifyFail(reason, arg) end
    end
    acting = false
end

-- Son de disqueuse rejoué toutes les 3,5 s tant que la barre tourne.
local function cutSound(state)
    local sound = GetSoundId()
    while state.running do
        StopSound(sound)
        PlaySoundFromEntity(sound, 'Drill_Pin_Break', PlayerPedId(), 'DLC_HEIST_FLEECA_SOUNDSET', true, 0)
        local nextAt = GetGameTimer() + 3500
        while state.running and GetGameTimer() < nextAt do Wait(250) end
    end
    StopSound(sound)
    ReleaseSoundId(sound)
end

local function doCut(veh)
    if not Config.Items.cutter then return notifyFail('error') end
    local fail = checkAction(veh)
    if fail then return notifyFail(fail) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    acting = true
    local ok, reason, arg = Callback.Await('pop_sabot:cut', netId, 'start')
    if not ok then
        acting = false
        return notifyFail(reason, arg)
    end
    local sound = { running = true }
    CreateThread(function() cutSound(sound) end)
    local done = Bridge.Progress(L('cutting'), Config.Durations.cut, { anim = ANIM })
    sound.running = false
    if done then
        ok, reason, arg = Callback.Await('pop_sabot:cut', netId, 'finish')
        if not ok then notifyFail(reason, arg) end
    end
    acting = false
end

local function targetOptions(veh)
    return {
        {
            label = L('target_remove'),
            icon = 'fa-solid fa-key',
            distance = Clamp.TARGET_DISTANCE,
            canInteract = function() return isJob and nearWheel(veh) end,
            onSelect = function() doRemove(veh) end,
        },
        {
            label = L('target_cut'),
            icon = 'fa-solid fa-screwdriver-wrench',
            distance = Clamp.TARGET_DISTANCE,
            canInteract = function() return not isJob and Config.Items.cutter ~= nil and nearWheel(veh) end,
            onSelect = function() doCut(veh) end,
        },
    }
end

------------------------------------------------------------------------
-- Prop local (visuel seulement) + interaction sur le véhicule
-- Le prop n'a pas de collision : ox_target / qb-target ne le détectent pas, le target est donc
-- toujours posé sur le véhicule (options limitées à la proximité de la roue par canInteract).
------------------------------------------------------------------------

local function attach(veh, data)
    local cfg = Config.Prop or {}
    local prop
    local model = cfg.model
    local hash = type(model) == 'string' and joaat(model) or model
    local bone = cfg.bone and GetEntityBoneIndexByName(veh, cfg.bone) or -1

    if hash and bone ~= -1 and IsModelInCdimage(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
        if HasModelLoaded(hash) and clamped[veh] == data and DoesEntityExist(veh) then
            local c = GetEntityCoords(veh)
            prop = CreateObject(hash, c.x, c.y, c.z + 2.0, false, false, false)
            SetEntityCollision(prop, false, false)
            local o, r = cfg.offset, cfg.rotation
            AttachEntityToEntity(prop, veh, bone, o.x, o.y, o.z, r.x, r.y, r.z,
                false, false, false, false, 2, true)
        end
        SetModelAsNoLongerNeeded(hash)
    end

    -- Le sabot a pu être retiré pendant le chargement du modèle.
    if clamped[veh] ~= data or not DoesEntityExist(veh) then
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        return
    end
    data.prop = prop
    data.target = Bridge.Target.AddLocalEntity(veh, targetOptions(veh))
end

------------------------------------------------------------------------
-- Boucle (uniquement tant qu'un véhicule saboté est connu) : 250 ms à moins de 10 m d'un véhicule
-- saboté, sinon 1000 ms.
------------------------------------------------------------------------

local NEAR_DISTANCE = 10.0

local function startLoop()
    if loopRunning or next(clamped) == nil then return end
    loopRunning = true
    CreateThread(function()
        while loopRunning and next(clamped) ~= nil do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local current = GetVehiclePedIsIn(ped, false)
            local wait = 1000

            -- Copie : attach() peut attendre, la table peut changer entre-temps.
            local list = {}
            for veh in pairs(clamped) do list[#list + 1] = veh end

            for _, veh in ipairs(list) do
                local data = clamped[veh]
                if data then
                    if not DoesEntityExist(veh) then
                        clear(veh)
                    else
                        immobilize(veh) -- le propriétaire réseau peut changer

                        if current == veh and GetPedInVehicleSeat(veh, -1) == ped then
                            SetVehicleEngineOn(veh, false, true, true)
                            SetVehicleUndriveable(veh, true)
                            if not data.warned then
                                data.warned = true
                                Bridge.Notify(L('clamped_driver'), 'error')
                            end
                        else
                            data.warned = false
                        end

                        local dist = #(pos - GetEntityCoords(veh))
                        if dist < NEAR_DISTANCE then wait = 250 end
                        if dist <= Clamp.PROP_DISTANCE then
                            if not data.target then attach(veh, data) end
                        elseif dist > Clamp.PROP_DISTANCE + 20.0 then
                            removeVisuals(data)
                        end
                    end
                end
            end
            Wait(wait)
        end
        loopRunning = false
    end)
end

local function track(veh, value)
    if value == true then
        if not clamped[veh] then clamped[veh] = { warned = false } end
        immobilize(veh) -- sans attendre la boucle
        startLoop()
    else
        clear(veh)
    end
end

------------------------------------------------------------------------
-- Synchro par statebag
------------------------------------------------------------------------

-- NOTE: à vérifier en jeu : un véhicule saboté qui sort de portée est supprimé localement (clear), puis
-- recréé quand il revient. On compte sur ce handler (réplication initiale du statebag) pour le resuivre ;
-- s'il ne se déclenche pas dans ce cas, ajouter un scan léger de GetGamePool('CVehicle').
AddStateBagChangeHandler(Clamp.STATE, nil, function(bagName, _, value)
    if not bagName:find('^entity:') then return end
    CreateThread(function()
        local veh = GetEntityFromStateBagName(bagName)
        local tries = 0
        while veh == 0 and tries < 20 do
            Wait(100)
            tries = tries + 1
            veh = GetEntityFromStateBagName(bagName)
        end
        if veh == 0 or GetEntityType(veh) ~= 2 then return end
        -- Après attente, l'état courant fait foi (un changement a pu suivre).
        if tries > 0 then value = Entity(veh).state[Clamp.STATE] end
        track(veh, value)
    end)
end)

local function scanVehicles()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if Entity(veh).state[Clamp.STATE] == true and not clamped[veh] then
            clamped[veh] = { warned = false }
            immobilize(veh)
        end
    end
    startLoop()
end

Bridge.OnPlayerLoaded(function()
    updateJob(Bridge.GetJob())
    scanVehicles()
end)

Bridge.OnJobUpdate(updateJob)

------------------------------------------------------------------------
-- Events serveur
------------------------------------------------------------------------

RegisterNetEvent('pop_sabot:client:startPlace', function()
    if acting or Bridge.IsBusy() then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    local pos = GetEntityCoords(ped)
    local best, bestDist = nil, Clamp.PLACE_DISTANCE
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(pos - GetEntityCoords(veh))
        if d <= bestDist then best, bestDist = veh, d end
    end

    if not best then return notifyFail('no_vehicle') end
    if not NetworkGetEntityIsNetworked(best)
        or GetEntityBoneIndexByName(best, Config.Prop.bone) == -1 then
        return notifyFail('vehicle_incompatible')
    end
    if clamped[best] or Entity(best).state[Clamp.STATE] then return notifyFail('already_clamped') end

    local netId = NetworkGetNetworkIdFromEntity(best)
    acting = true
    if Bridge.Progress(L('placing'), Config.Durations.place, { anim = ANIM }) then
        local ok, reason, arg = Callback.Await('pop_sabot:place', netId)
        if not ok then notifyFail(reason, arg) end
    end
    acting = false
end)

RegisterNetEvent('pop_sabot:client:cutAlert', function(coords)
    local t = type(coords)
    if t ~= 'table' and t ~= 'vector3' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    Bridge.Notify(L('police_alert'), 'warning')

    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('police_blip'))
    EndTextCommandSetBlipName(blip)
    blips[blip] = true

    SetTimeout((tonumber(Config.BlipTime) or 60) * 1000, function()
        if blips[blip] then
            RemoveBlip(blip)
            blips[blip] = nil
        end
    end)
end)

------------------------------------------------------------------------
-- Arrêt de la ressource
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    loopRunning = false
    for veh in pairs(clamped) do clear(veh) end
    for blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end)
