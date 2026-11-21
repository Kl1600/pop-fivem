-- Bridge client : données joueur, notifications, interactions (target ou prompt natif)
-- et barre de progression, quel que soit le framework.
-- Ne modifiez pas ce fichier dans un script : corrigez-le dans templates/pop_base.

Bridge = {}

local RES = GetCurrentResourceName()
local HAS_NUI = GetResourceMetadata(RES, 'ui_page', 0) ~= nil
local DEFAULT_DISTANCE = 2.0

local function started(name)
    return GetResourceState(name) == 'started'
end

local function debug(msg, ...)
    if Config.Debug then print(('[%s] bridge: ' .. msg):format(RES, ...)) end
end

local function toVec3(v)
    return vec3(v.x or v[1] or 0.0, v.y or v[2] or 0.0, v.z or v[3] or 0.0)
end

------------------------------------------------------------------------
-- Détection
------------------------------------------------------------------------

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbox' end
    if started('es_extended') then return 'esx' end
    if started('qb-core') then return 'qbcore' end
    return 'standalone'
end

local function detectTarget()
    if Config.Target ~= 'auto' then return Config.Target end
    if started('ox_target') then return 'ox_target' end
    if started('qb-target') then return 'qb-target' end
    return 'prompt'
end

local function detectNotify()
    if Config.Notify ~= 'auto' then return Config.Notify end
    return detectFramework() ~= 'standalone' and 'framework' or 'native'
end

Bridge.Framework = detectFramework()
Bridge.TargetSystem = detectTarget()
Bridge.NotifySystem = detectNotify()

local ESX, QBCore
if Bridge.Framework == 'esx' then
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then
        ESX = obj
    else
        -- NOTE: ancien ESX (avant Legacy).
        TriggerEvent('esx:getSharedObject', function(o) ESX = o end)
    end
elseif Bridge.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

debug('framework=%s target=%s notify=%s', Bridge.Framework, Bridge.TargetSystem, Bridge.NotifySystem)

------------------------------------------------------------------------
-- Données joueur
------------------------------------------------------------------------

--- Données brutes du framework ({} en standalone).
function Bridge.GetPlayerData()
    if Bridge.Framework == 'esx' then return ESX and ESX.GetPlayerData() or {} end
    if Bridge.Framework == 'qbcore' then return QBCore.Functions.GetPlayerData() or {} end
    if Bridge.Framework == 'qbox' then return exports.qbx_core:GetPlayerData() or {} end
    return {}
end

-- Format commun : { name, label, grade, gradeLabel, onDuty } (identique au serveur).
local function normalizeJob(j)
    if type(j) ~= 'table' then
        return { name = 'unemployed', label = 'Unemployed', grade = 0, gradeLabel = '', onDuty = false }
    end
    if Bridge.Framework == 'esx' then
        return { name = j.name, label = j.label, grade = tonumber(j.grade) or 0, gradeLabel = j.grade_label or '', onDuty = j.onDuty ~= false }
    end
    local g = type(j.grade) == 'table' and j.grade or { level = j.grade }
    return { name = j.name, label = j.label, grade = tonumber(g.level) or 0, gradeLabel = g.name or '', onDuty = j.onduty == true }
end

function Bridge.GetJob()
    return normalizeJob(Bridge.GetPlayerData().job)
end

--- Vrai quand le personnage est chargé (en standalone : dès que la session réseau a démarré).
function Bridge.IsLoaded()
    if Bridge.Framework == 'esx' then
        if not ESX then return false end
        if ESX.IsPlayerLoaded then return ESX.IsPlayerLoaded() == true end
        return ESX.GetPlayerData().job ~= nil
    end
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        return LocalPlayer.state.isLoggedIn == true
    end
    return NetworkIsSessionStarted()
end

local loadedHandlers, jobHandlers = {}, {}

local function fire(list, ...)
    for _, cb in ipairs(list) do
        local args = table.pack(...)
        CreateThread(function() cb(table.unpack(args, 1, args.n)) end)
    end
end

