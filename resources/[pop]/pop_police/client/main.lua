Police = Police or {}
Police.state = { officer = false, onDuty = false, grade = 0 }
Police.uiOpen, Police.menuActions = false, {}
local uiPage, civilian
local uiVersion, stateVersion = 0, 0
local blips, targets = {}, {}

local function message(name, data)
    data = data or {}
    data.action = 'pop_police:' .. name
    SendNUIMessage(data)
end

function Police.CloseUi()
    if not Police.uiOpen then return end
    SetNuiFocus(false, false)
    uiVersion = uiVersion + 1
    Police.uiOpen, Police.menuActions, Police.menuTarget, uiPage = false, {}, nil, nil
    message('close')
end
Bridge.OnUiClose(Police.CloseUi)

function Police.RefreshState()
    stateVersion = stateVersion + 1
    local version = stateVersion
    CreateThread(function()
        local state = Callback.Await('pop_police:getState')
        if version ~= stateVersion or type(state) ~= 'table' then return end
        Police.state = state
        if not state.onDuty then Police.CloseUi() end
    end)
end
Bridge.OnPlayerLoaded(Police.RefreshState)
Bridge.OnJobUpdate(Police.RefreshState)
local function unload()
    stateVersion = stateVersion + 1
    Police.state = { officer = false, onDuty = false, grade = 0 }
    civilian = nil
    Police.CloseUi()
end
RegisterNetEvent('esx:onPlayerLogout', unload)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', unload)

AddEventHandler('gameEventTriggered', function(name, data)
    if not Police.uiOpen or name ~= 'CEventNetworkEntityDamage' or data[1] ~= PlayerPedId() then return end
    SetTimeout(0, function()
        if IsEntityDead(PlayerPedId()) then Police.CloseUi() end
    end)
end)
AddStateBagChangeHandler(Police.STATE_DUTY, nil, function(bagName, _, value)
    if bagName ~= 'player:' .. GetPlayerServerId(PlayerId()) then return end
    Police.state.onDuty = value == true
    if not Police.state.onDuty then Police.CloseUi() end
end)

local function available()
    if not Police.state.officer then return false end
    if not Police.state.onDuty then
        Bridge.Notify(L('not_on_duty'), 'error')
        return false
    end
    return not IsEntityDead(PlayerPedId()) and not LocalPlayer.state.cuffed and not Bridge.IsBusy() and not IsPauseMenuActive()
end

local function showPage(page, data)
    uiVersion = uiVersion + 1
    uiPage = page
    data.show, data.theme = true, Config.Theme
    Police.uiOpen = true
    SetNuiFocus(true, true)
    message(page, data)
end

local function openMenu()
    if Police.uiOpen then
        Police.CloseUi()
        return
    end
    if not available() then return end
    local target, ped = Police.GetTarget()
    local actions = {}
    local state = target and Player(target).state
    local cuffed = state and state.cuffed == true
    local vehicle = ped and IsPedInAnyVehicle(ped, false)
    local function add(id) actions[#actions + 1] = id end
    if target and not cuffed and not vehicle then add('cuff') end
    if cuffed then add('uncuff') end
    if cuffed and not vehicle and not Police.escorting and not state[Police.STATE_ESCORT] then add('escort') end
    if Police.escorting then add('stop_escort') end
    if cuffed and not vehicle and Police.GetVehicle() then add('put_in_vehicle') end
    if cuffed and vehicle then add('take_out_vehicle') end
    if target and (cuffed or IsEntityDead(ped)) then add('search') end
    if target then add('fine') end
    add('mdt')
    add('panic')
    add('duty_off')
    Police.menuTarget, Police.menuActions = target, {}
    for _, id in ipairs(actions) do Police.menuActions[id] = true end
    showPage('menu', { target = target and { serverId = target }, actions = actions })
end

RegisterCommand('pop_police_menu', openMenu, false)
RegisterKeyMapping('pop_police_menu', L('keymap_menu'), 'keyboard', Config.KeyMappings.menu)
RegisterCommand('pop_police_panic', function()
    if available() then CreateThread(function() Police.Request('panic') end) end
end, false)
RegisterKeyMapping('pop_police_panic', L('keymap_panic'), 'keyboard', Config.KeyMappings.panic)

RegisterNUICallback('action', function(data, cb)
    local id = type(data) == 'table' and data.id
    if uiPage ~= 'menu' or type(id) ~= 'string' or not Police.menuActions[id] or not available() then
        cb({ ok = false })
        return
    end
    local target = Police.menuTarget
    if id == 'fine' then
        showPage('fineForm', { target = { serverId = target }, amounts = Police.fineAmounts })
    elseif id == 'mdt' then
        showPage('mdt', {})
    else
        Police.CloseUi()
        CreateThread(function() Police.RunAction(id, target) end)
    end
    cb({ ok = true })
end)

local function asInteger(value)
    if type(value) == 'number' or type(value) == 'string' then return math.tointeger(tonumber(value)) end
end

local function nui(name, page, prepare, field)
    RegisterNUICallback(name, function(data, cb)
        if uiPage ~= page or type(data) ~= 'table' or not available() then
            cb({ ok = false, error = 'error' })
            return
        end
        local args = prepare(data)
        if not args then
            cb({ ok = false, error = 'error' })
            return
        end
        local version = uiVersion
        CreateThread(function()
            local ok, reason, result = Police.Request(name, table.unpack(args))
            if ok and uiVersion == version and name == 'fine' then Police.CloseUi() end
            local response = { ok = ok == true, error = not ok and (reason or 'error') or nil }
            if field and ok then response[field] = result end
            cb(response)
        end)
    end)
end

nui('fine', 'fineForm', function(data)
    local option = asInteger(data.option)
    if option and type(data.reason) == 'string' and Police.menuTarget then
        return { Police.menuTarget, option, data.reason }
    end
end)
nui('mdtSearch', 'mdt', function(data)
    if type(data.query) == 'string' then return { data.query } end
end, 'results')
nui('mdtProfile', 'mdt', function(data)
    local citizenId, serverId = asInteger(data.citizenId), asInteger(data.serverId)
    if citizenId and data.serverId == nil then return { { citizenId = citizenId } } end
    if serverId and data.citizenId == nil then return { { serverId = serverId } } end
end, 'profile')
nui('mdtAddNote', 'mdt', function(data)
    local citizenId = asInteger(data.citizenId)
    if citizenId and type(data.text) == 'string' then return { citizenId, data.text } end
end, 'profile')
nui('mdtDeleteNote', 'mdt', function(data)
    local noteId = asInteger(data.noteId)
    if noteId then return { noteId } end
end, 'profile')

local function applyOutfit(ped, outfit)
    for id, item in pairs(outfit.components) do SetPedComponentVariation(ped, id, item[1], item[2], item[3] or 0) end
    for id, item in pairs(outfit.props) do
        if item[1] == -1 then ClearPedProp(ped, id)
        else SetPedPropIndex(ped, id, item[1], item[2], true) end
    end
end

local function wear(outfit)
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if not outfit then
        if not civilian or civilian.ped ~= ped or civilian.model ~= model then
            civilian = nil
            Bridge.Notify(L('no_saved_outfit'), 'error')
            return
        end
        applyOutfit(ped, civilian)
        civilian = nil
    else
        local style = model == joaat('mp_m_freemode_01') and outfit.male
            or model == joaat('mp_f_freemode_01') and outfit.female
        if not style then
            Bridge.Notify(L('outfit_unavailable'), 'error')
            return
        end
        if not civilian or civilian.ped ~= ped or civilian.model ~= model then
            civilian = { ped = ped, model = model, components = {}, props = {} }
            for id = 0, 11 do
                civilian.components[id] = { GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id), GetPedPaletteVariation(ped, id) }
            end
            for _, id in ipairs({ 0, 1, 2, 6, 7 }) do
                civilian.props[id] = { GetPedPropIndex(ped, id), GetPedPropTextureIndex(ped, id) }
            end
        end
        applyOutfit(ped, style)
    end
    Bridge.Notify(L('outfit_changed'), 'success')
