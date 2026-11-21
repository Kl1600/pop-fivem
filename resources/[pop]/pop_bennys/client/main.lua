-- pop_bennys : client (zones, blips, ouverture, aperçu, caméra, NUI).
-- Le client n'applique qu'un aperçu : le prix, le paiement et la sauvegarde sont décidés par le serveur.

local NEAR_DISTANCE = 50.0
local WHEEL_MOD = 23
local BACK_WHEEL_MOD = 24
local MAX_OPEN_SPEED = 2.0
-- Classes refusées : vélos, bateaux, hélicoptères, avions, trains.
local BLOCKED_CLASSES = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }
local CAM_INTERP = 500

-- Décalages locaux du véhicule (SPEC section 11).
local CAMERAS = {
    paint       = { pos = { 4.4, 0.0, 1.0 },   look = { 0.0, 0.0, 0.5 } },
    wheels      = { pos = { 3.0, 1.6, 0.2 },   look = { 0.0, 1.6, 0.1 } },
    body        = { pos = { 3.2, -3.2, 1.4 },  look = { 0.0, 0.0, 0.6 } },
    performance = { pos = { 0.0, 4.4, 1.3 },   look = { 0.0, 1.6, 0.6 } },
    lights      = { pos = { 3.2, 2.2, 0.1 },   look = { 0.0, 0.0, -0.3 } },
    windows     = { pos = { 2.6, 0.4, 1.3 },   look = { 0.0, 0.2, 1.0 } },
}

local PAINT_KEYS = { 'color1', 'color2', 'pearlescentColor', 'wheelColor' }
local PERF_INDEXES = { 11, 12, 13, 15, 16 } -- moteur, freins, transmission, suspension, blindage

local blips = {}
local session = nil      -- { veh, netId, shop, snapshot, extra, touched, radarHidden, bike, buying, cancelAfter }
local opening = false
local promptShown = false
local zoneShop, zoneAllowed = nil, nil -- cache du droit d'accès pour l'atelier où l'on se trouve
local cams, currentCam = {}, nil

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

-- Les nombres reçus de la NUI (JSON) peuvent arriver en flottants : 2.0 -> 2.
local function normalize(v)
    if type(v) == 'number' then
        return math.tointeger(v) or v
    elseif type(v) == 'table' then
        local out = {}
        for k, x in pairs(v) do out[k] = normalize(x) end
        return out
    end
    return v
end

local function clampInt(v, lo, hi, default)
    if math.type(v) ~= 'integer' or v < lo or v > hi then return default end
    return v
end

local function showPrompt()
    if promptShown then return end
    promptShown = true
    SendNUIMessage({ action = 'pop:prompt', show = true, key = Config.Keys.Interact.label, label = L('open_hint') })
end

local function hidePrompt()
    if not promptShown then return end
    promptShown = false
    SendNUIMessage({ action = 'pop:prompt', show = false })
end

-- Même format que Bridge.HasJob côté serveur : 'job', { 'a', 'b' } ou { job = gradeMin }. En service requis.
-- Simple confort d'affichage : le serveur revérifie.
local function hasJob(jobs)
    if not jobs then return true end
    local job = Bridge.GetJob()
    if not job or not job.onDuty then return false end
    if type(jobs) == 'string' then return job.name == jobs end
    if type(jobs) ~= 'table' then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' then
            if v == job.name then return true end
        elseif k == job.name then
            return (job.grade or 0) >= (tonumber(v) or 0)
        end
    end
    return false
end

Bridge.OnJobUpdate(function() zoneAllowed = nil end)

------------------------------------------------------------------------
-- Prix et contenu du menu (SPEC section 6)
------------------------------------------------------------------------

-- Prix affiché : nombre, ou liste des niveaux pour la performance (même source que Bennys.Price).
local function priceFor(key)
    local pk = Bennys.PriceKey(key)
    return pk and Config.Prices[pk] or 0
end

