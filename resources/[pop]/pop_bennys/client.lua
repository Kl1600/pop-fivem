local nuiOpen    = false
local vehicle    = 0
local origMods   = {}
local buildItemDb

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

-- Certains natives renvoient un booléen, d'autres 0/1 : on normalise.
local function isOn(v) return v == true or v == 1 end

local function saveOrig(veh)
    local p1, p2 = GetVehicleColours(veh)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)

    origMods = {
        isCustomP  = GetIsVehiclePrimaryColourCustom(veh),
        isCustomS  = GetIsVehicleSecondaryColourCustom(veh),
        pIdx       = p1, sIdx = p2,
        pr = r1, pg = g1, pb = b1,
        sr = r2, sg = g2, sb = b2,
        wheelType  = GetVehicleWheelType(veh),
        wheelMod   = GetVehicleMod(veh, 23),
        customTire = GetVehicleModVariation(veh, 23),
        mods       = {},
        engine     = GetVehicleMod(veh, 11),
        brakes     = GetVehicleMod(veh, 12),
        trans      = GetVehicleMod(veh, 13),
        susp       = GetVehicleMod(veh, 15),
        armor      = GetVehicleMod(veh, 16),
        turbo      = IsToggleModOn(veh, 18),
        xenon      = IsToggleModOn(veh, 22),
        nr = nr, ng = ng, nb = nb,
        neons      = {
            IsVehicleNeonLightEnabled(veh, 0),
            IsVehicleNeonLightEnabled(veh, 1),
            IsVehicleNeonLightEnabled(veh, 2),
            IsVehicleNeonLightEnabled(veh, 3),
        },
        winTint    = GetVehicleWindowTint(veh),
        plateStyle = GetVehicleNumberPlateTextIndex(veh),
        plateText  = GetVehicleNumberPlateText(veh),
        livery     = GetVehicleLivery(veh),
        liveryMod  = GetVehicleMod(veh, 48),
        extras     = {},
    }
    for _, mt in ipairs({0,1,2,3,4,6,7,8,9,10}) do
        origMods.mods[mt] = GetVehicleMod(veh, mt)
    end
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            origMods.extras[i] = isOn(IsVehicleExtraTurnedOn(veh, i))
        end
    end
end

local function revertAll()
    if not DoesEntityExist(vehicle) then return end
    local v = vehicle
    if origMods.isCustomP then
        SetVehicleCustomPrimaryColour(v, origMods.pr, origMods.pg, origMods.pb)
    else
        SetVehicleColours(v, origMods.pIdx, origMods.sIdx)
    end
    if origMods.isCustomS then
        SetVehicleCustomSecondaryColour(v, origMods.sr, origMods.sg, origMods.sb)
    end
    SetVehicleWheelType(v, origMods.wheelType)
    SetVehicleMod(v, 23, origMods.wheelMod, origMods.customTire)
    for mt, idx in pairs(origMods.mods) do SetVehicleMod(v, mt, idx, false) end
    SetVehicleMod(v, 11, origMods.engine, false)
    SetVehicleMod(v, 12, origMods.brakes, false)
    SetVehicleMod(v, 13, origMods.trans,  false)
    SetVehicleMod(v, 15, origMods.susp,   false)
    SetVehicleMod(v, 16, origMods.armor,  false)
    ToggleVehicleMod(v, 18, origMods.turbo)
    ToggleVehicleMod(v, 22, origMods.xenon)
    SetVehicleNeonLightsColour(v, origMods.nr, origMods.ng, origMods.nb)
    for i, on in ipairs(origMods.neons) do SetVehicleNeonLightEnabled(v, i - 1, on) end
    SetVehicleWindowTint(v, origMods.winTint)
    SetVehicleNumberPlateTextIndex(v, origMods.plateStyle)
    SetVehicleNumberPlateText(v, origMods.plateText)
    if origMods.livery ~= nil and origMods.livery >= 0 then SetVehicleLivery(v, origMods.livery) end
    if origMods.liveryMod ~= nil then SetVehicleMod(v, 48, origMods.liveryMod, false) end
    if origMods.extras then
        for id, on in pairs(origMods.extras) do SetVehicleExtra(v, id, on and 0 or 1) end
    end
end

