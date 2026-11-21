local surfaces, counts, slots, dictionaries = {}, {}, {}, {}
local worker = false

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function vector(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' then return end
    if not (finite(value.x) and finite(value.y) and finite(value.z)) then return end
    if math.abs(value.x) > 10000 or math.abs(value.y) > 10000 or math.abs(value.z) > 10000 then return end
    return vec3(value.x, value.y, value.z)
end

local function safePage(owner, page)
    if not owner:match('^[A-Za-z0-9_-]+$') or type(page) ~= 'string' or #page > 600 then return end
    local localPrefix, httpsPrefix = 'nui://' .. owner .. '/', 'https://cfx-nui-' .. owner .. '/'
    local path
    if page:sub(1, #localPrefix) == localPrefix then
        path = page:sub(#localPrefix + 1)
    elseif page:sub(1, #httpsPrefix) == httpsPrefix then
        path = page:sub(#httpsPrefix + 1)
    end
    if not path then return end
    local file, query = path:match('^([%w_.%/%-]+)(.*)$')
    if not file or file:sub(1, 1) == '/' or file:find('//', 1, true)
        or file:find('..', 1, true) or file:find('/./', 1, true)
        or file:sub(1, 2) == './' or not file:match('%.html?$') then return end
    if query ~= '' and not query:match('^%?[%w_.%%=&+%-]*$') then return end
    return httpsPrefix .. path
end

local function transform(position, normal, width, height)
    position, normal = vector(position), vector(normal)
    if not position or not normal or #normal < 0.01 then return end
    if not (finite(width) and finite(height) and width >= 0.05 and width <= 10 and height >= 0.05 and height <= 10) then
        return
    end
    normal = normal / #normal
    local up = math.abs(normal.z) > 0.98 and vec3(0, 1, 0) or vec3(0, 0, 1)
    local right = cross(up, normal)
    right = right / #right
    up = cross(normal, right) * (height * 0.5)
    right = right * (width * 0.5)
    local center = position + normal * 0.01
    return {
        position = position, normal = normal,
        tl = center - right + up, tr = center + right + up,
        br = center + right - up, bl = center - right - up,
    }
end

local function draw(surface, p)
    local a, b, c, d = p.tl, p.tr, p.br, p.bl
    local txd = surface.name
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, txd, 'page',
        0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0)
    DrawSpritePoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, 255, 255, 255, 255, txd, 'page',
        0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
end

local function prepare(surface)
    if not IsDuiAvailable(surface.dui) then return false end
    if not surface.ready then
        local dict = dictionaries[surface.slot]
        if not dict then
            dict = CreateRuntimeTxd(surface.name)
            dictionaries[surface.slot] = dict
        end
        local texture = CreateRuntimeTextureFromDuiHandle(dict, 'page', GetDuiHandle(surface.dui))
        surface.ready = texture ~= nil and texture ~= 0
    end
    return surface.ready
end

local function schedule()
    if worker then return end
    worker = true
    CreateThread(function()
        while next(slots) do
            local camera, player = GetGameplayCamCoord(), GetEntityCoords(PlayerPedId())
            local delay, hasPlane = 750, false
            for _, surface in pairs(slots) do
                local p = surface.plane
                if p then
                    hasPlane = true
                    local distance = #(player - p.position)
                    if distance <= Config.RenderDistance + 8 then delay = math.min(delay, 200) end
                    if distance <= Config.RenderDistance and dot(camera - p.position, p.normal) > 0
                        and IsSphereVisible(p.position.x, p.position.y, p.position.z, 5.0) and prepare(surface) then
                        draw(surface, p)
                        delay = 0
                    end
                end
            end
            if not hasPlane then break end
            Wait(delay)
        end
        worker = false
    end)
end

local function own(id)
    if type(id) ~= 'string' then return end
    local owner = GetInvokingResource()
    local entries = surfaces[owner]
    return entries and entries[id]
end

local function destroy(surface)
    DestroyDui(surface.dui)
    slots[surface.slot] = nil
    local owner = surface.owner
    surfaces[owner][surface.id] = nil
    counts[owner] = counts[owner] - 1
    if counts[owner] == 0 then
        counts[owner], surfaces[owner] = nil, nil
    end
    return true
end

exports('Create', function(id, options)
    local owner = GetInvokingResource()
    if not owner or type(id) ~= 'string' or #id < 1 or #id > 64 or own(id) or type(options) ~= 'table' then
        return false
    end
    if (counts[owner] or 0) >= Config.MaxPerResource then return false end
    local page = safePage(owner, options.page)
    local width, height = options.width, options.height
    if width == nil then width = 512 end
    if height == nil then height = 512 end
    local w = type(width) == 'number' and math.tointeger(width)
    local h = type(height) == 'number' and math.tointeger(height)
    if not page or not w or not h or w < 32 or h < 32 or w > Config.MaxResolution or h > Config.MaxResolution then
        return false
    end
    local plane
    if options.position ~= nil or options.normal ~= nil or options.worldWidth ~= nil or options.worldHeight ~= nil then
        plane = transform(options.position, options.normal, options.worldWidth, options.worldHeight)
        if not plane then return false end
    end
    for slot = 1, Config.MaxSurfaces do
        if not slots[slot] then
            local dui = CreateDui(page, w, h)
            if not dui or dui == 0 then return false end
            local surface = {
                owner = owner, id = id, slot = slot, plane = plane, dui = dui, width = w, height = h,
                name = ('pop_duiengine_%d'):format(slot),
            }
            surfaces[owner] = surfaces[owner] or {}
            surfaces[owner][id], slots[slot] = surface, surface
            counts[owner] = (counts[owner] or 0) + 1
            if plane then schedule() end
            return true
        end
    end
    return false
end)

exports('GetTexture', function(id)
    local surface = own(id)
    if surface and prepare(surface) then return surface.name, 'page' end
end)

exports('Send', function(id, data)
    local surface = own(id)
    if not surface or type(data) ~= 'table' or not IsDuiAvailable(surface.dui) then return false end
    local ok, text = pcall(json.encode, data)
    if not ok or type(text) ~= 'string' or #text > Config.MessageBytes then return false end
    SendDuiMessage(surface.dui, text)
    return true
end)

exports('Destroy', function(id)
    local surface = own(id)
    return surface ~= nil and destroy(surface)
end)

exports('SetTransform', function(id, position, normal, width, height)
    local surface = own(id)
    if not surface then return false end
    if position == nil then
        surface.plane = nil
        return true
    end
    local plane = transform(position, normal, width, height)
    if not plane then return false end
    surface.plane = plane
    schedule()
    return true
end)

exports('SetUrl', function(id, page)
    local surface = own(id)
    local url = surface and safePage(surface.owner, page)
    if not url then return false end
    SetDuiUrl(surface.dui, url)
    return true
end)

exports('MouseMove', function(id, u, v)
    local surface = own(id)
    if not surface or not IsDuiAvailable(surface.dui) or not finite(u) or not finite(v)
        or u < 0 or u > 1 or v < 0 or v > 1 then return false end
    SendDuiMouseMove(surface.dui, math.floor(u * (surface.width - 1)), math.floor(v * (surface.height - 1)))
    return true
end)

exports('MouseButton', function(id, button, pressed)
    local surface = own(id)
    if not surface or not IsDuiAvailable(surface.dui) or type(pressed) ~= 'boolean'
        or (button ~= 'left' and button ~= 'middle' and button ~= 'right') then return false end
    if pressed then SendDuiMouseDown(surface.dui, button) else SendDuiMouseUp(surface.dui, button) end
    return true
end)

exports('MouseWheel', function(id, delta)
    local surface = own(id)
    delta = type(delta) == 'number' and math.tointeger(delta)
    if not surface or not IsDuiAvailable(surface.dui) or not delta or math.abs(delta) > 1000 then return false end
    SendDuiMouseWheel(surface.dui, delta, 0)
    return true
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, surface in pairs(slots) do destroy(surface) end
    else
        for _, surface in pairs(surfaces[resource] or {}) do destroy(surface) end
    end
end)
