local resource = GetCurrentResourceName()
local dui = 'pop_duiengine'
local objects, targetHandles, screens, loadingModels, retryModels = {}, {}, {}, {}, {}
local current, opening
local generation = 0

local function nearby(coords, terminal, distance)
    return #(coords - terminal.coords) <= distance
end

local function close(fromKit)
    generation = generation + 1
    if not current then return end
    current = nil
    if not fromKit then SetNuiFocus(false, false) end
    SendNUIMessage({ action = 'pop_computer:close' })
end

local function allowedJob(terminal)
    local job = Bridge.GetJob()
    if terminal.onDuty and (not job or not job.onDuty) then return false end
    if not terminal.jobs then return true end
    if not job then return false end
    if type(terminal.jobs) == 'string' then return job.name == terminal.jobs end
    for _, name in ipairs(terminal.jobs) do
        if name == job.name then return true end
    end
    return type(terminal.jobs[job.name]) == 'number' and job.grade >= terminal.jobs[job.name]
end

local function open(index)
    if opening or current or not Bridge.IsLoaded() then return end
    local token = generation
    opening = true
    CreateThread(function()
        local ok, reason, data = Callback.Await('pop_computer:open', index)
        opening = false
        if generation ~= token then return end
        local ped = PlayerPedId()
        local terminal = Config.Terminals[index]
        if not nearby(GetEntityCoords(ped), terminal, Config.InteractionDistance)
            or IsEntityDead(ped) or not Bridge.IsLoaded() or not allowedJob(terminal) then return end
        if not ok or not data then return Bridge.Notify(L(reason or 'error'), 'error') end
        current = index
        data.action, data.terminalId = 'pop_computer:open', index
        SendNUIMessage(data)
        SetNuiFocus(true, true)
    end)
end

local function destroyScreen(index)
    if not screens[index] then return end
    if GetResourceState(dui) == 'started' then
        pcall(function() exports[dui]:Destroy('terminal_' .. index) end)
    end
    screens[index] = nil
end

local function showScreen(index, screen, now)
    if not screen or GetResourceState(dui) ~= 'started' then return end
    local id = 'terminal_' .. index
    if not screens[index] then
        local ok, registered = pcall(function()
            return exports[dui]:Create(id, {
                page = ('https://cfx-nui-%s/web/screen.html'):format(resource),
                width = 512, height = 384,
                position = screen.position, normal = screen.normal,
                worldWidth = screen.worldWidth, worldHeight = screen.worldHeight,
            })
        end)
        if not ok or not registered then return end
        screens[index] = { updateAt = 0 }
    end
    local state = screens[index]
    if now < state.updateAt then return end
    state.updateAt = now + 3000
    pcall(function()
        exports[dui]:Send(id, {
            action = 'pop_computer:screen', title = L('terminal_title'), status = L('terminal_ready'),
            rtl = GetLocaleTable()._rtl == true, accent = Config.AccentColor,
        })
    end)
end

local function removeObject(index)
    local object = objects[index]
    if object and DoesEntityExist(object) then DeleteObject(object) end
    objects[index] = nil
end

local function spawnObject(index, terminal)
    local model = type(terminal.model) == 'number' and terminal.model or joaat(terminal.model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return end
    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if HasModelLoaded(model) and nearby(GetEntityCoords(PlayerPedId()), terminal, Config.StreamDistance) then
        local p = terminal.coords
        local object = CreateObjectNoOffset(model, p.x, p.y, p.z, false, false, false)
        if object ~= 0 then
            SetEntityHeading(object, terminal.heading or 0.0)
            FreezeEntityPosition(object, true)
            objects[index] = object
        end
    end
    SetModelAsNoLongerNeeded(model)
end

local function stream(coords)
    local now = GetGameTimer()
    for index, terminal in ipairs(Config.Terminals) do
        if nearby(coords, terminal, Config.StreamDistance + (objects[index] and 5.0 or 0.0)) then
            if terminal.model and not objects[index] and not loadingModels[index] and now >= (retryModels[index] or 0) then
                retryModels[index] = now + 10000
                loadingModels[index] = true
                CreateThread(function()
                    spawnObject(index, terminal)
                    loadingModels[index] = nil
                end)
            end
            showScreen(index, terminal.screen, now)
        else
            removeObject(index)
            destroyScreen(index)
        end
    end
end

CreateThread(function()
    if #Config.Terminals == 0 then return end
    for index, terminal in ipairs(Config.Terminals) do
        targetHandles[index] = Bridge.Target.AddBoxZone('computer_' .. index, terminal.coords, vec3(0.8, 0.6, 1.0),
            terminal.heading or 0.0, { {
                distance = Config.InteractionDistance - 0.7, label = L('open_terminal'),
                canInteract = function() return Bridge.IsLoaded() and allowedJob(terminal) end,
                onSelect = function() open(index) end,
            } })
    end
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        if current and (IsEntityDead(ped) or not Bridge.IsLoaded() or not allowedJob(Config.Terminals[current])
            or not nearby(coords, Config.Terminals[current], Config.InteractionDistance)) then close() end
        stream(coords)
        Wait(current and 300 or 1250)
    end
end)

Bridge.OnUiClose(function() close(true) end)

AddEventHandler('onClientResourceStop', function(name)
    if name == dui then
        screens = {}
        return
    end
    if name ~= resource then return end
    close()
    for index in ipairs(Config.Terminals) do
        if targetHandles[index] then Bridge.Target.Remove(targetHandles[index]) end
        removeObject(index)
        destroyScreen(index)
    end
end)
