local name = GetCurrentResourceName()
local active, form, opening, pending = {}, nil, false, false
local nextPoll, generation = 0, 0

local function pack(value)
    return { x = value.x, y = value.y, z = value.z }
end

local function close()
    form = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

Bridge.OnUiClose(function()
    if form then close() end
end)

local function open(data, content)
    form = data
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', title = L('title'), editing = data.id ~= nil, content = content,
        maxPoints = Config.MaxPoints, maxStrokes = Config.MaxStrokes })
    CreateThread(function()
        while form == data do
            local ped = PlayerPedId()
            if not Bridge.IsLoaded() or IsEntityDead(ped) or #(GetEntityCoords(ped) - data.position) > Config.ActionDistance then
                close()
                break
            end
            Wait(400)
        end
    end)
end

local function edit(row)
    if form or opening or pending or Bridge.IsBusy() or IsNuiFocused() or not Bridge.IsLoaded() then return end
    opening = true
    local generationAtOpen = generation
    local ok, result, revision = Callback.Await(name .. ':edit', row.id)
    opening = false
    if generationAtOpen ~= generation then return end
    if not ok then
        Bridge.Notify(L(result or 'error'), 'error')
    elseif Bridge.IsLoaded() then
        open({ id = row.id, revision = revision, position = row.position, normal = row.normal }, result)
    end
end

local function placement()
    if form or opening or pending or Bridge.IsBusy() or IsNuiFocused() or not Bridge.IsLoaded() then return end
    opening = true
    local generationAtOpen = generation
    local allowed, reason = Callback.Await(name .. ':access')
    opening = false
    if generationAtOpen ~= generation then return end
    if not allowed or not Bridge.IsLoaded() then
        Bridge.Notify(L(reason or 'error'), 'error')
        return
    end

    local camera, angles = GetGameplayCamCoord(), GetGameplayCamRot(2)
    local yaw, pitch = math.rad(angles.z), math.rad(angles.x)
    local goal = camera + vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)) * 7.0
    local ped = PlayerPedId()
    local test = StartExpensiveSynchronousShapeTestLosProbe(camera.x, camera.y, camera.z, goal.x, goal.y, goal.z, 1, ped, 7)
    local result, hit, point, normal = GetShapeTestResult(test)
    if result ~= 2 or not hit or hit == 0 or #normal < 0.5 or math.abs(normal.z) > 0.25
        or #(GetEntityCoords(ped) - point) > Config.ActionDistance then
        Bridge.Notify(L('find_wall'), 'error')
        return
    end
    open({ position = point, normal = norm(normal) })
end

RegisterCommand(Config.Command, function() CreateThread(placement) end, false)
RegisterKeyMapping(Config.Command, L('command'), 'keyboard', '')

local function change(callback, cb, ...)
    if not form or pending then return cb({ ok = false, message = L('busy') }) end
    local data = form
    pending = true
    local ok, reason = Callback.Await(name .. ':' .. callback, ...)
    pending = false
    if ok or reason == 'changed' then
        nextPoll = 0
        if form == data then
            close()
            Bridge.Notify(L(reason or 'saved'), ok and 'success' or 'warning')
        end
    end
    cb({ ok = ok == true, message = L(reason or 'error') })
end

RegisterNUICallback('save', function(body, cb)
    if not form or type(body) ~= 'table' then return cb({ ok = false, message = L('error') }) end
    change('save', cb, form.id, form.revision, pack(form.position), pack(form.normal), body.content)
end)

RegisterNUICallback('remove', function(_, cb)
    if not form or not form.id then return cb({ ok = false, message = L('error') }) end
    change('remove', cb, form.id, form.revision)
end)

local function remove(id)
    local current = active[id]
    if not current then return end
    if current.target then Bridge.Target.Remove(current.target) end
    PopSurfaces.Destroy(current.display)
    active[id] = nil
end

local function addTarget(row)
    local pos, normal = row.position, row.normal
    local center = pos + normal * 0.10
    local heading = GetHeadingFromVector_2d(normal.x, normal.y)
    return Bridge.Target.AddBoxZone(('%s_%d'):format(name, row.id), center,
        vec3(Config.Size.width, 0.25, Config.Size.height), heading, {
            { label = L('edit'), distance = 1.8, onSelect = function() CreateThread(function() edit(row) end) end }
        })
end

local function add(row, revisionAtPoll)
    local content, revision = Callback.Await(name .. ':content', row.id)
    if revisionAtPoll ~= generation or content == nil or revision ~= row.revision or not Bridge.IsLoaded() then return end
    local display = PopSurfaces.Create(row, content)
    if not display then return end
    active[row.id] = { row = row, display = display, target = row.editable and addTarget(row) or nil }
end

local function refresh()
    local revisionAtPoll = generation
    local rows = Callback.Await(name .. ':nearby')
    if revisionAtPoll ~= generation or type(rows) ~= 'table' or not Bridge.IsLoaded() then return end
    local found = {}
    for _, row in ipairs(rows) do
        row.position = vec3(row.position.x, row.position.y, row.position.z)
        row.normal = vec3(row.normal.x, row.normal.y, row.normal.z)
        found[row.id] = row
    end
    for id, current in pairs(active) do
        local row = found[id]
        if not row or row.revision ~= current.row.revision then
            remove(id)
        elseif row.editable and not current.target then
            current.target = addTarget(row)
        elseif not row.editable and current.target then
            Bridge.Target.Remove(current.target)
            current.target = nil
        end
    end
    for _, row in ipairs(rows) do
        if not active[row.id] and #(GetEntityCoords(PlayerPedId()) - row.position) <= Config.RenderDistance + 2 then
            add(row, revisionAtPoll)
        end
    end
end

CreateThread(function()
    while true do
        if not Bridge.IsLoaded() then
            for id in pairs(active) do remove(id) end
            if form then close() end
            Wait(1500)
        else
            if GetGameTimer() >= nextPoll then
                nextPoll = GetGameTimer() + 2500
                refresh()
            end
            Wait(next(active) and 400 or 1000)
        end
    end
end)

RegisterNetEvent(name .. ':client:unloaded', function()
    if source ~= 65535 then return end
    generation = generation + 1
    for id in pairs(active) do remove(id) end
    if form then close() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= name then return end
    for id in pairs(active) do remove(id) end
    if form then close() end
end)
