-- Glisser un objet hors de l'inventaire : don à un joueur ou cible monde enregistrée.

local isDraggingOut   = false
local targetPlayer    = nil
local isDragItem      = nil   -- defId de l'item en cours de drag
local targetDragEntity = nil  -- entité monde survolée pendant un drag

-- ── Registry de cibles drag ──────────────────────────────────────────────────
local dragTargets = {}  -- [entityHandle] = { itemFilter, callback }

exports('registerDragTarget', function(entity, itemFilter, callback)
    dragTargets[entity] = { itemFilter = itemFilter, callback = callback }
end)

exports('unregisterDragTarget', function(entity)
    if dragTargets[entity] then
        if DoesEntityExist(entity) then SetEntityDrawOutline(entity, false) end
        dragTargets[entity] = nil
    end
end)

local function GetHoveredDragTarget()
    if not isDragItem then return nil end
    local cursorX, cursorY = GetNuiCursorPosition()
    local resX,   resY    = GetActiveScreenResolution()
    if resX == 0 or resY == 0 then return nil end
    local normX  = cursorX / resX
    local normY  = cursorY / resY
    local aspect = resX / resY
    local pPed   = PlayerPedId()
    local best, minDist = nil, 0.12

    for entity, target in pairs(dragTargets) do
        if (target.itemFilter == nil or target.itemFilter == isDragItem) and DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            if #(GetEntityCoords(pPed) - coords) < 10.0 then
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z + 0.5)
                if onScreen then
                    local dx = (sx - normX) * aspect
                    local dy = sy - normY
                    local d  = math.sqrt(dx^2 + dy^2)
                    if d < minDist then minDist = d ; best = entity end
                end
            end
        end
    end
    return best
end
-- ─────────────────────────────────────────────────────────────────────────────

RegisterNUICallback("startDraggingOut", function(data, cb)
    isDraggingOut = true
    isDragItem    = data.item and data.item.defId or nil
    if cb then cb('ok') end
end)

RegisterNUICallback("stopDraggingOut", function(data, cb)
    isDraggingOut = false
    isDragItem    = nil
    targetPlayer  = nil
    if targetDragEntity then
        if DoesEntityExist(targetDragEntity) then SetEntityDrawOutline(targetDragEntity, false) end
        targetDragEntity = nil
    end
    if cb then cb('ok') end
end)

function GetHoveredPlayer()
    local cursorX, cursorY = GetNuiCursorPosition()
    local resX, resY = GetActiveScreenResolution()

    local normX = 0.5
    local normY = 0.5

    if resX > 0 and resY > 0 then
        normX = cursorX / resX
        normY = cursorY / resY
    end

    local players = GetActivePlayers()
    local pPed = PlayerPedId()
    local aspect = 1.0
    if resY > 0 then aspect = resX / resY end

    local hoveredPlayer = nil
    local minScreenDist = 0.08

    for i=1, #players do
        local targetPed = GetPlayerPed(players[i])
        if targetPed ~= pPed and HasEntityClearLosToEntity(pPed, targetPed, 17) then
            local tCoords = GetEntityCoords(targetPed)
            local dist3D = #(GetEntityCoords(pPed) - tCoords)
            if dist3D < 8.0 then
                -- Check multiple points on the body (feet, chest, head)
                local offsets = {0.2, 0.9, 1.6}
                local pointMinDist = 999.0

                for _, zOffset in ipairs(offsets) do
                    local checkCoords = tCoords + vector3(0.0, 0.0, zOffset)
                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(checkCoords.x, checkCoords.y, checkCoords.z)
                    if onScreen then
                        local dx = (screenX - normX) * aspect
                        local dy = screenY - normY
                        local sDist = math.sqrt(dx^2 + dy^2)
                        if sDist < pointMinDist then pointMinDist = sDist end
                    end
                end

                local threshold = math.max(0.04, 0.15 - (dist3D * 0.012))

                if pointMinDist < threshold and pointMinDist < minScreenDist then
                    minScreenDist = pointMinDist
                    hoveredPlayer = players[i]
                end
            end
        end
    end
    return hoveredPlayer
end

RegisterNUICallback("confirmDraggingOut", function(data, cb)
    -- Priorité : entité monde enregistrée (ex: plante)
    if targetDragEntity then
        local target = dragTargets[targetDragEntity]
        if target and target.callback then
            target.callback(data)
        end
        if DoesEntityExist(targetDragEntity) then SetEntityDrawOutline(targetDragEntity, false) end
        targetDragEntity = nil
        isDraggingOut = false
        isDragItem    = nil
        if cb then cb({success = true}) end
        return
    end

    -- Fallback : don à un joueur
    if targetPlayer then
        local targetServerId = GetPlayerServerId(targetPlayer)
        if targetServerId > 0 then
            TriggerServerEvent('pop_inventory:server:giveItem', targetServerId, data.fromContainerId, data.fromSlot, data.item, data.fromType)
            isDraggingOut = false
            isDragItem    = nil
            if targetPlayer then
                local p = GetPlayerPed(targetPlayer)
                SetEntityDrawOutline(p, false)
                ResetEntityAlpha(p)
            end
            targetPlayer = nil
            if cb then cb({success = true}) end
            return
        end
    end
    isDraggingOut = false
    isDragItem    = nil
    if targetPlayer then
        local p = GetPlayerPed(targetPlayer)
        SetEntityDrawOutline(p, false)
        ResetEntityAlpha(p)
    end
    targetPlayer = nil
    Inv.Notify(L('give_cancelled'))
    if cb then cb({success = false}) end
end)

CreateThread(function()
    while true do
        if isDraggingOut then
            -- Entités monde enregistrées (plantes, etc.)
            local hoveredEntity = GetHoveredDragTarget()
            if hoveredEntity ~= targetDragEntity then
                if targetDragEntity and DoesEntityExist(targetDragEntity) then
                    SetEntityDrawOutline(targetDragEntity, false)
                end
                targetDragEntity = hoveredEntity
                if targetDragEntity and DoesEntityExist(targetDragEntity) then
                    SetEntityDrawOutline(targetDragEntity, true)
                    SetEntityDrawOutlineColor(0, 150, 255, 255)
                end
            end

            -- Joueurs proches (uniquement si pas de cible monde)
            local hovered = not targetDragEntity and GetHoveredPlayer() or nil
            if hovered then
                if targetPlayer and targetPlayer ~= hovered then
                    local p = GetPlayerPed(targetPlayer)
                    SetEntityDrawOutline(p, false)
                    ResetEntityAlpha(p)
                end
                targetPlayer = hovered
                local targetPed = GetPlayerPed(hovered)
                SetEntityAlpha(targetPed, 100, false)
                SetEntityDrawOutline(targetPed, true)
                SetEntityDrawOutlineColor(0, 255, 0, 255)
            else
                if targetPlayer then
                    local p = GetPlayerPed(targetPlayer)
                    SetEntityDrawOutline(p, false)
                    ResetEntityAlpha(p)
                end
                targetPlayer = nil
            end
            Wait(0)
        else
            if targetPlayer then
                local p = GetPlayerPed(targetPlayer)
                SetEntityDrawOutline(p, false)
                ResetEntityAlpha(p)
                targetPlayer = nil
            end
            Wait(250)
        end
    end
end)