local function buildMenu(veh, current, bike)
    local prices, byCat = {}, {}

    local function add(cat, item)
        prices[item.key] = priceFor(item.key)
        byCat[cat] = byCat[cat] or {}
        byCat[cat][#byCat[cat] + 1] = item
    end

    -- Peinture
    for _, key in ipairs(PAINT_KEYS) do
        add('paint', { key = key, type = 'color', value = current[key] or 0 })
    end

    -- Roues
    if bike then
        add('wheels', { key = 'wheels', type = 'list', value = 6, min = 6, max = 6 })
    else
        add('wheels', { key = 'wheels', type = 'list', value = clampInt(current.wheels, 0, 12, 0), min = 0, max = 12 })
    end
    add('wheels', {
        key = 'modFrontWheels', type = 'list', value = current.modFrontWheels or -1,
        min = -1, max = GetNumVehicleMods(veh, WHEEL_MOD) - 1,
    })

    -- Carrosserie : seulement les pièces disponibles sur ce modèle
    for _, i in ipairs(Bennys.BODY) do
        local count = GetNumVehicleMods(veh, i)
        local key = Props.MODS[i]
        if key and count > 0 then
            add('body', { key = key, type = 'list', value = current[key] or -1, min = -1, max = count - 1 })
        end
    end

    -- Performance : niveaux limités par le modèle et par la config
    for _, i in ipairs(PERF_INDEXES) do
        local key = Props.MODS[i]
        local levels = Config.Prices[Bennys.PERF[key]]
        local max = math.min(GetNumVehicleMods(veh, i), type(levels) == 'table' and #levels or 0) - 1
        if max >= 0 then
            add('performance', { key = key, type = 'list', value = current[key] or -1, min = -1, max = max })
        end
    end
    add('performance', { key = 'modTurbo', type = 'toggle', value = current.modTurbo == true })

    -- Éclairage
    add('lights', { key = 'modXenon', type = 'toggle', value = current.modXenon == true })
    add('lights', { key = 'xenonColor', type = 'list', value = clampInt(current.xenonColor, -1, 12, -1), min = -1, max = 12 })
    add('lights', { key = 'neonEnabled', type = 'neon', value = current.neonEnabled or { false, false, false, false } })
    add('lights', { key = 'neonColor', type = 'neoncolor', value = current.neonColor or { 255, 255, 255 } })

    -- Vitres
    add('windows', { key = 'windowTint', type = 'list', value = clampInt(current.windowTint, 0, 6, 0), min = 0, max = 6 })

    local categories = {}
    for _, id in ipairs(Bennys.CATEGORIES) do
        if byCat[id] and #byCat[id] > 0 then
            categories[#categories + 1] = { id = id, items = byCat[id] }
        end
    end

    local colors = {}
    for i, c in ipairs(Config.Colors) do colors[i] = { id = c.id, hex = c.hex } end

    return {
        action = 'pop_bennys:open',
        colors = colors,
        neonColors = Config.NeonColors,
        prices = prices,
        categories = categories,
    }
end

------------------------------------------------------------------------
-- Caméra
------------------------------------------------------------------------

------------------------------------------------------------------------
-- État hors format Props (peinture RGB, variation de jante) et restauration
------------------------------------------------------------------------

local function customColour(veh, primary)
    if primary then
        if not GetIsVehiclePrimaryColourCustom(veh) then return nil end
        return table.pack(GetVehicleCustomPrimaryColour(veh))
    end
    if not GetIsVehicleSecondaryColourCustom(veh) then return nil end
    return table.pack(GetVehicleCustomSecondaryColour(veh))
end

local function readExtra(veh)
    return {
        primary = customColour(veh, true),
        secondary = customColour(veh, false),
        variation = GetVehicleModVariation(veh, WHEEL_MOD),
        backVariation = GetVehicleModVariation(veh, BACK_WHEEL_MOD),
    }
end

-- Remet seulement ce que l'aperçu a touché (le reste n'a jamais été modifié par le script).
local function restore(s)
    if not DoesEntityExist(s.veh) or next(s.touched) == nil then return end
    local snap, t = s.snapshot, s.touched
    local p = {}
    for key in pairs(t) do p[key] = snap[key] end
    local wheelsTouched = t.wheels or t.modFrontWheels or t.modBackWheels
    if wheelsTouched then
        p.modFrontWheels = snap.modFrontWheels
        p.modBackWheels = snap.modBackWheels
    end
    Props.Set(s.veh, p)

    local x = s.extra
    if t.color1 and x.primary then SetVehicleCustomPrimaryColour(s.veh, x.primary[1], x.primary[2], x.primary[3]) end
    if t.color2 and x.secondary then SetVehicleCustomSecondaryColour(s.veh, x.secondary[1], x.secondary[2], x.secondary[3]) end
    if wheelsTouched then
        if snap.modFrontWheels then SetVehicleMod(s.veh, WHEEL_MOD, snap.modFrontWheels, x.variation == true or x.variation == 1) end
        if snap.modBackWheels then SetVehicleMod(s.veh, BACK_WHEEL_MOD, snap.modBackWheels, x.backVariation == true or x.backVariation == 1) end
    end
end

local function destroyCams()
    for cam in pairs(cams) do
        if DoesCamExist(cam) then
            SetCamActive(cam, false)
            DestroyCam(cam, false)
        end
    end
    cams, currentCam = {}, nil
end

local function setCamera(category)
    local view = CAMERAS[category]
    if not view or not session or not DoesEntityExist(session.veh) then return end
    local veh = session.veh
    local pos = GetOffsetFromEntityInWorldCoords(veh, view.pos[1], view.pos[2], view.pos[3])
    local look = GetOffsetFromEntityInWorldCoords(veh, view.look[1], view.look[2], view.look[3])

    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    cams[cam] = true

    local previous = currentCam
    currentCam = cam
    if previous and DoesCamExist(previous) then
        SetCamActiveWithInterp(cam, previous, CAM_INTERP, 1, 1)
        SetTimeout(CAM_INTERP + 100, function()
            if currentCam ~= previous and cams[previous] then
                cams[previous] = nil
                if DoesCamExist(previous) then DestroyCam(previous, false) end
            end
        end)
    else
        SetCamActive(cam, true)
        RenderScriptCams(true, true, CAM_INTERP, true, true)
    end

    -- Phares allumés pour voir xénon et néons.
    SetVehicleLights(veh, category == 'lights' and 2 or 0)
end

------------------------------------------------------------------------
-- Ouverture / fermeture
------------------------------------------------------------------------

-- doRestore = true : annulation (véhicule remis dans son état d'origine) ; false : achat réussi.
local function finish(doRestore, notifyServer)
    local s = session
    if not s then return end
    session = nil

    local exists = DoesEntityExist(s.veh)
    if doRestore and exists then restore(s) end
    if notifyServer then Callback.Trigger('pop_bennys:close', function() end, s.netId) end

    RenderScriptCams(false, true, CAM_INTERP, true, true)
    destroyCams()
    if exists then
        FreezeEntityPosition(s.veh, false)
        SetVehicleLights(s.veh, 0)
    end
    DisplayRadar(not s.radarHidden)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_bennys:close' })
end

local function cancel()
    local s = session
    if not s then return end
    if s.buying then
        s.cancelAfter = true -- résolu à la réponse du serveur
        return
    end
    finish(true, true)
end

local function isDriver(ped, veh)
    return veh ~= 0 and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped
end

local function watch(s)
    CreateThread(function()
        while session == s do
            Wait(500)
            if session ~= s then break end
            local ped = PlayerPedId()
            if not DoesEntityExist(s.veh) or IsEntityDead(ped) or GetPedInVehicleSeat(s.veh, -1) ~= ped then
                cancel()
            end
        end
    end)
end

local function open(index)
    if session or opening then return end
    opening = true
    hidePrompt()

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not isDriver(ped, veh) then
        opening = false
        return Bridge.Notify(L('not_driver'), 'error')
    end
    if not NetworkGetEntityIsNetworked(veh) or BLOCKED_CLASSES[GetVehicleClass(veh)] then
        opening = false
        return Bridge.Notify(L('vehicle_not_allowed'), 'error')
    end
    if GetEntitySpeed(veh) >= MAX_OPEN_SPEED then
        opening = false
        return Bridge.Notify(L('error'), 'error')
    end

    local current = Props.Get(veh)
    if not current then
        opening = false
        return Bridge.Notify(L('error'), 'error')
    end

    local netId = VehToNet(veh)
    local ok, reason = Callback.Await('pop_bennys:open', netId, index, current)
    if not ok then
        opening = false
        return Bridge.Notify(L(reason or 'error'), 'error')
    end

    -- Le joueur a pu quitter le véhicule pendant l'attente.
    ped = PlayerPedId()
    if not isDriver(ped, veh) then
        opening = false
        Callback.Trigger('pop_bennys:close', function() end, netId)
        return Bridge.Notify(L('not_driver'), 'error')
    end

    -- Moto (les vélos, classe 13, sont refusés plus haut) : même règle que le serveur (GetVehicleType 'bike').
    local isBike = IsThisModelABike(GetEntityModel(veh))
    local bike = isBike == true or isBike == 1
    local radarHidden = IsRadarHidden()
    session = {
        veh = veh, netId = netId, shop = index, snapshot = current, extra = readExtra(veh), touched = {},
        radarHidden = radarHidden == true or radarHidden == 1, bike = bike,
    }

    SetVehicleModKit(veh, 0)
    FreezeEntityPosition(veh, true)
    DisplayRadar(false)
    setCamera('paint')
    SendNUIMessage(buildMenu(veh, current, bike))
    SetNuiFocus(true, true)
    opening = false
    watch(session)
end

------------------------------------------------------------------------
-- NUI
------------------------------------------------------------------------

RegisterNUICallback('pop_bennys:preview', function(data, cb)
    local s = session
    if not s or s.buying or type(data) ~= 'table' or type(data.key) ~= 'string' or not DoesEntityExist(s.veh) then
        return cb({ ok = false })
    end
    local key, value = data.key, normalize(data.value)
    if not Bennys.Valid(key, value) then return cb({ ok = false }) end

    local updates = {}
    s.touched[key] = true
    if key == 'wheels' then
        local changes = { wheels = value, modFrontWheels = -1 }
        if s.bike then changes.modBackWheels = -1 end
        Props.Set(s.veh, changes)
        updates[1] = { key = 'modFrontWheels', max = GetNumVehicleMods(s.veh, WHEEL_MOD) - 1, value = -1 }
    else
        local changes = { [key] = value }
        if key == 'modFrontWheels' and s.bike then changes.modBackWheels = value end
        Props.Set(s.veh, changes)
    end
    cb({ ok = true, updates = updates })
end)

RegisterNUICallback('pop_bennys:camera', function(data, cb)
    if session and type(data) == 'table' and CAMERAS[data.category] then
        setCamera(data.category)
    end
    cb({ ok = true })
end)

RegisterNUICallback('pop_bennys:confirm', function(data, cb)
    local s = session
    if not s or s.buying then return cb({ ok = false, error = 'busy' }) end
    if type(data) ~= 'table' or type(data.changes) ~= 'table' then return cb({ ok = false, error = 'invalid_change' }) end

    local changes = {}
    for i, c in ipairs(data.changes) do
        if type(c) ~= 'table' or type(c.key) ~= 'string' then return cb({ ok = false, error = 'invalid_change' }) end
        changes[i] = { key = c.key, value = normalize(c.value) }
    end

    s.buying = true
    CreateThread(function()
        local ok, reason, arg = Callback.Await('pop_bennys:buy', s.netId, changes)
        s.buying = false
        if session ~= s then return cb({ ok = false, error = 'error' }) end

        -- Aucune réponse : l'achat a pu passer, on ferme sans restaurer.
        if ok == nil then
            Bridge.Notify(L('error'), 'error')
            cb({ ok = true })
            finish(false, true)
            return
        end

        if ok then
            cb({ ok = true })
            finish(false, false) -- le serveur a supprimé la session et notifié
            return
        end

        reason = reason or 'error'
        Bridge.Notify(L(reason, arg), 'error')
        cb({ ok = false, error = reason })
        if s.cancelAfter then finish(true, true) end
    end)
end)

-- Échap ou bouton Annuler (le bridge a déjà rendu le focus).
Bridge.OnUiClose(cancel)

exports('IsOpen', function()
    return session ~= nil
end)

------------------------------------------------------------------------
-- Blips et boucle de zone
------------------------------------------------------------------------

CreateThread(function()
    for i, shop in ipairs(Config.Shops) do
        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, 72)
            SetBlipColour(blip, 0)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip'))
            EndTextCommandSetBlipName(blip)
            blips[i] = blip
        end
    end
end)

CreateThread(function()
    while true do
        local wait
        if session or opening then
            hidePrompt()
            wait = 500
        else
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local nearest, index = math.huge, nil
            for i, shop in ipairs(Config.Shops) do
                local d = #(pos - shop.coords)
                if d < nearest then nearest, index = d, i end
            end

            local inside = index and nearest <= Config.Shops[index].radius
            if not inside then zoneShop, zoneAllowed = nil, nil end

            local veh = inside and GetVehiclePedIsIn(ped, false) or 0
            if inside and isDriver(ped, veh) and not IsEntityDead(ped) and not IsPauseMenuActive() then
                if zoneShop ~= index or zoneAllowed == nil then
                    zoneShop, zoneAllowed = index, hasJob(Config.Shops[index].jobs)
                end
                if zoneAllowed then
                    wait = 0
                    DisableControlAction(0, 86, true) -- klaxon (même touche que E en véhicule)
                    showPrompt()
                    if IsDisabledControlJustReleased(0, 86) or IsControlJustReleased(0, Config.Keys.Interact.control) then
                        hidePrompt()
                        opening = true -- bloque la boucle jusqu'au début de open()
                        CreateThread(function()
                            opening = false
                            open(index)
                        end)
                    end
                else
                    hidePrompt()
                    wait = 500
                end
            else
                hidePrompt()
                wait = nearest <= NEAR_DISTANCE and 500 or 1500
            end
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local s = session
    session = nil
    if s and DoesEntityExist(s.veh) then
        restore(s)
        FreezeEntityPosition(s.veh, false)
        SetVehicleLights(s.veh, 0)
    end
    if s then RenderScriptCams(false, false, 0, true, true) end
    destroyCams()
    if s then DisplayRadar(not s.radarHidden) end
    SetNuiFocus(false, false)
    hidePrompt()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end)
