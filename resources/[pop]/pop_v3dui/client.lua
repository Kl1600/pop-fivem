-- 3D NUI System
-- Modern 3D UI with HTML/CSS rendering for better performance and visuals

local activeElements = {}
local renderedElements = {}
local offScreenSince = {}
local lastPos = {}
local POS_EPSILON = 0.0005
local elementIdCounter = 0
local OFFSCREEN_GRACE_MS = 250

-- Create a new 3D UI element
-- @param options table: {
--   coords = vector3(x, y, z),
--   type = "text" | "box" | "prompt" | "icon-text",
--   content = { text = "...", key = "E", label = "...", icon = "..." },
--   drawDistance = 10.0 (optional),
--   offset = vector3(0, 0, 0) (optional),
--   style = { color = "...", fontSize = "...", backgroundColor = "..." } (optional)
-- }
-- @return number: element ID for later updates/removal
function Create3DUI(options)
    assert(options.coords, "coords required")
    assert(options.type, "type required (text, box, prompt, icon-text)")
    assert(options.content, "content required")
    
    -- Robust coords handling (exports can turn vectors into tables)
    local coords = options.coords
    if type(coords) == 'table' then
        coords = vector3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3])
    end

    local offset = options.offset or vector3(0, 0, 0)
    if type(offset) == 'table' then
        offset = vector3(offset.x or offset[1] or 0, offset.y or offset[2] or 0, offset.z or offset[3] or 0)
    end

    elementIdCounter = elementIdCounter + 1
    local id = elementIdCounter
    
    activeElements[id] = {
        resource = GetInvokingResource() or GetCurrentResourceName(),
        coords = coords,
        type = options.type,
        content = options.content,
        drawDistance = options.drawDistance or 15.0,
        offset = offset,
        style = options.style or {}
    }
    
    return id
end

-- Remove a 3D UI element
function Remove3DUI(id)
    if activeElements[id] then
        SendNUIMessage({
            action = 'remove',
            id = tostring(id)
        })
        activeElements[id] = nil
        renderedElements[id] = nil
        offScreenSince[id] = nil
        lastPos[id] = nil
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearAll3DUI()
    else
        for id, element in pairs(activeElements) do
            if element.resource == resourceName then
                Remove3DUI(id)
            end
        end
    end
end)

-- Update element content
function Update3DUI(id, newContent)
    if activeElements[id] then
        activeElements[id].content = newContent
        if renderedElements[id] then
            SendNUIMessage({ action = 'update', id = tostring(id), content = newContent })
        end
    end
end

-- Update element position
function Update3DUICoords(id, newCoords)
    if activeElements[id] then
        if type(newCoords) == 'table' then
            newCoords = vector3(newCoords.x or newCoords[1], newCoords.y or newCoords[2], newCoords.z or newCoords[3])
        end
        activeElements[id].coords = newCoords
    end
end

-- Clear all elements
function ClearAll3DUI()
    SendNUIMessage({ action = 'clear' })
    activeElements = {}
    renderedElements = {}
    offScreenSince = {}
    lastPos = {}
end

-- Main rendering thread
Citizen.CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local hasElements = false
        local shouldBeVisible = {} -- Track which elements SHOULD be visible this frame
        local nowMs = GetGameTimer()

        local positions = {}
        local hasPositions = false

        -- Check each active element
        for id, element in pairs(activeElements) do
            local dist = #(playerCoords - element.coords)

            -- Only process if within draw distance
            if dist <= element.drawDistance then
                hasElements = true
                local finalCoords = element.coords + element.offset
                local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(finalCoords.x, finalCoords.y, finalCoords.z)

                -- Only show if on screen
                if onScreen then
                    shouldBeVisible[id] = true
                    offScreenSince[id] = nil

                    -- Create element if it doesn't exist
                    local sid = tostring(id)
                    if not renderedElements[id] then
                        SendNUIMessage({
                            action = 'create',
                            id = sid,
                            type = element.type,
                            content = element.content,
                            style = element.style
                        })
                        renderedElements[id] = true
                    end

                    -- Store position for batch update only if it moved (string key -> JSON object)
                    local lp = lastPos[id]
                    if not lp or math.abs(lp.x - screenX) > POS_EPSILON or math.abs(lp.y - screenY) > POS_EPSILON then
                        local pos = { x = screenX, y = screenY }
                        positions[sid] = pos
                        lastPos[id] = pos
                        hasPositions = true
                    end
                elseif renderedElements[id] then
                    -- Off-screen but recently rendered: keep alive for OFFSCREEN_GRACE_MS to avoid create/remove churn
                    local since = offScreenSince[id]
                    if not since then
                        offScreenSince[id] = nowMs
                        shouldBeVisible[id] = true
                    elseif nowMs - since < OFFSCREEN_GRACE_MS then
                        shouldBeVisible[id] = true
                    end
                end
            end
        end

        -- Batch update all visible positions
        if hasPositions then
            SendNUIMessage({
                action = 'updatePositions',
                positions = positions
            })
        end

        -- Remove any rendered elements that should NOT be visible
        for id, _ in pairs(renderedElements) do
            if not shouldBeVisible[id] then
                SendNUIMessage({
                    action = 'remove',
                    id = tostring(id)
                })
                renderedElements[id] = nil
                offScreenSince[id] = nil
                lastPos[id] = nil
            end
        end

        -- Élément à portée : mise à jour toutes les ~30 ms (lissée en CSS), sinon 500 ms
        if hasElements then
            Wait(30)
        else
            Wait(500)
        end
    end
end)

-- Export functions
exports('Create', Create3DUI)
exports('Remove', Remove3DUI)
exports('Update', Update3DUI)
exports('UpdateCoords', Update3DUICoords)
exports('ClearAll', ClearAll3DUI)