local function buildVehicleData(veh)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)

    local modCounts = {}
    for _, mt in ipairs({0,1,2,3,4,6,7,8,9,10,11,12,13,15,16,23,48}) do
        modCounts[tostring(mt)] = GetNumVehicleMods(veh, mt)
    end

    local bodyMods = {}
    for _, mt in ipairs({0,1,2,3,4,6,7,8,9,10}) do
        bodyMods[tostring(mt)] = GetVehicleMod(veh, mt)
    end

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            extras[#extras + 1] = { id = i, on = isOn(IsVehicleExtraTurnedOn(veh, i)) }
        end
    end

    return {
        model      = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        plate      = GetVehicleNumberPlateText(veh),
        modCounts  = modCounts,
        pr = r1, pg = g1, pb = b1,
        sr = r2, sg = g2, sb = b2,
        isCustomP  = GetIsVehiclePrimaryColourCustom(veh),
        isCustomS  = GetIsVehicleSecondaryColourCustom(veh),
        wheelType  = GetVehicleWheelType(veh),
        wheelMod   = GetVehicleMod(veh, 23),
        bodyMods   = bodyMods,
        engine     = GetVehicleMod(veh, 11),
        brakes     = GetVehicleMod(veh, 12),
        trans      = GetVehicleMod(veh, 13),
        susp       = GetVehicleMod(veh, 15),
        armor      = GetVehicleMod(veh, 16),
        turbo      = IsToggleModOn(veh, 18),
        xenon      = IsToggleModOn(veh, 22),
        nr = nr, ng = ng, nb = nb,
        neons      = {
            IsVehicleNeonLightEnabled(veh, 0),
            IsVehicleNeonLightEnabled(veh, 1),
            IsVehicleNeonLightEnabled(veh, 2),
            IsVehicleNeonLightEnabled(veh, 3),
        },
        winTint    = GetVehicleWindowTint(veh),
        plateStyle = GetVehicleNumberPlateTextIndex(veh),
        plateText  = GetVehicleNumberPlateText(veh),
        liveryCount= GetVehicleLiveryCount(veh),
        livery     = GetVehicleLivery(veh),
        liveryMod  = GetVehicleMod(veh, 48),
        extras     = extras,
    }
end

-- ─────────────────────────────────────────────
-- Caméra (une vue par catégorie)
-- ─────────────────────────────────────────────

local cam = nil

local function focusCamera(catId)
    if not DoesEntityExist(vehicle) then return end
    local c = (Config.Cameras and Config.Cameras[catId]) or (Config.Cameras and Config.Cameras.body)
    if not c then return end

    local p = GetOffsetFromEntityInWorldCoords(vehicle, c.pos[1],  c.pos[2],  c.pos[3])
    local t = GetOffsetFromEntityInWorldCoords(vehicle, c.look[1], c.look[2], c.look[3])

    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        p.x, p.y, p.z, 0.0, 0.0, 0.0, Config.CameraFov or 50.0, false, 0)
    PointCamAtCoord(newCam, t.x, t.y, t.z)

    if cam then
        -- Transition douce depuis la vue précédente.
        SetCamActiveWithInterp(newCam, cam, 700, 1, 1)
        local old = cam
        CreateThread(function()
            Wait(750)
            if DoesCamExist(old) then DestroyCam(old, false) end
        end)
    else
        SetCamActive(newCam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    cam = newCam
end

local function destroyCamera()
    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
end

-- ─────────────────────────────────────────────
-- Open / Close
-- ─────────────────────────────────────────────

local function openMenu()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(veh) or veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)
    end
    if not DoesEntityExist(veh) or veh == 0 then
        exports['pop_notify']:ShowNotify({ icon = 'fas fa-circle-info', message = 'Aucun véhicule à proximité.', duration = 3000 })
        return
    end

    SetVehicleModKit(veh, 0)
    saveOrig(veh)
    vehicle = veh
    nuiOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action      = 'open',
        vehicle     = buildVehicleData(veh),
        itemCosts   = Config.ItemCosts,
        itemDb      = buildItemDb(),
        unknownIcon = Config.ItemIconBase .. Config.UnknownIcon,
    })

    -- Vue initiale = première catégorie du menu (jantes).
    focusCamera('wheels')

    -- Masque HUD + minimap (pop_hud) + speedometer le temps du menu.
    TriggerEvent('hud:toggleui', false)
    DisplayRadar(false)
end

