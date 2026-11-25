-- pop_ems : appels d'urgence côté secouriste. Liste reçue du serveur, blips, GPS, touche
-- d'acceptation et panneau NUI 'calls'. Le thread d'affichage ne tourne que s'il y a des appels.

local calls = {}     -- liste reçue (triée du plus récent au plus ancien)
local blips = {}     -- [id] = blip
local streets = {}   -- [id] = nom de rue (calculé une fois)
local displayRunning = false

local function streetOf(id, coords)
    local street = streets[id]
    if not street then
        local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        street = GetStreetNameFromHashKey(s1)
        if street == '' and s2 ~= 0 then street = GetStreetNameFromHashKey(s2) end
        streets[id] = street
    end
    return street
end

local function removeBlip(id)
    local blip = blips[id]
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    blips[id] = nil
end

local function addBlip(call)
    local cfg = Config.Blips.call
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.color)
    SetBlipScale(blip, cfg.scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('call_blip'))
    EndTextCommandSetBlipName(blip)
    blips[call.id] = blip
end

local function sendPanel()
    local pos = GetEntityCoords(PlayerPedId())
    local now = GetCloudTimeAsInt()
    local out = {}
    for i = 1, math.min(#calls, Config.Calls.maxShown) do
        local c = calls[i]
        out[i] = {
            id = c.id,
            street = streetOf(c.id, c.coords),
            distance = math.floor(#(pos - c.coords) + 0.5),
            age = math.max(0, math.floor((now - (c.time or now)) / 60)),
            status = c.status,
            medic = c.medic,
            mine = c.mine == true,
        }
    end
    SendNUIMessage({ action = 'calls', data = { acceptKey = Config.AcceptCallKey, calls = out } })
end

local function startDisplay()
    if displayRunning then return end
    displayRunning = true
    CreateThread(function()
        while #calls > 0 and Ems.onDuty do
            sendPanel()
            Wait(1000)
        end
        displayRunning = false
    end)
end

local function clearAll()
    for id in pairs(blips) do removeBlip(id) end
    calls, streets = {}, {}
    SendNUIMessage({ action = 'calls', data = { acceptKey = Config.AcceptCallKey, calls = {} } })
end

RegisterNetEvent('pop_ems:client:calls', function(list, newId)
    if not Ems.onDuty then return end
    if type(list) ~= 'table' then list = {} end

    local present = {}
    for _, c in ipairs(list) do
        c.coords = vec3(c.coords.x, c.coords.y, c.coords.z)
        present[c.id] = true
        if not blips[c.id] then addBlip(c) end
        SetBlipRoute(blips[c.id], c.mine == true)
    end
    for id in pairs(blips) do
        if not present[id] then
            removeBlip(id)
            streets[id] = nil
        end
    end
    calls = list

    if newId then
        for _, c in ipairs(list) do
            if c.id == newId then
                Bridge.Notify(L('call_new', streetOf(c.id, c.coords)), 'info')
                PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
                break
            end
        end
    end

    if #calls > 0 then
        sendPanel()
        startDisplay()
    else
        SendNUIMessage({ action = 'calls', data = { acceptKey = Config.AcceptCallKey, calls = {} } })
    end
end)

-- Prendre le plus récent appel en attente.
RegisterCommand('pop_ems_accept', function()
    if not Ems.onDuty then return end
    local target
    for _, c in ipairs(calls) do
        if c.status == 'pending' then target = c break end
    end
    if not target then return Bridge.Notify(L('call_none'), 'info') end
    CreateThread(function()
        local ok, data = Ems.Request('pop_ems:acceptCall', target.id)
        if not ok then return Ems.NotifyError(data) end
        SetNewWaypoint(target.coords.x, target.coords.y)
        Bridge.Notify(L('call_taken_you', target.id), 'success')
    end)
end, false)
RegisterKeyMapping('pop_ems_accept', L('keymap_accept'), 'keyboard', Config.AcceptCallKey)

Ems.OnDuty(function(state)
    if not state then clearAll() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(blips) do removeBlip(id) end
end)
