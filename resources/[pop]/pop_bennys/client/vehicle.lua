-- pop_bennys — client : état du véhicule (sauvegarde, restauration, données NUI)

Bennys = {
    nuiOpen  = false,
    vehicle  = 0,
    origMods = {},
}

-- Certains natives renvoient un booléen, d'autres 0/1 : on normalise.
local function isOn(v) return v == true or v == 1 end

function Bennys.SaveOrig(veh)
    local p1, p2 = GetVehicleColours(veh)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)

    Bennys.origMods = {
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
        Bennys.origMods.mods[mt] = GetVehicleMod(veh, mt)
    end
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            Bennys.origMods.extras[i] = isOn(IsVehicleExtraTurnedOn(veh, i))
        end
    end
end

function Bennys.RevertAll()
    if not DoesEntityExist(Bennys.vehicle) then return end
    local v = Bennys.vehicle
    if Bennys.origMods.isCustomP then
        SetVehicleCustomPrimaryColour(v, Bennys.origMods.pr, Bennys.origMods.pg, Bennys.origMods.pb)
    else
        SetVehicleColours(v, Bennys.origMods.pIdx, Bennys.origMods.sIdx)
    end
    if Bennys.origMods.isCustomS then
        SetVehicleCustomSecondaryColour(v, Bennys.origMods.sr, Bennys.origMods.sg, Bennys.origMods.sb)
    end
    SetVehicleWheelType(v, Bennys.origMods.wheelType)
    SetVehicleMod(v, 23, Bennys.origMods.wheelMod, Bennys.origMods.customTire)
    for mt, idx in pairs(Bennys.origMods.mods) do SetVehicleMod(v, mt, idx, false) end
    SetVehicleMod(v, 11, Bennys.origMods.engine, false)
    SetVehicleMod(v, 12, Bennys.origMods.brakes, false)
    SetVehicleMod(v, 13, Bennys.origMods.trans,  false)
    SetVehicleMod(v, 15, Bennys.origMods.susp,   false)
    SetVehicleMod(v, 16, Bennys.origMods.armor,  false)
    ToggleVehicleMod(v, 18, Bennys.origMods.turbo)
    ToggleVehicleMod(v, 22, Bennys.origMods.xenon)
    SetVehicleNeonLightsColour(v, Bennys.origMods.nr, Bennys.origMods.ng, Bennys.origMods.nb)
    for i, on in ipairs(Bennys.origMods.neons) do SetVehicleNeonLightEnabled(v, i - 1, on) end
    SetVehicleWindowTint(v, Bennys.origMods.winTint)
    SetVehicleNumberPlateTextIndex(v, Bennys.origMods.plateStyle)
    SetVehicleNumberPlateText(v, Bennys.origMods.plateText)
    if Bennys.origMods.livery ~= nil and Bennys.origMods.livery >= 0 then SetVehicleLivery(v, Bennys.origMods.livery) end
    if Bennys.origMods.liveryMod ~= nil then SetVehicleMod(v, 48, Bennys.origMods.liveryMod, false) end
    if Bennys.origMods.extras then
        for id, on in pairs(Bennys.origMods.extras) do SetVehicleExtra(v, id, on and 0 or 1) end
    end
end

function Bennys.BuildVehicleData(veh)
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

-- Catégories réellement modifiées, calculées ici (pas par la NUI) en comparant
-- le véhicule à son état d'origine. Le serveur en déduit lui-même le coût.
function Bennys.ChangedCategories(veh)
    local o, out = Bennys.origMods, {}
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
