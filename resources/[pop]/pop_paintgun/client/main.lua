-- pop_paintgun : client (ouverture du sélecteur, barre, effets ; application de la couleur demandée par le serveur).
-- Aucune boucle permanente : tout est déclenché par l'event d'ouverture ou la NUI.

local VEHICLE_DISTANCE = 4.0
local SESSION_TIMEOUT = 120 -- secondes (côté serveur ; repris ici pour fermer une UI oubliée)

local PROP_MODEL = joaat('prop_cs_spray_can')
local PTFX_ASSET = 'scr_recartheft'
local PTFX_NAME = 'scr_carsteal4_spraycan'
local ANIM = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 49 }

local TARGETS = { primary = true, secondary = true, both = true }

-- Couleurs autorisées : [id] = hex, et liste envoyée à la NUI.
local allowed, nuiColors = {}, {}
for i, c in ipairs(Config.Colors or {}) do
    allowed[c.id] = c.hex
    nuiColors[i] = { id = c.id, hex = c.hex }
end

local uiOpen = false   -- sélecteur affiché
local working = false  -- peinture en cours (barre, attente serveur, application)
local session = nil    -- { netId, openedAt }
local prop, fx = nil, nil

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function hexToRgb(hex)
    if type(hex) ~= 'string' then return 1.0, 1.0, 1.0 end
    local r, g, b = hex:match('^#?(%x%x)(%x%x)(%x%x)$')
    if not r then return 1.0, 1.0, 1.0 end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function closestVehicle(pos)
    local best, bestDist = nil, VEHICLE_DISTANCE
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(pos - GetEntityCoords(veh))
        if d <= bestDist and NetworkGetEntityIsNetworked(veh) then
            best, bestDist = veh, d
        end
    end
    return best
end

