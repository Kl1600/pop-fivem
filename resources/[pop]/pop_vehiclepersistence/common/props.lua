-- Propriétés de véhicule (contrat partagé POP : pop_vehiclepersistence, pop_bennys).
-- Format = noms ESX / QBCore / ox_lib, couleurs de palette uniquement (entiers).
-- Get / Set : natives client. Sanitize / Merge : fonctions pures, utilisables des deux côtés.
-- Copié tel quel dans pop_bennys : ne pas y ajouter de dépendance au script.

Props = {}

-- Index de mod GTA -> clé (valeur : entier -1..255, -1 = d'origine).
Props.MODS = {
    [0] = 'modSpoilers', [1] = 'modFrontBumper', [2] = 'modRearBumper', [3] = 'modSideSkirt', [4] = 'modExhaust',
    [5] = 'modFrame', [6] = 'modGrille', [7] = 'modHood', [8] = 'modFender', [9] = 'modRightFender', [10] = 'modRoof',
    [11] = 'modEngine', [12] = 'modBrakes', [13] = 'modTransmission', [14] = 'modHorns', [15] = 'modSuspension',
    [16] = 'modArmor', [23] = 'modFrontWheels', [24] = 'modBackWheels', [25] = 'modPlateHolder',
    [26] = 'modVanityPlate', [27] = 'modTrimA', [28] = 'modOrnaments', [29] = 'modDashboard', [30] = 'modDial',
    [31] = 'modDoorSpeaker', [32] = 'modSeats', [33] = 'modSteeringWheel', [34] = 'modShifterLeavers',
    [35] = 'modAPlate', [36] = 'modSpeakers', [37] = 'modTrunk', [38] = 'modHydrolic', [39] = 'modEngineBlock',
    [40] = 'modAirFilter', [41] = 'modStruts', [42] = 'modArchCover', [43] = 'modAerials', [44] = 'modTrimB',
    [45] = 'modTank', [46] = 'modWindows', [48] = 'modLivery',
}

-- Mods à bascule -> clé (valeur : boolean).
Props.TOGGLES = { [18] = 'modTurbo', [20] = 'modSmokeEnabled', [22] = 'modXenon' }

------------------------------------------------------------------------
-- Validation (pure)
------------------------------------------------------------------------

-- Champs simples : { type, min, max }.
local SCALARS = {
    plateIndex       = { 'int', 0, 5 },
    bodyHealth       = { 'num', -4000, 1000 },
    engineHealth     = { 'num', -4000, 1000 },
    tankHealth       = { 'num', -4000, 1000 },
    fuelLevel        = { 'num', 0, 100 },
    dirtLevel        = { 'num', 0, 15 },
    color1           = { 'int', 0, 255 },
    color2           = { 'int', 0, 255 },
    pearlescentColor = { 'int', 0, 255 },
    wheelColor       = { 'int', 0, 255 },
    wheels           = { 'int', -1, 12 },
    windowTint       = { 'int', -1, 6 },
    xenonColor       = { 'int', -1, 255 },
    livery           = { 'int', -1, 255 },
}
for _, key in pairs(Props.MODS) do SCALARS[key] = { 'int', -1, 255 } end
for _, key in pairs(Props.TOGGLES) do SCALARS[key] = { 'bool' } end

local function isFinite(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

-- Entier dans [lo, hi] (les flottants entiers venus du JSON sont convertis), sinon nil.
local function toInt(v, lo, hi)
    if not isFinite(v) then return nil end
    if math.type(v) ~= 'integer' then
        if math.floor(v) ~= v then return nil end
        v = math.tointeger(v)
        if not v then return nil end
    end
    if v < lo or v > hi then return nil end
    return v
end

local function toNum(v, lo, hi)
    if not isFinite(v) or v < lo or v > hi then return nil end
    return v + 0.0
end

local function toBool(v)
    if type(v) == 'boolean' then return v end
    return nil
end

local function onlyTrue(v)
    if v == true then return true end
    return nil
end

local function toColor(v)
    return toInt(v, 0, 255)
end

-- Liste de exactement n valeurs valides, sinon nil.
local function toList(v, n, fn)
    if type(v) ~= 'table' then return nil end
    local out = {}
    for i = 1, n do
        local x = v[i]
        if x == nil then return nil end
        x = fn(x)
        if x == nil then return nil end
        out[i] = x
    end
    return out
end

-- Table indexée "0".."max" (clés chaînes ; clés entières acceptées en entrée). Parcours borné à 0..max.
local function toMap(v, max, fn)
    if type(v) ~= 'table' then return nil end
    local out = {}
    for id = 0, max do
        local key = tostring(id)
        local x = v[key]
        if x == nil then x = v[id] end
        if x ~= nil then x = fn(x) end
        if x ~= nil then out[key] = x end
    end
    return out
end

--- Nouvelle table ne gardant que les champs connus, du bon type et dans les bornes ; nil si p n'est pas une table.
function Props.Sanitize(p)
    if type(p) ~= 'table' then return nil end
    local out = {}
    for key, rule in pairs(SCALARS) do
        local v = p[key]
        if v ~= nil then
            local r
            if rule[1] == 'int' then
                r = toInt(v, rule[2], rule[3])
            elseif rule[1] == 'num' then
                r = toNum(v, rule[2], rule[3])
            else
                r = toBool(v)
            end
            if r ~= nil then out[key] = r end
        end
    end
    out.neonEnabled    = toList(p.neonEnabled, 4, toBool)
    out.neonColor      = toList(p.neonColor, 3, toColor)
    out.tyreSmokeColor = toList(p.tyreSmokeColor, 3, toColor)
    out.extras         = toMap(p.extras, 20, toBool)
    out.doorsBroken    = toMap(p.doorsBroken, 5, onlyTrue)
    out.windowsBroken  = toMap(p.windowsBroken, 7, onlyTrue)
    out.tyreBurst      = toMap(p.tyreBurst, 7, onlyTrue)
    return out
end

local function deepCopy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepCopy(x) end
    return out
end

--- Copie de base (ou {}) dont les champs sont remplacés par ceux de changes (copie profonde).
function Props.Merge(base, changes)
    local out = type(base) == 'table' and deepCopy(base) or {}
    if type(changes) == 'table' then
        for k, v in pairs(changes) do out[k] = deepCopy(v) end
    end
    return out
end

------------------------------------------------------------------------
-- Lecture / application (client)
------------------------------------------------------------------------

-- Certaines natives renvoient 1/0 selon les builds.
local function bool(v)
    return v == true or v == 1
end

--- Propriétés complètes du véhicule (validées), ou nil si l'entité n'existe pas.
function Props.Get(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local p = {}

    p.plateIndex   = GetVehicleNumberPlateTextIndex(veh)
    p.bodyHealth   = GetVehicleBodyHealth(veh)
    p.engineHealth = GetVehicleEngineHealth(veh)
    p.tankHealth   = GetVehiclePetrolTankHealth(veh)

    local fuel = Entity(veh).state.fuel
    if type(fuel) ~= 'number' then fuel = GetVehicleFuelLevel(veh) end
    p.fuelLevel = math.max(0.0, math.min(100.0, fuel + 0.0))
    p.dirtLevel = GetVehicleDirtLevel(veh)

    p.color1, p.color2 = GetVehicleColours(veh)
    p.pearlescentColor, p.wheelColor = GetVehicleExtraColours(veh)
    p.wheels     = GetVehicleWheelType(veh)
    p.windowTint = GetVehicleWindowTint(veh)
    p.xenonColor = GetVehicleXenonLightsColor(veh)
    p.livery     = GetVehicleLivery(veh)

    p.neonEnabled = {}
    for i = 0, 3 do p.neonEnabled[i + 1] = bool(IsVehicleNeonLightEnabled(veh, i)) end
    p.neonColor = table.pack(GetVehicleNeonLightsColour(veh))
    p.neonColor.n = nil
    p.tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(veh))
    p.tyreSmokeColor.n = nil

    p.extras = {}
    for id = 0, 20 do
        if DoesExtraExist(veh, id) then p.extras[tostring(id)] = bool(IsVehicleExtraTurnedOn(veh, id)) end
    end

    for index, key in pairs(Props.MODS) do p[key] = GetVehicleMod(veh, index) end
    for index, key in pairs(Props.TOGGLES) do p[key] = bool(IsToggleModOn(veh, index)) end

    p.doorsBroken = {}
    for i = 0, 5 do
        if bool(IsVehicleDoorDamaged(veh, i)) then p.doorsBroken[tostring(i)] = true end
    end
    p.windowsBroken = {}
    for i = 0, 7 do
        if not bool(IsVehicleWindowIntact(veh, i)) then p.windowsBroken[tostring(i)] = true end
    end
    p.tyreBurst = {}
    for i = 0, 7 do
        if bool(IsVehicleTyreBurst(veh, i, false)) then p.tyreBurst[tostring(i)] = true end
    end

    return Props.Sanitize(p)
end

--- Applique les champs présents (validés au préalable). Les dégâts sont appliqués en dernier
--- (SetVehicleExtra et les mods réparent le véhicule).
function Props.Set(veh, p)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    p = Props.Sanitize(p)
    if not p then return false end

    SetVehicleModKit(veh, 0)
    if p.wheels then SetVehicleWheelType(veh, p.wheels) end

    -- Couleurs : une couleur absente garde la valeur actuelle.
    if p.color1 or p.color2 then
        local c1, c2 = GetVehicleColours(veh)
        if p.color1 then ClearVehicleCustomPrimaryColour(veh) end
        if p.color2 then ClearVehicleCustomSecondaryColour(veh) end
        SetVehicleColours(veh, p.color1 or c1, p.color2 or c2)
    end
    if p.pearlescentColor or p.wheelColor then
        local pearl, wheel = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, p.pearlescentColor or pearl, p.wheelColor or wheel)
    end

    for index, key in pairs(Props.MODS) do
        if p[key] then SetVehicleMod(veh, index, p[key], false) end
    end
    for index, key in pairs(Props.TOGGLES) do
        if p[key] ~= nil then ToggleVehicleMod(veh, index, p[key]) end
    end

    if p.neonEnabled then
        for i = 1, 4 do SetVehicleNeonLightEnabled(veh, i - 1, p.neonEnabled[i]) end
    end
    if p.neonColor then SetVehicleNeonLightsColour(veh, p.neonColor[1], p.neonColor[2], p.neonColor[3]) end
    if p.tyreSmokeColor then SetVehicleTyreSmokeColor(veh, p.tyreSmokeColor[1], p.tyreSmokeColor[2], p.tyreSmokeColor[3]) end
    if p.windowTint then SetVehicleWindowTint(veh, p.windowTint) end
    if p.xenonColor then SetVehicleXenonLightsColor(veh, p.xenonColor) end
    if p.livery and p.livery >= 0 then SetVehicleLivery(veh, p.livery) end

    if p.extras then
        for key, on in pairs(p.extras) do
            local id = tonumber(key)
            if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, on and 0 or 1) end
        end
    end

    if p.plateIndex then SetVehicleNumberPlateTextIndex(veh, p.plateIndex) end

    if p.bodyHealth then SetVehicleBodyHealth(veh, p.bodyHealth + 0.0) end
    if p.engineHealth then SetVehicleEngineHealth(veh, p.engineHealth + 0.0) end
    if p.tankHealth then SetVehiclePetrolTankHealth(veh, p.tankHealth + 0.0) end

    if p.fuelLevel then
        SetVehicleFuelLevel(veh, p.fuelLevel + 0.0)
        -- ox_fuel lit le statebag ; refusé si ce client n'a pas le droit d'écrire : sans conséquence.
        pcall(function() Entity(veh).state:set('fuel', p.fuelLevel, true) end)
        if DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then DecorSetFloat(veh, '_FUEL_LEVEL', p.fuelLevel + 0.0) end
    end
    if p.dirtLevel then SetVehicleDirtLevel(veh, p.dirtLevel + 0.0) end

    -- Dégâts en dernier.
    if p.doorsBroken then
        for key in pairs(p.doorsBroken) do SetVehicleDoorBroken(veh, tonumber(key), true) end
    end
    if p.windowsBroken then
        for key in pairs(p.windowsBroken) do SmashVehicleWindow(veh, tonumber(key)) end
    end
    if p.tyreBurst then
        for key in pairs(p.tyreBurst) do SetVehicleTyreBurst(veh, tonumber(key), false, 1000.0) end
    end
    return true
end