-- Base des items référencés par les recettes : pour chaque defId, on résout son
-- label, sa vraie icône et la quantité possédée par le joueur.
-- L'icône/label viennent de pop_inventory (export GetItemDef) si dispo, sinon des
-- valeurs du config ; si rien n'existe -> icône '?'. Robuste si l'export manque.
local function safeExport(fn, default)
    local ok, res = pcall(fn)
    if ok then return res end
    return default
end

buildItemDb = function()
    local inv = exports[Config.Inventory]
    local base, unknown = Config.ItemIconBase, Config.UnknownIcon
    local db = {}
    for _, recipe in pairs(Config.ItemCosts) do
        for _, need in ipairs(recipe) do
            if db[need.item] == nil then
                local def   = safeExport(function() return inv:GetItemDef(need.item) end, nil)
                local owned = safeExport(function() return inv:getItemCount(need.item) end, 0) or 0
                local icon  = (def and def.icon) or need.icon or unknown
                db[need.item] = {
                    label = (def and def.label) or need.label or need.item,
                    icon  = base .. icon,
                    owned = owned,
                }
            end
        end
    end
    return db
end

local function closeMenu(apply)
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    destroyCamera()
    if not apply then revertAll() end
    vehicle = 0

    -- Restaure HUD + minimap + speedometer.
    TriggerEvent('hud:toggleui', true)
    DisplayRadar(true)
end

-- ─────────────────────────────────────────────
-- NUI callbacks
-- ─────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    closeMenu(false)
    cb('ok')
end)

RegisterNUICallback('focusCamera', function(data, cb)
    focusCamera(data.cat)
    cb('ok')
end)

-- Catégories réellement modifiées, calculées ici (pas par la NUI) en comparant
-- le véhicule à son état d'origine. Le serveur en déduit lui-même le coût.
local function changedCategories(veh)
    local o, out = origMods, {}
    if GetVehicleWheelType(veh) ~= o.wheelType or GetVehicleMod(veh, 23) ~= o.wheelMod then out.wheel = 1 end

    local bodyN = 0
    for mt, idx in pairs(o.mods) do
        if GetVehicleMod(veh, mt) ~= idx then bodyN = bodyN + 1 end
    end
    if bodyN > 0 then out.body = bodyN end

    if GetVehicleMod(veh, 11) ~= o.engine or GetVehicleMod(veh, 12) ~= o.brakes
        or GetVehicleMod(veh, 13) ~= o.trans or GetVehicleMod(veh, 15) ~= o.susp
        or GetVehicleMod(veh, 16) ~= o.armor
        or isOn(IsToggleModOn(veh, 18)) ~= isOn(o.turbo) or isOn(IsToggleModOn(veh, 22)) ~= isOn(o.xenon) then
        out.performance = 1
    end

    local nr, ng, nb = GetVehicleNeonLightsColour(veh)
    local neonChanged = nr ~= o.nr or ng ~= o.ng or nb ~= o.nb
    for i = 0, 3 do
        if isOn(IsVehicleNeonLightEnabled(veh, i)) ~= isOn(o.neons[i + 1]) then neonChanged = true end
    end
    if neonChanged then out.neon = 1 end

    if GetVehicleWindowTint(veh) ~= o.winTint then out.window = 1 end
    if GetVehicleNumberPlateTextIndex(veh) ~= o.plateStyle then out.plate = 1 end
    if GetVehicleLivery(veh) ~= o.livery or GetVehicleMod(veh, 48) ~= o.liveryMod then out.livery = 1 end

    local extraN = 0
    for id, on in pairs(o.extras or {}) do
        if isOn(IsVehicleExtraTurnedOn(veh, id)) ~= on then extraN = extraN + 1 end
    end
    if extraN > 0 then out.extra = extraN end
    return out
end

local payPending = false
RegisterNUICallback('apply', function(_, cb)
    cb('ok')
    if not DoesEntityExist(vehicle) or payPending then return end
    -- Le texte de plaque n'est jamais modifiable ici (copie de plaque impossible)
    SetVehicleNumberPlateText(vehicle, origMods.plateText)
    local cats = changedCategories(vehicle)
    if next(cats) == nil then
        closeMenu(true)
        return
    end
    payPending = true
    TriggerServerEvent('pop_bennys:payItems', cats)
end)

RegisterNetEvent('pop_bennys:payResult', function(ok)
    payPending = false
    if ok then
        closeMenu(true)
        exports['pop_notify']:ShowNotify({ icon = 'fas fa-circle-info', message = 'Modifications appliquées !', duration = 3000 })
    else
        closeMenu(false)
        exports['pop_notify']:ShowNotify({ icon = 'fas fa-circle-info', message = 'Items insuffisants.', duration = 3000 })
    end
end)

