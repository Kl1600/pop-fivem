-- CREDITS
-- Andyyy7666: https://github.com/overextended/ox_lib/pull/453
-- AvarianKnight: https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8?u=demi-automatic

local dataview = require 'client.dataview'

local enableScale = false -- allow scaling mode. doesnt scale collisions and resets when physics are applied it seems
local isCursorActive = false
local gizmoEnabled = false
local currentMode = 'translate'
local isRelative = true
local currentEntity

-- FUNCTIONS

local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return 0, 0, 0
    end
    return x / length, y / length, z / length
end

local function makeEntityMatrix(entity)
    local f, r, u, a = GetEntityMatrix(entity)
    local view = dataview.ArrayBuffer(60)

    view:SetFloat32(0, r.x)
        :SetFloat32(4, r.y)
        :SetFloat32(8, r.z)
        :SetFloat32(12, 0)
        :SetFloat32(16, f.x)
        :SetFloat32(20, f.y)
        :SetFloat32(24, f.z)
        :SetFloat32(28, 0)
        :SetFloat32(32, u.x)
        :SetFloat32(36, u.y)
        :SetFloat32(40, u.z)
        :SetFloat32(44, 0)
        :SetFloat32(48, a.x)
        :SetFloat32(52, a.y)
        :SetFloat32(56, a.z)
        :SetFloat32(60, 1)

    return view
end

local function applyEntityMatrix(entity, view)
    local x1, y1, z1 = view:GetFloat32(16), view:GetFloat32(20), view:GetFloat32(24)
    local x2, y2, z2 = view:GetFloat32(0), view:GetFloat32(4), view:GetFloat32(8)
    local x3, y3, z3 = view:GetFloat32(32), view:GetFloat32(36), view:GetFloat32(40)
    local tx, ty, tz = view:GetFloat32(48), view:GetFloat32(52), view:GetFloat32(56)

    if not enableScale then
        x1, y1, z1 = normalize(x1, y1, z1)
        x2, y2, z2 = normalize(x2, y2, z2)
        x3, y3, z3 = normalize(x3, y3, z3)
    end

    SetEntityMatrix(entity,
        x1, y1, z1,
        x2, y2, z2,
        x3, y3, z3,
        tx, ty, tz
    )

    if IsEntityAVehicle(entity) or IsEntityAPed(entity) then
        SetEntityCoordsNoOffset(entity, tx, ty, tz, false, false, false)
    end
end

-- LOOPS

local function gizmoLoop(entity)
    if not gizmoEnabled then
        return LeaveCursorMode()
    end

    EnterCursorMode()

    if IsEntityAPed(entity) then
        SetEntityAlpha(entity, 200)
    else
        SetEntityDrawOutline(entity, true)
    end
    isCursorActive = true
    while gizmoEnabled and DoesEntityExist(entity) do
        Wait(0)
        if IsControlJustPressed(0, 47) then -- G
            if isCursorActive then
                LeaveCursorMode()
            else
                EnterCursorMode()
            end
            isCursorActive = not isCursorActive
        end
        
        -- Fallback key checks when NUI focus blocks RegisterKeyMapping
        if IsDisabledControlJustPressed(0, 32) then -- W
            currentMode = 'Translate'
            ExecuteCommand('+gizmoTranslation')
        end
        if IsDisabledControlJustPressed(0, 45) then -- R
            currentMode = 'Rotate'
            ExecuteCommand('+gizmoRotation')
        end
        if IsDisabledControlJustPressed(0, 44) then -- Q
            isRelative = not isRelative
            ExecuteCommand('+gizmoLocal')
        end
        -- Valider UNIQUEMENT sur Entrée clavier (18). On retire le contrôle 201
        -- (FRONTEND_ACCEPT) qui, en mode curseur, est aussi déclenché par le
        -- CLIC GAUCHE -> sinon cliquer pour attraper une poignée validait direct.
        if IsDisabledControlJustPressed(0, 18)
            and not IsDisabledControlPressed(0, 24)   -- pas pendant un clic gauche
            and not IsDisabledControlPressed(0, 237)  -- pas le clic curseur
        then
            gizmoEnabled = false
        end
        if IsDisabledControlJustPressed(0, 19) then -- LAlt
            PlaceObjectOnGroundProperly(entity)
        end

        DisableControlAction(0, 24, true)  -- lmb
        DisableControlAction(0, 25, true)  -- rmb
        DisableControlAction(0, 140, true) -- r
        DisablePlayerFiring(cache.playerId, true)

        local matrixBuffer = makeEntityMatrix(entity)
        local changed = Citizen.InvokeNative(0xEB2EDCA2, matrixBuffer:Buffer(), 'Editor1',
            Citizen.ReturnResultAnyway())

        if changed then
            applyEntityMatrix(entity, matrixBuffer)
        end
    end
    isCursorActive = false
    LeaveCursorMode()

    if DoesEntityExist(entity) then
        if IsEntityAPed(entity) then SetEntityAlpha(entity, 255) end
        SetEntityDrawOutline(entity, false)
    end

    gizmoEnabled = false
    currentEntity = nil
