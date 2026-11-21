local current, preview, cam
local opening = false
local generation, requestId = 0, 0
local zones = {}

local function modelOf(ped)
    return ClothesCatalog.Model(GetEntityModel(ped))
end

local function variationExists(ped, category, values)
    local drawable, texture = values[1], values[2]
    if category.native == 'tattoo' then return true end
    if category.native == 'overlay' then return drawable == -1 or drawable < GetPedHeadOverlayNum(category.slot) end
    if category.native == 'prop' then
        if drawable == -1 then return true end
        return drawable < GetNumberOfPedPropDrawableVariations(ped, category.slot)
            and texture < GetNumberOfPedPropTextureVariations(ped, category.slot, drawable)
    end
    if drawable < 0 or drawable >= GetNumberOfPedDrawableVariations(ped, category.slot) then return false end
    return category.native == 'hair' or texture < GetNumberOfPedTextureVariations(ped, category.slot, drawable)
end

local function apply(ped, selections, model)
    if modelOf(ped) ~= model then return end
    local clearTattoos = true
    for _, category in ipairs(Config.Catalog) do
        local option = ClothesCatalog.Option(category.id, selections[category.id], model)
        if option then
            local values = option[model]
            if variationExists(ped, category, values) then
                local slot, drawable, texture = category.slot, values[1], values[2]
                if category.native == 'prop' then
                    if drawable < 0 then ClearPedProp(ped, slot) else SetPedPropIndex(ped, slot, drawable, texture, true) end
                elseif category.native == 'tattoo' then
                    if clearTattoos then ClearPedDecorations(ped) clearTattoos = false end
                    if drawable and texture then AddPedDecorationFromHashes(ped, joaat(drawable), joaat(texture)) end
                elseif category.native == 'overlay' then
                    SetPedHeadOverlay(ped, slot, drawable < 0 and 255 or drawable, 1.0)
                    if drawable >= 0 then SetPedHeadOverlayColor(ped, slot, 1, texture, texture) end
                elseif category.native == 'hair' then
                    SetPedComponentVariation(ped, slot, drawable, 0, 0)
                    SetPedHairColor(ped, texture, texture)
                else
                    SetPedComponentVariation(ped, slot, drawable, texture, 0)
                end
            end
        end
    end
end

local function close(cancel)
    local state = current
    current = nil
    if not state then return end
    if state.focused then SetNuiFocus(false, false) end
    SendNUIMessage({ action = 'pop_clothes:panel', show = false })
    if cam then RenderScriptCams(false, false, 0, true, true) DestroyCam(cam, false) cam = nil end
    if preview then DeleteEntity(preview) preview = nil end
    if cancel and not state.saving then Callback.Trigger('pop_clothes:cancel', function() end, state.token) end
end

local function makePreview(ped, kind)
    preview = ClonePed(ped, false, false, true)
    if preview == 0 then preview = nil return false end
    local position = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.6, 0.0)
    SetEntityCoordsNoOffset(preview, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(preview, GetEntityHeading(ped) + 180.0)
    SetEntityCollision(preview, false, false)
    SetEntityInvincible(preview, true)
    FreezeEntityPosition(preview, true)
    SetBlockingOfNonTemporaryEvents(preview, true)

    local closeUp = kind == 'barber'
    local front = GetOffsetFromEntityInWorldCoords(preview, 0.85, closeUp and 1.15 or 2.7, closeUp and 0.72 or 0.30)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, front.x, front.y, front.z)
    PointCamAtCoord(cam, position.x, position.y, position.z + (closeUp and 0.66 or 0.0))
    SetCamFov(cam, closeUp and 34.0 or 42.0)
    RenderScriptCams(true, false, 0, true, true)
    return true
end

local function visibleOptions(state, ped)
    local list = {}
    for _, category in ipairs(Config.Catalog) do
        if category.kind == state.kind then
            local row = { id = category.id, selected = state.selections[category.id], options = {} }
            for _, option in ipairs(category.options) do
                if ClothesCatalog.Option(category.id, option.id, state.model)
                    and variationExists(ped, category, option[state.model]) then
                    row.options[#row.options + 1] = {
                        id = option.id, label = option.label, price = state.free and 0 or option.price,
                    }
                end
            end
            if #row.options > 0 then list[#list + 1] = row end
        end
    end
    return list
end