local function vehicleFromNetId(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

local function closeUi()
    if uiOpen then
        SendNUIMessage({ action = 'pop_paintgun:close' })
    end
    SetNuiFocus(false, false)
    uiOpen = false
end

------------------------------------------------------------------------
-- Effets (bombe en main + jet coloré)
------------------------------------------------------------------------

local function stopEffects()
    if fx then
        StopParticleFxLooped(fx, false)
        fx = nil
    end
    if prop then
        if DoesEntityExist(prop) then
            DetachEntity(prop, true, false)
            DeleteEntity(prop)
        end
        prop = nil
    end
    RemoveNamedPtfxAsset(PTFX_ASSET)
end

local function startEffects(ped, hex)
    RequestModel(PROP_MODEL)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(PROP_MODEL) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(PROP_MODEL) then return end

    local pos = GetEntityCoords(ped)
    prop = CreateObject(PROP_MODEL, pos.x, pos.y, pos.z + 0.2, false, true, false)
    SetModelAsNoLongerNeeded(PROP_MODEL)
    if not prop or prop == 0 then
        prop = nil
        return
    end
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005),
        0.12, 0.0, -0.04, -70.0, 0.0, 0.0, true, true, false, true, 1, true)

    RequestNamedPtfxAsset(PTFX_ASSET)
    timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(PTFX_ASSET) and GetGameTimer() < timeout do Wait(50) end
    if not HasNamedPtfxAssetLoaded(PTFX_ASSET) or not prop then return end

    UseParticleFxAsset(PTFX_ASSET)
    fx = StartParticleFxLoopedOnEntity(PTFX_NAME, prop, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    if fx and fx ~= 0 then
        local r, g, b = hexToRgb(hex)
        SetParticleFxLoopedColour(fx, r, g, b, false)
    else
        fx = nil
    end
end

-- Préchargement pendant que le sélecteur est ouvert (la barre démarre sans attente).
local function preloadEffects()
    RequestModel(PROP_MODEL)
    RequestNamedPtfxAsset(PTFX_ASSET)
end

local function releasePreload()
    SetModelAsNoLongerNeeded(PROP_MODEL)
    RemoveNamedPtfxAsset(PTFX_ASSET)
end

------------------------------------------------------------------------
-- Application de la couleur : demandée par le serveur au propriétaire réseau du véhicule
-- (repli : le peintre), après validation complète côté serveur.
------------------------------------------------------------------------

local function applyColour(veh, color, target)
    NetworkRequestControlOfEntity(veh)
    for _ = 1, 10 do
        if NetworkHasControlOfEntity(veh) then break end
        Wait(100)
        NetworkRequestControlOfEntity(veh)
    end
    if not DoesEntityExist(veh) then return end

    local p, s = GetVehicleColours(veh)
    if target == 'primary' or target == 'both' then
        ClearVehicleCustomPrimaryColour(veh)
        p = color
    end
    if target == 'secondary' or target == 'both' then
        ClearVehicleCustomSecondaryColour(veh)
        s = color
    end
    SetVehicleColours(veh, p, s)
end

------------------------------------------------------------------------
-- Peinture
------------------------------------------------------------------------

local function paint(netId, color, target)
    working = true
    local ped = PlayerPedId()
    local veh = vehicleFromNetId(netId)
    if not veh then
        working = false
        releasePreload()
        return Bridge.Notify(L('no_vehicle'), 'error')
    end

    TaskTurnPedToFaceEntity(ped, veh, 500)
    Wait(500)

    startEffects(ped, allowed[color])
    local done = Bridge.Progress(L('painting'), Config.Duration, { anim = ANIM })
    stopEffects()

    if done then
        -- Succès : le serveur notifie et fait appliquer la couleur par le propriétaire réseau.
        local ok, reason, arg = Callback.Await('pop_paintgun:paint', netId, color, target)
        if not ok then
            Bridge.Notify(L(reason or 'error', arg), 'error')
        end
    end
    working = false
end

------------------------------------------------------------------------
-- Application demandée par le serveur (ce client est propriétaire réseau du véhicule, ou le peintre en repli)
------------------------------------------------------------------------

RegisterNetEvent('pop_paintgun:client:apply', function(netId, color, target)
    netId = math.tointeger(netId)
    color = math.tointeger(color)
    if not netId or not color or not allowed[color] then return end
    if type(target) ~= 'string' or not TARGETS[target] then return end
    local veh = vehicleFromNetId(netId)
    if veh then applyColour(veh, color, target) end
end)

------------------------------------------------------------------------
-- Ouverture (event serveur, après utilisation de l'item)
------------------------------------------------------------------------

-- Attend que la NUI d'une autre interface soit libérée (1 s max). true si libre.
local function waitNuiFree()
    local timeout = GetGameTimer() + 1000
    while IsNuiFocused() and GetGameTimer() < timeout do Wait(50) end
    return not IsNuiFocused()
end

RegisterNetEvent('pop_paintgun:client:open', function()
    if uiOpen then
        if IsNuiFocused() then return end -- sélecteur réellement ouvert
        closeUi() -- état orphelin (focus perdu) : on repart proprement
        releasePreload()
        session = nil
    end
    if working or Bridge.IsBusy() then return end
    if not waitNuiFree() then return end
    if uiOpen or working or Bridge.IsBusy() then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    local veh = closestVehicle(GetEntityCoords(ped))
    if not veh then
        return Bridge.Notify(L('no_vehicle'), 'error')
    end

    local p, s = GetVehicleColours(veh)
    session = { netId = NetworkGetNetworkIdFromEntity(veh), openedAt = GetGameTimer() }
    uiOpen = true
    preloadEffects()
    SendNUIMessage({
        action = 'pop_paintgun:open',
        colors = nuiColors,
        current = { primary = p, secondary = s },
    })
    SetNuiFocus(true, true)
end)

------------------------------------------------------------------------
-- NUI
------------------------------------------------------------------------

RegisterNUICallback('pop_paintgun:apply', function(data, cb)
    cb({ ok = true })
    local wasOpen = uiOpen
    closeUi() -- le focus est toujours rendu, même si les données sont refusées

    local s = session
    session = nil
    if not wasOpen or working then return end

    data = type(data) == 'table' and data or {}
    local n = tonumber(data.color)
    local color = n and math.tointeger(n)
    local target = data.target
    if not s or GetGameTimer() - s.openedAt > SESSION_TIMEOUT * 1000
        or not color or not allowed[color]
        or type(target) ~= 'string' or not TARGETS[target] then
        releasePreload() -- refus : ressources préchargées libérées
        return
    end

    -- Ressources préchargées : libérées par startEffects / stopEffects.
    CreateThread(function() paint(s.netId, color, target) end)
end)

Bridge.OnUiClose(function()
    if uiOpen and not working then releasePreload() end
    uiOpen = false
    session = nil
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_paintgun:close' })
    stopEffects()
end)