end

local function GetVectorText(vectorType) 
    if not currentEntity then return 'ERR_NO_ENTITY_' .. (vectorType or "UNK") end
    local label = (vectorType == "coords" and "Position" or "Rotation")
    local vec = (vectorType == "coords" and GetEntityCoords(currentEntity) or GetEntityRotation(currentEntity))
    return ('%s: %.2f, %.2f, %.2f'):format(label, vec.x, vec.y, vec.z)
end


local function textUILoop()
    CreateThread(function()
        while gizmoEnabled do
            Wait(100)
            local scaleText = (enableScale and '[S]     - Scale Mode  \n') or ''
            lib.showTextUI(
                ('Current Mode: %s | %s  \n'):format(currentMode, (isRelative and 'Relative') or 'World') ..
                GetVectorText("coords") .. '  \n' ..
                GetVectorText("rotation") .. '  \n' ..
                '[G]     - ' .. (isCursorActive and "Disable" or "Enable") .. ' Cursor  \n' ..
                '[W]     - Translate Mode  \n' ..
                '[R]     - Rotate Mode  \n' ..
                scaleText ..
                '[Q]     - Relative/World  \n' ..
                '[LALT]  - Snap To Ground  \n' ..
                '[ENTER] - Done Editing  \n'
            )
        end
        lib.hideTextUI()
    end)
end

-- EXPORTS

local function useGizmo(entity)
    -- IsNuiFocusActive n'existe pas sur tous les builds : on garde l'appel
    -- optionnel pour éviter "attempt to call a nil value".
    local wasNuiFocusActive = IsNuiFocusActive and IsNuiFocusActive()
    if wasNuiFocusActive then
        SetNuiFocus(true, false)
    end

    gizmoEnabled = true
    currentEntity = entity
    textUILoop()
    gizmoLoop(entity)

    if wasNuiFocusActive then
        SetNuiFocus(true, true)
    end

    return {
        handle = entity,
        position = GetEntityCoords(entity),
        rotation = GetEntityRotation(entity)
    }
end

exports("useGizmo", useGizmo)

-- CONTROLS these execute the existing gizmo commands but allow me to add additional logic to update the mode display.

lib.addKeybind({
    name = '_gizmoSelect',
    description = 'Selects the currently highlighted gizmo',
    defaultMapper = 'MOUSE_BUTTON',
    defaultKey = 'MOUSE_LEFT',
    onPressed = function(self)
        if not gizmoEnabled then return end
        ExecuteCommand('+gizmoSelect')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoSelect')
    end
})

lib.addKeybind({
    name = '_gizmoTranslation',
    description = 'Sets mode of the gizmo to translation',
    defaultKey = 'W',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Translate'
        ExecuteCommand('+gizmoTranslation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoTranslation')
    end
})

lib.addKeybind({
    name = '_gizmoRotation',
    description = 'Sets mode for the gizmo to rotation',
    defaultKey = 'R',
    onPressed = function(self)
        if not gizmoEnabled then return end
        currentMode = 'Rotate'
        ExecuteCommand('+gizmoRotation')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoRotation')
    end
})

lib.addKeybind({
    name = '_gizmoLocal',
    description = 'toggle gizmo to be local to the entity instead of world',
    defaultKey = 'Q',
    onPressed = function(self)
        if not gizmoEnabled then return end
        isRelative = not isRelative
        ExecuteCommand('+gizmoLocal')
    end,
    onReleased = function (self)
        ExecuteCommand('-gizmoLocal')
    end
})

lib.addKeybind({
    name = 'gizmoclose',
    description = 'close gizmo',
    defaultKey = 'RETURN',
    onPressed = function(self)
        if not gizmoEnabled then return end
        gizmoEnabled = false
    end,
})

lib.addKeybind({
    name = 'gizmoSnapToGround',
    description = 'snap current gizmo object to floor/surface',
    defaultKey = 'LMENU',
    onPressed = function(self)
        if not gizmoEnabled then return end
        PlaceObjectOnGroundProperly(currentEntity)
    end,
})

if enableScale then
    lib.addKeybind({
        name = '_gizmoScale',
        description = 'Sets mode for the gizmo to scale',
        defaultKey = 'S',
        onPressed = function(self)
            if not gizmoEnabled then return end
            currentMode = 'Scale'
            ExecuteCommand('+gizmoScale')
        end,
        onReleased = function (self)
            ExecuteCommand('-gizmoScale')
        end
    })
end