local function open(shopId)
    if opening or current or not Bridge.IsLoaded() or IsNuiFocused() or IsEntityDead(PlayerPedId()) then return end
    opening = true
    local revision = generation
    local state, reason = Callback.Await('pop_clothes:open', shopId)
    opening = false
    if revision ~= generation or not Bridge.IsLoaded() then return end
    if not state then Bridge.Notify(L(reason or 'error'), 'error') return end
    if IsNuiFocused() then
        Callback.Trigger('pop_clothes:cancel', function() end, state.token)
        return
    end

    local ped = PlayerPedId()
    current = state
    if modelOf(ped) ~= state.model or not makePreview(ped, state.kind) then
        close(true)
        Bridge.Notify(L('unsupported_model'), 'error')
        return
    end
    apply(preview, state.selections, state.model)
    SendNUIMessage({
        action = 'pop_clothes:panel', show = true, kind = state.kind,
        categories = visibleOptions(state, preview), currency = Config.Currency,
    })
    state.focused = true
    SetNuiFocus(true, true)
    CreateThread(function()
        local deadline = GetGameTimer() + Config.SessionSeconds * 1000
        while current == state do
            Wait(400)
            local activePed = PlayerPedId()
            if current == state and (not Bridge.IsLoaded() or IsEntityDead(activePed) or modelOf(activePed) ~= state.model
                or #(GetEntityCoords(activePed) - Config.Shops[shopId].coords) > Config.ShopDistance
                or GetGameTimer() >= deadline) then
                close(true)
            end
        end
    end)
end

local function refresh()
    requestId = requestId + 1
    local request = requestId
    if current or not Bridge.IsLoaded() then return end
    local revision = generation
    for _ = 1, 5 do
        if current or generation ~= revision or request ~= requestId or not Bridge.IsLoaded() then return end
        local data, reason = Callback.Await('pop_clothes:load')
        if data and generation == revision and request == requestId and Bridge.IsLoaded() and not current then
            apply(PlayerPedId(), data.selections, data.model)
            return
        end
        if reason and reason ~= 'busy' and reason ~= 'unsupported_model' then return end
        Wait(500)
    end
end

RegisterNUICallback('pop_clothes:preview', function(data, cb)
    local state = current
    if not state or state.saving or not preview or type(data) ~= 'table' then return cb(false) end
    local ped = PlayerPedId()
    if modelOf(ped) ~= state.model then return cb(false) end

    local selections = {}
    for id, option in pairs(state.selections) do selections[id] = option end
    local count = 0
    for id, option in pairs(data) do
        count = count + 1
        if count > 32 or not ClothesCatalog.Option(id, option, state.model, state.kind) then return cb(false) end
        selections[id] = option
    end
    ClonePedToTarget(ped, preview)
    apply(preview, selections, state.model)
    cb(true)
end)

RegisterNUICallback('pop_clothes:rotate', function(data, cb)
    local direction = type(data) == 'table' and data.direction
    if preview and (direction == -1 or direction == 1) then
        SetEntityHeading(preview, GetEntityHeading(preview) + direction * 30.0)
    end
    cb(true)
end)

RegisterNUICallback('pop_clothes:buy', function(data, cb)
    local state = current
    if not state or state.saving or type(data) ~= 'table' then return cb(false) end
    state.saving = true
    local revision = generation
    local ok, result = Callback.Await('pop_clothes:buy', state.token, data)
    state.saving = nil
    if not ok then
        if current == state then
            Bridge.Notify(L(result or 'error'), 'error')
            if result == 'session_expired' then close(false) end
        end
        return cb(false)
    end
    if revision == generation and Bridge.IsLoaded() then
        apply(PlayerPedId(), result, state.model)
        Bridge.Notify(L('purchased'), 'success')
    end
    if current == state then close(true) end
    cb(true)
end)

Bridge.OnPlayerLoaded(function()
    generation = generation + 1
    close(true)
    refresh()
end)
RegisterNetEvent('pop_clothes:client:unloaded', function()
    if source ~= 65535 then return end
    generation = generation + 1
    close(false)
end)
AddEventHandler('pop_charcreator:client:applied', function() CreateThread(refresh) end)
AddEventHandler('playerSpawned', function() CreateThread(refresh) end)
exports('Reapply', function() CreateThread(refresh) end)

for index, shop in ipairs(Config.Shops) do
    zones[#zones + 1] = Bridge.Target.AddBoxZone(('pop_clothes_%d'):format(index), shop.coords, vec3(1.4, 1.4, 2.0), 0.0, {
        { label = L(shop.kind), distance = 2.0, onSelect = function() CreateThread(function() open(index) end) end },
    })
end

Bridge.OnUiClose(function() close(true) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    close(false)
    for _, zone in ipairs(zones) do Bridge.Target.Remove(zone) end
end)