end

local function option(label, icon, condition, run)
    return {
        label = L(label), icon = icon, distance = Police.STATION_DISTANCE,
        canInteract = function()
            return not LocalPlayer.state.cuffed and not IsEntityDead(PlayerPedId()) and condition()
        end,
        onSelect = run,
    }
end

CreateThread(function()
    for i, station in ipairs(Config.Stations) do
        local dutyIcon = 'fa-solid fa-id-badge'
        local dutyOptions = {
            option('target_duty_on', dutyIcon, function() return Police.state.officer and not Police.state.onDuty end, function()
                CreateThread(function() Police.Request('setDuty', true, i) end)
            end),
            option('target_duty_off', dutyIcon, function() return Police.state.onDuty end, function()
                CreateThread(function() Police.Request('setDuty', false) end)
            end),
        }
        targets[#targets + 1] = Bridge.Target.AddBoxZone('pop_police_duty_' .. i, station.duty, vec3(1.2, 1.2, 2.0), 0.0, dutyOptions)
        if station.locker then
            local icon, options = 'fa-solid fa-shirt', {}
            for _, outfit in ipairs(Config.Outfits) do
                options[#options + 1] = option(outfit.label, icon, function()
                    return Police.state.onDuty and Police.state.grade >= outfit.grade
                end, function() wear(outfit) end)
            end
            options[#options + 1] = option('target_civilian', icon, function() return Police.state.onDuty end, function() wear() end)
            targets[#targets + 1] = Bridge.Target.AddBoxZone('pop_police_locker_' .. i, station.locker, vec3(1.2, 1.2, 2.0), 0.0, options)
        end
    end
end)

local function alert(data, panic)
    if source ~= 65535 or not Police.state.onDuty or type(data) ~= 'table' or type(data.coords) ~= 'table' then return end
    local coords = data.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    blips[blip] = true
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, panic and 1 or 3)
    SetBlipScale(blip, panic and 1.2 or 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(L(panic and 'panic_blip' or 'alert_blip'))
    EndTextCommandSetBlipName(blip)
    if panic then
        Bridge.Notify(L('panic_alert', data.name), 'error', 10000)
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        PulseBlip(blip)
        SetNewWaypoint(coords.x, coords.y)
    else
        Bridge.Notify(data.text, 'warning', 8000)
    end
    SetTimeout(Config.Panic.blipTime * 1000, function()
        if blips[blip] then RemoveBlip(blip) end
        blips[blip] = nil
    end)
end
RegisterNetEvent('pop_police:client:panic', function(data) alert(data, true) end)
RegisterNetEvent('pop_police:client:alert', function(data) alert(data, false) end)
exports('IsOnDuty', function() return Police.state.onDuty end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Police.CloseUi()
    for blip in pairs(blips) do RemoveBlip(blip) end
    for _, id in ipairs(targets) do Bridge.Target.Remove(id) end
end)