RegisterNUICallback('preview_paint', function(data, cb)
    if DoesEntityExist(vehicle) then
        if data.target == 'primary' then
            SetVehicleCustomPrimaryColour(vehicle, data.r, data.g, data.b)
        else
            SetVehicleCustomSecondaryColour(vehicle, data.r, data.g, data.b)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_wheel', function(data, cb)
    if DoesEntityExist(vehicle) then
        SetVehicleWheelType(vehicle, data.wheelType)
        SetVehicleMod(vehicle, 23, data.modIndex, data.customTires or false)
    end
    cb('ok')
end)

RegisterNUICallback('preview_body', function(data, cb)
    if DoesEntityExist(vehicle) then
        SetVehicleMod(vehicle, data.modType, data.modIndex, false)
    end
    cb('ok')
end)

RegisterNUICallback('preview_performance', function(data, cb)
    if DoesEntityExist(vehicle) then
        if data.isToggle then
            ToggleVehicleMod(vehicle, data.modType, data.value)
        else
            SetVehicleMod(vehicle, data.modType, data.modIndex, false)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_neon', function(data, cb)
    if DoesEntityExist(vehicle) then
        if data.type == 'color' then
            SetVehicleNeonLightsColour(vehicle, data.r, data.g, data.b)
        else
            SetVehicleNeonLightEnabled(vehicle, data.index, data.enabled)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_window', function(data, cb)
    if DoesEntityExist(vehicle) then
        SetVehicleWindowTint(vehicle, data.tint)
    end
    cb('ok')
end)

RegisterNUICallback('preview_plate', function(data, cb)
    if DoesEntityExist(vehicle) then
        -- Seul le style de plaque est modifiable (le texte est lié aux papiers du véhicule)
        if data.style ~= nil then SetVehicleNumberPlateTextIndex(vehicle, data.style) end
    end
    cb('ok')
end)

RegisterNUICallback('preview_livery', function(data, cb)
    if DoesEntityExist(vehicle) then
        if data.system == 'mod' then
            SetVehicleMod(vehicle, 48, data.index, false)
        else
            SetVehicleLivery(vehicle, data.index)
        end
    end
    cb('ok')
end)

RegisterNUICallback('preview_extra', function(data, cb)
    if DoesEntityExist(vehicle) then
        -- SetVehicleExtra : 0 = activé, 1 = désactivé (inversé).
        SetVehicleExtra(vehicle, data.id, data.enabled and 0 or 1)
    end
    cb('ok')
end)

-- ─────────────────────────────────────────────
-- Trigger
-- ─────────────────────────────────────────────

-- /bennys : réservé aux admins (contrôle côté serveur), sinon passer par le point Benny's
RegisterNetEvent('pop_bennys:adminOpen', function()
    if not nuiOpen then openMenu() end
end)

exports('open', openMenu)

-- ─────────────────────────────────────────────
-- Point Benny's + touches
-- ─────────────────────────────────────────────

local bennysUiId = nil

CreateThread(function()
    local inZone = false
    while true do
        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)
        local dist = #(pos - Config.BennysCoords)

        if dist < Config.BennysRadius then
            if not inZone then
                inZone = true
                if bennysUiId then exports.pop_v3dui:Remove(bennysUiId) end
                bennysUiId = exports.pop_v3dui:Create({
                    coords       = Config.BennysCoords + vector3(0, 0, 1.2),
                    type         = 'prompt',
                    content      = { key = 'E', label = "Benny's Motor Works", icon = 'fas fa-wrench' },
                    drawDistance = Config.BennysRadius + 2.0,
                })
            end
            -- Touche E (38) pour ouvrir, Backspace/Escape (200) pour fermer
            if IsControlJustPressed(0, 38) and not nuiOpen then
                openMenu()
            elseif nuiOpen and IsControlJustPressed(0, 200) then
                SendNUIMessage({ action = 'close' })
                closeMenu(false)
            end
            Wait(0)
        else
            if inZone then
                inZone = false
                if bennysUiId then exports.pop_v3dui:Remove(bennysUiId) end
                bennysUiId = nil
            end
            if nuiOpen and IsControlJustPressed(0, 200) then
                SendNUIMessage({ action = 'close' })
                closeMenu(false)
            end
            Wait(500)
        end
    end
end)