--- cb(playerData) à chaque chargement du personnage ; appelé tout de suite s'il est déjà chargé.
function Bridge.OnPlayerLoaded(cb)
    loadedHandlers[#loadedHandlers + 1] = cb
    if Bridge.IsLoaded() then fire({ cb }, Bridge.GetPlayerData()) end
end

--- cb(job) à chaque changement de job (format commun).
function Bridge.OnJobUpdate(cb)
    jobHandlers[#jobHandlers + 1] = cb
end

if Bridge.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded', function(xPlayer) fire(loadedHandlers, xPlayer) end)
    RegisterNetEvent('esx:setJob', function(job) fire(jobHandlers, normalizeJob(job)) end)
elseif Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() fire(loadedHandlers, Bridge.GetPlayerData()) end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) fire(jobHandlers, normalizeJob(job)) end)
elseif not Bridge.IsLoaded() then
    -- Standalone : "chargé" dès que la session réseau a démarré.
    CreateThread(function()
        while not NetworkIsSessionStarted() do Wait(500) end
        fire(loadedHandlers, {})
    end)
end

------------------------------------------------------------------------
-- NUI (kit web/kit)
------------------------------------------------------------------------

local function nui(data)
    if HAS_NUI then SendNUIMessage(data) end
end

if HAS_NUI then
    -- pop.js demande sa configuration au chargement : pas de course au démarrage.
    RegisterNUICallback('pop:ready', function(_, cb)
        cb({ locale = GetLocaleTable(), accent = Config.AccentColor })
    end)

    local closeHandlers = {}

    --- cb() quand l'interface demande sa fermeture (Échap). Le focus est déjà rendu au jeu.
    function Bridge.OnUiClose(cb)
        closeHandlers[#closeHandlers + 1] = cb
    end

    RegisterNUICallback('close', function(_, cb)
        SetNuiFocus(false, false)
        fire(closeHandlers)
        cb('ok')
    end)
else
    function Bridge.OnUiClose() end
end

------------------------------------------------------------------------
-- Notifications : type = 'info' | 'success' | 'error' | 'warning'
------------------------------------------------------------------------

local QB_TYPES = { info = 'primary', success = 'success', error = 'error', warning = 'error' }
local OX_TYPES = { info = 'inform', success = 'success', error = 'error', warning = 'warning' }

local function nativeNotify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

function Bridge.Notify(msg, notifyType, duration)
    msg = tostring(msg)
    notifyType = notifyType or 'info'
    duration = tonumber(duration) or 5000
    local mode = Bridge.NotifySystem

    if mode == 'framework' then
        if Bridge.Framework == 'esx' and ESX then
            return ESX.ShowNotification(msg, notifyType, duration)
        elseif Bridge.Framework == 'qbcore' then
            return QBCore.Functions.Notify(msg, QB_TYPES[notifyType] or 'primary', duration)
        elseif Bridge.Framework == 'qbox' then
            return exports.qbx_core:Notify(msg, OX_TYPES[notifyType] or 'inform', duration)
        end
    elseif mode == 'ox_lib' then
        return TriggerEvent('ox_lib:notify', { description = msg, type = OX_TYPES[notifyType] or 'inform', duration = duration })
    elseif mode == 'pop' and HAS_NUI then
        return nui({ action = 'pop:notify', message = msg, type = notifyType, duration = duration })
    end
    nativeNotify(msg)
end

RegisterNetEvent(RES .. ':bridge:notify', function(msg, notifyType, duration)
    Bridge.Notify(msg, notifyType, duration)
end)

------------------------------------------------------------------------
-- Prompt natif "[E] Texte" (utilisé si ni ox_target ni qb-target)
-- Une seule boucle partagée, cadence adaptée à la distance du point le plus proche.
------------------------------------------------------------------------

local points = {}       -- [id] = { coords = vec3 | entity = handle, radius, options }
local modelTargets = {} -- [id] = { hashes = { [hash] = true }, pools = { CObject = true, ... }, radius, options }
local candidates = {}   -- entités proches correspondant à un modèle : { entity, target }
local hasModels = false
local loopRunning = false
local progressActive = false
local shown, shownIndex = nil, 1 -- texte affiché, option sélectionnée

local function maxDistance(options)
    local d = 0.0
    for _, o in ipairs(options) do d = math.max(d, o.distance or DEFAULT_DISTANCE) end
    return d
end

local function showPrompt(label, index, count)
    local text = count > 1 and ('%s (%d/%d)'):format(label, index, count) or label
    if HAS_NUI then
        if shown ~= text then
            nui({ action = 'pop:prompt', show = true, key = Config.Keys.Interact.label, label = label, index = index, count = count })
        end
    else
        if shown ~= text then AddTextEntry('POP_PROMPT', ('[%s] %s'):format(Config.Keys.Interact.label, text)) end
        DisplayHelpTextThisFrame('POP_PROMPT', false)
    end
    shown = text
end

local function hidePrompt()
    if shown == nil then return end
    shown, shownIndex = nil, 1
    nui({ action = 'pop:prompt', show = false })
end

-- Recherche (1 fois par seconde) des entités proches dont le modèle est ciblé.
local function scanModels(pos)
    candidates = {}
    local pools = {}
    for _, t in pairs(modelTargets) do
        for pool in pairs(t.pools) do pools[pool] = true end
    end
    for pool in pairs(pools) do
        for _, entity in ipairs(GetGamePool(pool)) do
            local hash = GetEntityModel(entity)
            for _, t in pairs(modelTargets) do
                if t.pools[pool] and t.hashes[hash] and #(pos - GetEntityCoords(entity)) < 30.0 then
                    candidates[#candidates + 1] = { entity = entity, target = t }
                end
            end
        end
    end
end

local function validOptions(target, entity, dist)
    local list = {}
    for _, o in ipairs(target.options) do
        if dist <= (o.distance or DEFAULT_DISTANCE) then
            local ok = true
            if o.canInteract then
                local success, res = pcall(o.canInteract, entity)
                ok = success and res ~= false and res ~= nil
            end
            if ok then list[#list + 1] = o end
        end
    end
    return list
end

local function startLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local lastScan, lastBest = 0, nil
        local pos, nearest, best, bestEntity, bestDist

        -- Garde le point le plus proche, et le meilleur point à portée d'interaction.
        local function check(target, coords, entity)
            local d = #(pos - coords)
            if d < nearest then nearest = d end
            if d <= target.radius and d < bestDist then best, bestEntity, bestDist = target, entity, d end
        end

        while loopRunning do
            if next(points) == nil and not hasModels then break end

            local ped = PlayerPedId()
            pos = GetEntityCoords(ped)
            nearest, best, bestEntity, bestDist = math.huge, nil, nil, math.huge

            local now = GetGameTimer()
            if hasModels and now - lastScan >= 1000 then
                scanModels(pos)
                lastScan = now
            end

            for _, p in pairs(points) do
                if p.entity then
                    if DoesEntityExist(p.entity) then check(p, GetEntityCoords(p.entity), p.entity) end
                else
                    check(p, p.coords, nil)
                end
            end
            for _, c in ipairs(candidates) do
                if DoesEntityExist(c.entity) then check(c.target, GetEntityCoords(c.entity), c.entity) end
            end

            local opts = (best and not progressActive and not IsPauseMenuActive() and not IsEntityDead(ped))
                and validOptions(best, bestEntity, bestDist) or {}
            local count = #opts

            if count > 0 then
                if best ~= lastBest then shownIndex, lastBest = 1, best end
                if count > 1 then
                    -- Molette : changer d'option.
                    DisableControlAction(0, 14, true)
                    DisableControlAction(0, 15, true)
                    if IsDisabledControlJustPressed(0, 14) then shownIndex = shownIndex % count + 1 end
                    if IsDisabledControlJustPressed(0, 15) then shownIndex = (shownIndex - 2) % count + 1 end
                end
                if shownIndex > count then shownIndex = 1 end
                local option = opts[shownIndex]
                showPrompt(option.label, shownIndex, count)
                if IsControlJustReleased(0, Config.Keys.Interact.control) then
                    hidePrompt()
                    local entity = bestEntity
                    CreateThread(function() option.onSelect(entity) end)
                    Wait(500) -- évite un double déclenchement
                end
                Wait(0)
            else
                hidePrompt()
                lastBest = nil
                Wait(nearest < 5.0 and 100 or nearest < 30.0 and 250 or 1000)
            end
        end
        hidePrompt()
        loopRunning = false
    end)
end

------------------------------------------------------------------------
-- Target : options = { { label, icon, distance, canInteract = fn(entity), onSelect = fn(entity) }, ... }
-- Chaque Add* renvoie un id à passer à Bridge.Target.Remove(id).
------------------------------------------------------------------------

Bridge.Target = {}
local targets = {} -- [id] = { kind, handle, entity, models, names }
local lastTargetId = 0

local function newId(prefix)
    lastTargetId = lastTargetId + 1
    return ('%s_%d'):format(prefix, lastTargetId)
end

local function optionNames(id, options)
    local names = {}
    for i in ipairs(options) do names[i] = ('%s:%s:%d'):format(RES, id, i) end
    return names
end

local function oxOptions(names, options, withEntity)
    local out = {}
    for i, o in ipairs(options) do
        out[i] = {
            name = names[i],
            label = o.label,
            icon = o.icon,
            distance = o.distance or DEFAULT_DISTANCE,
            canInteract = o.canInteract and function(entity) return o.canInteract(withEntity and entity or nil) end or nil,
            onSelect = function(data) o.onSelect(withEntity and data.entity or nil) end,
        }
    end
    return out
end

local function qbOptions(options, withEntity)
    local out = {}
    for i, o in ipairs(options) do
        out[i] = {
            label = o.label,
            icon = o.icon,
            canInteract = o.canInteract and function(entity) return o.canInteract(withEntity and entity or nil) end or nil,
            action = function(entity) o.onSelect(withEntity and entity or nil) end,
        }
    end
    return { options = out, distance = maxDistance(options) }
end

local function labels(options)
    local out = {}
    for i, o in ipairs(options) do out[i] = o.label end
    return out
end

--- Zone rectangulaire. size = vec3(longueur, largeur, hauteur), heading en degrés.
function Bridge.Target.AddBoxZone(id, coords, size, heading, options)
    Bridge.Target.Remove(id)
    coords, size, heading = toVec3(coords), toVec3(size or vec3(1.5, 1.5, 2.0)), heading or 0.0
    local sys = Bridge.TargetSystem
    if sys == 'ox_target' then
        local handle = exports.ox_target:addBoxZone({
            coords = coords, size = size, rotation = heading, debug = Config.Debug,
            options = oxOptions(optionNames(id, options), options, false),
        })
        targets[id] = { kind = 'ox_zone', handle = handle }
    elseif sys == 'qb-target' then
        exports['qb-target']:AddBoxZone(id, coords, size.x, size.y, {
            name = id, heading = heading, debugPoly = Config.Debug,
            minZ = coords.z - size.z / 2, maxZ = coords.z + size.z / 2,
        }, qbOptions(options, false))
        targets[id] = { kind = 'qb_zone' }
    else
        -- NOTE: le prompt mesure la distance au centre de la zone (rayon = distance max des options,
        -- au moins la moitié du plus grand côté).
        local radius = math.max(maxDistance(options), math.max(size.x, size.y) / 2)
        points[id] = { coords = coords, radius = radius, options = options }
        targets[id] = { kind = 'point' }
        startLoop()
    end
    return id
end

--- Options sur une entité locale (ped, objet ou véhicule créé par le script).
function Bridge.Target.AddLocalEntity(entity, options)
    local id = newId('entity')
    local sys = Bridge.TargetSystem
    if sys == 'ox_target' then
        local names = optionNames(id, options)
        exports.ox_target:addLocalEntity(entity, oxOptions(names, options, true))
        targets[id] = { kind = 'ox_entity', entity = entity, names = names }
    elseif sys == 'qb-target' then
        exports['qb-target']:AddTargetEntity(entity, qbOptions(options, true))
        targets[id] = { kind = 'qb_entity', entity = entity, names = labels(options) }
    else
        points[id] = { entity = entity, radius = maxDistance(options), options = options }
        targets[id] = { kind = 'point' }
        startLoop()
    end
    return id
end

--- Options sur tous les objets / peds / véhicules d'un ou plusieurs modèles (nom ou hash).
function Bridge.Target.AddModel(models, options)
    if type(models) ~= 'table' then models = { models } end
    local id = newId('model')
    local sys = Bridge.TargetSystem
    if sys == 'ox_target' then
        local names = optionNames(id, options)
        exports.ox_target:addModel(models, oxOptions(names, options, true))
        targets[id] = { kind = 'ox_model', models = models, names = names }
    elseif sys == 'qb-target' then
        exports['qb-target']:AddTargetModel(models, qbOptions(options, true))
        targets[id] = { kind = 'qb_model', models = models, names = labels(options) }
    else
        local hashes, pools = {}, {}
        for _, m in ipairs(models) do
            local hash = type(m) == 'string' and joaat(m) or m
            hashes[hash] = true
            if IsModelAPed(hash) then pools.CPed = true
            elseif IsModelAVehicle(hash) then pools.CVehicle = true
            else pools.CObject = true end
        end
        modelTargets[id] = { hashes = hashes, pools = pools, radius = maxDistance(options), options = options }
        hasModels = true
        targets[id] = { kind = 'model' }
        startLoop()
    end
    return id
end

function Bridge.Target.Remove(id)
    local t = targets[id]
    if not t then return end
    targets[id] = nil
    if t.kind == 'ox_zone' then
        exports.ox_target:removeZone(t.handle)
    elseif t.kind == 'qb_zone' then
        exports['qb-target']:RemoveZone(id)
    elseif t.kind == 'ox_entity' then
        exports.ox_target:removeLocalEntity(t.entity, t.names)
    elseif t.kind == 'qb_entity' then
        exports['qb-target']:RemoveTargetEntity(t.entity, t.names)
    elseif t.kind == 'ox_model' then
        exports.ox_target:removeModel(t.models, t.names)
    elseif t.kind == 'qb_model' then
        exports['qb-target']:RemoveTargetModel(t.models, t.names)
    elseif t.kind == 'point' then
        points[id] = nil
    elseif t.kind == 'model' then
        modelTargets[id] = nil
        hasModels = next(modelTargets) ~= nil
        if not hasModels then candidates = {} end
    end
end

------------------------------------------------------------------------
-- Barre de progression
-- opts = { canCancel = true, disableMovement = true, disableCombat = true,
--          anim = { dict = '...', clip = '...', flag = 49 } }
------------------------------------------------------------------------

local cancelRequested = false

--- Renvoie true si terminée, false si annulée (touche, mort, ou Bridge.CancelProgress()).
function Bridge.Progress(label, duration, opts)
    if progressActive then return false end
    opts = opts or {}
    duration = tonumber(duration) or 0
    progressActive, cancelRequested = true, false
    hidePrompt()

    local ped = PlayerPedId()
    local anim = opts.anim
    if anim and anim.dict then
        RequestAnimDict(anim.dict)
        local timeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end
        if HasAnimDictLoaded(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
        end
    end

    local canCancel = opts.canCancel ~= false
    nui({
        action = 'pop:progress', show = true, label = label, duration = duration,
        cancelKey = canCancel and Config.Keys.Cancel.label or nil,
    })

    local finish = GetGameTimer() + duration
    local cancelled = false
    while GetGameTimer() < finish do
        if opts.disableMovement ~= false then
            DisableControlAction(0, 30, true) -- gauche / droite
            DisableControlAction(0, 31, true) -- avant / arrière
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- saut
        end
        if opts.disableCombat ~= false then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
        end
        if cancelRequested or IsEntityDead(ped)
            or (canCancel and IsControlJustPressed(0, Config.Keys.Cancel.control)) then
            cancelled = true
            break
        end
        if not HAS_NUI then
            local pct = math.floor((1 - (finish - GetGameTimer()) / math.max(duration, 1)) * 100)
            AddTextEntry('POP_PROGRESS', ('%s %d%%'):format(label, pct))
            DisplayHelpTextThisFrame('POP_PROGRESS', false)
        end
        Wait(0)
    end

    if anim and anim.dict then
        StopAnimTask(ped, anim.dict, anim.clip, 1.0)
        RemoveAnimDict(anim.dict)
    end
    nui({ action = 'pop:progress', show = false })
    progressActive = false
    if cancelled then Bridge.Notify(L('progress_cancelled'), 'error') end
    return not cancelled
end

function Bridge.CancelProgress()
    if progressActive then cancelRequested = true end
end

function Bridge.IsBusy()
    return progressActive
end

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id in pairs(targets) do pcall(Bridge.Target.Remove, id) end
    loopRunning = false
    if progressActive then ClearPedTasks(PlayerPedId()) end
    if HAS_NUI then SetNuiFocus(false, false) end
end)
