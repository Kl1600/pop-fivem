PopSurfaces = {}

local name = GetCurrentResourceName()
local slots, dictionaries, byKey = {}, {}, {}
local generation = 0
local worker = false

local function quad(row)
    local position, normal = row.position, row.normal
    local center = position + normal * 0.012
    local right = norm(cross(vec3(0, 0, 1), normal)) * (Config.Size.width / 2)
    local up = norm(cross(normal, right)) * (Config.Size.height / 2)
    return center - right + up, center + right + up, center + right - up, center - right - up
end

local function draw(surface)
    local a, b, c, d = surface.a, surface.b, surface.c, surface.d
    local txd = surface.name
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, txd, 'art',
        0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0)
    DrawSpritePoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, 255, 255, 255, 255, txd, 'art',
        0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
end

local function schedule()
    if worker then return end
    worker = true
    CreateThread(function()
        while next(slots) do
            local player, cam = GetEntityCoords(PlayerPedId()), GetGameplayCamCoord()
            local delay = 250
            for slot, surface in pairs(slots) do
                local pos = surface.row.position
                if #(player - pos) <= Config.RenderDistance and dot(cam - pos, surface.row.normal) > 0
                    and IsSphereVisible(pos.x, pos.y, pos.z, 2.0) and IsDuiAvailable(surface.dui) then
                    if not surface.texture or surface.texture == 0 then
                        local dict = dictionaries[slot] or CreateRuntimeTxd(surface.name)
                        dictionaries[slot] = dict
                        surface.texture = CreateRuntimeTextureFromDuiHandle(dict, 'art', GetDuiHandle(surface.dui))
                    end
                    if surface.texture and surface.texture ~= 0 then
                        draw(surface)
                        delay = 0
                    end
                end
            end
            Wait(delay)
        end
        worker = false
    end)
end

function PopSurfaces.Create(row, content)
    for slot = 1, Config.MaxVisible do
        if not slots[slot] then
            generation = generation + 1
            local key = tostring(generation)
            local url = ('https://cfx-nui-%s/web/display.html?key=%s'):format(name, key)
            local height = math.floor(512 * Config.Size.height / Config.Size.width)
            local dui = CreateDui(url, 512, math.max(128, math.min(1024, height)))
            if not dui or dui == 0 then return end
            local a, b, c, d = quad(row)
            local surface = { slot = slot, key = key, dui = dui, row = row, content = content,
                name = ('%s_surface_%d'):format(name, slot), a = a, b = b, c = c, d = d }
            slots[slot], byKey[key] = surface, surface
            schedule()
            return surface
        end
    end
end

function PopSurfaces.Destroy(surface)
    if not surface or slots[surface.slot] ~= surface then return end
    slots[surface.slot], byKey[surface.key] = nil, nil
    DestroyDui(surface.dui)
end

RegisterNUICallback('surfaceReady', function(body, cb)
    local surface = type(body) == 'table' and type(body.key) == 'string' and byKey[body.key]
    cb(surface and { content = surface.content } or {})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= name then return end
    for _, surface in pairs(slots) do PopSurfaces.Destroy(surface) end
end)
